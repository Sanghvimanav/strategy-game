class_name UnitsContainer
extends Node2D

const BattlePhase = preload("res://src/battle/battle_phase.gd")
const TurnExecutor = preload("res://src/battle/turn_executor.gd")
const PlanningAI = preload("res://src/battle/ai/planning_ai.gd")
const UNIT_SCENE := preload("res://src/unit/unit.tscn")

var groups: Array = []
var ai_group_names: Array[String] = []
var battle_phase: BattlePhase.Phase = BattlePhase.Phase.PLANNING
var planning_unit_index: int = 0
var current_unit: Unit
var current_acs: Array  # Array of { ac: ActionInstance, is_move: bool }
var selected_action_key: String = ""
var turn_number: int = 1

var last_turn_recording: Dictionary = {}  # { actions: [], died_ids: [], summary: [] }

func _ready() -> void:
	_refresh_groups()
	EventBus.execute_turn_requested.connect(_on_execute_turn_requested)
	EventBus.replay_turn_requested.connect(_on_replay_turn_requested)
	EventBus.unit_pick_requested.connect(_on_unit_pick_requested)
	EventBus.action_key_selected.connect(_on_action_key_selected)

func _on_action_key_selected(action_key: String) -> void:
	selected_action_key = action_key
	_build_combined_acs()
	# Auto-commit if exactly one option and it's a self-target (e.g. Rest) - no tile click needed
	if current_unit and current_acs.size() == 1:
		var entry = current_acs[0]
		if HexGrid.cell_equal(entry.ac.end_point, current_unit.cell):
			_store_planned_action(current_unit, entry.ac, entry.is_move)
			_advance_planning()
			selected_action_key = ""
			EventBus.action_key_selected.emit("")

func _on_execute_turn_requested() -> void:
	if battle_phase == BattlePhase.Phase.PLANNING and _all_units_have_planned_action():
		_execute_planned_actions()

func _refresh_groups() -> void:
	groups.clear()
	for child in get_children():
		groups.append(child)

## Apply a scenario: clear group children and spawn units from scenario spec.
func apply_scenario(scenario: Dictionary) -> void:
	if scenario.is_empty():
		return
	ai_group_names.clear()
	var randomize_pos: bool = scenario.get("randomize_positions", false)
	for group_spec in scenario.get("groups", []):
		var group_name: String = group_spec.get("name", "")
		if group_spec.get("ai", false):
			ai_group_names.append(group_name)
		var group_node := get_node_or_null(group_name)
		if group_node == null:
			group_node = Node2D.new()
			group_node.name = group_name
			group_node.y_sort_enabled = true
			add_child(group_node)
		for c in group_node.get_children():
			group_node.remove_child(c)
			c.queue_free()
		var units_list: Array = group_spec.get("units", [])
		var cell_pool: Array = group_spec.get("cell_pool", [])
		if randomize_pos and cell_pool.size() >= units_list.size():
			cell_pool = cell_pool.duplicate()
			cell_pool.shuffle()
		for i in units_list.size():
			var u_spec = units_list[i]
			var def_path: String = u_spec.get("def_path", "") if u_spec is Dictionary else ""
			if def_path.is_empty():
				continue
			var cell: Vector2i
			if randomize_pos and i < cell_pool.size():
				cell = cell_pool[i] if cell_pool[i] is Vector2i else Vector2i(cell_pool[i].x, cell_pool[i].y)
			elif u_spec is Dictionary and u_spec.has("cell"):
				cell = u_spec.get("cell", Vector2i.ZERO)
			else:
				cell = Vector2i.ZERO
			var def: UnitDefinition = load(def_path) as UnitDefinition
			if def == null:
				continue
			var unit: Unit = UNIT_SCENE.instantiate() as Unit
			unit.def = def
			unit.starting_cell = cell
			group_node.add_child(unit)
	_refresh_groups()

func start_battle() -> void:
	turn_number = 1
	battle_phase = BattlePhase.Phase.PLANNING
	_clear_all_planned_actions()
	last_turn_recording = {}
	EventBus.turn_changed.emit(turn_number)
	EventBus.replay_available_changed.emit(false)
	_begin_planning()

