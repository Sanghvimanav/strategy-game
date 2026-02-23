#!/usr/bin/env bash
# Run the hex strategy game test suite. Use from repo root or from hex-strategy-game.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"
if command -v godot >/dev/null 2>&1; then
	godot --headless --path . res://tests/test_runner.tscn
else
	echo "Godot not found in PATH. Install Godot 4 and add it to PATH, or run:"
	echo "  godot --headless --path $PROJECT_DIR res://tests/test_runner.tscn"
	exit 1
fi
