# Tests

Scenario and behavior tests for the hex strategy game. Run on commit or as needed.

## Run locally

From the **hex-strategy-game** project directory:

```bash
# If Godot is in your PATH
godot --headless --path . res://tests/test_runner.tscn

# Or use the script (from hex-strategy-game)
./tests/run_tests.sh
```

Exit code: `0` on success, `1` on failure.

## Run on PR / merge (CI)

Tests run automatically on **push** and **pull_request** to `main` or `master` via GitHub Actions (`.github/workflows/tests.yml`). The workflow installs Godot 4.2.2 on Ubuntu and runs the test scene.

To run the same command manually (e.g. in another CI), from the repo root:

```bash
cd hex-strategy-game
godot --headless --path . res://tests/test_runner.tscn
```

Or use the script: `hex-strategy-game/tests/run_tests.sh`

## What’s covered

- **Actions** – `get_action_type()` and `get_action_config()` callable on script class (static; avoids parser error), `ACTION_ORDER`, `energy_consumption` / `recharge` config, reload/recharge as slow ability.
- **HexGrid** – `cell_equal`, `hex_distance`, `are_adjacent`, `get_hexes_at_distance`, `build_path_to`.
- **TurnExecutor** – `ABILITY_TYPES` and `MOVE_TYPES`; `attack_passive` has pattern `"self"`; `get_damage_cells()` uses attacker’s current cell for self-pattern (so Zergling can move then attack and hit Marine); fast ability before move in `ACTION_ORDER`.
- **EventBus** – `show_units_panel` signal exists and can be connected/emitted (avoids UNUSED_SIGNAL regression).

## Adding tests

- Add new test scripts under `tests/` that extend `RefCounted` and define `static func run_all(tests: Node) -> bool`.
- Call your script from `run_tests.gd` in `_ready()` and use `tests._log()`, `tests._pass()`, `tests._fail()` for output.