func get_active_units() -> Array[Unit]:
	var units: Array[Unit] = []
	for group in groups:
		for child in group.get_children():
			if child is Unit and child.is_active:
				units.append(child)
	return units

func get_all_units() -> Array[Unit]:
	var units: Array[Unit] = []
	for group in groups:
		for child in group.get_children():
			if child is Unit:
				units.append(child)
	return units

func _clear_all_planned_actions() -> void:
	for u in get_active_units():
		u.planned_action = null

func _unhandled_input(event: InputEvent) -> void:
	if battle_phase == BattlePhase.Phase.EXECUTING:
		return

	if event is InputEventMouseMotion:
		var cell = Navigation.world_to_cell(get_global_mouse_position())
		var match_ac = null
		for entry in current_acs:
			if HexGrid.cell_equal(cell, entry.ac.end_point):
				match_ac = entry.ac
				break
		var from_cell := current_unit.cell if current_unit else Vector2.ZERO
		EventBus.show_move_path.emit(match_ac, from_cell)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell = Navigation.world_to_cell(get_global_mouse_position())
		for entry in current_acs:
			if HexGrid.cell_equal(cell, entry.ac.end_point):
				_store_planned_action(current_unit, entry.ac, entry.is_move)
				_advance_planning()
				return
		# No action selected: allow clicking a unit to select it for planning
		if selected_action_key.is_empty():
			var units_at_cell = _get_units_at_cell_for_planning(cell)
			if units_at_cell.size() > 1:
				EventBus.show_units_panel.emit(units_at_cell)
			elif units_at_cell.size() == 1:
				_select_unit_for_planning(units_at_cell[0])
				return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if _all_units_have_planned_action():
				_execute_planned_actions()
		elif event.keycode == KEY_TAB:
			_cycle_planning_unit(1 if not event.shift_pressed else -1)

func _store_planned_action(unit: Unit, ac: ActionInstance, is_move: bool) -> void:
	unit.planned_action = ac
	unit.planned_action_is_move = is_move

func _all_units_have_planned_action() -> bool:
	var active = get_active_units()
	if active.is_empty():
		return false
	for u in active:
		if u.planned_action == null:
			return false
	return true

func _begin_planning() -> void:
	battle_phase = BattlePhase.Phase.PLANNING
	_clear_all_planned_actions()
	planning_unit_index = 0
	EventBus.planning_started.emit()
	_select_planning_unit()

func _get_unit_at_cell(cell: Vector2) -> Unit:
	var units = _get_units_at_cell_for_planning(cell)
	return units[0] if units.size() > 0 else null

## Returns all active units at cell (player + opponent) for planning/selection.
func _get_units_at_cell_for_planning(cell: Vector2) -> Array:
	var result: Array = []
	for u in get_active_units():
		if HexGrid.cell_equal(u.cell, cell):
			result.append(u)
	return result

func _select_unit_for_planning(unit: Unit) -> void:
	var active = get_active_units()
	var idx = active.find(unit)
	if idx >= 0:
		planning_unit_index = idx
		_select_planning_unit()
		if _all_units_have_planned_action():
			EventBus.planning_complete.emit()

func _cycle_planning_unit(delta: int) -> void:
	var active = get_active_units()
	if active.is_empty():
		return
	planning_unit_index = wrapi(planning_unit_index + delta, 0, active.size())
	_select_planning_unit()
	if _all_units_have_planned_action():
		EventBus.planning_complete.emit()

func _advance_planning() -> void:
	var active = get_active_units()
	if active.is_empty():
		return
	# Find next unit without a planned action (wrap from current index)
	var start_idx := planning_unit_index + 1
	for i in active.size():
		var idx := (start_idx + i) % active.size()
		if active[idx].planned_action == null:
			planning_unit_index = idx
			_select_planning_unit()
			return
	# All units have planned actions
	EventBus.planning_complete.emit()

