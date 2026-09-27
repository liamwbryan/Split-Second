#!/usr/bin/env bash
# Headless movement/weapon regression tests.
#   tests/run_tests.sh              run everything
#   tests/run_tests.sh wallrun      run one test by name
#   tests/run_tests.sh aim          aim assist tests only (aim:slowdown_near_target for one)
#   tests/run_tests.sh spiral       SPIRAL route checks only
#   tests/run_tests.sh weapons      weapon tests only (weapon:lunge_closes_distance for one)
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
# Gamepad aim assist (scripted stick/mouse look against dummies).
if [[ $# -eq 0 || "$1" == aim* ]]; then
	AIM_ARGS=()
	[[ $# -gt 0 && "$1" != "aim" ]] && AIM_ARGS=(++ "--only=${1#aim:}")
	perl -e 'alarm shift; exec @ARGV' 180 \
		"$GODOT" --headless --path . --fixed-fps 120 res://tests/aim_assist_tests.tscn ${AIM_ARGS[@]+"${AIM_ARGS[@]}"} 2>&1 \
		| grep -vE "^\s*$|ObjectDB instances|Godot Engine v|at: cleanup|at: clear|resources still in use"
	aim="${PIPESTATUS[0]}"
	[[ "$aim" != 0 && "$status" == 0 ]] && status="$aim"
fi
# Weapons (slots, rail sniper, blade melee and lunge).
if [[ $# -eq 0 || "$1" == weapon* ]]; then
	WPN_ARGS=()
	[[ $# -gt 0 && "$1" != "weapons" ]] && WPN_ARGS=(++ "--only=${1#weapon:}")
	perl -e 'alarm shift; exec @ARGV' 240 \
		"$GODOT" --headless --path . --fixed-fps 120 res://tests/weapon_tests.tscn ${WPN_ARGS[@]+"${WPN_ARGS[@]}"} 2>&1 \
		| grep -vE "^\s*$|ObjectDB instances|Godot Engine v|at: cleanup|at: clear|resources still in use"
	wpn="${PIPESTATUS[0]}"
	[[ "$wpn" != 0 && "$status" == 0 ]] && status="$wpn"
fi
# SPIRAL route checks (pads, the Express helix, drop-in, outside car).
if [[ $# -eq 0 || "$1" == spiral ]]; then
	perl -e 'alarm shift; exec @ARGV' 180 \
		"$GODOT" --headless --path . --fixed-fps 120 res://tests/spiral_tests.tscn 2>&1 \
		| grep -E "ok  |FAIL|spiral:|SCRIPT ERROR|Parse Error"
	spiral="${PIPESTATUS[0]}"
	[[ "$spiral" != 0 && "$status" == 0 ]] && status="$spiral"
fi
# Level placement lint (dummies inside walls, floating, spawns in geometry).
perl -e 'alarm shift; exec @ARGV' 120 "$GODOT" --headless --path . -s res://tests/level_lint.gd 2>&1 \
	| grep -E "FAIL|level lint|SCRIPT ERROR|Parse Error" || true
lint="${PIPESTATUS[0]}"
[[ "$status" != 0 ]] && exit "$status"
exit "$lint"
