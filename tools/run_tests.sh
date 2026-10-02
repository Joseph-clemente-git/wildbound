#!/usr/bin/env bash
# Re-imports the project (refreshes the global class cache) and runs the
# headless test suite. Usage: tools/run_tests.sh [filter]
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
args=()
if [[ $# -gt 0 ]]; then args=(-- "--filter=$1"); fi
"$GODOT" --headless --path . res://tests/test_runner.tscn "${args[@]}" 2>&1 | grep -vE '^\s*$|^Godot Engine'
