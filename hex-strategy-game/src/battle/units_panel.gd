extends PanelContainer
## Units panel: when multiple player units are on the same hex, shows a list to pick which to plan for.

@onready var title_label: Label = $margin/vbox/title
@onready var units_list: VBoxContainer = $margin/vbox/units_list

func _ready() -> void:
	EventBus.show_units_panel.connect(_on_show_units_panel)
	EventBus.planning_started.connect(_on_planning_started)
	hide()

func _on_planning_started() -> void:
	hide()

func _on_show_units_panel(units: Array) -> void:
	title_label.text = "Select unit at hex (%d, %d)" % [int(units[0].cell.x), int(units[0].cell.y)]
	for c in units_list.get_children():
		c.queue_free()
	for u in units:
		var btn := Button.new()
		btn.text = u.def.name
		btn.pressed.connect(_on_unit_picked.bind(u))
		units_list.add_child(btn)
	show()

func _on_unit_picked(unit: Unit) -> void:
	hide()
	EventBus.unit_pick_requested.emit(unit)
