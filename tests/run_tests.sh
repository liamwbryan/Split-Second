#!/usr/bin/env bash
# Headless movement/weapon regression tests.
#   tests/run_tests.sh              run everything
#   tests/run_tests.sh wallrun      run one test by name
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# Refresh the global class cache so newly added class_name scripts resolve.
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
ARGS=()
[[ $# -gt 0 ]] && ARGS=(++ "--only=$1")
# perl alarm = portable timeout (macOS has no `timeout`); a compile error would otherwise hang.
perl -e 'alarm shift; exec @ARGV' 600 \
	"$GODOT" --headless --path . --fixed-fps 120 res://tests/movement_tests.tscn ${ARGS[@]+"${ARGS[@]}"} 2>&1 \
	| grep -vE "^\s*$|ObjectDB instances|Godot Engine v|at: cleanup|resources still in use"
status="${PIPESTATUS[0]}"
# Level placement lint (dummies inside walls, floating, spawns in geometry).
perl -e 'alarm shift; exec @ARGV' 120 "$GODOT" --headless --path . -s res://tests/level_lint.gd 2>&1 \
	| grep -E "FAIL|level lint|SCRIPT ERROR|Parse Error" || true
lint="${PIPESTATUS[0]}"
[[ "$status" != 0 ]] && exit "$status"
exit "$lint"
