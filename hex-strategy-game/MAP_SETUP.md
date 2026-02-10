# Map and Starting Position Setup

## Board shape and size

**File:** `src/maps/hex_map.gd`

- **`hex_radius`** – Hexagon radius; only hexes within this distance from center (0,0) are included.
  - Default: 5 (board is 5 tiles from center to edge).
  - For radius 5, the map has ~91 hexes.
- **`spacing`** – Distance between hex centers (affects visual size).
- **`tile_radius`** – Size of each hex polygon.

The board is built as a hexagon by filtering hexes with `hex_distance(0, 0, q, r) <= hex_radius`.

## Starting positions

**File:** `src/battle/battle.tscn`

Unit positions are set as pixel coordinates on each unit node under `units/player` and `units/opponent`:

- `position = Vector2(x, y)` – pixel position in the battle scene.

When a battle starts, each unit’s position is snapped to the nearest hex. Use hex coordinates to decide where to place them:

- **Center:** (0, 0)
- **Axial:** `q` = east/west, `r` = north/south (negative r ≈ north).
- **Example:** Player at (-3, 2), (-4, 1); Opponent at (3, -2), (4, -1).

To convert hex (q, r) to pixels for the scene, you can:

1. Run the game, move a unit to the desired hex, and note its pixel position.
2. Use `Navigation.cell_to_world(Vector2(q, r))` in a script.
3. Adjust positions in the Godot editor and run the game to verify.
