extends Node
## Project configuration. Server host/port for multiplayer (ENet).

const DEFAULT_SERVER_HOST := "127.0.0.1"
const DEFAULT_SERVER_PORT := 8081

func get_server_host() -> String:
	if ProjectSettings.has_setting("network/server_host"):
		return str(ProjectSettings.get_setting("network/server_host"))
	return DEFAULT_SERVER_HOST

func get_server_port() -> int:
	if ProjectSettings.has_setting("network/server_port"):
		return int(ProjectSettings.get_setting("network/server_port"))
	return DEFAULT_SERVER_PORT
