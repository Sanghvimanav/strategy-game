extends Node2D
## One-shot heal VFX: plays the default animation then frees itself.

@onready var sprite: AnimatedSprite2D = $sprite

func _ready() -> void:
	sprite.modulate = Color(0.85, 1.0, 0.9)  # Slight green tint
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("default")

func _on_animation_finished() -> void:
	queue_free()
