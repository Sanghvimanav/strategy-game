extends Node
## Central registry of action definitions, similar to server3.js ACTIONS.
## Maps action keys (e.g. 'move_short') to hex grid ActionDefinitions.
## Unit definitions reference action keys; this file generates the concrete paths.

const HexGridType = preload("res://src/global/hex_grid.gd")
const ActionDefinition = preload("res://src/unit/action_definition.gd")

## Action configs mirror server3.js: key, type, name, minRange, maxRange, blockMode, etc.
const ACTION_CONFIGS: Dictionary = {
	"move_short": {
		key = "move_short",
		type = "move",
		name = "Move",
		min_range = 1,
		max_range = 1,
		color = "#0000FF",
		power_consumption = 0,
		block_mode = 3,  # Ignore - simultaneous turns, don't block by units in path
	},
	"move_long": {
		key = "move_long",
		type = "move",
		name = "Dash",
		min_range = 2,
		max_range = 2,
		color = "#0000FF",
		power_consumption = 2,
		block_mode = 3,  # Ignore
	},
	"fast_move": {
		key = "fast_move",
		type = "fast move",
		name = "Fast Move",
		min_range = 1,
		max_range = 1,
		color = "#0000FF",
		power_consumption = 0,
		block_mode = 3,
	},
	"slow_move": {
		key = "slow_move",
		type = "slow move",
		name = "Slow Move",
		min_range = 1,
		max_range = 1,
		color = "#0000FF",
		power_consumption = 0,
		block_mode = 3,
	},
	"attack_short": {
		key = "attack_short",
		type = "attack",
		name = "Attack",
		min_range = 1,
		max_range = 1,
		color = "#FF0000",
		power_consumption = 1,
		block_mode = 3,  # Ignore (can attack through)
		area_of_effect = {
			directions = [2],  # Relative direction from attack direction (server3: directions: [2])
			distance = 1,
		},
	},
	"attack_long": {
		key = "attack_long",
		type = "attack",
		name = "Long Attack",
		min_range = 2,
		max_range = 2,
		color = "#FF0000",
		power_consumption = 2,
		block_mode = 3,
	},
	"attack_ray": {
		key = "attack_ray",
		type = "attack",
		name = "Shoot",
		pattern = "ray",
		min_range = 1,
		max_range = 4,
		color = "#FF0000",
		power_consumption = 2,
		block_mode = 3,  # Ignore - simultaneous turns
	},
	"attack_area_adjacent": {
		key = "attack_area_adjacent",
		type = "attack",
		name = "Flame Burst",
		pattern = "area_adjacent",
		color = "#FF6600",
		power_consumption = 2,
		block_mode = 3,  # Ignore - hits all adjacent
	},
	"attack_passive": {
		key = "attack_passive",
		type = "fast attack",
		name = "Passive Attack",
		pattern = "self",
		color = "#FF4444",
		power_consumption = 0,
		block_mode = 3,
	},
	"stun": {
		key = "stun",
		type = "stun",
		name = "Stun",
		pattern = "self",
		color = "#FF69B4",
		power_consumption = 0,
		block_mode = 3,
		disable_actions = ["move", "attack"],
	},
	"explode": {
		key = "explode",
		type = "slow attack",
		name = "Explode",
		pattern = "area_adjacent",
		color = "#FF69B4",
		power_consumption = 0,
		block_mode = 3,
		self_damage = true,  # Baneling dies when exploding (server3: self: true)
	},
	"reload": {
		key = "reload",
		type = "reload",
		name = "Rest",
		min_range = 0,
		max_range = 0,
		color = "#9C27B0",
		power_consumption = -1,
		block_mode = 3,
	},
}

## Processing order matching server3.js actionOrder
const ACTION_ORDER: Array[String] = [
	"fast move", "fast attack", "stun", "move", "attack",
	"slow move", "slow attack", "spawn", "reload", "extract"
]

func get_action_config(action_key: String) -> Dictionary:
	return ACTION_CONFIGS.get(action_key, {})

func get_action_type(action_key: String) -> String:
	return get_action_config(action_key).get("type", "")

## Returns definitions for passive actions (attack or stun). Stun uses self-target, no damage.
func get_passive_definitions_for_action(action_key: String) -> Array[ActionDefinition]:
	var config = ACTION_CONFIGS.get(action_key)
	if config == null:
		push_warning("Unknown action key: %s" % action_key)
		return []
	var atype: String = config.get("type", "")
	if atype in ["attack", "fast attack", "slow attack"]:
		return get_ability_definitions_for_action(action_key)
	if atype == "stun":
		var block_mode: int = config.get("block_mode", 3)
		var result: Array[ActionDefinition] = _build_self_definitions(block_mode, config.get("name", "Stun"))
		for ad in result:
			ad.action_key = action_key
		return result
	push_warning("Action %s is not a passive type (attack/stun): %s" % [action_key, atype])
	return []

## Returns ActionDefinition resources for move actions (used for movement phase).
func get_move_definitions_for_action(action_key: String) -> Array[ActionDefinition]:
	var config = ACTION_CONFIGS.get(action_key)
	if config == null:
		push_warning("Unknown action key: %s" % action_key)
		return []
	var atype: String = config.get("type", "")
	if atype == "reload":
		# Rest/Stay - no movement (server3: minRange 0, maxRange 0)
		var block_mode: int = config.get("block_mode", 3)
		var result: Array[ActionDefinition] = _build_self_definitions(block_mode, config.get("name", "Rest"))
		for ad in result:
			ad.action_key = action_key
		return result
	if atype != "move" and atype != "fast move" and atype != "slow move":
		push_warning("Action %s is not a move type" % action_key)
		return []
	var min_r: int = config.get("min_range", 1)
	var max_r: int = config.get("max_range", 1)
	var block_mode: int = config.get("block_mode", 0)
	var result_arr: Array[ActionDefinition] = _build_move_definitions(min_r, max_r, block_mode, config.get("name", "Move"))
	for ad in result_arr:
		ad.action_key = action_key
	return result_arr

