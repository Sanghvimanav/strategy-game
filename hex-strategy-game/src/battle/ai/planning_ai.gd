extends RefCounted
## Picks actions for AI-controlled units. Works with any unit type.

## Returns {ac: ActionInstance, is_move: bool} or null if no valid action.
static func pick_action(unit: Unit, groups: Array, get_units_at_cell: Callable) -> Dictionary:
	var options: Array = _collect_all_options(unit)
	if options.is_empty():
		return {}
	var enemies: Array = _get_enemy_units(unit, groups)
	# Prefer attack that hits an enemy
	for entry in options:
		if not entry.is_move:
			if _action_hits_enemy(entry.ac, enemies):
				return entry
	# Prefer move toward nearest enemy
	var best_move: Dictionary = {}
	var best_dist := INF
	for entry in options:
		if entry.is_move:
			var d := _dist_to_nearest_enemy(entry.ac.end_point, enemies)
			if d < best_dist:
				best_dist = d
				best_move = entry
	if not best_move.is_empty():
		return best_move
	# Fallback: first option (e.g. Rest)
	return options[0]

static func _collect_all_options(unit: Unit) -> Array:
	var result: Array = []
	var db = unit.abilities_db
	if db == null:
		return []
	for key in unit.def.move_action_keys:
		result.append_array(db.get_options_for_action_key(key))
	for key in unit.def.ability_action_keys:
		result.append_array(db.get_options_for_action_key(key))
	return result

static func _get_enemy_units(unit: Unit, groups: Array) -> Array:
	var my_group: Node = unit.get_parent()
	var enemies: Array = []
	for group in groups:
		if group == my_group:
			continue
		for child in group.get_children():
			if child is Unit and child.is_active:
				enemies.append(child)
	return enemies

static func _action_hits_enemy(ac: ActionInstance, enemies: Array) -> bool:
	var full_path: Array = ac.path + [ac.end_point]
	for e in enemies:
		for cell in full_path:
			if HexGrid.cell_equal(e.cell, cell):
				return true
	# Check AoE (for targeted attacks with area_of_effect)
	var config: Dictionary = Actions.get_action_config(ac.definition.action_key) if ac.definition else {}
	var aoe: Dictionary = config.get("area_of_effect", {})
	if not aoe.is_empty():
		var from_cell: Vector2 = ac.unit.cell
		var aoe_cells: Array = HexGrid.get_aoe_tiles(from_cell, ac.end_point, aoe)
		for aoe_cell in aoe_cells:
			for e in enemies:
				if HexGrid.cell_equal(e.cell, aoe_cell):
					return true
	return false

static func _dist_to_nearest_enemy(cell: Vector2, enemies: Array) -> float:
	if enemies.is_empty():
		return INF
	var min_d := INF
	for e in enemies:
		var d := HexGrid.hex_distance_vec(cell, e.cell)
		if d < min_d:
			min_d = d
	return float(min_d)
