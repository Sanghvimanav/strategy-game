extends Node2D

@onready var hex_map: Node2D = %hex_map
@onready var units: UnitsContainer = %units
@onready var camera: Camera2D = $Camera2D

const SCROLL_SPEED := 200.0
const ZOOM_MIN := 1.5
const ZOOM_MAX := 4.0
const ZOOM_STEP := 0.1

var _panning := false

func _ready() -> void:
	# Navigation is initialized by hex_map._ready() (runs before units)
	var scenario := Scenarios.get_selected_scenario()
	if not scenario.is_empty():
		units.apply_scenario(scenario)
	units.start_battle()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_camera(1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_camera(-1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _panning:
		camera.position -= event.relative / camera.zoom.x
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		if event.pressed:
			var delta := Vector2.ZERO
			if event.keycode in [KEY_W, KEY_UP]:
				delta.y = -1
			elif event.keycode in [KEY_S, KEY_DOWN]:
				delta.y = 1
			elif event.keycode in [KEY_A, KEY_LEFT]:
				delta.x = -1
			elif event.keycode in [KEY_D, KEY_RIGHT]:
				delta.x = 1
			if delta != Vector2.ZERO:
				camera.position += delta * SCROLL_SPEED
				get_viewport().set_input_as_handled()

func _zoom_camera(direction: int) -> void:
	var target := camera.zoom.x + direction * ZOOM_STEP
	target = clampf(target, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(target, target)
