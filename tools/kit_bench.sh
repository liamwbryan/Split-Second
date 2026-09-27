#!/usr/bin/env bash
# Bench a map on Low and High (art-kit performance gate).
#   tools/kit_bench.sh spiral rooftops
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
for m in "$@"; do
	for q in 0 2; do
		echo "== $m quality $q"
		"$GODOT" --path . "res://scenes/$m.tscn" -- --bench --quality=$q 2>&1 | grep -E "BENCH avg|draw calls" &
		pid=$!
		( sleep 90; pkill -f "scenes/$m.tscn" ) >/dev/null 2>&1 &
		wait $pid
	done
done
