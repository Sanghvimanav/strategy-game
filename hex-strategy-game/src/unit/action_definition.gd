class_name ActionDefinition
extends Resource

const HexGridType = preload("res://src/global/hex_grid.gd")

enum ActionType {
	Move,
	Ability
}

enum BlockMode {
	Cancel,
	TruncateBefore,
	TruncateOn,
	Ignore,
}

@export var block_mode: BlockMode
@export var display_name: String = ""
## Action key from Actions registry (e.g. "move_short", "stun") for type lookup
var action_key: String = ""

## All values relative to the origin at (0, 0)
@export var path: Array[Vector2] = []
## All values relative to the origin at (0, 0)
@export var end_point: Vector2

var full_path: Array:
	get:
		return path + [end_point]

func to_action_instance(unit: Unit) -> ActionInstance:
	var current_cell: Vector2 = Navigation.world_to_cell(unit.global_position)
	var ac := ActionInstance.new(self, unit)
	var prev: Vector2 = current_cell
	ac.path = []
	for rel in path:
		var abs_cell: Vector2 = rel + current_cell
		# Validate: each step must be exactly 1 hex from previous (hex-adjacent)
		if not HexGridType.are_adjacent(int(prev.x), int(prev.y), int(abs_cell.x), int(abs_cell.y)):
			push_warning("Action path has non-adjacent hex step: %s -> %s" % [prev, abs_cell])
		ac.path.append(abs_cell)
		prev = abs_cell
	var abs_end: Vector2 = end_point + current_cell
	if HexGridType.cell_equal(prev, abs_end):
		pass  # end_point matches last path cell - valid
	elif not HexGridType.are_adjacent(int(prev.x), int(prev.y), int(abs_end.x), int(abs_end.y)):
		push_warning("Action end_point not adjacent to path: %s -> %s" % [prev, abs_end])
	ac.end_point = abs_end
	return ac
