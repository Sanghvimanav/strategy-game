class_name HexAStar
extends AStar2D
## AStar2D with hex distance heuristic for axial coordinates.
## Points store (q, r) as Vector2; _estimate_cost uses Red Blob Games hex distance.
## https://www.redblobgames.com/grids/hexagons/#distances

const HexGridType = preload("res://src/global/hex_grid.gd")

func _estimate_cost(from_id: int, to_id: int) -> float:
	var from_pos := get_point_position(from_id)
	var to_pos := get_point_position(to_id)
	return float(HexGridType.hex_distance(int(from_pos.x), int(from_pos.y), int(to_pos.x), int(to_pos.y)))
