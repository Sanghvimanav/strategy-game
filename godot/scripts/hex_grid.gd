extends Node
## Hex grid math: axial coordinates (q, r), pixel conversion, neighbors.
## Ported from strategy_game_v8.html. Use from anywhere via HexGrid autoload.

const TILE_SIZE: int = 40
const HEIGHT_MULTIPLIER: int = 4

## Six axial directions: East, NE, NW, West, SW, SE
const AXIAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
]

static func hex_to_pixel(q: int, r: int, min_x: float, min_y: float, grid: Dictionary) -> Vector2:
	var key := _key(q, r)
	var tile = grid.get(key)
	var height_adj := 0.0
	if tile and tile.get("height") != null:
		height_adj = float(tile.height) * HEIGHT_MULTIPLIER
	var x := TILE_SIZE * sqrt(3.0) * (q + r / 2.0)
	var y := TILE_SIZE * 1.5 * r - height_adj
	return Vector2(x - min_x + TILE_SIZE, y - min_y + TILE_SIZE)

static func pixel_to_hex(px: float, py: float, min_x: float, min_y: float) -> Vector2i:
	var x := px - TILE_SIZE + min_x
	var y := py - TILE_SIZE + min_y
	var q := (x / (TILE_SIZE * sqrt(3.0))) - (y / (TILE_SIZE * 3.0))
	var r := y / (TILE_SIZE * 1.5)
	return Vector2i(roundi(q), roundi(r))

static func calculate_map_bounds(grid: Dictionary) -> Dictionary:
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for key in grid:
		var tile = grid[key]
		var q: int = tile.q
		var r: int = tile.r
		var x := TILE_SIZE * sqrt(3.0) * (q + r / 2.0)
		var y := TILE_SIZE * 1.5 * r
		min_x = minf(min_x, x)
		max_x = maxf(max_x, x)
		min_y = minf(min_y, y)
		max_y = maxf(max_y, y)
	return { min_x = min_x, max_x = max_x, min_y = min_y, max_y = max_y }

static func get_adjacent_tile_keys(q: int, r: int) -> Array:
	var keys: Array = []
	for i in AXIAL_DIRECTIONS.size():
		var d := AXIAL_DIRECTIONS[i]
		var nq := q + d.x
		var nr := r + d.y
		keys.append({ key = _key(nq, nr), direction = i, q = nq, r = nr })
	return keys

static func hex_distance(tile1: Dictionary, tile2: Dictionary) -> int:
	var q1: int = tile1.q
	var r1: int = tile1.r
	var q2: int = tile2.q
	var r2: int = tile2.r
	var s1 := -q1 - r1
	var s2 := -q2 - r2
	return int((absi(q1 - q2) + absi(r1 - r2) + absi(s1 - s2)) / 2.0)

static func polygon_points_hex(center_x: float, center_y: float, radius: float, height_offset: float) -> PackedVector2Array:
	var points: PackedVector2Array = []
	for i in 6:
		var angle_deg := -60 * i + 30
		var angle_rad := deg_to_rad(angle_deg)
		var x := center_x + radius * cos(angle_rad)
		var y := center_y + radius * sin(angle_rad) - height_offset
		points.append(Vector2(x, y))
	return points

static func _key(q: int, r: int) -> String:
	return "%d,%d" % [q, r]
