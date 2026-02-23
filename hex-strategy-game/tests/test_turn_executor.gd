extends RefCounted
## Tests for TurnExecutor (ABILITY_TYPES, phase order, damage cells for self-pattern).

const TurnExecutor = preload("res://src/battle/turn_executor.gd")
const ActionInstance = preload("res://src/unit/action_collection.gd")

static func run_all(tests: Node) -> bool:
	var ok := true
	ok = _test_ability_types_include_phases(tests) and ok
	ok = _test_move_types(tests) and ok
	ok = _test_attack_passive_has_self_pattern(tests) and ok
	ok = _test_get_damage_cells_self_pattern_uses_attacker_cell(tests) and ok
	ok = _test_get_damage_cells_non_self_uses_path(tests) and ok
	ok = _test_fast_ability_before_move(tests) and ok
	return ok

static func _test_ability_types_include_phases(tests: Node) -> bool:
	tests._log("test_turn_executor: ABILITY_TYPES")
	if not TurnExecutor.ABILITY_TYPES.has("fast ability"):
		tests._fail("ABILITY_TYPES should contain fast ability")
		return false
	if not TurnExecutor.ABILITY_TYPES.has("ability"):
		tests._fail("ABILITY_TYPES should contain ability")
		return false
	if not TurnExecutor.ABILITY_TYPES.has("slow ability"):
		tests._fail("ABILITY_TYPES should contain slow ability")
		return false
	if TurnExecutor.ABILITY_TYPES.size() != 3:
		tests._fail("ABILITY_TYPES should have 3 elements")
		return false
	tests._pass("ABILITY_TYPES")
	return true

static func _test_move_types(tests: Node) -> bool:
	tests._log("test_turn_executor: MOVE_TYPES")
	if not TurnExecutor.MOVE_TYPES.has("fast move"):
		tests._fail("MOVE_TYPES should contain fast move")
		return false
	if not TurnExecutor.MOVE_TYPES.has("move"):
		tests._fail("MOVE_TYPES should contain move")
		return false
	if not TurnExecutor.MOVE_TYPES.has("slow move"):
		tests._fail("MOVE_TYPES should contain slow move")
		return false
	tests._pass("MOVE_TYPES")
	return true

static func _test_attack_passive_has_self_pattern(tests: Node) -> bool:
	tests._log("test_turn_executor: attack_passive has pattern self")
	var config: Dictionary = Actions.get_action_config("attack_passive")
	if config.get("pattern", "") != "self":
		tests._fail("attack_passive should have pattern=self so damage uses attacker current cell after move, got %s" % config.get("pattern", ""))
		return false
	tests._pass("attack_passive pattern=self")
	return true

static func _test_get_damage_cells_self_pattern_uses_attacker_cell(tests: Node) -> bool:
	tests._log("test_turn_executor: get_damage_cells self pattern uses attacker cell")
	var ac := ActionInstance.new(null, null)
	ac.path = []
	ac.end_point = Vector2(0, 0)
	var config: Dictionary = { "pattern": "self" }
	var attacker_cell := Vector2(3, -1)
	var cells: Array = TurnExecutor.get_damage_cells(attacker_cell, ac, config)
	if cells.size() != 1:
		tests._fail("self pattern should return 1 cell, got %d" % cells.size())
		return false
	if not HexGrid.cell_equal(cells[0], attacker_cell):
		tests._fail("self pattern should return [attacker_cell], got %s" % cells)
		return false
	tests._pass("get_damage_cells self uses attacker cell")
	return true

static func _test_get_damage_cells_non_self_uses_path(tests: Node) -> bool:
	tests._log("test_turn_executor: get_damage_cells non-self uses path+end_point")
	var ac := ActionInstance.new(null, null)
	ac.path = [Vector2(1, 0)]
	ac.end_point = Vector2(2, 0)
	var config: Dictionary = { "pattern": "ray" }
	var cells: Array = TurnExecutor.get_damage_cells(Vector2(0, 0), ac, config)
	if cells.size() != 2:
		tests._fail("non-self should return path+end_point (2 cells), got %d" % cells.size())
		return false
	if not HexGrid.cell_equal(cells[0], Vector2(1, 0)) or not HexGrid.cell_equal(cells[1], Vector2(2, 0)):
		tests._fail("non-self cells should match path+end_point, got %s" % cells)
		return false
	tests._pass("get_damage_cells non-self uses path")
	return true

static func _test_fast_ability_before_move(tests: Node) -> bool:
	tests._log("test_turn_executor: fast ability before move in ACTION_ORDER")
	var order: Array = Actions.ACTION_ORDER
	var idx_fast_ability := order.find("fast ability")
	var idx_move := order.find("move")
	if idx_fast_ability < 0 or idx_move < 0:
		tests._fail("ACTION_ORDER missing fast ability or move")
		return false
	if idx_fast_ability >= idx_move:
		tests._fail("fast ability must run before move so units can move then attack (e.g. Zergling onto Marine), fast_ability=%d move=%d" % [idx_fast_ability, idx_move])
		return false
	tests._pass("fast ability before move")
	return true
