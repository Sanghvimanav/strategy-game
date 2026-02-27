extends Node
## Central game state and ENet client.
## Connects via ENetMultiplayerPeer; receives messages via GameServer.client_receive_message -> handle_server_message().

const DEFAULT_HOST := "127.0.0.1"
const DEFAULT_PORT := 8080

var game_state: Dictionary = {}
var player_id: int = -1
var player_color: String = ""
var player_username: String = "GodotPlayer"
var actions_list: Dictionary = {}

signal connected_to_server
signal username_requested
signal welcome_received(player_id: int, available_colors: Array, game_types: Array)
signal color_selected(color: String)
signal game_state_updated(state: Dictionary)
signal actions_list_received(actions: Dictionary)
signal game_over(winner_id: int)
signal error_message(message: String)

func _ready() -> void:
	pass


func _get_game_server() -> Node:
	return get_node_or_null("/root/GameServer")


func connect_to_server(host: String = DEFAULT_HOST, port: int = DEFAULT_PORT) -> Error:
	var gs: Node = _get_game_server()
	if gs == null:
		error_message.emit("GameServer node not found. Is main scene root named GameServer?")
		return ERR_DOES_NOT_EXIST
	if not gs.has_method("join_server"):
		error_message.emit("GameServer has no join_server method")
		return ERR_METHOD_NOT_FOUND
	return gs.join_server(host, port)


func _on_connected_to_server() -> void:
	connected_to_server.emit()
	send_username(player_username)


func send_username(username: String) -> void:
	player_username = username
	var gs: Node = _get_game_server()
	if gs != null and gs.has_method("server_receive_username"):
		gs.server_receive_username.rpc_id(1, username)


func send_color_selection(color: String) -> void:
	var gs: Node = _get_game_server()
	if gs != null and gs.has_method("server_receive_color_selection"):
		gs.server_receive_color_selection.rpc_id(1, color)


func send_action(unit_id: int, action_key: String, path: Array) -> void:
	var gs: Node = _get_game_server()
	if gs != null and gs.has_method("server_receive_action"):
		gs.server_receive_action.rpc_id(1, {
			unitId = unit_id,
			actionKey = action_key,
			path = path
		})


func send_restart() -> void:
	var gs: Node = _get_game_server()
	if gs != null and gs.has_method("server_receive_restart"):
		gs.server_receive_restart.rpc_id(1)


func send_game_type_selection(game_type: String) -> void:
	# Optional: add server_receive_game_type_selection if needed
	pass


## Called by GameServer.client_receive_message when server sends a message.
func handle_server_message(msg: Dictionary) -> void:
	var msg_type: String = str(msg.get("type", ""))
	match msg_type:
		"request_username":
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
			pass
		"game_over":
			game_over.emit(msg.get("winner", -1))
		"error":
			error_message.emit(msg.get("message", "Unknown error"))
		_:
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
