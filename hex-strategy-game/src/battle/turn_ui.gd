extends CanvasLayer

@onready var execute_button: Button = $turn_panel/vbox/execute_button
@onready var replay_button: Button = $turn_panel/vbox/replay_button
@onready var turn_label: Label = $turn_panel/vbox/turn_label
@onready var scenarios_button: Button = $turn_panel/vbox/scenarios_button

func _ready() -> void:
	execute_button.pressed.connect(_on_execute_pressed)
	execute_button.disabled = true
	if scenarios_button:
		scenarios_button.pressed.connect(_on_scenarios_pressed)
	if replay_button:
		replay_button.pressed.connect(_on_replay_pressed)
		replay_button.disabled = true
	EventBus.planning_started.connect(_on_planning_started)
	EventBus.planning_complete.connect(_on_planning_complete)
	EventBus.turn_changed.connect(_on_turn_changed)
	EventBus.replay_available_changed.connect(_on_replay_available_changed)
	EventBus.replay_finished.connect(_on_replay_finished)

func _on_turn_changed(turn_number: int) -> void:
	if turn_label:
		turn_label.text = "Turn %d" % turn_number

func _on_planning_started() -> void:
	execute_button.disabled = true

func _on_planning_complete() -> void:
	execute_button.disabled = false

func _on_execute_pressed() -> void:
	EventBus.execute_turn_requested.emit()
	execute_button.disabled = true

func _on_replay_pressed() -> void:
	EventBus.replay_turn_requested.emit()
	if replay_button:
		replay_button.disabled = true

func _on_replay_finished() -> void:
	if replay_button:
		replay_button.disabled = false

func _on_replay_available_changed(available: bool) -> void:
	if replay_button:
		replay_button.disabled = not available

func _on_scenarios_pressed() -> void:
	get_tree().change_scene_to_file("res://src/battle/scenario_picker.tscn")
