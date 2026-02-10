extends Node
## Scenario registry and selection. Used for quick debug setups and future multiplayer.
## Select a scenario before loading battle; battle reads selected_scenario_id and applies it.

var selected_scenario_id: String = "default"
var available_scenarios: Array[Dictionary] = []

func _ready() -> void:
	_build_scenarios()

func _build_scenarios() -> void:
	available_scenarios.clear()
	# Default: Knight, Ghost, Mage vs Zergling (matches current battle.tscn layout)
	available_scenarios.append({
		"id": "default",
		"display_name": "Default (Knight, Ghost, Mage vs Zergling)",
		"groups": [
			{
				"name": "player",
				"units": [
					{"def_path": "res://src/unit/definitions/knight.tres", "cell": Vector2i(1, 0)},
					{"def_path": "res://src/unit/definitions/ghost.tres", "cell": Vector2i(0, 1)},
					{"def_path": "res://src/unit/definitions/mage.tres", "cell": Vector2i(0, 0)},
				]
			},
		{
			"name": "opponent",
			"ai": true,
			"units": [
				{"def_path": "res://src/unit/definitions/zergling.tres", "cell": Vector2i(-1, 1)},
			]
		},
		]
	})
	# Ghost energy debug: just Ghost vs Zergling
	available_scenarios.append({
		"id": "ghost_debug",
		"display_name": "Ghost Debug (Ghost vs Zergling)",
		"groups": [
			{"name": "player", "units": [
				{"def_path": "res://src/unit/definitions/ghost.tres", "cell": Vector2i(0, 0)},
			]},
			{"name": "opponent", "ai": true, "units": [
				{"def_path": "res://src/unit/definitions/zergling.tres", "cell": Vector2i(-1, 1)},
			]},
		]
	})
	# Zergling vs Zergling
	available_scenarios.append({
		"id": "zerg_vs_zerg",
		"display_name": "Zergling vs Zergling",
		"groups": [
			{"name": "player", "units": [
				{"def_path": "res://src/unit/definitions/zergling.tres", "cell": Vector2i(1, 0)},
			]},
			{"name": "opponent", "ai": true, "units": [
				{"def_path": "res://src/unit/definitions/zergling.tres", "cell": Vector2i(-1, 1)},
			]},
		]
	})
	# Marine debug: Marine vs Zergling (attack_short + AoE)
	available_scenarios.append({
		"id": "marine_debug",
		"display_name": "Marine Debug (Marine vs Zergling)",
		"groups": [
			{"name": "player", "units": [
				{"def_path": "res://src/unit/definitions/marine.tres", "cell": Vector2i(0, 0)},
			]},
			{"name": "opponent", "ai": true, "units": [
				{"def_path": "res://src/unit/definitions/zergling.tres", "cell": Vector2i(-1, 1)},
			]},
		]
	})
	# 2 Marines vs 5 Zerglings + 1 Baneling (randomized positions)
	available_scenarios.append({
		"id": "marines_vs_zerglings",
		"display_name": "2 Marines vs 5 Zerglings + Baneling",
		"randomize_positions": true,
		"groups": [
			{
				"name": "player",
				"units": [
					{"def_path": "res://src/unit/definitions/marine.tres"},
					{"def_path": "res://src/unit/definitions/marine.tres"},
				],
				"cell_pool": [
					Vector2i(2, 0), Vector2i(2, -1), Vector2i(1, 1), Vector2i(1, 0), Vector2i(1, -1),
					Vector2i(0, 2), Vector2i(0, 1), Vector2i(0, 0), Vector2i(0, -1), Vector2i(0, -2),
				],
			},
			{
				"name": "opponent",
				"ai": true,
				"units": [
					{"def_path": "res://src/unit/definitions/zergling.tres"},
					{"def_path": "res://src/unit/definitions/zergling.tres"},
					{"def_path": "res://src/unit/definitions/zergling.tres"},
					{"def_path": "res://src/unit/definitions/zergling.tres"},
					{"def_path": "res://src/unit/definitions/zergling.tres"},
					{"def_path": "res://src/unit/definitions/baneling.tres"},
				],
				"cell_pool": [
					Vector2i(-2, 0), Vector2i(-2, 1), Vector2i(-1, 2), Vector2i(-1, 1), Vector2i(-1, 0),
					Vector2i(-1, -1), Vector2i(0, 2), Vector2i(0, 1), Vector2i(0, -1), Vector2i(0, -2),
					Vector2i(-2, 2), Vector2i(-2, -1),
				],
			},
		],
	})
	# 1v1 Knight
	available_scenarios.append({
		"id": "knight_1v1",
		"display_name": "1v1 Knight vs Mage",
		"groups": [
			{"name": "player", "units": [
				{"def_path": "res://src/unit/definitions/knight.tres", "cell": Vector2i(1, 0)},
			]},
			{"name": "opponent", "ai": true, "units": [
				{"def_path": "res://src/unit/definitions/mage.tres", "cell": Vector2i(-1, 1)},
			]},
		]
	})

func select_scenario(id: String) -> void:
	selected_scenario_id = id

func get_selected_scenario() -> Dictionary:
	for s in available_scenarios:
		if s.id == selected_scenario_id:
			return s
	return available_scenarios[0] if available_scenarios.size() > 0 else {}
