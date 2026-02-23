extends RefCounted
## Tests for HexGrid (cell_equal, hex_distance, get_hexes_at_distance, are_adjacent, get_aoe_tiles).

static func run_all(tests: Node) -> bool:
	var ok := true
	ok = _test_cell_equal(tests) and ok
	ok = _test_hex_distance(tests) and ok
	ok = _test_are_adjacent(tests) and ok
	ok = _test_get_hexes_at_distance(tests) and ok
	ok = _test_build_path_to(tests) and ok
	return ok

static func _test_cell_equal(tests: Node) -> bool:
	tests._log("test_hex_grid: cell_equal")
	if not HexGrid.cell_equal(Vector2(0, 0), Vector2(0, 0)):
		tests._fail("cell_equal (0,0) (0,0)")
		return false
	if not HexGrid.cell_equal(Vector2(1.2, -1.8), Vector2(1, -2)):
		tests._fail("cell_equal should use int comparison")
		return false
	if HexGrid.cell_equal(Vector2(0, 0), Vector2(1, 0)):
		tests._fail("cell_equal (0,0) vs (1,0) should be false")
		return false
	tests._pass("cell_equal")
	return true

static func _test_hex_distance(tests: Node) -> bool:
	tests._log("test_hex_grid: hex_distance")
	if HexGrid.hex_distance(0, 0, 0, 0) != 0:
		tests._fail("distance (0,0) to (0,0) should be 0")
		return false
	if HexGrid.hex_distance(0, 0, 1, 0) != 1:
		tests._fail("distance (0,0) to (1,0) should be 1")
		return false
	if HexGrid.hex_distance(0, 0, 1, -1) != 1:
		tests._fail("distance (0,0) to (1,-1) should be 1")
		return false
	if HexGrid.hex_distance(0, 0, 2, 0) != 2:
		tests._fail("distance (0,0) to (2,0) should be 2")
		return false
	tests._pass("hex_distance")
	return true

static func _test_are_adjacent(tests: Node) -> bool:
	tests._log("test_hex_grid: are_adjacent")
	if not HexGrid.are_adjacent(0, 0, 1, 0):
		tests._fail("(0,0) and (1,0) should be adjacent")
		return false
	if HexGrid.are_adjacent(0, 0, 2, 0):
		tests._fail("(0,0) and (2,0) should not be adjacent")
		return false
	tests._pass("are_adjacent")
	return true

static func _test_get_hexes_at_distance(tests: Node) -> bool:
	tests._log("test_hex_grid: get_hexes_at_distance")
	var ring0: Array = HexGrid.get_hexes_at_distance(0, 0, 0)
	if ring0.size() != 1:
		tests._fail("distance 0 ring should have 1 hex, got %d" % ring0.size())
		return false
	var ring1: Array = HexGrid.get_hexes_at_distance(0, 0, 1)
	if ring1.size() != 6:
		tests._fail("distance 1 ring should have 6 hexes, got %d" % ring1.size())
		return false
	var ring2: Array = HexGrid.get_hexes_at_distance(0, 0, 2)
	if ring2.size() != 12:
		tests._fail("distance 2 ring should have 12 hexes, got %d" % ring2.size())
		return false
	tests._pass("get_hexes_at_distance")
	return true

static func _test_build_path_to(tests: Node) -> bool:
	tests._log("test_hex_grid: build_path_to")
	var path: Array = HexGrid.build_path_to(0, 0, 2, 0)
	if path.is_empty():
		tests._fail("path (0,0) to (2,0) should not be empty")
		return false
	var last: Vector2 = path[path.size() - 1]
	if int(last.x) != 2 or int(last.y) != 0:
		tests._fail("path should end at (2,0), got %s" % last)
		return false
	tests._pass("build_path_to")
	return true
