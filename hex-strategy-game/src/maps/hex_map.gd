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
var _hex_base_colors: Dictionary = {}  # "q,r" -> Color, for fog dimming
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
	# Fog of war: refresh once units are in place (deferred)
	call_deferred("_refresh_fog")

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
		var tile_color := Color(r, g, b)
		poly.color = tile_color
		_hex_base_colors[key] = tile_color
		add_child(poly)
		_hex_nodes[key] = poly

## Fog of war: visible_cell_keys is a Dictionary of "q,r" -> true for hexes visible to player.
## Empty = show entire map (no fog). Call after unit placement or movement.
## Also hides enemy units whose cell is not in visible_cell_keys.
func update_fog(visible_cell_keys: Dictionary) -> void:
	if _hex_nodes.is_empty():
		return
	var no_fog: bool = visible_cell_keys.is_empty()
	for key in _hex_nodes:
		var poly: Polygon2D = _hex_nodes[key]
		var base_color: Color = _hex_base_colors.get(key, poly.color)
		if no_fog or visible_cell_keys.get(key, false):
			poly.color = base_color
			poly.visible = true
		else:
			# Dim tile in fog (darken and reduce saturation)
			var dimmed := base_color.darkened(0.55)
			dimmed.s = dimmed.s * 0.4
			poly.color = dimmed
			poly.visible = true
	_update_enemy_visibility(visible_cell_keys)

## Recomputes visible hexes from observer units (e.g. player marines with sight_range=2) and applies fog.
## Call after unit placement or after movement (e.g. end of turn).
func refresh_fog() -> void:
	var visible_keys := _compute_visible_cell_keys()
	update_fog(visible_keys)

func _refresh_fog() -> void:
	refresh_fog()

## Returns Dictionary "q,r" -> true for all hexes visible to any observer unit.
## Observers = units in first group (player) that have sight_range > 0.
## If no observers (sight_range > 0), returns full map so fog is off.
func _compute_visible_cell_keys() -> Dictionary:
	var result: Dictionary = {}
	var units_node = get_parent().get_node_or_null("units")
	if not units_node or not units_node.has_method("get_active_units"):
		return result
	var groups: Array = units_node.groups if "groups" in units_node else []
	if groups.is_empty():
		return result
	# First group = player (observers for fog)
	var player_group: Node = groups[0]
	for child in player_group.get_children():
		if not child is Unit:
			continue
		var u: Unit = child
		if not u.is_active or not u.def:
			continue
		var range_limit: int = u.def.sight_range
		if range_limit < 0:
			# Full visibility for this unit type: skip (don't contribute to fog)
			continue
		if range_limit == 0:
			continue
		var cell := u.cell
		var q := int(cell.x)
		var r := int(cell.y)
		var hexes := HexGrid.get_hexes_in_range(q, r, range_limit)
		for h in hexes:
			var key := HexGrid.get_cell_key(h.x, h.y)
			if grid.has(key):
				result[key] = true
	# No observers with sight = no fog (show full map)
	if result.is_empty():
		for k in grid:
			result[k] = true
	return result

## Hides enemy units (non-player groups) when their cell is not in visible_cell_keys.
## Dead units are always hidden and never shown by fog logic.
func _update_enemy_visibility(visible_cell_keys: Dictionary) -> void:
	var units_node = get_parent().get_node_or_null("units")
	if not units_node or "groups" not in units_node:
		return
	var groups: Array = units_node.groups
	if groups.size() <= 1:
		return
	var show_all: bool = visible_cell_keys.is_empty()
	# groups[0] = player; rest = enemy
	for i in range(1, groups.size()):
		var group_node: Node = groups[i]
		for child in group_node.get_children():
			if not child is Unit:
				continue
			var u: Unit = child
			if not u.is_active:
				u.visible = false
				continue
			var cell_key := HexGrid.get_cell_key(int(u.cell.x), int(u.cell.y))
			u.visible = show_all or visible_cell_keys.get(cell_key, false)
