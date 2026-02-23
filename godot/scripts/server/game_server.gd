extends Node
## Minimal WebSocket server – same JSON protocol as server3.js.
## Run this as the main scene (or in a dedicated project) to host; point clients at ws://127.0.0.1:PORT.
## Expand _handle_message() with full game state and turn logic ported from server3.js.

const PORT := 8080

var _server: WebSocketServer
var _next_player_id: int = 1
# Map server peer id (from Godot) -> our player id (1, 2, 3...)
var _server_id_to_player_id: Dictionary = {}
# Map our player id -> server peer id (for sending)
var _player_id_to_server_id: Dictionary = {}
var _game_state: Dictionary = {}  # TODO: port full state from server3.js

func _ready() -> void:
	_server = WebSocketServer.new()
	_server.client_connected.connect(_on_client_connected)
	_server.client_disconnected.connect(_on_client_disconnected)
	_server.data_received.connect(_on_data_received)
	var err := _server.listen(PORT)
	if err != OK:
		push_error("Server failed to listen on port %d: %s" % [PORT, error_string(err)])
		return
	print("WebSocket server listening on port %d" % PORT)

func _process(_delta: float) -> void:
	_server.poll()

func _on_client_connected(server_id: int, _proto: String) -> void:
	var player_id: int = _next_player_id
	_next_player_id += 1
	_server_id_to_player_id[server_id] = player_id
	_player_id_to_server_id[player_id] = server_id
	_send_welcome(player_id)
	print("Client connected (server id %d) -> player %d" % [server_id, player_id])

func _on_client_disconnected(server_id: int, _was_clean: bool) -> void:
	var player_id: int = _server_id_to_player_id.get(server_id, -1)
	_server_id_to_player_id.erase(server_id)
	if player_id >= 0:
		_player_id_to_server_id.erase(player_id)
	print("Client disconnected (server id %d, player %d)" % [server_id, player_id])

func _on_data_received(server_id: int) -> void:
	var peer: WebSocketPeer = _server.get_peer(server_id)
	if peer.get_available_packet_count() == 0:
		return
	var packet: PackedByteArray = peer.get_packet()
	var text: String = packet.get_string_from_utf8()
	var player_id: int = _server_id_to_player_id.get(server_id, -1)
	_handle_message(player_id, server_id, text)

func _send_welcome(player_id: int) -> void:
	var colors: Array = ["#4CAF50", "#0000FF", "#FFA500", "#800080", "#FF0000", "#00FFFF"]
	var game_types: Array = [
		{ typeKey = "elimination", name = "Elimination", description = "Eliminate all opponent units." },
		{ typeKey = "goldRush", name = "Gold Rush", description = "First to 30 gold wins." },
	]
	var msg: Dictionary = {
		type = "welcome",
		playerId = player_id,
		availableColors = colors,
		gameTypes = game_types
	}
	_send_to_player(player_id, msg)

func _handle_message(player_id: int, _server_id: int, text: String) -> void:
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("Invalid JSON from player %d" % player_id)
		return
	var msg = json.get_data()
	if msg == null:
		return
	var msg_type: String = str(msg.get("type", ""))
	match msg_type:
		"username":
			print("Player %d username: %s" % [player_id, msg.get("username", "")])
		"color_selection":
			# TODO: assign color, check if all ready, then initialize game and broadcast update
			print("Player %d chose color %s" % [player_id, msg.get("color", "")])
		"action":
			# TODO: validate and store in playerActions; when all ready, execute turn and broadcast
			pass
		"restart":
			# TODO: reset game state and broadcast
			pass
		_:
			print("Unknown message type from player %d: %s" % [player_id, msg_type])

func _send_to_player(player_id: int, obj: Dictionary) -> void:
	var server_id: int = _player_id_to_server_id.get(player_id, -1)
	if server_id < 0:
		return
	var peer: WebSocketPeer = _server.get_peer(server_id)
	peer.send_text(JSON.stringify(obj))

func _broadcast(obj: Dictionary) -> void:
	var text: String = JSON.stringify(obj)
	for server_id in _server_id_to_player_id:
		_server.get_peer(server_id).send_text(text)
