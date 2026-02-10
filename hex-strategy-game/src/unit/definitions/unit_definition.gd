class_name UnitDefinition
extends Resource

enum Type {
	Knight,
	Ghost,
	Mage,
	Rogue,
	Peasant,
	Zergling
}

@export var name: String
@export var type: Type
@export var frames: SpriteFrames
## Scale for the unit sprite (e.g. 0.25 for 128x128 sprites to match 32x32 size)
@export var sprite_scale: Vector2 = Vector2.ONE
## Offset for the sprite position (positive Y = down)
@export var sprite_offset: Vector2 = Vector2.ZERO
@export var type_components: Array[PackedScene] = []
## Action keys from Actions registry (e.g. ["move_short"]). Used when move_definitions is empty.
@export var move_action_keys: Array[String] = []
## Action keys from Actions registry for abilities. Used when ability_definitions is empty.
@export var ability_action_keys: Array[String] = []
## Passive action keys - auto-executed each turn in addition to planned action (e.g. attack_passive).
@export var passive_action_keys: Array[String] = []
## Max health (0 = use default 2). Override per unit type.
@export var max_health: int = 0
## Max energy (0 = no energy bar). Ghost and similar units use energy for attacks.
@export var max_energy: int = 0
## Explicit move definitions. Ignored if move_action_keys is not empty.
@export var move_definitions: Array[ActionDefinition] = []
## Explicit ability definitions. Ignored if ability_action_keys is not empty.
@export var ability_definitions: Array[ActionDefinition] = []

func get_move_definitions_resolved() -> Array[ActionDefinition]:
	if move_action_keys.size() > 0:
		var result: Array[ActionDefinition] = []
		for key in move_action_keys:
			result.append_array(Actions.get_move_definitions_for_action(key))
		return result
	return move_definitions

func get_ability_definitions_resolved() -> Array[ActionDefinition]:
	if ability_action_keys.size() > 0:
		var result: Array[ActionDefinition] = []
		for key in ability_action_keys:
			result.append_array(Actions.get_ability_definitions_for_action(key))
		return result
	return ability_definitions

func get_passive_ability_definitions_resolved() -> Array[ActionDefinition]:
	if passive_action_keys.size() > 0:
		var result: Array[ActionDefinition] = []
		for key in passive_action_keys:
			result.append_array(Actions.get_passive_definitions_for_action(key))
		return result
	return []