func _select_planning_unit() -> void:
	var active = get_active_units()
	if active.is_empty():
		current_unit = null
		current_acs = []
		selected_action_key = ""
		_update_highlights()
		EventBus.unit_selected_for_planning.emit(null)
		return
	current_unit = active[planning_unit_index]
	var unit_group_name: String = current_unit.get_parent().name if current_unit.get_parent() else ""
	if unit_group_name in ai_group_names:
		_run_ai_planning()
		return
	selected_action_key = ""
	EventBus.unit_selected_for_planning.emit(current_unit)
	_build_combined_acs()

func _run_ai_planning() -> void:
	var entry = PlanningAI.pick_action(current_unit, groups, _get_units_at_cell_for_planning)
	if entry.is_empty():
		# No valid action (shouldn't happen) - pick Rest if available
		var options = current_unit.abilities_db.get_options_for_action_key("reload")
		if options.is_empty():
			for key in current_unit.def.move_action_keys:
				options = current_unit.abilities_db.get_options_for_action_key(key)
				if not options.is_empty():
					break
		if not options.is_empty():
			entry = options[0]
	if not entry.is_empty():
		_store_planned_action(current_unit, entry.ac, entry.is_move)
	_advance_planning()

func _build_combined_acs() -> void:
	current_acs = []
	if current_unit == null:
		_update_highlights()
		return
	# Only show options when an action is selected
	if not selected_action_key.is_empty():
		var options = current_unit.abilities_db.get_options_for_action_key(selected_action_key)
		current_acs.assign(options)
	_update_highlights()

func _update_highlights() -> void:
	EventBus.show_move_path.emit(null, Vector2.ZERO)
	if current_unit != null:
		EventBus.show_selected_unit_cell.emit(current_unit.cell)
	else:
		EventBus.show_selected_unit_cell.emit(null)
	if current_acs.is_empty():
		EventBus.show_move_acs.emit([])
		EventBus.show_attack_acs.emit([], Vector2.ZERO)
		return
	var move_acs: Array = []
	var attack_acs: Array = []
	for entry in current_acs:
		if entry.is_move:
			move_acs.append(entry.ac)
		else:
			attack_acs.append(entry.ac)
	EventBus.show_move_acs.emit(move_acs)
	EventBus.show_attack_acs.emit(attack_acs, current_unit.cell)

func _finish_turn_after_execution() -> void:
	print("[EXEC] _finish_turn_after_execution START turn=", turn_number)
	_clear_all_planned_actions()
	turn_number += 1
	print("[EXEC] _finish_turn_after_execution DONE, starting turn ", turn_number)
	EventBus.turn_changed.emit(turn_number)
	EventBus.replay_available_changed.emit(true)
	_begin_planning()

func _execute_planned_actions() -> void:
	print("[EXEC] _execute_planned_actions START")
	battle_phase = BattlePhase.Phase.EXECUTING
	EventBus.unit_selected_for_planning.emit(null)
	EventBus.show_selected_unit_cell.emit(null)
	EventBus.show_move_path.emit(null, Vector2.ZERO)
	EventBus.show_move_acs.emit([])
	_record_turn_before_execution()
	await _run_planned_actions_phase3()
	print("[EXEC] _run_planned_actions_phase3 DONE, calling _finish_turn_after_execution")
	call_deferred("_finish_turn_after_execution")

func _record_turn_before_execution() -> void:
	last_turn_recording = { "actions": [], "died_ids": [], "summary": [], "before_state": {}, "damage_causers": {} }
	var active = get_active_units()
	for u in active:
		var s: Dictionary = { "cell": u.cell, "health": u.health }
		if u.max_energy > 0:
			s["energy"] = u.energy
		last_turn_recording.before_state[u.get_instance_id()] = s
	for u in active:
		if not u.is_active:
			continue
		if u.planned_action != null:
			var ac: ActionInstance = u.planned_action
			var action_name: String = ac.definition.display_name if ac.definition.display_name else "Action"
			last_turn_recording.summary.append({ "unit_name": u.def.name, "action_name": action_name, "instance_id": u.get_instance_id() })
		for def in u.def.get_passive_ability_definitions_resolved():
			if Actions.get_action_type(def.action_key) == "stun":
				continue
			var action_name: String = def.display_name if def.display_name else "Passive"
			last_turn_recording.summary.append({ "unit_name": u.def.name, "action_name": action_name, "instance_id": u.get_instance_id(), "action_key": def.action_key, "is_passive": true })

