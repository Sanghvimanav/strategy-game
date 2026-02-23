extends Node
## Central game state and WebSocket client.
## Connects to the same server as the HTML client; keeps state in sync with 'update' messages.

const SERVER_URL := "wss://strategy-game.onrender.com"
# const SERVER_URL := "ws://127.0.0.1:8080"

var socket: WebSocketPeer
var game_state: Dictionary = {}
var player_id: int = -1
var player_color: String = ""
var player_username: String = "GodotPlayer"
var actions_list: Dictionary = {}  # ACTIONS from server

signal connected_to_server
signal username_requested  # Server wants a username; UI should show input and then call send_username()
signal welcome_received(player_id: int, available_colors: Array, game_types: Array)
signal color_selected(color: String)
signal game_state_updated(state: Dictionary)
signal actions_list_received(actions: Dictionary)
signal game_over(winner_id: int)
signal error_message(message: String)

var _was_connected := false

func _ready() -> void:
	socket = WebSocketPeer.new()

func _process(_delta: float) -> void:
	# Must poll every frame so CONNECTING can become OPEN
	socket.poll()
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _was_connected:
			_was_connected = true
			connected_to_server.emit()
		while true:
			var packet := socket.get_packet()
			if packet.size() == 0:
				break
			var text := packet.get_string_from_utf8()
			_handle_message(text)
	elif state == WebSocketPeer.STATE_CLOSED:
		var code := socket.get_close_code()
		if code != -1:
			error_message.emit("Connection closed: code %d" % code)

func connect_to_server() -> Error:
	return socket.connect_to_url(SERVER_URL)

func send_color_selection(color: String) -> void:
	_send({ type = "color_selection", color = color })

func send_action(unit_id: int, action_key: String, path: Array) -> void:
	_send({
		type = "action",
		action = {
			unitId = unit_id,
			actionKey = action_key,
			path = path
		}
	})

func send_restart() -> void:
	_send({ type = "restart" })

func send_game_type_selection(game_type: String) -> void:
	_send({ type = "game_type_selection", gameType = game_type })

func send_username(username: String) -> void:
	player_username = username
	_send({ type = "username", username = username })

func _send(obj: Dictionary) -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	socket.send_text(JSON.stringify(obj))

func _handle_message(text: String) -> void:
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("JSON parse error: " + text)
		error_message.emit("JSON parse error")
		return
	var msg = json.get_data()
	if msg == null:
		return

	# Ensure type is a string (JSON may give StringName or int in some edge cases)
	var msg_type: String = str(msg.get("type", ""))
	match msg_type:
		"request_username":
			# Server wants a username; let the UI show an input, then call send_username()
			username_requested.emit()
		"welcome":
			player_id = msg.get("playerId", 0)
			var colors: Array = msg.get("availableColors", [])
			var types_raw: Array = msg.get("gameTypes", [])
			var game_types: Array = []
			for t in types_raw:
				game_types.append({ type_key = t.get("typeKey", ""), name = t.get("name", ""), description = t.get("description", "") })
			welcome_received.emit(player_id, colors, game_types)
		"color_selected":
			player_color = msg.get("color", "")
			color_selected.emit(player_color)
		"actions_list":
			actions_list = msg.get("actions", {})
			actions_list_received.emit(actions_list)
		"update":
			game_state = msg.get("state", {})
			game_state_updated.emit(game_state)
		"player_action":
			pass  # Optional: update local preview of other player's actions
		"game_over":
			game_over.emit(msg.get("winner", -1))
		"error":
			error_message.emit(msg.get("message", "Unknown error"))
		_:
			# Debug: server sent something we don't handle (e.g. empty type)
			if msg_type.is_empty():
				error_message.emit("Server sent message with no type. Keys: %s" % str(msg.keys()))
			else:
				error_message.emit("Unknown message type: '%s'" % msg_type)

func get_player_color(pid: int) -> String:
	var players: Array = game_state.get("players", [])
	for p in players:
		if p.get("playerId", -1) == pid:
			return p.get("color", "#000000")
	return "#000000"

func get_tile_key(q: int, r: int) -> String:
	return "%d,%d" % [q, r]