## Returns ActionDefinition resources for ability/attack actions.
func get_ability_definitions_for_action(action_key: String) -> Array[ActionDefinition]:
	var config = ACTION_CONFIGS.get(action_key)
	if config == null:
		push_warning("Unknown action key: %s" % action_key)
		return []
	var atype: String = config.get("type", "")
	if atype == "reload":
		# Rest/Stay - self-target, same as move path
		var block_mode: int = config.get("block_mode", 3)
		var result: Array[ActionDefinition] = _build_self_definitions(block_mode, config.get("name", "Rest"))
		for ad in result:
			ad.action_key = action_key
		return result
	if atype not in ["attack", "fast attack", "slow attack"]:
		push_warning("Action %s is not an attack type (got %s)" % [action_key, atype])
		return []
	var result: Array[ActionDefinition] = []
	if config.get("pattern", "") == "area_adjacent":
		var block_mode: int = config.get("block_mode", 3)
		result = _build_area_adjacent_definitions(block_mode, config.get("name", "Attack"))
	elif config.get("pattern", "") == "self":
		var block_mode: int = config.get("block_mode", 3)
		result = _build_self_definitions(block_mode, config.get("name", "Attack"))
	elif config.get("pattern", "") == "ray":
		var min_r: int = config.get("min_range", 1)
		var max_r: int = config.get("max_range", 1)
		var block_mode: int = config.get("block_mode", 2)
		result = _build_ray_ability_definitions(min_r, max_r, block_mode, config.get("name", "Attack"))
	else:
		var min_r: int = config.get("min_range", 1)
		var max_r: int = config.get("max_range", 1)
		var block_mode: int = config.get("block_mode", 3)
		result = _build_ability_definitions(min_r, max_r, block_mode, config.get("name", "Attack"))
	for ad in result:
		ad.action_key = action_key
	return result

func _build_move_definitions(min_range: int, max_range: int, block_mode_val: int, display_name: String = "") -> Array[ActionDefinition]:
	var block_mode: ActionDefinition.BlockMode = block_mode_val as ActionDefinition.BlockMode
	var result: Array[ActionDefinition] = []
	for dist in range(min_range, max_range + 1):
		var hexes := HexGridType.get_hexes_at_distance(0, 0, dist)
		for hex in hexes:
			var path: Array = HexGridType.build_path_to(0, 0, hex.x, hex.y)
			if path.is_empty():
				continue
			var ad := ActionDefinition.new()
			ad.block_mode = block_mode
			ad.display_name = display_name
			ad.path = path.slice(0, path.size() - 1)
			ad.end_point = path[path.size() - 1]
			result.append(ad)
	return result

func _build_ability_definitions(min_range: int, max_range: int, block_mode_val: int, display_name: String = "") -> Array[ActionDefinition]:
	var block_mode: ActionDefinition.BlockMode = block_mode_val as ActionDefinition.BlockMode
	var result: Array[ActionDefinition] = []
	for dist in range(min_range, max_range + 1):
		var hexes := HexGridType.get_hexes_at_distance(0, 0, dist)
		for hex in hexes:
			var path: Array = HexGridType.build_path_to(0, 0, hex.x, hex.y)
			if path.is_empty():
				continue
			var ad := ActionDefinition.new()
			ad.block_mode = block_mode
			ad.display_name = display_name
			ad.path = path.slice(0, path.size() - 1)
			ad.end_point = path[path.size() - 1]
			result.append(ad)
	return result

## Ray attack: 6 definitions, one per axial direction. Path extends radially from origin.
func _build_ray_ability_definitions(min_range: int, max_range: int, block_mode_val: int, display_name: String = "") -> Array[ActionDefinition]:
	var block_mode: ActionDefinition.BlockMode = block_mode_val as ActionDefinition.BlockMode
	var result: Array[ActionDefinition] = []
	for d in HexGridType.AXIAL_DIRECTIONS:
		var path: Array[Vector2] = []
		for step in range(1, max_range):
			path.append(Vector2(d.x * step, d.y * step))
		var ad := ActionDefinition.new()
		ad.block_mode = block_mode
		ad.display_name = display_name
		ad.path = path
		ad.end_point = Vector2(d.x * max_range, d.y * max_range)
		result.append(ad)
	return result

## Self-target: hits only the unit's own cell (the tile it ends on).
func _build_self_definitions(block_mode_val: int, display_name: String = "") -> Array[ActionDefinition]:
	var block_mode: ActionDefinition.BlockMode = block_mode_val as ActionDefinition.BlockMode
	var ad := ActionDefinition.new()
	ad.block_mode = block_mode
	ad.display_name = display_name
	ad.path = []
	ad.end_point = Vector2(0, 0)
	return [ad]

## Area attack hitting all 6 adjacent hexes. end_point = (0,0) so target is self (click mage to activate).
func _build_area_adjacent_definitions(block_mode_val: int, display_name: String = "") -> Array[ActionDefinition]:
	var block_mode: ActionDefinition.BlockMode = block_mode_val as ActionDefinition.BlockMode
	var ad := ActionDefinition.new()
	ad.block_mode = block_mode
	ad.display_name = display_name
	ad.path = []
	for d in HexGridType.AXIAL_DIRECTIONS:
		ad.path.append(Vector2(d.x, d.y))
	ad.end_point = Vector2(0, 0)  # Target is self - player clicks mage to activate
	return [ad]
