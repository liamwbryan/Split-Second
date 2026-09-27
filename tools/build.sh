#!/usr/bin/env bash
# Builds the game: tools/build.sh [mac|windows|all]  (default: all)
# Output: build/mac/Split Second.app, build/windows/SplitSecond.exe
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
target="${1:-all}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
if [[ "$target" == mac || "$target" == all ]]; then
	mkdir -p build/mac
	"$GODOT" --headless --path . --export-release "macOS" "build/mac/Split Second.app"
	echo "Built build/mac/Split Second.app"
fi
if [[ "$target" == windows || "$target" == all ]]; then
	mkdir -p build/windows
	"$GODOT" --headless --path . --export-release "Windows" "build/windows/SplitSecond.exe"
	echo "Built build/windows/SplitSecond.exe"
fi
