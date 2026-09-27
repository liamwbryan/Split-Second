# Asset Sources (CC0, script-downloadable)

Checked on 2026-09-26. Each URL below was tested with `curl` (HEAD, or a ranged GET where HEAD is refused) and returned HTTP 200/206 with the expected content-type. Sizes come from `Content-Length` / `Content-Range`. Every asset here is **CC0 1.0** (public domain); the license text was read from the package or from the site's API.

> Nothing has been downloaded into this repo. Put third-party files under something like `assets/third_party/<source>/` and keep each pack's `License.txt` next to it.

---

## Recommended picks

| Need | Pick | Why |
|---|---|---|
| Character + animations | **Quaternius Universal Animation Library 1 + 2 (Standard, free)** + **Universal Base Characters (Standard, free)** | All three use the **same 65-bone UE-Mannequin-style skeleton** (`root, pelvis, spine_01..03, neck_01, Head, clavicle/upperarm/lowerarm/hand_*, full fingers, thigh/calf/foot/ball_*`). I checked this by comparing the joint lists in the glTF files: identical names in identical order. So you can share one `AnimationLibrary` across every body. Godot-ready `.glb`/`.gltf` exports, with root-motion (`_RM`) and in-place variants. |
| Parkour-specific clips | UAL2: `Slide_Start/Slide_Loop/Slide_Exit`, `ClimbUp_1m`, `NinjaJump_Start/Idle_Loop/Land`; UAL1: `Sprint_Loop`, `Jog_Fwd_Loop`, `Jump_Start/Loop/Land`, `Crouch_Idle_Loop`, `Crouch_Fwd_Loop`, `Roll` | Covers idle, walk, run, sprint, jump, fall/air loop, land, crouch, crouch-move, slide, mantle/climb-up and roll. |
| Textures | Poly Haven (API) for concrete/plaster/corrugated/roof/tiles; **ambientCG** for brushed metal and glass facades (Poly Haven has neither) | Both are CC0 with stable direct URLs. ambientCG zips even include a Godot `.tres` material. |
| Sky | Poly Haven `homecoming_center_rooftop` (clear midday rooftop with city skyline); alt `rooftop_day`, `portland_landing_pad` | Bright, high-contrast daytime; urban. |
| City kit (stylized/low-poly, tiny) | Kenney **City Kit (Commercial)** + **City Kit (Industrial)** + **Building Kit** | GLB with one shared `colormap.png` atlas. Industrial has shipping containers, water tower, tanks, chimneys, solar panels. |
| City kit (realistic-ish, PBR) | Quaternius **Downtown City MegaKit (Standard, free)** | 153 modular pieces in `glTF (Godot)` format with PBR textures (brick, concrete, metal, trim, roof slate) plus `Prop_ACUnit` and metal stair rails. 223 MB. |
| Rooftop props | Poly Pizza single GLBs (Quaternius, CC0): Air Conditioner ×2, Water Tank, Roof Antenna, Antenna, Vent, Shipping Container, Container Structure, Metal Fence | Individually fetchable, tiny. |
| Rifle | Poly Pizza Quaternius **Assault Rifle** / **Ak47** GLB (CC0), or Quaternius **Ultimate Gun Pack** (FBX, 57 guns + attachments) | Ready-made GLB with no conversion step. Kenney Blaster Kit is toy/sci-fi foam blasters (GLB). |

**Not covered by the free tiers:** a dedicated **wall-run** clip, **rifle-hold/aim** clips (Standard UAL1 has only `Pistol_*` aim/idle/shoot/reload), and **8-direction strafes**. Those are in UAL1 **Pro** (paid, $9.99 minimum on itch). Workarounds: (a) the game is first-person, so the third-person body only matters for other players and mirrors; use `Sprint_Loop` with a procedural lean/roll for wall-run and `Jog_Fwd_Loop` with a hip-yaw offset for strafing; (b) put a Pistol_Aim upper-body blend on a rifle bone attachment; (c) buy UAL Pro later. It is CC0 as well and uses the same skeleton, so it drops straight in.

---

## 1. Characters & animation

### Quaternius on itch.io: works without login (name-your-own-price, $0 min)

