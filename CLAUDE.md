# Split Second

The game is called **Split Second** (renamed from "Parkour Shooter" on 2026-09-26). Use that name in code, builds and docs.

**Start with `docs/HANDOFF.md`**: it has the current state, Liam's decisions, known issues and next steps.

First-person parkour shooter for macOS (Windows later, so keep code portable) in Godot 4 (GDScript, static typing). Single-player combat-parkour courses plus 1–4 player local split-screen.

- Design: `docs/DESIGN.md`. Roadmap and current milestone: `docs/ROADMAP.md`. Update these when decisions change.
- Movement must follow the anti-jank rules in DESIGN §4.2–4.3. Keep one velocity owner, use the explicit state machine transition table, and keep all tuning in `MovementTuning`.
- Never treat the player as a singleton. Read input through the per-player `InputRouter`, not the global `Input`.
- Performance budget: 120 Hz fixed tick, 120 fps single-player, locked 60 fps at 4-player split-screen. Pool anything spawned during gameplay.
- Liam is the playtester. Expose tunables in the live debug panel, not as constants buried in code.
- Run `tests/run_tests.sh` after any movement or weapon change, and add a test for every new rule or bug fix. Use `godot --path . -- --shots=DIR` to check visuals and `-- --bench` for performance.
- New `class_name` scripts need `godot --headless --path . --import` before headless runs; the test script does this for you.

## Efficiency (Liam's main target is a mid-range Windows PC; don't burden weak machines)
- Level visuals must go through `LevelBuilder`. It merges static blocks into chunked meshes. Don't add per-block MeshInstances.
- Surface shading is one texture set per pixel (`shaders/surface.gdshader`). No per-pixel noise or fbm, and no triplanar.
- Expensive effects stay behind `Graphics` presets (Low/Medium/High/Ultra). Maps declare their ideal look, and `Graphics.apply_to_level` scales it down.
- Anything that animates or updates per frame should skip work when nobody can see it (see `RunnerAvatar.needed`).
- Measure with `godot --path . res://scenes/rooftops.tscn -- --bench [--quality=0-3] [--off=ssao,...]`. Keep test and benchmark runs short, since the Mac runs hot.

## Art pipeline
- CC0 assets: `tools/fetch_assets.sh` (sources in `docs/ASSET_SOURCES.md`).
- Models are Blender Python scripts in `art/blender/`. Run `blender -b --python art/blender/<script>.py` and it exports `.glb` to `assets/models/`. Preview with `art/blender/preview.py`.
- The material named "Accent" is recolored per player in-game.

## First-person body
- `FPBody` is the owner-only first-person body. Its arms use the gun's shader FOV (`FPBody.FP_FOV`, which must match the gun's material) and IK to the gun sockets or world contacts. Contact targets go through `_prewarp`.
- The third-person `RunnerAvatar` always animates, because it casts the owner's shadow. The FP body casts no shadow.
- Check poses with `tests/fp_shots.tscn` screenshots rather than guessing (shots 13–15 cover the sniper, blade swings and knife).
- Every weapon model has a `GripR` socket (guns also have `GripL` and `Muzzle`; blades have `Base`/`Tip` for the slash trail). The viewmodel positions come from each `WeaponData`. Blades use a mount rotation (`model_rot_deg`) that stands them up out of the fist like a pistol grip, so the right hand's grip basis works for every weapon.
