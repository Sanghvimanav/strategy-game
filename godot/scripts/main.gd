extends Control
## Main scene: connects to server, shows color selection, and refreshes board on state updates.

@onready var status_label: Label = $StatusLabel
@onready var username_panel: PanelContainer = $UsernamePanel
@onready var username_edit: LineEdit = $UsernamePanel/VBox/UsernameEdit
@onready var username_ok: Button = $UsernamePanel/VBox/OKButton
@onready var color_selection: PanelContainer = $ColorSelection
@onready var color_vbox: VBoxContainer = $ColorSelection/VBox
@onready var turn_label: Label = $TurnLabel
@onready var log_edit: TextEdit = $Log
@onready var board_viewport: SubViewportContainer = $BoardViewport
@onready var board_renderer: Node2D = $BoardViewport/SubViewport/BoardRenderer

func _ready() -> void:
	# Connect all signals first
	GameState.connected_to_server.connect(_on_connected)
	GameState.username_requested.connect(_on_username_requested)
	GameState.welcome_received.connect(_on_welcome)
	GameState.color_selected.connect(_on_color_selected)
	GameState.game_state_updated.connect(_on_state_updated)
	GameState.game_over.connect(_on_game_over)
	GameState.error_message.connect(_on_error)
	GameState.actions_list_received.connect(_on_actions_list)
	username_ok.pressed.connect(_on_username_submitted)
	username_edit.text_submitted.connect(_on_username_submitted)

	# Start connection immediately so we get welcome / request_username
	status_label.text = "Connecting..."
	_log("Connecting...")
	var err: Error = GameState.connect_to_server()
	if err != OK:
		status_label.text = "Connection failed"
		_log("Failed to start connection: %s" % error_string(err))

func _on_username_requested() -> void:
	status_label.text = "Enter your name"
	username_panel.visible = true
	username_edit.clear()
	username_edit.placeholder_text = "Your name"
	username_edit.grab_focus()

func _on_username_submitted(_arg: String = "") -> void:
	var name_str: String = username_edit.text.strip_edges()
	if name_str.is_empty():
		name_str = "Player"
	GameState.send_username(name_str)
	username_panel.visible = false
	status_label.text = "Username sent, waiting for welcome..."
	_log("Username set: %s" % name_str)

func _on_connected() -> void:
	status_label.text = "Connected, waiting for server..."
	_log("Connected! Waiting for welcome...")

func _on_welcome(player_id: int, available_colors: Array, _game_types: Array) -> void:
	status_label.text = "Welcome! Select your color."
	_log("Welcome, player %d. Select your color." % player_id)
	color_selection.visible = true
	# Clear previous color buttons
	for c in color_vbox.get_children():
		if c is Button:
			c.queue_free()
	# Use server colors, or fallback if empty
	var colors: Array = available_colors
	if colors.is_empty():
		colors = ["#4CAF50", "#0000FF", "#FFA500", "#800080", "#FF0000", "#00FFFF"]
	# Add color buttons (one per color)
	for col in colors:
		var btn := Button.new()
		btn.text = col
		btn.custom_minimum_size = Vector2(80, 36)
		var font_col: Color = Color.from_string(col if col.begins_with("#") else "#000000", Color.BLACK)
		btn.add_theme_color_override("font_color", font_col)
		btn.pressed.connect(_on_color_button_pressed.bind(col))
		color_vbox.add_child(btn)

func _on_color_button_pressed(color: String) -> void:
	GameState.send_color_selection(color)
	color_selection.visible = false
	_log("Color selected. Waiting for other players...")

func _on_color_selected(_color: String) -> void:
	pass

func _on_state_updated(state: Dictionary) -> void:
	var turn: int = state.get("turn", 0)
	turn_label.text = "Turn: %d" % turn

func _on_game_over(winner_id: int) -> void:
	if winner_id > 0:
		_log("Game Over! Player %d wins!" % winner_id)
	else:
		_log("Game Over! Draw or turn limit.")

func _on_error(message: String) -> void:
	_log("Error: %s" % message)

func _on_actions_list(_actions: Dictionary) -> void:
	_log("Actions list received.")

func _log(msg: String) -> void:
	log_edit.text += msg + "\n"
	log_edit.scroll_vertical = 99999
