class_name TurnExecutor
extends RefCounted
## Unified turn execution pipeline. Processes actions by type in ACTION_ORDER.
## Used for both live execution and replay. Add new action types by extending
## _get_handler_for_type and implementing the handler.

const MOVE_TYPES: Array[String] = ["fast move", "move", "slow move"]
const ATTACK_TYPES: Array[String] = ["fast attack", "attack", "slow attack"]
const ATTACK_TIMEOUT: float = 5.0

## Execution context passed through the pipeline.
## apply_damage: if false, animations only (replay mode)
## recording: { actions: [], died_ids: [], summary: [] } - built during execution
class ExecutionContext:
	var groups: Array
	var apply_damage: bool
	var recording: Dictionary
	var stunned_unit_ids: Dictionary = {}
	var damage_by_id: Dictionary = {}
	var get_units_at_cell: Callable
	var tree: SceneTree

	func _init(p_groups: Array, p_apply_damage: bool, p_recording: Dictionary, p_get_units: Callable, p_tree: SceneTree) -> void:
		groups = p_groups
		apply_damage = p_apply_damage
		recording = p_recording
		get_units_at_cell = p_get_units
		tree = p_tree

## Runs the pipeline. actions_by_type: { type -> [{unit, ac, is_move}] }
## Records to ctx.recording when apply_damage is true.
static func run_pipeline(actions_by_type: Dictionary, ctx: ExecutionContext) -> void:
	for action_type in Actions.ACTION_ORDER:
		var entries: Array = actions_by_type.get(action_type, [])
		if not entries.is_empty():
			print("[EXEC] pipeline processing: ", action_type, " count=", entries.size())
		var filtered: Array = []
		for entry in entries:
			var uid: int = entry.unit.get_instance_id()
			var disabled: Array = ctx.stunned_unit_ids.get(uid, [])
			if action_type in disabled:
				continue
			filtered.append(entry)
		if filtered.is_empty():
			continue
		var handler := _get_handler_for_type(action_type)
		if handler.is_valid():
			await handler.call(action_type, filtered, ctx)
			print("[EXEC] pipeline done with ", action_type)

## Returns Callable for the given action type, or invalid for no-op types.
static func _get_handler_for_type(action_type: String) -> Callable:
	if action_type in MOVE_TYPES:
		return _handle_moves
	if action_type in ATTACK_TYPES:
		return _handle_attacks
	if action_type == "stun":
		return _handle_stun
	if action_type == "reload":
		return _handle_reload
	# spawn, extract: no-op
	return Callable()

static func _handle_reload(_action_type: String, entries: Array, ctx: ExecutionContext) -> void:
	for entry in entries:
		var u = entry.unit
		if not _valid_unit(u):
			continue
		if ctx.apply_damage:
			ctx.recording.actions.append({ "type": "reload", "unit": u })

static func _handle_moves(action_type: String, entries: Array, ctx: ExecutionContext) -> void:
	for entry in entries:
		var u = entry.unit
		if not _valid_unit(u) or not entry.is_move:
			print("[EXEC] _handle_moves skip unit or not move")
			continue
		print("[EXEC] _handle_moves moving ", u.def.name)
		var ac: ActionInstance = entry.ac
		var from_cell: Vector2 = u.cell
		u.move_along_path(ac.path + [ac.end_point])
		await u.movement_complete
		if ctx.apply_damage:
			ctx.recording.actions.append({ "type": "move", "unit": u, "from_cell": from_cell, "path": ac.path + [ac.end_point] })

