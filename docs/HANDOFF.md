# Session handoff

Read this first in a new session, then `CLAUDE.md`, `docs/DESIGN.md` and `docs/ROADMAP.md`.
Last updated: 2026-09-26.

## What this is
A first-person parkour shooter (Titanfall 2 movement and gunplay, Mirror's Edge look) in **Godot 4.7.2** (GDScript), for Mac now and **Windows as Liam's main target**. The modes are single-player combat-parkour courses and 1–4 player local split-screen. Online multiplayer is being considered but not started (see `docs/ONLINE_MULTIPLAYER.md`).

## How to run / build / test
- Play: `godot --path .` (main menu → Rooftops or Movement Gym). Editor: `godot -e --path .`.
- Builds: `tools/build.sh [mac|windows|all]` → `build/mac/Parkour Shooter.app`, `build/windows/ParkourShooter.exe`. Export templates are installed at `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`. The shader baker is on.
- Tests: `tests/run_tests.sh` (87 headless movement/weapon/moving-platform tests, plus a level lint over both maps). Run it after every movement or level change.
- Visual checks (these open windows; keep them short, since the Mac runs hot):
  - `godot --path . res://scenes/rooftops.tscn -- --shots=DIR [--third] [--panel]`: one screenshot per station.
  - `godot --path . res://tests/fp_shots.tscn -- --out=DIR`: first-person arm and gun poses during idle, sprint, slide, vault, mantle, climb, wall-run and grapple.
  - `... -- --bench [--quality=0-3] [--off=ssao,ssil,shadows,glow,fog]`: frame times. `-- --idle=DIR`: frames over 36 s standing still.
- Assets: `tools/fetch_assets.sh` (CC0: Quaternius UAL1/UAL2 mannequin and animations, Poly Haven textures and HDRI). Blender models: `blender -b --python art/blender/<script>.py` exports to `assets/models/`. Preview renders: `art/blender/preview.py`. SFX: `godot --headless --path . -s res://tools/bake_sfx.gd`.

## Decisions Liam made (don't re-ask)
- **Controls:** Titanfall/Apex layout. **Hold** to slide/crouch (Ctrl/C/B) and **hold** to grapple (Q/LB). Walk by default, sprint on hold Shift / L3 toggle. Station cycling is `[ ]`, the tuning panel is backtick, the debug readout is O, third-person is P, restart is T. **No F-keys** (they're media keys on Mac).
- **Character:** a stealth special agent (Mirror's Edge silhouette, Splinter Cell tech, a Matrix-ish "hidden in a normal city" vibe). Matte black suit, tri-lens goggles, belt, holster, forearm grapple bracer, spine unit. Player color appears only on lenses and lights: P1 orange, P2 cyan, P3 lime, P4 magenta.
- **Maps:** each map is its own setting. Every map is both a couch FFA arena and a timed single-player course. Rooftops is the flagship (spec in DESIGN §7.5).
- **Wind audio:** only while airborne, grappling, wall-running or sliding. Subtle and speed-scaled.
- **Priority:** Mirror's Edge-quality first-person animation (hands on ledges, legs visible, gun moving with the body).
- **Efficiency:** Liam mainly plays on a mid-range Windows PC. Keep code lean, run on most machines, don't cook the Mac.

## Current state (what's done)
- **Movement (M1 ✅):** full kit plus anti-jank rules. Wall coyote, per-wall climb limit, moving-surface support (ride, wall-run and mantle on `Mover`s).
- **Rooftops map:** 4 blocks, crane (swing), rotating billboard, window-washer lift, container bridge, skyline, boundary ring. Stations: `[ ]`.
- **Rendering:** `LevelBuilder` merges static blocks into chunked meshes. `surface.gdshader` does one texture set per pixel with procedural facade windows and sRGB→linear vertex tints. `Graphics` presets (Low 223 fps / Medium 118 / High 77 at full Retina on an M3 Pro) and a 30 fps unfocused throttle.
- **Third-person agent:** `RunnerAvatar` + Blender gear. Always animates, because it casts the owner's shadow.
- **First-person body (in progress):** `FPBody` + `FPPoseModifier`.
  - A split mannequin (`fp_mannequin.glb`: FP_Arms + FP_Body, head removed).
  - Arms use the gun's shader with its own FOV (68°; fixed an abs() on the projection Y term), IK'd with `TwoBoneIK3D` to the carbine's `GripR`/`GripL` sockets.
  - Per-state contact targets for mantle, wall-run, slide, grapple and climb, all pre-warped for the arm FOV.
- **Carbine:** `art/blender/rifle.py` (suppressed, holo sight, no glass). Stock hidden in first person.
- **Builds** work on Mac and Windows. The Windows build is untested on real hardware.

## Known issues / next steps (in order)
1. **First-person arms need a tuning pass.** Use `tests/fp_shots.tscn` and iterate on the screenshots.
   - The hands aren't visible during vault, wall-run or sprint: contact points fall below or outside the frame, or the right-hand IK can't reach the sprint gun pose.
   - The upper arms are still bulky at the bottom corners.
   - The right-hand grip orientation needs checking up close.
   - Add a mantle camera nod (pitch down ~10–15° mid-mantle) so the ledge plants are visible.
   - Consider a mantle duration of 0.3–0.4 s (currently ~0.2–0.27 s) so plants read.
   - Spine pitch share, and the legs when looking down, need verifying.
   - Details: `docs/research/fp_body_animation.md` §3.6 table.
2. **Shadow shimmer / "glitchy" reports.** Springs are now substepped (`Springs`), shadow presets are improved, and road z-fighting is fixed. Liam should re-test. If it persists, check shadow bias/normal bias on the sun, and SSAO.
3. **Boot time.** SFX are now baked and the shader baker is enabled. Confirm the exported app boots fast.
4. Rooftops Run course: timer, checkpoints, finish, par time (DESIGN §7.5).
5. Blender props: AC units, lattice crane, water tower, vents (replace the primitives in `Props`).
6. Roadmap M2: more guns and aim assist. M3: split-screen FFA (the FOV for 32:9 splits needs handling).
7. Online multiplayer decision (Liam is interested; see the doc).

## Gotchas learned the hard way
- **Controls:** `set_anchors_preset` keeps a zero size; use `set_anchors_and_offsets_preset`.
- **Lambdas:** GDScript lambdas capture locals **by value**; use members for state.
- **Headless runs:** new `class_name` scripts need `godot --headless --path . --import` first (the test script does this). A compile error makes headless runs hang, hence the perl `alarm` timeouts.
- **Movers:** a Mover reads its base transform on its first physics tick, so set `position` before `add_child`. The same goes for `TargetDummy` (it reads home on its first physics frame).
- **Custom shaders:** vertex `COLOR` is raw sRGB, so convert to linear (see `surface.gdshader`). The projection `[1][1]` term is negative on Vulkan/Metal.
- **Winding:** Godot's front faces are clockwise (see `LevelBuilder._append_box`).
- **Exports:** macOS arm64 needs ETC2/ASTC import enabled (it is).
- **Mac window focus:** the unfocused throttle drops to 30 fps whenever the game window loses focus, so benchmarks go through `Graphics.vsync`.