func _filter_passive_summary_entries() -> void:
	var causers: Dictionary = last_turn_recording.get("damage_causers", {})
	var filtered: Array = []
	for entry in last_turn_recording.summary:
		if entry.get("is_passive", false):
			var key := "%d_%s" % [entry.instance_id, entry.get("action_key", "")]
			if not causers.get(key, false):
				continue
		filtered.append(entry)
	last_turn_recording.summary = filtered

func _on_unit_pick_requested(unit: Unit) -> void:
	_select_unit_for_planning(unit)

func _on_replay_turn_requested() -> void:
	if battle_phase != BattlePhase.Phase.PLANNING or last_turn_recording.is_empty():
		return
	var summary_lines: Array = []
	var died_ids: Array = last_turn_recording.get("died_ids", [])
	for entry in last_turn_recording.get("summary", []):
		var suffix := " (eliminated)" if entry.instance_id in died_ids else ""
		summary_lines.append("%s: %s%s" % [entry.unit_name, entry.action_name, suffix])
	EventBus.show_replay_summary.emit(summary_lines)
	_replay_last_turn()

func _replay_last_turn() -> void:
	battle_phase = BattlePhase.Phase.EXECUTING
	EventBus.unit_selected_for_planning.emit(null)
	EventBus.show_selected_unit_cell.emit(null)
	EventBus.show_move_path.emit(null, Vector2.ZERO)
	_restore_before_state(last_turn_recording.get("before_state", {}))
	var actions: Array = last_turn_recording.get("actions", [])
	await TurnExecutor.run_replay(actions, get_tree())
	var damage_by_id: Dictionary = last_turn_recording.get("damage_by_id", {})
	var units_that_will_die: Array = []
	for uid in damage_by_id:
		var unit = instance_from_id(uid as int)
		if is_instance_valid(unit):
			unit.health -= damage_by_id[uid]
			if unit.health <= 0:
				units_that_will_die.append(unit)
	var to_await := units_that_will_die.filter(func(u): return is_instance_valid(u))
	if not to_await.is_empty():
		var completed_arr := [0]
		var total := to_await.size()
		for unit in to_await:
			unit.death_animation_complete.connect(func(): completed_arr[0] += 1, CONNECT_ONE_SHOT)
		var timeout := get_tree().create_timer(5.0)
		while completed_arr[0] < total:
			await get_tree().process_frame
			if timeout.time_left <= 0:
				for u in to_await:
					if is_instance_valid(u):
						u.visible = false
				break
	await get_tree().process_frame
	battle_phase = BattlePhase.Phase.PLANNING
	EventBus.replay_finished.emit()

func _restore_before_state(before_state: Dictionary) -> void:
	for uid in before_state:
		var unit = instance_from_id(uid as int)
		if is_instance_valid(unit) and unit is Unit:
			var s: Dictionary = before_state[uid]
			var energy_val: int = s.get("energy", -1)
			unit.restore_state(s.cell, s.health, energy_val)

## Restore to start of last turn (for future undo). Same as replay restore but without re-executing.
func undo_last_turn() -> void:
	if last_turn_recording.is_empty():
		return
	_restore_before_state(last_turn_recording.get("before_state", {}))
	for u in get_all_units():
		u.planned_action = null