itch.io "free / name your price" files can be fetched anonymously. The signed CDN URL **expires within minutes**, so resolve it right before downloading. Each pack's **upload ID is stable**. HEAD requests on the signed URL return 403, so verify with a GET or a range GET. itch rate-limits (HTTP 429) if you hit it quickly, so space requests a few seconds apart.

```bash
# itch_fetch.sh <game page url> <upload_id> <out.zip>
page="$1"; id="$2"; out="$3"; jar=$(mktemp)
csrf=$(curl -sL -c "$jar" "$page" | grep -oE 'csrf_token" value="[^"]+"' | head -1 | sed 's/.*value="//;s/"$//')
url=$(curl -s -b "$jar" -X POST --data-urlencode "csrf_token=$csrf" \
        "$page/file/$id?source=game_download" | python3 -c 'import sys,json;print(json.load(sys.stdin)["url"])')
curl -L --fail -o "$out" "$url"
```

(Do **not** pass a `key=` parameter. For free files, the POST without a key returns `{"url": "...r2.cloudflarestorage.com/upload2/game/<game>/<upload>?X-Amz-..."}`.)

| Asset | Page / upload ID | License | Format | Size | Contents / notes |
|---|---|---|---|---|---|
| **Universal Animation Library [Standard]** | `https://quaternius.itch.io/universal-animation-library` · upload **17958403** | CC0 | GLB (`Unreal-Godot/UAL1_Standard.glb`, `UAL1_Standard_RM.glb`), FBX (Unity) | 15.9 MB zip (GLB 7.6 MB each) | 1 mesh ("Mannequin"), 65 joints, **43 clips**: A_TPose, Idle_Loop, Idle_Talking_Loop, Idle_Torch_Loop, Walk_Loop, Walk_Formal_Loop, Jog_Fwd_Loop, **Sprint_Loop**, **Jump_Start / Jump_Loop / Jump_Land**, **Crouch_Idle_Loop / Crouch_Fwd_Loop**, **Roll**, Push_Loop, Swim_*, Pistol_Idle_Loop / Pistol_Aim_Up/Neutral/Down / Pistol_Shoot / Pistol_Reload, Punch_Jab/Cross, Sword_*, Spell_Simple_*, Hit_Chest, Hit_Head, Death01, Interact, PickUp_Table, Sitting_*, Driving_Loop, Dance_Loop, Fixing_Kneeling. Includes `Godot_Setup.png`. Pro ($9.99) = 120+ clips incl. 8-dir locomotion; Source ($14.99) = .blend. |
| **Universal Animation Library 2 [Standard]** | `https://quaternius.itch.io/universal-animation-library-2` · upload **17958478** | CC0 | GLB (`UAL2_Standard.glb`, `_RM`), FBX, + `Female Mannequin/Unreal-Godot/Mannequin_F.glb` (+ .blend) | 17 MB zip | Same 65-joint skeleton as UAL1 (verified). **43 clips**: **Slide_Start / Slide_Loop / Slide_Exit**, **ClimbUp_1m**, **NinjaJump_Start / NinjaJump_Idle_Loop / NinjaJump_Land**, Hit_Knockback, LayToIdle, Melee_Hook(+_Rec), OverhandThrow, Shield_*, Sword_* combos, Idle_FoldArms_Loop, Idle_Rail_Loop/Call, Idle_TalkingPhone_Loop, Walk_Carry_Loop, Zombie_*, Farm_*, Chest_Open, Consume, TreeChopping_Loop, Yes, Idle_No_Loop. |
| **Universal Base Characters [Standard]** | `https://quaternius.itch.io/universal-base-characters` · upload **15861669** | CC0 | glTF+bin (`Base Characters/Godot - UE/Superhero_Male_FullBody.gltf`, `Superhero_Female_FullBody.gltf`), FBX (Unity), PNG textures | 129 MB zip (the two bodies + textures are about 40 MB; most of the zip is hair/texture variants) | Realistic stylized male and female bodies with BaseColor (light/dark skin), Normal (a separate "Normals Unity - Godot" folder, i.e. GL convention), Roughness. **Same 65-joint skeleton as UAL, same order (verified)**. The body file has no animations; use the UAL clips. Hairstyles/eyebrows come as separate glTFs, either "Rigged to Head Bone" or "Origin at 0". Pro/Source tiers are paid ($19.99+). |

