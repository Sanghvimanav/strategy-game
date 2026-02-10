extends PanelContainer
## Shows last turn's actions when replaying, including dead units.

@onready var title_label: Label = $margin/vbox/title
@onready var lines_container: VBoxContainer = $margin/vbox/lines

func _ready() -> void:
	EventBus.show_replay_summary.connect(_on_show_replay_summary)
	EventBus.replay_finished.connect(_on_replay_finished)
	hide()

func _on_show_replay_summary(lines: Array) -> void:
	title_label.text = "Last turn actions"
	for c in lines_container.get_children():
		c.queue_free()
	for line in lines:
		var lbl := Label.new()
		lbl.text = str(line)
		lines_container.add_child(lbl)
	show()

func _on_replay_finished() -> void:
	hide()
