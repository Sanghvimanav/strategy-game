extends Node
## Hex grid math: axial coordinates (q, r), pixel conversion, neighbors.
## Used for hexagonal game board.

static var spacing: int = 24  ## Distance between hex centers (grid layout)
static var tile_radius: float = 12  ## Visual radius of each hex (for drawing)
const HEIGHT_MULTIPLIER: int = 4

## Six axial directions: East, NE, NW, West, SW, SE
const AXIAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
]

static func get_cell_key(q: int, r: int) -> String:
	return "%d,%d" % [q, r]

static func hex_to_pixel(q: int, r: int, min_x: float, min_y: float, height_adj: float = 0.0) -> Vector2:
	var x := spacing * sqrt(3.0) * (q + r / 2.0)
	var y := spacing * 1.5 * r - height_adj
	return Vector2(x - min_x + spacing, y - min_y + spacing)

static func pixel_to_hex(px: float, py: float, min_x: float, min_y: float) -> Vector2i:
	var x := px - spacing + min_x
	var y := py - spacing + min_y
	var q := (x / (spacing * sqrt(3.0))) - (y / (spacing * 3.0))
	var r := y / (spacing * 1.5)
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
		var x := spacing * sqrt(3.0) * (q + r / 2.0)
		var y := spacing * 1.5 * r
		min_x = minf(min_x, x)
		max_x = maxf(max_x, x)
		min_y = minf(min_y, y)
		max_y = maxf(max_y, y)
	return { min_x = min_x, max_x = max_x, min_y = min_y, max_y = max_y }

static func get_adjacent_hexes(q: int, r: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d in AXIAL_DIRECTIONS:
		result.append(Vector2i(q + d.x, r + d.y))
	return result

## Hex distance in axial coords. From https://www.redblobgames.com/grids/hexagons/#distances
## Cube: s = -q-r; distance = (abs(dq) + abs(dr) + abs(ds)) / 2
static func hex_distance(q1: int, r1: int, q2: int, r2: int) -> int:
	var s1 := -q1 - r1
	var s2 := -q2 - r2
	return int((absi(q1 - q2) + absi(r1 - r2) + absi(s1 - s2)) / 2.0)

static func hex_distance_vec(a: Vector2, b: Vector2) -> int:
	return hex_distance(int(a.x), int(a.y), int(b.x), int(b.y))

## Returns true if two hexes are adjacent (distance 1)
static func are_adjacent(q1: int, r1: int, q2: int, r2: int) -> bool:
	return hex_distance(q1, r1, q2, r2) == 1

## Returns all hex coordinates at exactly distance N from center. Ring has 6*N hexes.
static func get_hexes_at_distance(center_q: int, center_r: int, dist: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dq in range(-dist, dist + 1):
		for dr in range(-dist, dist + 1):
			var q := center_q + dq
			var r := center_r + dr
			if hex_distance(center_q, center_r, q, r) == dist:
				result.append(Vector2i(q, r))
	return result

## Builds a path from (from_q, from_r) to (to_q, to_r) - each step toward target.
static func build_path_to(from_q: int, from_r: int, to_q: int, to_r: int) -> Array[Vector2]:
	var path: Array[Vector2] = []
	var cur_q := from_q
	var cur_r := from_r
	var target_dist := hex_distance(from_q, from_r, to_q, to_r)
	while target_dist > 0:
		var best_dq := 0
		var best_dr := 0
		var best_next_dist := target_dist
		for d in AXIAL_DIRECTIONS:
			var nq := cur_q + d.x
			var nr := cur_r + d.y
			var next_dist := hex_distance(nq, nr, to_q, to_r)
			if next_dist < best_next_dist:
				best_next_dist = next_dist
				best_dq = d.x
				best_dr = d.y
		if best_next_dist >= target_dist:
			break
		cur_q += best_dq
		cur_r += best_dr
		path.append(Vector2(cur_q, cur_r))
		target_dist = best_next_dist
	return path

static func polygon_points_hex(center_x: float, center_y: float, radius: float, height_offset: float = 0.0) -> PackedVector2Array:
	var points: PackedVector2Array = []
	for i in 6:
		var angle_deg := -60 * i + 30
		var angle_rad := deg_to_rad(angle_deg)
		var x := center_x + radius * cos(angle_rad)
		var y := center_y + radius * sin(angle_rad) - height_offset
		points.append(Vector2(x, y))
	return points

static func cell_equal(a: Vector2, b: Vector2) -> bool:
	return int(a.x) == int(b.x) and int(a.y) == int(b.y)

## Returns direction index 0-5 from from_cell to to_cell, or -1 if same cell.
## Mirrors server3 getDirectionIndex (cube direction dot product).
static func get_direction_index(from_q: int, from_r: int, to_q: int, to_r: int) -> int:
	if from_q == to_q and from_r == to_r:
		return -1
	var dx := to_q - from_q
	var dy := -to_q - to_r - (-from_q - from_r)  # cube y: -q - r
	var dz := to_r - from_r
	var max_dot := -INF
	var best_dir := 0
	for i in 6:
		var d := AXIAL_DIRECTIONS[i]
		var cx := d.x
		var cz := d.y
		var cy := -cx - cz
		var dot := dx * cx + dy * cy + dz * cz
		if dot > max_dot:
			max_dot = dot
			best_dir = i
	return best_dir

## Returns AoE cells for area_of_effect: { directions: Array[int], distance: int }.
## from_cell = attacker cell, target_cell = primary target. Relative directions from attack direction.
static func get_aoe_tiles(from_cell: Vector2, target_cell: Vector2, area_of_effect: Dictionary) -> Array[Vector2i]:
	var dirs: Array = area_of_effect.get("directions", [])
	var dist: int = int(area_of_effect.get("distance", 1))
	if dirs.is_empty():
		return []
	var dir_idx := get_direction_index(int(from_cell.x), int(from_cell.y), int(target_cell.x), int(target_cell.y))
	if dir_idx < 0:
		return []
	var result: Array[Vector2i] = []
	var tq := int(target_cell.x)
	var tr := int(target_cell.y)
	for rel_dir in dirs:
		var idx := (dir_idx + int(rel_dir) + 6) % 6
		var d := AXIAL_DIRECTIONS[idx]
		var cq := tq
		var cr := tr
		for step in dist:
			cq += d.x
			cr += d.y
		result.append(Vector2i(cq, cr))
	return result
