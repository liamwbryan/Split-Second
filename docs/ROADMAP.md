# Roadmap

Each milestone ends with a playable build and a **feel review** by Liam. A milestone isn't done until its exit criteria pass. Quality gates scope: if something is janky, it gets cut or fixed before new features go in.

See [DESIGN.md](DESIGN.md) for the what and why.

---

## M1 — Movement Gym ✅ (feel approved by Liam; tweaks continue as we go)
**Goal:** the full movement kit feels great in a graybox playground.

**Status (2026-09-26):** everything below is implemented; 59 headless tests pass (`tests/run_tests.sh`); about 120–140 fps at native Retina on an M3 Pro with auto FSR scale. Still open: a hands-on feel pass on keyboard and Xbox pad, and a check with 4 pads.

- Godot project scaffold: fixed 120 Hz tick + physics interpolation, a `PlayerSlot`/`InputRouter` built for multiple players from day one, Xbox pad + KB/M bindings
- Movement state machine: ground, sprint, jump (coyote + buffer), double jump, air strafe, slide, slide-hop, wall-run, wall-kick, wall-climb, mantle/vault, grapple
- Camera rig: speed FOV, wall-run tilt, slide drop, landing dip, head bob (with toggle)
- `MovementTuning` resource + an in-game live tuning panel + a speedometer/state debug overlay
- One hitscan rifle + target dummies with hitmarkers (enough to feel shooting while moving)
- Gym level: one lane per mechanic, a combo route that chains everything, surface color language
- Test that 4 Xbox pads connect and are each identified

**Exit criteria:** every move triggers when you intend it and never when you don't. No snagging on geometry. Momentum flows through every transition. 120 fps holds. Liam signs off on feel.

## Current phase — Look & Rooftops (pulled forward at Liam's request)
- [x] Moving-geometry framework (part of M5): lifts, sliders, rotators, swings, riding and wall-running on movers
- [x] Rooftops map: 4 blocks, crane, rotating billboard, lift, container bridge, skyline
- [x] Real materials (Poly Haven CC0), merged-mesh level rendering, quality presets, unfocused throttling
- [x] Runner avatar (UAL mannequin + Blender helmet/jump-kit, player-color accents, state-driven animation)
- [x] Blender-modeled carbine (viewmodel); stealth-agent redesign of the runner
- [x] Mac + Windows export builds (`tools/build.sh`); quality presets; baked SFX; shader baker
- [ ] **First-person body awareness** (IK hands on gun/ledges/walls, legs): in progress, see HANDOFF next steps
- [ ] Third-person rifle on the avatar
- [ ] Rooftops Run course: timer, checkpoints, finish, par time
- [ ] Blender props: AC units, water tower, crane lattice, vents, billboard frame
- [x] Windows export (untested on real hardware yet)

## M2 — Gunplay Core
- Weapon framework (`WeaponData`): hitscan + projectile, fire modes, magazines/reload, ADS, patterned recoil, movement-aware spread
- Roster: rifle, SMG, shotgun, rail sniper, sidearm, boost launcher
- Feedback stack: hitmarkers, headshots, kill freeze, audio layers, viewmodel sway/bob/tilt, impact effects (pooled)
- Gamepad aim assist (slowdown + rotational), with tunable presets
- Melee lunge

**Exit:** each gun has a distinct role and feels punchy. Shooting while wall-running is a highlight, not a compromise.

## M3 — Split-Screen Foundation
- "Press A to join" lobby, 1–4 players, per-player settings (sensitivity, aim assist, invert)
- Per-viewport HUDs, per-player viewmodel render layers, split layouts for 2/3/4 players (the scaffolding already exists in `SplitScreen`)
- FOV handling for wide/tall split viewports (keep horizontal FOV sane on 32:9 top/bottom splits)
- Player damage, death, respawn, spawn protection
- **First couch mode: FFA deathmatch** in a graybox arena
- Performance pass: locked 60 fps with 4 players on the TV

**Exit:** 4 people can pick up controllers and play a fun FFA round with no setup friction.

## M4 — AI Enemies
- Behavior tree + utility layer, navmesh with vertical traversal links
- Grunt, Rusher, Sniper, Drone (Shield/Heavy in M8)
- Telegraphed attacks; accuracy drops against fast targets
- Encounter spawner + a combat gym

**Exit:** enemies are readable, threatening, and fun to kill mid-parkour, and they don't just stand still.

## M5 — Dynamic Geometry
- Mover framework: path movers, rotators, elevators, sliding walls, conveyors, trains
- The player inherits platform velocity; wall-running works on moving surfaces
- Deterministic cycles, so timing windows can be learned
- Crushers/hazards with fair telegraphs

**Exit:** riding, jumping off, and wall-running on moving things feels as solid as static geometry.

## M6 — Courses & Scoring
- Course framework: start/finish, checkpoints, instant restart, timer
- Style scoring: air kills, wall-run kills, chain multiplier
- Medals, ghost replays, local leaderboard
- **First real map: Rooftops** (course + arena variants)
- **Couch: Race and Co-op** (these reuse the course framework)

**Exit:** you want to hit restart to shave a second off your time.

## M7 — Mode Framework & Variety
- `GameModeRules` + `Modifier` data-driven system
- Team DM (2v2), Gun Game, King of the Moving Hill, Tag, Capture the Flag, Elimination, Horde co-op
- Modifiers: low gravity, instagib, grapple-only, pistols-only, infinite double jump, speed-demon, big-head

**Exit:** a couch night has at least 6 meaningfully different ways to play.

## M8 — Content Expansion
- Maps: Transit, Foundry, Spire, Gyre, Shift
- Enemies: Shield, Heavy, Hunter (parkour elite)
- Weapons: lock-on pistol, charge rifle, energy melee, grenades/ordnance
- 10+ single-player courses with a difficulty curve

## M9 — Presentation & Polish
- Main/pause menus, settings (video, audio, controls), full rebinding, controller glyphs
- Audio pass + adaptive music
- Visual pass: lighting, post-processing, VFX, viewmodel art
- Accessibility: FOV slider, motion reduction (camera tilt/bob off), colorblind-safe surface palette, subtitles for cues

## M10 — Ship (Mac + Windows)
- Signed + notarized Mac `.app`, app icon, crash-safe saves
- Windows export: `.exe` build, XInput pad check, perf check on mid-range PC GPU (Forward+ via D3D12/Vulkan)
- Optional: Steam or itch.io release

---

## Future / maybe
- Online multiplayer (a big architectural lift; only if couch play proves the game)
- Level editor / custom courses
- Controller rumble tuned per event
- Linux build (Godot makes this cheap)
