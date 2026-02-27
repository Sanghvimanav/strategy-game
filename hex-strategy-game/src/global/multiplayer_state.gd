extends Node
## Holds multiplayer battle state when host launches; battle scene can read this to run in multiplayer mode.

var pending_battle_state: Dictionary = {}
var is_multiplayer: bool = false
var is_host: bool = false
var my_group: String = ""

func clear() -> void:
	pending_battle_state = {}
	is_multiplayer = false
	is_host = false
	my_group = ""