### Kenney: direct zip, but only 3 animations

| Asset | URL | License | Format | Size | Notes |
|---|---|---|---|---|---|
| Animated Characters: Protagonists | https://kenney.nl/media/pages/assets/animated-characters-protagonists/608191acc4-1774773108/kenney_animated-characters-protagonists.zip | CC0 | **FBX only** (`Model/characterMedium.fbx` + skins PNG) | 0.58 MB | Only `idle.fbx`, `jump.fbx`, `run.fbx`. Low-poly blocky. **Not suitable** for the animation set. |
| Animated Characters: Survivors | https://kenney.nl/media/pages/assets/animated-characters-survivors/27b16052a7-1774772958/kenney_animated-characters-survivors.zip | CC0 | FBX | 0.72 MB | Same rig/anim set as above. |
| Animated Characters: Retro | https://kenney.nl/media/pages/assets/animated-characters-retro/93305a3c49-1774772819/kenney_animated-characters-retro.zip | CC0 | FBX | 0.71 MB | Same. |

### Other character sources checked

| Asset | URL | License | Format | Size | Notes |
|---|---|---|---|---|---|
| Quaternius "Character Soldier" (Toon Shooter Game Kit) | https://static.poly.pizza/1083c1d3-d1d4-4682-adf6-bc516d06ac84.glb | CC0 | GLB | 1.3 MB | Toon soldier, 43-joint `CharacterArmature` (**different rig from UAL**), 14 clips: Idle, Idle_Shoot, Run, **Run_Gun**, Jump, Jump_Idle, Jump_Land, Duck, HitReact, Death, Punch, Wave, Yes, No. A useful fallback for an armed enemy. |
| Quaternius "Animated Human" | https://static.poly.pizza/170235d2-cdeb-4cb2-a82f-4828585138fe.glb | CC0 | GLB | 0.7 MB | 41 joints, 8 clips (Idle, Walk, Run, Jump, Punch, Death, Working). Different rig. |
| Quaternius Ultimate Animated Character Pack | https://quaternius.com/packs/ultimatedanimatedcharacter.html → Google Drive folder `1sNi1AfenfPRrvRt5yfaj5QMMd6KKcUJ5` | CC0 | glTF / FBX / OBJ / blend (~50 characters) | ? | **Manual download.** Only hosted on Google Drive, and every anonymous `drive.usercontent.google.com/download?id=…` request returned the "Quota exceeded" HTML page. Not on itch.io. Superseded by UAL + UBC anyway. |
| Poly Pizza "Animated Base Character" (`cwYvO5UauX`) | — | **CC-BY 3.0 per Poly Pizza** | GLB | 2.3 MB | UAL-like clips with a 53-joint rig. **Skip it**: the listed license is not CC0, and the itch UAL is the canonical CC0 source. |

---

## 2. Textures & HDRIs

### Poly Haven API (CC0)

* **You must send a non-default User-Agent.** Python's `urllib` default UA gets **403**, while `curl`'s default and a custom UA get 200. Poly Haven asks for a unique UA such as `SplitSecond/1.0 (liam)`.
* List: `https://api.polyhaven.com/assets?t=textures` (or `t=hdris`). Files: `https://api.polyhaven.com/files/<id>` returns JSON keyed by map (`Diffuse`, `nor_gl`, `nor_dx`, `Rough`, `AO`, `arm`, `Displacement`, sometimes `Metal`), then resolution (`1k`, `2k`, …), then format (`jpg`, `png`, `exr`), then `{url, size, md5}`. There's also a `gltf` key that bundles a ready glTF material with its textures.
* URL pattern (all 198 URLs below match it and returned 200 `image/jpeg` / `image/vnd.radiance` / `image/aces`):
  * Texture: `https://dl.polyhaven.org/file/ph-assets/Textures/jpg/{res}/{id}/{id}_{map}_{res}.jpg`, where `{map}` ∈ `diff`, `nor_gl`, `rough`, `ao`, `arm` (AO/Rough/Metal packed), `metal`, `disp`; `{res}` ∈ `1k`, `2k`, `4k`, …
  * HDRI: `https://dl.polyhaven.org/file/ph-assets/HDRIs/{hdr|exr}/{res}/{id}_{res}.{hdr|exr}`