static func _handle_attacks(action_type: String, entries: Array, ctx: ExecutionContext) -> void:
	for entry in entries:
		var attacker = entry.unit
		if not _valid_unit(attacker):
			print("[EXEC] _handle_attacks skip invalid unit")
			continue
		var ac: ActionInstance = entry.ac
		print("[EXEC] _handle_attacks calling attack for ", attacker.def.name)
		if ac.definition and Actions.get_action_config(ac.definition.action_key).get("pattern", "") == "self":
			entry.ac = ac.definition.to_action_instance(attacker)
			ac = entry.ac
		attacker.attack(ac)
		var done_flag: Array = [false]
		attacker.attack_complete.connect(func(): done_flag[0] = true, CONNECT_ONE_SHOT)
		var timeout := ctx.tree.create_timer(ATTACK_TIMEOUT)
		timeout.timeout.connect(func(): done_flag[0] = true, CONNECT_ONE_SHOT)
		while not done_flag[0]:
			await ctx.tree.process_frame
		print("[EXEC] _handle_attacks attack complete for ", attacker.def.name)
	for entry in entries:
		if not ctx.apply_damage:
			continue
		var attacker = entry.unit
		var ac: ActionInstance = entry.ac
		var config: Dictionary = Actions.get_action_config(ac.definition.action_key) if ac.definition else {}
		var full_path := ac.path + [ac.end_point]
		var attacker_group: Node = attacker.get_parent()
		var action_key: String = ac.definition.action_key if ac.definition else ""
		var is_passive: bool = action_key in attacker.def.passive_action_keys
		var dealt_damage := false
		for cell in full_path:
			for group in ctx.groups:
				for child in group.get_children():
					if child is Unit and HexGrid.cell_equal(child.cell, cell) and child != attacker:
						if child.get_parent() == attacker_group:
							continue  # Same group = ally, don't damage
						dealt_damage = true
						var uid: int = child.get_instance_id()
						ctx.damage_by_id[uid] = ctx.damage_by_id.get(uid, 0) + 1
		# AoE damage: from = attacker cell, target = ac.end_point
		var aoe: Dictionary = config.get("area_of_effect", {})
		if not aoe.is_empty():
			var from_cell: Vector2 = attacker.cell
			var target_cell: Vector2 = ac.end_point
			var aoe_cells: Array = HexGrid.get_aoe_tiles(from_cell, target_cell, aoe)
			for aoe_cell in aoe_cells:
				for group in ctx.groups:
					for child in group.get_children():
						if child is Unit and HexGrid.cell_equal(child.cell, aoe_cell) and child != attacker:
							if child.get_parent() == attacker_group:
								continue  # Same group = ally, don't damage
							dealt_damage = true
							var uid: int = child.get_instance_id()
							ctx.damage_by_id[uid] = ctx.damage_by_id.get(uid, 0) + 1
		if config.get("self_damage", false):
			dealt_damage = true
			var uid: int = attacker.get_instance_id()
			var self_dmg: int = int(config.get("self_damage_amount", 999))
			ctx.damage_by_id[uid] = ctx.damage_by_id.get(uid, 0) + self_dmg
		if ctx.apply_damage:
			var should_record := not is_passive or dealt_damage
			if should_record:
				ctx.recording.actions.append({ "type": "attack", "unit": attacker, "ac": ac })
			if dealt_damage and is_passive:
				var causers: Dictionary = ctx.recording.get("damage_causers", {})
				var key := "%d_%s" % [attacker.get_instance_id(), action_key]
				causers[key] = true
				ctx.recording["damage_causers"] = causers

static func _handle_stun(action_type: String, entries: Array, ctx: ExecutionContext) -> void:
	for entry in entries:
		var attacker = entry.unit
		if not _valid_unit(attacker):
			continue
		var ac: ActionInstance = entry.ac
		var config: Dictionary = Actions.get_action_config(ac.definition.action_key)
		var disable_actions: Array = config.get("disable_actions", ["move", "attack"])
		var target_cell: Vector2 = attacker.cell
		var targets: Array = ctx.get_units_at_cell.call(target_cell)
		for target in targets:
			if target == attacker:
				continue
			if target.get_parent() == attacker.get_parent():
				continue
			var uid: int = target.get_instance_id()
			var existing: Array = ctx.stunned_unit_ids.get(uid, [])
			for dt in disable_actions:
				if dt not in existing:
					existing.append(dt)
			ctx.stunned_unit_ids[uid] = existing

static func _valid_unit(u) -> bool:
	return is_instance_valid(u) and u.is_active

## Replay: runs recorded actions (animations only, no damage).
## recording_actions: Array of { type: "move"|"attack", unit, from_cell?, path?, ac? }
static func run_replay(recording_actions: Array, tree: SceneTree) -> void:
	for action in recording_actions:
		if action.type == "move":
			var u = action.unit
			if not _valid_unit(u):
				continue
			u.global_position = Navigation.cell_to_world(action.from_cell, true)
			u.move_along_path(action.path)
			await u.movement_complete
		elif action.type == "attack":
			var attacker = action.unit
			if not _valid_unit(attacker):
				continue
			var ac: ActionInstance = action.ac
			var fresh_ac := ActionInstance.new(ac.definition, attacker)
			fresh_ac.path = ac.path.duplicate()
			fresh_ac.end_point = ac.end_point
			attacker.attack(fresh_ac)
			var done_flag: Array = [false]
			attacker.attack_complete.connect(func(): done_flag[0] = true, CONNECT_ONE_SHOT)
			var timeout := tree.create_timer(ATTACK_TIMEOUT)
			timeout.timeout.connect(func(): done_flag[0] = true, CONNECT_ONE_SHOT)
			while not done_flag[0]:
				await tree.process_frame
