extends Node2D
## Hex map: defines walkable hex grid and draws hex tiles.
## Replaces square TileMap for hexagonal gameplay.

@export_range(8, 96, 2) var spacing: int = 24  ## Distance between hex centers
@export_range(4, 64, 1) var tile_radius: float = 12  ## Visual size of each hex (radius from center to corner)
## Hexagon radius: board includes all hexes within this distance from center (0,0). 5 = 5 tiles across.
@export var hex_radius: int = 5
@export var hex_color: Color = Color(0.2, 0.5, 0.2)
@export var hex_color_alt: Color = Color(0.25, 0.55, 0.25)
@export var color_variation: float = 0.12  ## Random hue/sat offset per tile

var grid: Dictionary = {}  # "q,r" -> { q, r, is_solid }
var _hex_nodes: Dictionary = {}
var _bounds: Dictionary = {}

func _ready() -> void:
	HexGrid.spacing = spacing
	HexGrid.tile_radius = tile_radius
	_build_grid()
	_draw_hexes()
	# Init Navigation before units run (hex_map is first child, units later)
	var units_node = get_parent().get_node_or_null("units")
	if units_node and units_node.has_method("get_active_units"):
		Navigation.init_level_hex(grid, units_node.get_active_units)

func _build_grid() -> void:
	grid.clear()
	for q in range(-hex_radius, hex_radius + 1):
		for r in range(-hex_radius, hex_radius + 1):
			if HexGrid.hex_distance(0, 0, q, r) <= hex_radius:
				var key := HexGrid.get_cell_key(q, r)
				grid[key] = { q = q, r = r, is_solid = false }
	_bounds = HexGrid.calculate_map_bounds(grid)

func _draw_hexes() -> void:
	for c in get_children():
		c.queue_free()
	_hex_nodes.clear()
	
	z_index = -2  ## Tiles draw below highlights
	var min_x: float = _bounds.min_x
	var min_y: float = _bounds.min_y
	for key in grid:
		var tile = grid[key]
		var pos := HexGrid.hex_to_pixel(tile.q, tile.r, min_x, min_y, 0.0)
		var poly := Polygon2D.new()
		poly.polygon = HexGrid.polygon_points_hex(pos.x, pos.y, tile_radius, 0.0)
		var is_alt: bool = (int(tile.q) + int(tile.r)) % 2 == 0
		var base: Color = hex_color if is_alt else hex_color_alt
		var seed_val: int = int(tile.q) * 7919 + int(tile.r) * 7877
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val
		var r := clampf(base.r + (rng.randf() - 0.5) * color_variation, 0.0, 1.0)
		var g := clampf(base.g + (rng.randf() - 0.5) * color_variation, 0.0, 1.0)
		var b := clampf(base.b + (rng.randf() - 0.5) * color_variation, 0.0, 1.0)
		poly.color = Color(r, g, b)
		add_child(poly)
		_hex_nodes[key] = poly
