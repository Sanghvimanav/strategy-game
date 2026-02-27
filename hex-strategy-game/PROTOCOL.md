# Hex Strategy Game – Multiplayer Protocol

ENet protocol for the Godot multiplayer server. The server runs inside the same project: run **res://src/server/game_server.tscn** as main scene to host. Clients connect via ENet to the host and port (see Config.get_server_host() / get_server_port()), then send messages as dictionaries via **server_receive_packet.rpc_id(1, msg)**. The server sends back using **client_receive_message**; connect to the GameServer node’s **server_message_received** signal to handle them.

## Client → Server

| Type | Payload | Description |
|------|---------|-------------|
| `username` | `{ username: string }` | Identify on connect. Server responds with `welcome`. |
| `create_game` | `{ scenario_id?: string }` | Create a new game. Optional scenario (default: "default"). |
| `join_game` | `{ game_id?: string, short_code?: string }` | Join by game_id or short_code. |
| `submit_actions` | `{ actions: Array<Action> }` | Submit planned actions for current turn. |
| `restart` | `{}` | Request game restart. |

### Action shape

```json
{
  "unit_id": 1,
  "action_key": "move_short",
  "path": [[1, 0]],
  "end_point": [2, 0]
}
```

- `unit_id`: Server-assigned unit id from game_state.
- `action_key`: e.g. `move_short`, `attack_short`, `fast_move`, `reload`.
- `path`: Array of `[q, r]` hex cells (movement path).
- `end_point`: `[q, r]` target cell.

## Server → Client

| Type | Payload | Description |
|------|---------|-------------|
| `welcome` | `{ player_id, session_id, message }` | After username. |
| `lobby` | `{ games: Array }` | List of games (game_id, short_code, scenario_id, player_count, status). |
| `game_created` | `{ game_id, short_code, scenario_id, your_group }` | After create_game. |
| `game_joined` | `{ game_id, your_group, scenario_id }` | After join_game. |
| `game_state` | `{ state: GameState, turn_result?: TurnResult }` | Full state; optional turn_result after execution. |
| `player_actions_received` | `{ group, state }` | When a group submits actions. |
| `game_over` | `{ winner: string \| null, message }` | Game ended. |
| `error` | `{ message: string }` | Validation or protocol error. |

## GameState shape

- `game_id`, `short_code`, `scenario_id`, `phase` ("planning" | "executing"), `turn`
- `groups`: each has `name`, `ai`, `player_id`, `units`: array of `{ unit_id, def_path, cell, health, max_health, energy, max_energy, is_active }`
- `player_actions`: per-group submitted actions for current turn

## How to host and test by yourself

1. **Main scene** is `res://src/main_menu.tscn` (menu with Host / Join / Single player).
2. **First window:** Run the project → click **Host server**. That window becomes the server (listens on port 8081). You can leave it open or minimize it.
3. **Second window:** Run the project again (e.g. Run → Run Project again, or a second editor run) → click **Join game**. That window opens the multiplayer lobby and connects to the server.
4. In the lobby: enter a name, then one window **Create game**, the other **Join game** with the shown code. Both are now in the same game.

**Client connection:** Use the **multiplayer lobby** scene: set Main Scene to `res://src/multiplayer/multiplayer_lobby.tscn`, run the project (with the server already running in another instance or from a separate run). The lobby connects, asks for your name, then lets you Create game or Join with a code. For a custom client, ensure the scene has a node with the GameServer script, call `join_server(host, port)`, send messages with `server_receive_packet.rpc_id(1, msg)`, and connect to `server_message_received` to handle replies.
