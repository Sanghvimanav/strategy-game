# Converting Hex Conquest to Godot

This guide explains how to turn your HTML/JS hex strategy game into a **Godot 4** project while keeping the same WebSocket server and game logic.

## What You Have Now

- **Client:** Single HTML file with SVG hex grid, WebSocket client, turn-based UI (unit selection, actions, path building).
- **Server:** Node.js (`server3.js`) with WebSocket; handles game state, turns, actions, win conditions.

## High-Level Strategy

1. **Keep the server** – Your existing Node WebSocket server can stay unchanged. Godot will connect as a client using the same JSON message protocol.
2. **Recreate the client in Godot** – Hex grid, units, and UI as Godot scenes/nodes; game state and message handling in GDScript.
3. **Port hex math and game rules** – Reuse your axial coordinates, `hexToPixel`, path validation, and action flow in GDScript.

## 1. Godot Version and Setup

- Use **Godot 4.x** (4.2 or 4.3).
- Create a new project (Renderer: Forward+ or Mobile is fine; 2D game).

## 2. Project Structure (Suggested)

```
strategy-game-godot/
├── project.godot
├── main.tscn                    # Root: UI + game view
├── scenes/
│   ├── hex_tile.tscn            # Single hex (Polygon2D or custom)
│   ├── unit_display.tscn        # Unit sprite/circle + label
│   └── game_board.tscn          # Container for hex grid + units
├── scripts/
│   ├── game_client.gd           # WebSocket + game state + message handling
│   ├── hex_grid.gd              # Hex math (axial coords, pixel, neighbors)
│   ├── board_renderer.gd        # Build/update hexes and units from state
│   └── ui_controller.gd        # Panels, buttons, log, turn counter
└── assets/                      # Textures, fonts (optional)
```

## 3. WebSocket Connection (Same Protocol)

Your server sends/receives JSON. In Godot use `WebSocketPeer` (or the high-level `WebSocketClient` in 4.x):

- **Connect** to `wss://strategy-game.onrender.com` (or `ws://127.0.0.1:8080` for local).
- **On connect:** same flow (e.g. receive `welcome` → show color selection).
- **Send:** `color_selection`, `action`, `restart`, `game_type_selection` with the same JSON shapes.
- **Receive:** `update` (full state), `player_action`, `game_over`, `actions_list`, etc.

Example (conceptual) in GDScript:

```gdscript
var socket: WebSocketPeer

func _ready():
    socket = WebSocketPeer.new()
    var err = socket.connect_to_url("wss://strategy-game.onrender.com")
    # Then poll in _process() and parse JSON from socket.get_packet().get_string_from_utf8()
```

Parse incoming JSON with `JSON.parse_string()` and update a central **game state** object (grid, players, units, turn, lastTurnActions, etc.) that mirrors your current `gameState` in JS.

## 4. Hex Grid in Godot

- **Coordinates:** Keep axial `(q, r)`. Port `hexToPixel`, `calculateMapBounds`, and neighbor directions from your JS (e.g. the 6 `{ dq, dr }` direction list).
- **Rendering:** Each hex can be a `Polygon2D` (or a scene with `Polygon2D` + optional `Label`). Build polygon points from your existing formula (e.g. 6 vertices, 30° step, radius = tile size). Apply `tile.color` for fill.
- **Height/ramps:** You already have `height` and `enterableFromDirections`. Use them the same way for movement validation; you can optionally offset hex position by `height * HEIGHT_MULTIPLIER` when converting to pixel (as in your `hexToPixel`).
- **Input:** Use `_input_event()` or a global click and **pixel-to-hex**: convert mouse position to `(q, r)` (inverse of `hexToPixel`) and look up the tile in `gameState.grid[key]`. Then replicate your `handleTileClick` logic (select unit, show actions, build path, finalize).

## 5. Units and Actions

- **Units:** For each unit (or stack) on a hex, draw a circle and label at the hex center (e.g. `Sprite2D` + `Label`, or custom draw in a `Node2D`). Use `getPlayerColor(playerId)` equivalent for color; show count and maybe type abbreviation.
- **Actions:** When the user selects a unit, show the same action list (from `ACTIONS` / `actions_list`). On “action with path”, build `movementPath` by clicking adjacent hexes (same rules: adjacency, range, enterable directions). When done, send `{ type: "action", action: { unitId, actionKey, path } }` as in your JS.

Reuse the server’s validation; Godot only needs to send valid paths and action keys and to reflect the state it receives in `update`.

## 6. UI Equivalents

| HTML/JS                    | Godot approach |
|----------------------------|----------------|
| Color selection panel      | `VBoxContainer` + `Button` per color; send `color_selection` on click |
| Game type (player 1)       | Same: buttons from `gameTypes`, send `game_type_selection` |
| Units panel (list)         | `ItemList` or `VBoxContainer` of labels/buttons; show unit details, highlight selected |
| Action buttons             | Dynamic `HBoxContainer`/`VBoxContainer` of `Button`s from `ACTIONS` |
| Turn counter               | `Label` text = `"Turn: %d" % game_state.turn` |
| Log                        | `TextEdit` or `ItemList` (read-only), append new messages |
| Restart                    | `Button` → send `restart` |
| Trail/attack lines         | `Line2D` or `draw_line` in a `Node2D`; use `lastTurnActions` to draw moves/attacks same as in JS |

## 7. Game State and Message Flow

- **Single source of truth:** One object (e.g. autoload `GameState` or a node) holding: `grid`, `players`, `turn`, `playerActions`, `lastTurnActions`, `delayedActions`, `lastTurnDefeatedUnits`, `winConditions`, `actions` (from `actions_list`).
- **On `update`:** Replace local game state with `message.state`, then refresh:
  - Hex grid (tile colors, heights if you draw them).
  - Units on hexes.
  - Trail/attack lines from `lastTurnActions` and delayed-action targets from `delayedActions`.
  - UI: turn, player info, unit list, action buttons (based on selected unit and power).
- **On `game_over`:** Show a popup or label with winner; optionally offer restart.

## 8. What to Port Directly

- **Hex math:** `hexToPixel`, `calculateMapBounds`, `getAdjacentTileKeys`, `getAdjacentTile`, `hexDistance`, `getDirectionIndex`, axial directions list.
- **Game rules:** Movement validation (adjacency, height, enterable directions), action keys and ranges – server already enforces; client can mirror for UX (e.g. highlighting valid tiles).
- **Message types and JSON shapes:** Keep identical so the same `server3.js` works without changes.

## 9. Optional: Run Server from Godot

You can keep running the server with `node server3.js` (or your existing deploy). If you later want a Godot-based server, you’d reimplement the turn execution and state updates in GDScript and use `WebSocketServer` or ENet, and still keep the same message protocol so both HTML and Godot clients can connect.

## 10. Minimal First Milestone

1. Godot project with a single scene that connects to your WebSocket server.
2. On `welcome`, show color selection; on `update`, parse state and draw a simple hex grid (no units yet).
3. Add unit circles and labels from `gameState.players[].units` and `grid[key].units`.
4. Add tile click → unit selection → action buttons → path building → send `action` and refresh from `update`.

Once that works, add polish: ramps, delayed actions, log, turn counter, game-over screen, and any visuals you want beyond the current SVG look.

---

**Summary:** Treat the Godot client as a new front-end that speaks the same WebSocket protocol as your HTML client. Port hex math and state handling to GDScript, and replicate UI and input flow. Your existing Node server can stay as-is.
