extends PanelContainer

@onready var list: VBoxContainer = $list

func _ready() -> void:
	_build_list()

func _build_list() -> void:
	if not list:
		return
	for child in list.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "Action Order"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.WHITE)
	list.add_child(title)
	for i in Actions.ACTION_ORDER.size():
		var action_type: String = Actions.ACTION_ORDER[i]
		var label := Label.new()
		label.text = "%d. %s" % [i + 1, action_type.capitalize()]
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		list.add_child(label)
