extends CanvasLayer
## Scenario selection UI shown at game start. Pick a scenario and start battle.

@onready var list: VBoxContainer = $panel/margin/vbox/list
@onready var start_btn: Button = $panel/margin/vbox/start_btn

func _ready() -> void:
	_rebuild_buttons()
	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)

func _rebuild_buttons() -> void:
	if not list:
		return
	for c in list.get_children():
		c.queue_free()
	for s in Scenarios.available_scenarios:
		var btn := Button.new()
		btn.text = s.display_name
		btn.toggle_mode = true
		btn.button_group = _get_button_group()
		if s.id == Scenarios.selected_scenario_id:
			btn.button_pressed = true
		btn.pressed.connect(_on_scenario_pressed.bind(s.id))
		list.add_child(btn)

var _btn_group: ButtonGroup
func _get_button_group() -> ButtonGroup:
	if _btn_group == null:
		_btn_group = ButtonGroup.new()
	return _btn_group

func _on_scenario_pressed(id: String) -> void:
	Scenarios.select_scenario(id)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://src/battle/battle.tscn")
