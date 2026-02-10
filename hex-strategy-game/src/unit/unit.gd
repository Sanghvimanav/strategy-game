class_name Unit
extends Node2D

signal movement_complete
signal attack_beginning(ac)
signal attack_complete
signal death_animation_complete

@export var def: UnitDefinition
## Hex coordinate (q, r) for starting position. Use (-9999, -9999) to use scene position.
@export var starting_cell: Vector2i = Vector2i(-9999, -9999)
@export var move_speed_per_cell: float = 0.15
@export var flash_color: Color = Color('#b76954')

@onready var abilities_db: Node = %abilities_db
@onready var sprite: AnimatedSprite2D = %sprite
@onready var health_bar: Node2D = %health_bar
@onready var energy_bar: Node2D = %energy_bar
var _planned_checkmark: Label

var cell: Vector2:
	get:
		return Navigation.world_to_cell(global_position)

var max_health: int = 2
var health: int = 2: set = _set_health
var flash_tween: Tween
var max_energy: int = 0
var energy: int = 0

var is_active: bool:
	get:
		return health > 0

## Assigned during planning phase. Null until assigned.
var _planned_action_backing: ActionInstance = null
var planned_action: ActionInstance:
	get: return _planned_action_backing
	set(v):
		_planned_action_backing = v
		if _planned_checkmark:
			_planned_checkmark.visible = (v != null)
var planned_action_is_move: bool = false

func _ready() -> void:
	if starting_cell.x != -9999 or starting_cell.y != -9999:
		global_position = Navigation.cell_to_world(Vector2(starting_cell.x, starting_cell.y), true)
	else:
		global_position = Navigation.snap_to_tile(global_position, true)
	abilities_db.unit = self
	if def.max_health > 0:
		max_health = def.max_health
		health = max_health
	health_bar.init(health, max_health)
	max_energy = def.max_energy
	energy = max_energy
	if energy_bar:
		energy_bar.visible = max_energy > 0
		if max_energy > 0:
			energy_bar.init(energy, max_energy)
	_setup_planned_checkmark()
	_init_def()

func _setup_planned_checkmark() -> void:
	_planned_checkmark = Label.new()
	_planned_checkmark.text = "✓"
	_planned_checkmark.add_theme_font_size_override("font_size", 18)
	_planned_checkmark.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
	_planned_checkmark.position = Vector2(12, -28)
	_planned_checkmark.visible = false
	_planned_checkmark.z_index = 2
	add_child(_planned_checkmark)

func _init_def() -> void:
	sprite.sprite_frames = def.frames
	sprite.scale = def.sprite_scale
	sprite.position += def.sprite_offset
	sprite.play()
	
	for component in def.type_components:
		var comp = component.instantiate() as UnitTypeComponent
		add_child(comp)
		comp.unit = self

func attack(ac: ActionInstance) -> void:
	var is_passive := ac.definition and ac.definition.action_key in def.passive_action_keys
	if not is_passive and max_energy > 0 and energy > 0:
		energy -= 1
		if energy_bar:
			energy_bar.update_value(energy)
	attack_beginning.emit(ac)
	sprite.play('attack')
	if ac.end_point.x < cell.x:
		sprite.flip_h = true
	elif ac.end_point.x > cell.x:
		sprite.flip_h = false
	await sprite.animation_finished
	attack_complete.emit()
	sprite.play('idle')

func move_along_path(path: Array) -> void:
	if path.is_empty():
		movement_complete.emit()
		return
	var move_tween = create_tween()
	move_tween.set_ease(Tween.EASE_OUT)
	move_tween.set_trans(Tween.TRANS_CUBIC)
	for pcell in path:
		move_tween.tween_property(
			self,
			'global_position',
			Navigation.cell_to_world(pcell, true),
			move_speed_per_cell
		)
		if pcell.x < cell.x:
			sprite.flip_h = true
		elif pcell.x > cell.x:
			sprite.flip_h = false
	await move_tween.finished
	movement_complete.emit()

func get_attack_paths() -> Array:
	return abilities_db.get_attack_paths()

func get_move_paths() -> Array:
	return abilities_db.get_move_paths()

func _set_health(value: int) -> void:
	if value < health and value != 0:
		if flash_tween and flash_tween.is_valid():
			flash_tween.kill()
		sprite.play('hit')
		sprite.modulate = flash_color
		flash_tween = create_tween()
		flash_tween.set_ease(Tween.EASE_OUT)
		flash_tween.tween_property(sprite, 'modulate', Color.WHITE, 0.35)
		# Don't await - lets all hit animations play in parallel (damage applied in one batch)
		sprite.animation_finished.connect(func(): sprite.play('idle'), CONNECT_ONE_SHOT)
	health = value
	health_bar.update_value(health)
	if health == 0:
		sprite.play('death')
		if not sprite.animation_finished.is_connected(_on_death_finished):
			sprite.animation_finished.connect(_on_death_finished, CONNECT_ONE_SHOT)

func _on_death_finished() -> void:
	death_animation_complete.emit()
	visible = false
	# Don't queue_free: enables replay/undo to restore state

## Restore unit for replay/undo. Sets position, health, energy, and visibility.
func restore_state(cell: Vector2, health_val: int, energy_val: int = -1) -> void:
	global_position = Navigation.cell_to_world(cell, true)
	health = health_val
	if energy_val >= 0:
		energy = energy_val
		if energy_bar and max_energy > 0:
			energy_bar.update_value(energy)
	visible = true
	sprite.play("idle")
	sprite.modulate = Color.WHITE

