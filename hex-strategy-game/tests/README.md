# Tests

Scenario and behavior tests for the hex strategy game. Run on commit or as needed.

## Run tests

You need **Godot 4** installed and the `godot` binary on your PATH (or use the full path to the executable).

From the **hex-strategy-game** project directory:

```bash
godot --headless --path . res://tests/test_runner.tscn
```

Or from repo root: `cd hex-strategy-game && godot --headless --path . res://tests/test_runner.tscn`

Or use the script (from hex-strategy-game): `./tests/run_tests.sh`

Exit code: `0` on success, `1` on failure. If `godot` is not found, add Godot to PATH or run with the full path (e.g. on macOS: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn`).

## Run on PR / merge (CI)

Tests run automatically on **push** and **pull_request** to `main` or `master` via GitHub Actions (`.github/workflows/tests.yml`). The workflow installs Godot 4.2.2 on Ubuntu and runs the test scene.

To run the same command manually (e.g. in another CI), from the repo root:

```bash
cd hex-strategy-game
godot --headless --path . res://tests/test_runner.tscn
```

Or use the script: `hex-strategy-game/tests/run_tests.sh`

## What's covered

- **Actions** – `get_action_type()` and `get_action_config()` callable on script class (static; avoids parser error), `ACTION_ORDER`, `energy_consumption` / `recharge` config, reload/recharge as slow ability.
- **HexGrid** – `cell_equal`, `hex_distance`, `are_adjacent`, `get_hexes_at_distance`, `build_path_to`.
- **TurnExecutor** – `ABILITY_TYPES` and `MOVE_TYPES`; `attack_passive` has pattern `"self"`; `get_damage_cells()` uses attacker's current cell for self-pattern (so Zergling can move then attack and hit Marine); fast ability before move in `ACTION_ORDER`.
- **EventBus** – `show_units_panel` signal exists and can be connected/emitted (avoids UNUSED_SIGNAL regression).

The tests use the real autoloads and scripts: **EventBus**, **TurnExecutor**, **Actions**, **HexGrid**.

## Adding tests

Add scripts under `tests/` that extend `RefCounted` and define `static func run_all(tests: Node) -> bool`; register in `run_tests.gd`.
