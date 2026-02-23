# Hex Conquest – Godot 4 Client

Minimal Godot 4 project that connects to the same WebSocket server as the HTML client.

## How to run

1. **Godot 4.2+** – Install from [godotengine.org](https://godotengine.org).
2. **Start the server** (from the repo root):
   ```bash
   node server3.js
   ```
3. **Open this folder in Godot** – Open Project → select `godot/project.godot`.
4. **Run the project** (F5 or Play). It will connect to `wss://strategy-game.onrender.com` by default. To use your local server, change `SERVER_URL` in `scripts/game_state.gd` to `ws://127.0.0.1:8080`.
5. **Select a color** when the welcome panel appears. When all players have chosen colors, the hex board and units will appear.

## What’s included

- **HexGrid** (autoload) – Axial hex math: `hex_to_pixel`, `pixel_to_hex`, `calculate_map_bounds`, `get_adjacent_tile_keys`, `hex_distance`, `polygon_points_hex`.
- **GameState** (autoload) – WebSocket client and game state; same message protocol as the HTML client.
- **BoardRenderer** – Draws hex tiles and unit stacks from `GameState.game_state`.
- **Main** – UI: color selection, turn label, log. Hooks up signals from GameState.

## Next steps

- **Tile click** – In `BoardRenderer` or main, handle input and call `HexGrid.pixel_to_hex` + `GameState.get_tile_key` to get the clicked hex; then implement unit selection and action flow (see `GODOT_CONVERSION.md`).
- **Units panel & action buttons** – Recreate the HTML units list and action buttons; send actions with `GameState.send_action(unit_id, action_key, path)`.
- **Camera/pan** – Add a `Camera2D` and pan/zoom so the board stays centered or scrollable.

See **../GODOT_CONVERSION.md** for the full conversion guide.
