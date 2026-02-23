extends Node2D
## Draws the hex grid and units from GameState.game_state.
## Attach to a Node2D that will hold hex polygons and unit nodes.

const HexGridType = preload("res://scripts/hex_grid.gd")

@export var tile_size: int = 40
@export var hex_color_default: Color = Color(0.88, 0.88, 0.88)

var _hex_nodes: Dictionary = {}  # key -> Polygon2D
var _unit_nodes: Dictionary = {}  # key -> Node2D (container for circle + label)
var _bounds: Dictionary = {}

func _ready() -> void:
	if not GameState.game_state_updated.is_connected(_on_game_state_updated):
		GameState.game_state_updated.connect(_on_game_state_updated)
	if GameState.game_state.size() > 0:
		_refresh_board()

func _on_game_state_updated(_state: Dictionary) -> void:
	_refresh_board()

func _refresh_board() -> void:
	var state: Dictionary = GameState.game_state
	var grid: Dictionary = state.get("grid", {})
	if grid.is_empty():
		return

	_bounds = HexGridType.calculate_map_bounds(grid)
	var min_x: float = _bounds.min_x
	var min_y: float = _bounds.min_y

	# Clear old hexes we don't need; create/update hexes
	for key in grid:
		var tile = grid[key]
		var q: int = tile.q
		var r: int = tile.r
		var pos: Vector2 = HexGridType.hex_to_pixel(q, r, min_x, min_y, grid)
		var radius: float = tile_size * 0.5
		var height_off: float = 0.0
		if tile.get("height"):
			height_off = float(tile.height) * 4.0

		if not _hex_nodes.has(key):
			var poly := Polygon2D.new()
			poly.polygon = HexGridType.polygon_points_hex(pos.x, pos.y, radius, height_off)
			poly.set_meta("q", q)
			poly.set_meta("r", r)
			poly.set_meta("key", key)
			add_child(poly)
			_hex_nodes[key] = poly

		var poly_node: Polygon2D = _hex_nodes[key]
		var col_str: String = tile.get("color", "#e0e0e0")
		poly_node.color = Color.from_string(col_str if col_str.begins_with("#") else "#e0e0e0", Color.GRAY)
		poly_node.position = Vector2.ZERO
		poly_node.polygon = HexGridType.polygon_points_hex(pos.x, pos.y, radius, height_off)

	# Draw units per tile
	var tile_units: Dictionary = {}
	var players: Array = state.get("players", [])
	for p in players:
		for unit in p.get("units", []):
			var t: Dictionary = unit.get("tile", {})
			var uk: String = GameState.get_tile_key(t.q, t.r)
			if not tile_units.has(uk):
				tile_units[uk] = []
			tile_units[uk].append(unit)

	for key in tile_units:
		var units: Array = tile_units[key]
		var tile = grid.get(key, {})
		var q: int = tile.get("q", 0)
		var r: int = tile.get("r", 0)
		var pos: Vector2 = HexGridType.hex_to_pixel(q, r, min_x, min_y, grid)

		if not _unit_nodes.has(key):
			var container := Node2D.new()
			add_child(container)
			_unit_nodes[key] = container

		var cont: Node2D = _unit_nodes[key]
		for c in cont.get_children():
			c.queue_free()

		var fill_color: Color = Color(GameState.get_player_color(units[0].playerId))
		if units.size() > 1:
			var unique_players: int = 0
			var pids: Dictionary = {}
			for u in units:
				pids[u.playerId] = true
			unique_players = pids.size()
			if unique_players > 1:
				fill_color = Color(0.5, 0.5, 0.5)  # Multiple players

		var circ := Polygon2D.new()
		var segs: int = 24
		var rad: float = tile_size / 3.0
		var pts: PackedVector2Array = []
		for i in segs:
			var a: float = TAU * float(i) / float(segs)
			pts.append(pos + Vector2(cos(a), sin(a)) * rad)
		circ.polygon = pts
		circ.color = fill_color
		cont.add_child(circ)

		var label := Label.new()
		label.text = str(units.size())
		label.position = pos + Vector2(-8, -8)
		label.add_theme_font_size_override("font_size", 14)
		cont.add_child(label)

	# Remove unit nodes for tiles that no longer have units
	for key in _unit_nodes.keys():
		if not tile_units.has(key) or tile_units[key].is_empty():
			var n: Node = _unit_nodes[key]
			n.queue_free()
			_unit_nodes.erase(key)

func get_hex_at_position(global_pos: Vector2) -> String:
	var local := global_pos - global_position
	var grid: Dictionary = GameState.game_state.get("grid", {})
	if grid.is_empty():
		return ""
	_bounds = HexGridType.calculate_map_bounds(grid)
	var min_x: float = _bounds.min_x
	var min_y: float = _bounds.min_y
	var v: Vector2i = HexGridType.pixel_to_hex(local.x, local.y, min_x, min_y)
	return GameState.get_tile_key(v.x, v.y)
