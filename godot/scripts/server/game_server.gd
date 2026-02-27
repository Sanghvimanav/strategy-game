extends Node
## Game server using ENetMultiplayerPeer. Same node works as host or client.
## Run as main scene to host; run main.tscn and call join_server() to connect as client.
## Client sends: server_receive_username(), server_receive_color_selection(), server_receive_action(), server_receive_restart().

const PORT := 8080
const MAX_CLIENTS := 16
const DEFAULT_HOST := "127.0.0.1"

var _peer
var _next_player_id: int = 1
var _peer_id_to_player_id: Dictionary = {}
var _player_id_to_peer_id: Dictionary = {}
var _game_state: Dictionary = {}

func _ready() -> void:
	# If this scene has no Main child, we're the dedicated server scene (run alone to host).
	if _is_dedicated_server_scene():
		_start_server()


func _is_dedicated_server_scene() -> bool:
	return get_node_or_null("Main") == null


func _start_server() -> void:
	_peer = ENetMultiplayerPeer.new()
	var err: int = _peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		push_error("Server failed to create ENet server on port %d: %s" % [PORT, error_string(err)])
		return
	multiplayer.multiplayer_peer = _peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("ENet server listening on port %d" % PORT)


func join_server(host: String = DEFAULT_HOST, port: int = PORT) -> Error:
	if _peer != null:
		return ERR_ALREADY_IN_USE
	_peer = ENetMultiplayerPeer.new()
	var err: int = _peer.create_client(host, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = _peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	print("ENet client connecting to %s:%d" % [host, port])
	return OK


func _on_connected_to_server() -> void:
	if Engine.has_singleton("GameState"):
		GameState._on_connected_to_server()
	return


func _on_connection_failed() -> void:
	if Engine.has_singleton("GameState"):
		GameState.error_message.emit("Connection failed")
	return


func _on_peer_connected(peer_id: int) -> void:
	var player_id: int = _next_player_id
	_next_player_id += 1
	_peer_id_to_player_id[peer_id] = player_id
	_player_id_to_peer_id[player_id] = peer_id
	_send_welcome(player_id)
	print("Peer %d connected -> player %d" % [peer_id, player_id])


func _on_peer_disconnected(peer_id: int) -> void:
	var player_id: int = _peer_id_to_player_id.get(peer_id, -1)
	_peer_id_to_player_id.erase(peer_id)
	if player_id >= 0:
		_player_id_to_peer_id.erase(player_id)
	print("Peer %d disconnected (player %d)" % [peer_id, player_id])


func _send_to_player(player_id: int, obj: Dictionary) -> void:
	var peer_id: int = _player_id_to_peer_id.get(player_id, -1)
	if peer_id < 0:
		return
	client_receive_message.rpc_id(peer_id, obj)


func _broadcast(obj: Dictionary) -> void:
	for peer_id in _peer_id_to_player_id:
		client_receive_message.rpc_id(peer_id, obj)


## Called on clients when server sends a message. Forwards to GameState so UI stays in sync.
@rpc("authority", "reliable")
func client_receive_message(obj: Dictionary) -> void:
	if Engine.has_singleton("GameState"):
		GameState.handle_server_message(obj)
	return


# ---- Server RPCs: called by clients ----

@rpc("any_peer", "reliable")
func server_receive_username(username: String) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	var player_id: int = _peer_id_to_player_id.get(peer_id, -1)
	if player_id < 0:
		return
	print("Player %d username: %s" % [player_id, username])


@rpc("any_peer", "reliable")
func server_receive_color_selection(color: String) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	var player_id: int = _peer_id_to_player_id.get(peer_id, -1)
	if player_id < 0:
		return
	print("Player %d chose color %s" % [player_id, color])
	# TODO: assign color, check if all ready, then initialize game and broadcast update


@rpc("any_peer", "reliable")
func server_receive_action(action: Dictionary) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	var player_id: int = _peer_id_to_player_id.get(peer_id, -1)
	if player_id < 0:
		return
	# TODO: validate and store in playerActions; when all ready, execute turn and broadcast
	pass


@rpc("any_peer", "reliable")
func server_receive_restart() -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	var player_id: int = _peer_id_to_player_id.get(peer_id, -1)
	if player_id < 0:
		return
	# TODO: reset game state and broadcast
	pass


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
