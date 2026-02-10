extends Node
## Hex-based navigation: pathfinding, world/cell conversion.
## Uses axial coordinates (q, r) via Vector2 where x=q, y=r.

const HexGridType = preload("res://src/global/hex_grid.gd")

var astar: AStar2D
var grid: Dictionary = {}  # "q,r" -> { q, r, is_solid }
var unit_lookup: Callable
var _bounds: Dictionary = {}

func init_level_hex(hex_grid: Dictionary, unit_lookup_callable: Callable) -> void:
	unit_lookup = unit_lookup_callable
	grid = hex_grid
	_bounds = HexGridType.calculate_map_bounds(grid)
	
	astar = HexAStar.new()  # HexAStar is a global class from hex_astar.gd
	for key in grid:
		var tile = grid[key]
		if tile.get("is_solid", false):
			continue
		var id := _point_id(tile.q, tile.r)
		astar.add_point(id, Vector2(tile.q, tile.r))
	
	for key in grid:
		var tile = grid[key]
		if tile.get("is_solid", false):
			continue
		var neighbors = HexGridType.get_adjacent_hexes(tile.q, tile.r)
		var id_from := _point_id(tile.q, tile.r)
		for n in neighbors:
			var nkey := HexGridType.get_cell_key(n.x, n.y)
			if grid.has(nkey) and not grid[nkey].get("is_solid", false):
				var id_to := _point_id(n.x, n.y)
				if astar.has_point(id_to):
					astar.connect_points(id_from, id_to)

func _point_id(q: int, r: int) -> int:
	# Encode q,r into unique int (assumes reasonable range e.g. -64 to 63)
	return (q + 64) * 256 + (r + 64)

func snap_to_tile(pos: Vector2, include_half_offset: bool = false) -> Vector2:
	var min_x: float = _bounds.get("min_x", 0)
	var min_y: float = _bounds.get("min_y", 0)
	var vi := HexGridType.pixel_to_hex(pos.x, pos.y, min_x, min_y)
	return cell_to_world(Vector2(vi.x, vi.y), include_half_offset)

func world_to_cell(pos: Vector2) -> Vector2:
	var min_x: float = _bounds.get("min_x", 0)
	var min_y: float = _bounds.get("min_y", 0)
	var vi := HexGridType.pixel_to_hex(pos.x, pos.y, min_x, min_y)
	return Vector2(vi.x, vi.y)

func cell_to_world(cell: Vector2, include_half_offset: bool = false) -> Vector2:
	var min_x: float = _bounds.get("min_x", 0)
	var min_y: float = _bounds.get("min_y", 0)
	var px := HexGridType.hex_to_pixel(int(cell.x), int(cell.y), min_x, min_y, 0.0)
	if include_half_offset:
		# Center of hex (already centered in hex_to_pixel)
		pass
	return px

func is_valid_cell(cell: Vector2) -> bool:
	var key := HexGridType.get_cell_key(int(cell.x), int(cell.y))
	return grid.has(key) and not grid[key].get("is_solid", false)

func get_ac_block_point(ac: ActionInstance) -> Vector2:
	var units: Array = unit_lookup.call()
	units = units.filter(func(u): return u != ac.unit)
	var unit_cells: Array = []
	for u in units:
		unit_cells.append(u.cell)
	
	for i in range(ac.full_path.size()):
		var cell = ac.full_path[i]
		if not is_valid_cell(cell):
			return cell
		for ucell in unit_cells:
			if HexGridType.cell_equal(cell, ucell):
				return cell
	
	return Vector2(INF, INF)
