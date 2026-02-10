extends Node

var unit: Unit

func _find_cell_in_path(path: Array, cell: Vector2) -> int:
	for i in path.size():
		if HexGrid.cell_equal(path[i], cell):
			return i
	return -1

func _filter_acs(acs: Array) -> Array:
	var valid: Array = []
	
	for ac in acs:
		if ac.definition.block_mode == ActionDefinition.BlockMode.Ignore:
			valid.append(ac)
			continue
		
		var block = Navigation.get_ac_block_point(ac)

		if block.x == INF:
			valid.append(ac)
			continue
		
		if ac.definition.block_mode == ActionDefinition.BlockMode.TruncateBefore:
			ac.end_point = block
			var idx := _find_cell_in_path(ac.full_path, block)
			if idx >= 0:
				ac.path = ac.full_path.slice(0, idx)
			valid.append(ac)
			continue
		
		if ac.definition.block_mode == ActionDefinition.BlockMode.TruncateOn:
			var idx := _find_cell_in_path(ac.full_path, block)
			if idx >= 0:
				ac.path = ac.full_path.slice(0, idx + 1)
				ac.end_point = ac.path[ac.path.size() - 1]
			valid.append(ac)
	
	return valid

func get_attack_paths() -> Array:
	var defs: Array = unit.def.get_ability_definitions_resolved()
	return _filter_acs(defs.map(func (def): return def.to_action_instance(unit) as ActionInstance))

func get_move_paths() -> Array:
	var defs: Array = unit.def.get_move_definitions_resolved()
	return _filter_acs(defs.map(func (def): return def.to_action_instance(unit) as ActionInstance))

## Returns Array of {ac: ActionInstance, is_move: bool} for a single action key.
func get_options_for_action_key(action_key: String) -> Array:
	var result: Array = []
	if action_key in unit.def.move_action_keys:
		var defs_arr: Array = Actions.get_move_definitions_for_action(action_key)
		for def in defs_arr:
			var ac: ActionInstance = def.to_action_instance(unit) as ActionInstance
			result.append({"ac": ac, "is_move": true})
		return _filter_acs_and_wrap(result)
	if action_key in unit.def.ability_action_keys:
		var config: Dictionary = Actions.get_action_config(action_key)
		var power: int = int(config.get("power_consumption", 0))
		if power > 0 and unit.max_energy > 0 and unit.energy <= 0:
			return []
		var defs_arr: Array = Actions.get_ability_definitions_for_action(action_key)
		for def in defs_arr:
			var ac: ActionInstance = def.to_action_instance(unit) as ActionInstance
			result.append({"ac": ac, "is_move": false})
		return _filter_acs_and_wrap(result)
	return []

func _filter_acs_and_wrap(entries: Array) -> Array:
	var acs: Array = []
	for e in entries:
		acs.append(e.ac)
	var filtered: Array = _filter_acs(acs)
	var is_move_map: Dictionary = {}
	for e in entries:
		is_move_map[e.ac] = e.is_move
	var out: Array = []
	for ac in filtered:
		out.append({"ac": ac, "is_move": is_move_map.get(ac, false)})
	return out
