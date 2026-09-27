#!/usr/bin/env bash
# Builds the game: tools/build.sh [mac|windows|all]  (default: all)
# Output: build/mac/Parkour Shooter.app, build/windows/ParkourShooter.exe
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
target="${1:-all}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
if [[ "$target" == mac || "$target" == all ]]; then
	mkdir -p build/mac
	"$GODOT" --headless --path . --export-release "macOS" "build/mac/Parkour Shooter.app"
	echo "Built build/mac/Parkour Shooter.app"
fi
if [[ "$target" == windows || "$target" == all ]]; then
	mkdir -p build/windows
	"$GODOT" --headless --path . --export-release "Windows" "build/windows/ParkourShooter.exe"
	echo "Built build/windows/ParkourShooter.exe"
fi
