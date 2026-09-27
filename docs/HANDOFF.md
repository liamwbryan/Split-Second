# Session handoff

Read this first in a new session, then `CLAUDE.md`, `docs/DESIGN.md` and `docs/ROADMAP.md`.
Last updated: 2026-09-26.

## What this is
A first-person parkour shooter (Titanfall 2 movement and gunplay, Mirror's Edge look) in **Godot 4.7.2** (GDScript), for Mac now and **Windows as Liam's main target**. The modes are single-player combat-parkour courses and 1–4 player local split-screen. Online multiplayer is being considered but not started (see `docs/ONLINE_MULTIPLAYER.md`).

## How to run / build / test
- Play: `godot --path .` (main menu → Rooftops or Movement Gym). Editor: `godot -e --path .`.
- Builds: `tools/build.sh [mac|windows|all]` → `build/mac/Parkour Shooter.app`, `build/windows/ParkourShooter.exe`. Export templates are installed at `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`. The shader baker is on.
- Tests: `tests/run_tests.sh` (110 headless movement/weapon/moving-platform/first-person-arm/course tests, plus a level lint over both maps). Run it after every movement or level change.
- Visual checks (these open windows; keep them short, since the Mac runs hot):
  - `godot --path . res://scenes/rooftops.tscn -- --shots=DIR [--third] [--panel]`: one screenshot per station.
  - `godot --path . res://tests/fp_shots.tscn -- --out=DIR [--only=PREFIX]`: first-person arm and gun poses (idle, look down/at feet, sprint, slide, vault, a 3-frame mantle, climb, wall-run, grapple) plus two grip close-ups from a side camera with skin-tinted arms. It prints per-hand IK error, reach % and camera-space positions. Run it with `--headless` to get just those numbers, with no window.
  - `... -- --bench [--quality=0-3] [--off=ssao,ssil,shadows,glow,fog]`: frame times. `-- --idle=DIR`: frames over 36 s standing still.
- Assets: `tools/fetch_assets.sh` (CC0: Quaternius UAL1/UAL2 mannequin and animations, Poly Haven textures and HDRI). Blender models: `blender -b --python art/blender/<script>.py` exports to `assets/models/`. Preview renders: `art/blender/preview.py`. SFX: `godot --headless --path . -s res://tools/bake_sfx.gd`.

## Decisions Liam made (don't re-ask)
- **Controls:** Titanfall/Apex layout. **Hold** to slide/crouch (Ctrl/C/B) and **hold** to grapple (Q/LB). Walk by default, sprint on hold Shift / L3 toggle. Station cycling is `[ ]`, the tuning panel is backtick, the debug readout is O, third-person is P, restart is T. **No F-keys** (they're media keys on Mac).
- **Character:** a stealth special agent (Mirror's Edge silhouette, Splinter Cell tech, a Matrix-ish "hidden in a normal city" vibe). Matte black suit, tri-lens goggles, belt, holster, forearm grapple bracer, spine unit. Player color appears only on lenses and lights: P1 orange, P2 cyan, P3 lime, P4 magenta.
- **Maps:** each map is its own setting. Every map is both a couch FFA arena and a timed single-player course. Rooftops is the flagship (spec in DESIGN §7.5).
- **Wind audio:** only while airborne, grappling, wall-running or sliding. Subtle and speed-scaled.
- **Priority:** Mirror's Edge-quality first-person animation (hands on ledges, legs visible, gun moving with the body).
- **Gun carry (2026-09-26):** SMG style. One hand on the gun at the hip, the other hand free: it swings with your stride and reaches for walls and ledges. Both hands when aiming. The free arm pumps in time with the gun at a sprint. `WeaponData.one_hand_hip` (the Rifle tuning tab) switches back to a two-handed rifle carry for comparison. Liam said the rifle might become more SMG-like; that's open for M2.
- **Climb jump (2026-09-26):** during a wall-climb, forward + jump hops up the face (no push-off, no camera turn). Neutral or back + jump, or a wall behind you (a chimney), still kicks off and auto-turns. The auto-turn was jerking the camera while climbing buildings.
- **Efficiency:** Liam mainly plays on a mid-range Windows PC. Keep code lean, run on most machines, don't cook the Mac.

## Current state (what's done)
- **Movement (M1 ✅):** full kit plus anti-jank rules. Wall coyote, per-wall climb limit, moving-surface support (ride, wall-run and mantle on `Mover`s).
- **Rooftops map:** 4 blocks, crane (swing), rotating billboard, window-washer lift, container bridge, skyline, boundary ring. Stations: `[ ]`.
- **Rendering:** `LevelBuilder` merges static blocks into chunked meshes. `surface.gdshader` does one texture set per pixel with procedural facade windows and sRGB→linear vertex tints. `Graphics` presets (Low 223 fps / Medium 118 / High 77 at full Retina on an M3 Pro) and a 30 fps unfocused throttle.
- **Third-person agent:** `RunnerAvatar` + Blender gear. Always animates, because it casts the owner's shadow.
- **First-person body (tuning pass done 2026-09-26):** `FPBody` + `FPPoseModifier`.
  - A split mannequin (`fp_mannequin.glb`: FP_Arms + FP_Body, head removed). The arms are slimmed around their bones in Blender (upper arm 75%).
  - **Hand targets are inertialized in camera space.** A target switch captures an offset that decays. Never smooth the targets in world space: they trail a moving body by speed ÷ rate, which was why the arms vanished whenever you moved.
  - **The body hangs from the eye by the neck, in the same frame.** `FPPoseModifier._anchor_neck` shifts the pelvis so the posed neck lands on `NECK_BODY`, which keeps the upper body rigid to the camera. Only the legs take the clip bounce. Reading the neck back a frame late made the sprint clip's 13 cm bounce shake the arms; there's a test for this now. In a slide, the pelvis lift is capped so the feet stay down. `tests/fp_shots.tscn -- --jitter` (run headless) prints per-bone frame-to-frame jerk.
  - The viewmodel is updated by the camera rig right before the arms (`Viewmodel.update`), so hands never chase last frame's gun. The head bob, gun and arms share `CameraRig.stride_phase`.
  - Every IK target is clamped just inside full reach: a two-bone IK at full stretch flips the elbow.
  - **Chest stance lock:** the spine is turned so the chest is upright, follows 60% of the pitch, and is bladed 18° with 22° of clavicle protraction. The FP arms are 12% longer (`ARM_STRETCH`), the usual FP cheat, so both hands reach the gun.
  - Per-state hands:
    - mantle: both hands slap onto the lip and push down, with the chest hunched 28°; plants are reach-clamped.
    - wall-run: the hand glides along the wall.
    - slide: a balance arm out front-left, with an open hand.
    - grapple: the arm reaches toward the anchor.
    - wall-climb: hand over hand.
  - The left hand's handguard wrap is synthesized (`LEFT_CURL`).
  - Mantle camera nod: `mantle_camera_nod` (15°, in the tuning panel).
  - Arms use the gun's shader with its own FOV (68°; fixed an abs() on the projection Y term), IK'd with `TwoBoneIK3D` to the carbine's `GripR`/`GripL` sockets.
  - Per-state contact targets for mantle, wall-run, slide, grapple and climb, all pre-warped for the arm FOV.
- **Carbine:** `art/blender/rifle.py` (suppressed, holo sight, no glass). Stock hidden in first person.
- **Builds** work on Mac and Windows. The Windows build is untested on real hardware. **Liam plays the builds**, so run `tools/build.sh all` (about 10 s) after anything he should see.
- **Rooftops Run course:** `Course` (`scripts/world/course.gd`) + `CourseHud`.
  - Gates are cylinders checked per tick against each player's next gate (no physics areas).
  - The clock starts when you leave the start zone. Gates count in order and each becomes your respawn.
  - T restarts the run through `Player.restart_handler`. Station teleports void a running run or disarm an armed one.
  - Splits vs best, medals (gold ≤ par, silver ≤ 1.15×, bronze ≤ 1.35×) and a result card.
  - Best time and splits go to `user://records.cfg`.
  - Route and gates are in `rooftops.gd` `_course()`; the par of 75 s is a guess until Liam times a run.
  - The level lint checks each gate has a floor and fits a player.

## Known issues / next steps (in order)
1. **Liam: playtest the first-person arms.** Also judge the longer mantle: `mantle_time_base` went 0.16 → 0.24 s, so mantles now take 0.30–0.39 s. Both it and `mantle_camera_nod` are in the tuning panel.
   - Still weak: mantle and vault plants are on screen only briefly. The motor lifts the body about half-way in the first ~0.07 s (an ease-out up-curve), so the ledge drops below the frame. The real fix is a time-seeked climb animation, or a gentler up-curve, which is a movement-feel change for Liam to OK.
   - Sprint shows the clip's pumping left hand at the bottom-left. The right hand hides under the lowered gun.
   - When looking down you see the gun and a little torso. The feet only show near −80° pitch.
   - The grip close-ups (shots 11/12) look right. The right index finger rests below the grip, and the left thumb points forward along the handguard.
2. **Shadow shimmer / "glitchy" reports.** Springs are now substepped (`Springs`), shadow presets are improved, and road z-fighting is fixed. Liam should re-test. If it persists, check shadow bias/normal bias on the sun, and SSAO.
3. ~~Boot time~~: confirmed on the M3 Pro (2026-09-26). The exported app reaches the menu in 1.7 s cold / 0.7 s warm, and `-- --level=rooftops` (skip-menu arg) renders Rooftops in 3.7 s cold / 1.3 s warm. Re-check on the Windows PC.
4. **Liam: run Rooftops Run end to end.** Check that every gate is reachable, especially the crane → office roof leg, then set the par. Ghost replays and the local leaderboard (DESIGN §8) come later.
5. Blender props. **Done:** AC units (small/big), vent stack and water tower (`art/blender/rooftop_props.py` → `assets/models/prop_*.glb`). They're drawn as one MultiMesh per model (`Props.finalize()`) and keep their old box collision (`LevelBuilder.collider`). **Left:** crane lattice and billboard frame. These ride `Mover`s, so they'd attach as child meshes, not MultiMesh.
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
