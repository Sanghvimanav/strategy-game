extends UnitTypeComponent
## Shows tile flame animation on all cells affected by Baneling explode (self + 6 adjacent).

const tile_flame = preload("res://src/unit/art/mage/tile_flame_spriteframes.tres")
const DELAY: float = 0.15
const OFFSET = Vector2(0, -8)

@onready var timer: Timer = $timer

var sprites: Array[AnimatedSprite2D] = []

func _on_attack_beginning(ac: ActionInstance) -> void:
	if not ac.definition or ac.definition.action_key != "explode":
		return
	for child in sprites:
		child.queue_free()
	sprites.clear()
	var full_path: Array = ac.path + [ac.end_point]
	for cell in full_path:
		var sprite = AnimatedSprite2D.new()
		sprite.sprite_frames = tile_flame
		sprite.z_index = 1
		add_child(sprite)
		sprite.global_position = Navigation.cell_to_world(cell, true) + OFFSET
		sprites.append(sprite)
		sprite.visible = false
	sprites.shuffle()
	timer.start(DELAY)
	await timer.timeout
	for child in sprites:
		child.visible = true
		child.play("default")
		await get_tree().process_frame
