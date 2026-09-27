#!/usr/bin/env bash
# Downloads the CC0 assets the game uses (see docs/ASSET_SOURCES.md).
# Safe to re-run: skips files that already exist.
set -euo pipefail
cd "$(dirname "$0")/.."
UA="SplitSecond/1.0 (asset fetch)"
TMP="${TMPDIR:-/tmp}/ps_assets"; mkdir -p "$TMP"

fetch() { # url out
	[[ -s "$2" ]] && return 0
	mkdir -p "$(dirname "$2")"
	curl -sL --fail -A "$UA" -o "$2" "$1" && echo "  got $2"
}

itch() { # page upload_id out.zip
	[[ -s "$3" ]] && return 0
	local jar csrf url
	jar=$(mktemp)
	csrf=$(curl -sL -c "$jar" "$1" | grep -oE 'csrf_token" value="[^"]+"' | head -1 | sed 's/.*value="//;s/"$//')
	url=$(curl -s -b "$jar" -X POST --data-urlencode "csrf_token=$csrf" "$1/file/$2?source=game_download" \
		| python3 -c 'import sys,json;print(json.load(sys.stdin)["url"])')
	curl -sL --fail -o "$3" "$url" && echo "  got $3"
	sleep 3
}

echo "Character + animations (Quaternius Universal Animation Library 1 & 2)"
itch https://quaternius.itch.io/universal-animation-library 17958403 "$TMP/ual1.zip"
itch https://quaternius.itch.io/universal-animation-library-2 17958478 "$TMP/ual2.zip"
mkdir -p assets/characters
for z in ual1 ual2; do
	unzip -oq "$TMP/$z.zip" -d "$TMP/$z"
done
find "$TMP/ual1" -name 'UAL1_Standard.glb' -exec cp {} assets/characters/UAL1_Standard.glb \;
find "$TMP/ual2" -name 'UAL2_Standard.glb' -exec cp {} assets/characters/UAL2_Standard.glb \;

echo "Textures (Poly Haven, 1k)"
PH=https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k
for id in white_plaster_02 concrete_wall_008 tarred_gravel bitumen metal_plate concrete_tiles; do
	for map in diff nor_gl arm; do
		fetch "$PH/$id/${id}_${map}_1k.jpg" "assets/textures/$id/${id}_${map}_1k.jpg"
	done
done

echo "Sky (Poly Haven HDRI)"
fetch https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/homecoming_center_rooftop_2k.hdr assets/sky/homecoming_center_rooftop_2k.hdr

echo "Rifle (Quaternius via Poly Pizza)"
fetch https://static.poly.pizza/b3e6be61-0299-4866-a227-58f5f3fe610b.glb assets/weapons/assault_rifle.glb

echo "done"