* For Godot, use `nor_gl` (OpenGL normal convention). The `arm` map maps directly to StandardMaterial3D's ORM texture (R=AO, G=Rough, B=Metal) with `ORMMaterial3D`.

Example (clean white plaster, 1k):
```
https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/white_plaster_02/white_plaster_02_diff_1k.jpg
https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/white_plaster_02/white_plaster_02_nor_gl_1k.jpg
https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/white_plaster_02/white_plaster_02_rough_1k.jpg
https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/white_plaster_02/white_plaster_02_ao_1k.jpg
https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/white_plaster_02/white_plaster_02_arm_1k.jpg
```

| Category | Asset ID | Description | diff+nor_gl+rough+ao size (1k / 2k) | Notes |
|---|---|---|---|---|
| Clean/white plaster (Mirror's Edge white) | `white_plaster_02` | Smooth flat white plaster, matte | 2.0 MB / 9.7 MB | **Top pick** for clean walls |
| Painted concrete/plaster | `concrete_wall_001` | White painted concrete with trim lines, light chipping | 0.5 MB / 2.4 MB | |
| Painted plaster | `painted_plaster_wall` | Slightly discolored exterior plaster | 2.5 MB / 11.0 MB | |
| Painted concrete (dark) | `painted_concrete_02` | Dark matte paint over cement | 1.9 MB / 8.3 MB | |
| Concrete | `concrete_wall_008` | Weathered concrete wall, hairline cracks, bolt holes | 2.2 MB / 9.2 MB | |
| Concrete facade tiles | `concrete_tile_facade` | Grooved modern facade squares, sharp grout | 2.6 MB / 10.7 MB | Good for building faces |
| Facade tiles | `rectangular_facade_tiles` | Dark concrete rectangular tiles | 2.2 MB / 9.0 MB | |
| Floor tiles | `concrete_tiles` | Stamped concrete basketweave tiles | 3.1 MB / 12.9 MB | |
| Anti-slip rooftop walkway | `anti_slip_concrete` | Concrete with raised tactile dots | 3.0 MB / 12.3 MB | |
| Painted steel | `blue_metal_plate` | Painted blue steel plate, seams, scuffs | 1.1 MB / 4.2 MB | |
| Diamond plate | `metal_plate` | Worn diamond-plate steel (has `metal` map) | 2.8 MB / 10.6 MB | |
| Corrugated metal | `corrugated_iron_02` | Galvanized corrugated roofing (has `metal` map) | 2.2 MB / 9.3 MB | |
| Corrugated metal (painted) | `box_profile_metal_sheet` | Red box-profile steel cladding | 1.8 MB / 7.8 MB | |
| Container side | `container_side` | Green corrugated container side | 1.9 MB / 7.8 MB | |
| Rooftop tar/gravel | `tarred_gravel` | Tarred gravel, embedded stones | 3.4 MB / 13.5 MB | **Top pick** for flat roofs |
| Roofing tar | `bitumen` | Dark cracked bitumen roofing | 1.6 MB / 7.5 MB | |
| Gravel concrete | `gravel_concrete` | Rough aggregate concrete | 3.8 MB / 15.3 MB | No `arm` map (AO is present) |

**HDRIs (Poly Haven, CC0).** Sizes are 1k hdr / 2k hdr / 2k exr.

| ID | Look | 1k .hdr | 2k .hdr | 2k .exr |
|---|---|---|---|---|
| `homecoming_center_rooftop` | **Pick:** sunny rooftop, city skyline + mountains, clear blue midday | 1.5 MB | 6.2 MB | 21.7 MB |
| `rooftop_day` | Rooftop parking, crisp sun, partly cloudy | 1.5 MB | 6.2 MB | 4.8 MB |
| `portland_landing_pad` | Urban helipad, midday, thin clouds | 1.6 MB | 6.2 MB | 21.1 MB |
| `wide_street_01` | Wide city avenue, clear midday, hard sun | 1.5 MB | 5.8 MB | 4.6 MB |
| `modern_buildings_2` | Modern glass/concrete riverside plaza | 1.7 MB | 6.5 MB | 21.9 MB |
| `canary_wharf` | Skyscraper district, soft partly cloudy | 1.7 MB | 6.6 MB | 6.0 MB |

e.g. `https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/homecoming_center_rooftop_2k.hdr`

### ambientCG (CC0): fills Poly Haven's gaps

API: `https://ambientcg.com/api/v2/full_json?type=Material&q=<query>&include=downloadData`. Download: `https://ambientcg.com/get?file=<AssetId>_<1K|2K>-JPG.zip`, which 302-redirects to `acg-download.struffelproductions.com` and returns 200 `application/zip`. Each zip contains `_Color`, `_NormalGL`, `_NormalDX`, `_Roughness`, `_Metalness`, `_Displacement` JPGs, plus a **Godot `.tres`**, `.mtlx`, `.usdc` and `.blend`. There is no AO map; use SSAO/SDFGI.

| Asset | URL (1K) | Size 1K / 2K | Notes |
|---|---|---|---|
| Brushed steel | https://ambientcg.com/get?file=Metal009_1K-JPG.zip | 4.8 MB / 16.7 MB | Brushed, scratched silver steel. Siblings: Metal010, Metal011, Metal012 |
| Brushed aluminum | https://ambientcg.com/get?file=Metal051A_1K-JPG.zip | 3.1 MB / 9.1 MB | Circular-brushed aluminum (B/C variants too) |
| Brushed metal plates | https://ambientcg.com/get?file=MetalPlates001_1K-JPG.zip | 5.1 MB / 15.6 MB | Paneled brushed steel |
| Glass facade | https://ambientcg.com/get?file=Facade001_1K-JPG.zip | 2.9 MB / 5.5 MB | Reflective glass curtain wall (Facade002/003/005/006 also) |
| Glass facade | https://ambientcg.com/get?file=Facade006_2K-JPG.zip | — / 5.8 MB | |
| Diamond plate (clean) | https://ambientcg.com/get?file=DiamondPlate008A_1K-JPG.zip | 7.8 MB / 23.9 MB | Industrial tread plate |

---

## 3. City / rooftop prop kits

### Kenney: direct zips (CC0)

The hashed path segment changes when Kenney updates a pack. If a link 404s, scrape the asset page: `curl -sL https://kenney.nl/assets/<slug> | grep -oE 'https://kenney.nl/media/[^"]+\.zip'`. All GLBs are under `Models/GLB format/` and share `Models/GLB format/Textures/colormap.png` (one palette atlas).

| Asset | URL | License | Format | Size | Contents |
|---|---|---|---|---|---|
| **City Kit (Commercial) 2.1** | https://kenney.nl/media/pages/assets/city-kit-commercial/a742d900eb-1753115042/kenney_city-kit-commercial_2.1.zip | CC0 | GLB, FBX, OBJ | 4.1 MB | 41 GLB: building-a…n, building-skyscraper-a…e, low-detail variants, awnings, overhangs, parasols |
| **City Kit (Industrial) 2.0** | https://kenney.nl/media/pages/assets/city-kit-industrial/0ec35b139d-1788171848/kenney_city-kit-industrial_2.0.zip | CC0 | GLB, FBX, OBJ | 5.0 MB | 37 GLB: building-a…t, **shipping-container-a/b/c**, **water-tower**, **detail-tank(-large)**, chimneys ×4, **solar panels**, windmills |
| **Building Kit** | https://kenney.nl/media/pages/assets/building-kit/0de7aaa492-1743244741/kenney_building-kit.zip | CC0 | GLB, FBX, OBJ | 1.6 MB | 79 GLB modular: walls/windows/doorways, **roof-flat-* pieces**, borders (parapets), columns, stairs, **gutters/pipes**, barricades |
| Modular Buildings | https://kenney.nl/media/pages/assets/modular-buildings/3253b4219a-1707397411/kenney_modular-buildings.zip | CC0 | GLB, FBX, OBJ | 1.8 MB | Building blocks/windows/doors, **detail-ac-a/b (AC units)**, flat-roof borders/details, sample towers |
| City Kit (Roads) | https://kenney.nl/media/pages/assets/city-kit-roads/74288c9459-1787042796/kenney_city-kit-roads.zip | CC0 | GLB, FBX, OBJ | 2.8 MB | Roads/bridges, construction barriers/cones/fence, dumpster, **electricity poles/wires**, street lights, signs, traffic lights |
| Retro Urban Kit | https://kenney.nl/media/pages/assets/retro-urban-kit/8314d4db22-1738147509/kenney_retro-urban-kit.zip | CC0 | GLB, FBX, OBJ | 2.2 MB | Walls, **balcony ladders**, **scaffolding**, **roof-metal pieces**, barriers, cables, dumpsters, pallets, trucks |
| Factory Kit 3.0 | https://kenney.nl/media/pages/assets/factory-kit/edaac9d4f6-1777639602/kenney_factory-kit_3.0.zip | CC0 | GLB, FBX, OBJ | 4.5 MB | **Catwalks (+stairs)**, **crane / crane-lift / crane-magnet**, conveyors, pipes, hoppers, boxes |
| Prototype Kit | https://kenney.nl/media/pages/assets/prototype-kit/4d3b7073ed-1724832076/kenney_prototype-kit.zip | CC0 | GLB, FBX, OBJ | 3.0 MB | Graybox shapes, ladders, stairs, pipes, crates, doors, floor indicators: good for the gym |
| Space Station Kit | https://kenney.nl/media/pages/assets/space-station-kit/6475288f2e-1712749919/kenney_space-station-kit.zip | CC0 | GLB, FBX, OBJ | 1.8 MB | Sci-fi corridors (optional) |

### Quaternius (CC0)

| Asset | URL | License | Format | Size | Contents / notes |
|---|---|---|---|---|---|
| **Downtown City MegaKit [Standard]** | `https://quaternius.itch.io/downtown-city-megakit` · itch upload **17615373** (use `itch_fetch.sh`) | CC0 | **glTF+bin (`glTF (Godot)/`)**, FBX (Unity), FBX (Unreal) | 235 MB zip | 153 modular pieces: Brick_* / Metal_* / Trim_* walls, windows, columns, corners, Cornice_*, Roof_2x2/4x4 & Roof_Slate*, **Prop_ACUnit**, Prop_Bollard/Drain/ManholeCover/Planter, **Stairs_Rails_Metal***, Street_*/Sidewalk_*, Decals, Building_Large/Medium/Small samples. Shared PBR textures (BaseColor/Normal/ORM): Concrete, MetalConcrete, RedBrick, Trim, RoofSlate, MarbleFloor, Ornaments, Dirt; interior-mapping window PNGs. |
| Modular Street Pack | `https://quaternius.itch.io/lowpoly-modular-street` · upload **1128619** | CC0 | FBX, OBJ, blend | 3.6 MB | Streets/bridges/elevated ramps, streetlights, traffic lights, signs. No glTF. |
| Individual rooftop props (Poly Pizza, Quaternius, all CC0) | see below | CC0 | GLB | 6–250 KB each | Fetch with a plain GET. The URL is `https://static.poly.pizza/<uuid>.glb`. |

Poly Pizza GLBs (each verified with a 200 `gltf-binary` GET and a valid glTF header; Poly Pizza lists the license as "CC0 1.0"):

| Prop | URL | Size |
|---|---|---|
| Air Conditioner | https://static.poly.pizza/84fe2fe4-9b0b-48ef-ba8e-84bfbcaebac0.glb | 33 KB |
| Air Conditioner (alt) | https://static.poly.pizza/75029333-e7b5-4170-8183-a75dfa0b54e6.glb | 39 KB |
| Water Tank | https://static.poly.pizza/90ce7828-ec94-4b41-9e44-e524af7aafa5.glb | 35 KB |
| Roof Antenna | https://static.poly.pizza/f11fe705-f599-4b9f-8a1b-3b1fb81b40a6.glb | 29 KB |
| Antenna | https://static.poly.pizza/c958f28b-bcea-4b96-81ab-1eb01914bb73.glb | 6 KB |
| Vent | https://static.poly.pizza/85760ddf-dbec-4c22-8198-ee6c27f72483.glb | 35 KB |
| Shipping Container | https://static.poly.pizza/e56c8efb-940f-4150-9bf8-d468c0165116.glb | 57 KB |
| Shipping Container Structure | https://static.poly.pizza/a5a8487c-a09f-473b-b5a7-fae74832404e.glb | 246 KB |
| Metal Fence | https://static.poly.pizza/94d06743-b682-4a86-9bba-499c351282b7.glb | 90 KB |

Model pages are at `https://poly.pizza/m/<publicID>` (e.g. `0MdE89Ijtt`, `XVB8vUbnZb`, `Fbdg52kqJ6`, `UDFcnJ0U73`, `dQXRtm5GbO`). Billboards and cranes: use Kenney Factory Kit `crane*` and Kenney City Kit Roads `sign-highway*`. No standalone CC0 billboard GLB was found.

---

## 4. Rifles / weapons

| Asset | URL | License | Format | Size | Notes |
|---|---|---|---|---|---|
| **Assault Rifle** (Quaternius, Poly Pizza) | https://static.poly.pizza/b3e6be61-0299-4866-a227-58f5f3fe610b.glb | CC0 | GLB | 74 KB | Static mesh, flat-shaded low-poly. Variants: `…/db2d564c-63b2-4316-a89e-0f7d7a2416c9.glb` (79 KB), `…/9a0e478c-de82-4773-9b70-a0219bb0057c.glb` (134 KB) |
| Ak47 (Quaternius Toon Shooter, Poly Pizza) | https://static.poly.pizza/cf6f2c6d-87a2-47d5-883f-1efd73900f41.glb | CC0 | GLB | 60 KB | Toon style, matches "Character Soldier" |
| Rifle (Quaternius, Poly Pizza) | https://static.poly.pizza/875d7c7c-188f-4447-8cf8-bc6da771c25a.glb | CC0 | GLB | 108 KB | alt: `…/da83f4f9-7a4e-4739-9033-79d688aa3b5e.glb` (64 KB) |
| **Ultimate Gun Pack** (Quaternius) | `https://quaternius.itch.io/50-lowpoly-guns` · upload **1588315** | CC0 | FBX, OBJ, blend (**no glTF**) | 7.4 MB | 40 guns (AssaultRifle_1-5, AssaultRifle2_1-4, Bullpup_1-3, SniperRifle_1-6, SubmachineGun_1-5, Shotgun_*, Pistol_1-6, Revolver_1-5) + 15 attachments (scopes, silencers, grip, bipod, stock, flashlight, bayonets). Godot imports FBX natively (ufbx). |
| Kenney Blaster Kit 2.1 | https://kenney.nl/media/pages/assets/blaster-kit/261d80a716-1753959510/kenney_blaster-kit_2.1.zip | CC0 | GLB, FBX, OBJ | 1.7 MB | 18 toy/sci-fi blasters (a–r), foam bullets, clips, scopes, silencers, grenades, crates, targets. Stylized, colormap atlas. |
| Quaternius Toon Shooter Game Kit / Animated Guns / Cyberpunk Kit | quaternius.com pack pages → Google Drive | CC0 | glTF/FBX | ? | **Manual download.** Google Drive returns "Quota exceeded" to anonymous curl. Individual meshes from these kits are on Poly Pizza (above). |

---

## Needs manual download / not scriptable

* **Quaternius Google-Drive-only packs** (Ultimate Animated Character Pack, Toon Shooter Game Kit, Animated Guns, Cyberpunk Game Kit, Buildings, Ultimate Textured Buildings, Sci-Fi Modular Guns). Folder listings work via `https://drive.google.com/embeddedfolderview?id=<folder>`, but every file download returned Google's "Quota exceeded" page. Download these in a browser if needed.
* **UAL Pro / UBC Pro / Downtown City Pro** are paid itch tiers. They are still CC0 once bought, but a purchase needs a login.
* **Mixamo** was not considered: it's free but not CC0, needs a login, and has no API.