func _run_planned_actions_phase3() -> void:
	print("[EXEC] _run_planned_actions_phase3 START")
	var actions_by_type := _collect_actions(get_active_units())
	var ctx := TurnExecutor.ExecutionContext.new(
		groups,
		true,
		last_turn_recording,
		_get_units_at_cell_for_planning,
		get_tree()
	)
	await TurnExecutor.run_pipeline(actions_by_type, ctx)
	print("[EXEC] pipeline DONE")

	var damage_by_id: Dictionary = ctx.damage_by_id
	last_turn_recording["damage_by_id"] = damage_by_id.duplicate()
	_filter_passive_summary_entries()
	var units_that_will_die: Array = []
	for uid in damage_by_id:
		var unit = instance_from_id(uid as int)
		if is_instance_valid(unit) and unit.health - damage_by_id[uid] <= 0:
			units_that_will_die.append(unit)
			last_turn_recording.died_ids.append(uid)
	for uid in damage_by_id:
		var unit = instance_from_id(uid as int)
		if is_instance_valid(unit):
			unit.health -= damage_by_id[uid]

	var to_await := units_that_will_die.filter(func(u): return is_instance_valid(u))
	if not to_await.is_empty():
		var completed_arr := [0]
		var total := to_await.size()
		for unit in to_await:
			unit.death_animation_complete.connect(func(): completed_arr[0] += 1, CONNECT_ONE_SHOT)
		var timeout := get_tree().create_timer(5.0)
		while completed_arr[0] < total:
			await get_tree().process_frame
			if timeout.time_left <= 0:
				for u in to_await:
					if is_instance_valid(u):
						u.visible = false
				break
	print("[EXEC] death anims DONE")
	await get_tree().process_frame
	print("[EXEC] after process_frame")
	var active := get_active_units()
	print("[EXEC] clearing planned_action for ", active.size(), " units")
	for u in active:
		u.planned_action = null
	print("[EXEC] planned_action cleared")

## Collects planned + passive actions from units, grouped by type.
func _collect_actions(active: Array) -> Dictionary:
	var actions_by_type: Dictionary = {}
	for t in Actions.ACTION_ORDER:
		actions_by_type[t] = []
	for u in active:
		if not u.is_active:
			continue
		if u.planned_action != null:
			var ac: ActionInstance = u.planned_action
			var key: String = ac.definition.action_key if ac.definition else ""
			var atype: String = Actions.get_action_type(key)
			if not atype.is_empty():
				actions_by_type[atype] = actions_by_type.get(atype, []) + [{"unit": u, "ac": ac, "is_move": u.planned_action_is_move}]
		for def in u.def.get_passive_ability_definitions_resolved():
			var pac: ActionInstance = def.to_action_instance(u)
			var patype: String = Actions.get_action_type(def.action_key)
			if not patype.is_empty():
				actions_by_type[patype] = actions_by_type.get(patype, []) + [{"unit": u, "ac": pac, "is_move": false}]
	return actions_by_type

## Execute an arbitrary turn spec. Use for replays, tests, or custom scenarios.
## spec: { units: Array, positions: Dictionary, actions: Dictionary }
##   positions: optional, unit_id -> Vector2 cell. Units teleported before execution.
##   actions: optional, pre-built actions_by_type. If empty, uses units' planned_action + passives.
func execute_turn_spec(spec: Dictionary) -> Dictionary:
	var units: Array = spec.get("units", [])
	var positions: Dictionary = spec.get("positions", {})
	var actions_by_type: Dictionary = spec.get("actions", {})
	if actions_by_type.is_empty():
		actions_by_type = _collect_actions(units)
	for u in units:
		var uid = u.get_instance_id()
		if positions.has(uid):
			u.global_position = Navigation.cell_to_world(positions[uid], true)
	var recording := { "actions": [], "died_ids": [], "summary": [] }
	var ctx := TurnExecutor.ExecutionContext.new(
		groups,
		true,
		recording,
		_get_units_at_cell_for_planning,
		get_tree()
	)
	await TurnExecutor.run_pipeline(actions_by_type, ctx)
	var units_that_will_die: Array = []
	for uid in ctx.damage_by_id:
		var unit = instance_from_id(uid as int)
		if is_instance_valid(unit):
			unit.health -= ctx.damage_by_id[uid]
			if unit.health <= 0:
				units_that_will_die.append(unit)
				recording.died_ids.append(uid)
	var to_await := units_that_will_die.filter(func(u): return is_instance_valid(u))
	if not to_await.is_empty():
		var completed_arr := [0]
		var total := to_await.size()
		for unit in to_await:
			unit.death_animation_complete.connect(func(): completed_arr[0] += 1, CONNECT_ONE_SHOT)
		while completed_arr[0] < total:
			await get_tree().process_frame
	await get_tree().process_frame
	for u in units:
		u.planned_action = null
	return recording
