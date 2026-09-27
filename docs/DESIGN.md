# Parkour Shooter — Game Design Document

> Working title TBD. Living document: update it when a decision changes.

## 1. Pitch

A first-person parkour shooter for Mac, with Windows support once the game is where we want it. You never stop moving. Your speed protects you and it's also how you attack.
The movement and gunplay take after **Titanfall 2's pilots**, and the architecture and visual readability take after **Mirror's Edge**.
The maps are vertical, full of moving parts, and built to be fun to cross. Fun wins over realism every time.

- **Single-player:** timed combat-parkour courses against AI enemies, scored on time and style.
- **Local couch multiplayer:** 1–4 player split-screen on a TV, run from a Mac, with Xbox controllers.
- **No:** Titans, story campaign, online netcode (maybe much later), monetization.

## 2. Design pillars

1. **Flow is sacred.** Every mechanic exists to keep you moving. Nothing should stop you unexpectedly, snag you on geometry, or eat an input.
2. **Every action has one clear job.** Movement abilities never compete for the same input in the same situation. When two could apply, a documented rule decides (see §4.3).
3. **Speed is your armor.** Moving fast makes you harder to hit and gets rewarded by the scoring. Standing still is the riskiest thing you can do.
4. **Readable at 30 m/s.** Surfaces tell you what they're for through color. You can plan a route in the half second you have.
5. **Smooth and fast.** High, stable framerate, a fixed-tick simulation, and no hitches. A smaller set of polished features beats a larger set of janky ones.

## 3. Platform & performance targets

| Target | Budget |
|---|---|
| Engine | Godot 4 (latest stable), GDScript with static typing, Jolt physics, Forward+ on Metal |
| Platforms | macOS (primary, Apple Silicon); Windows (later, see ROADMAP M10). Avoid platform-specific code; keep paths/input/rendering portable |
| Hardware baseline | Apple Silicon M3 Pro |
| Single-player | 120 fps at native res (ProMotion), never below 60 |
| 4-player split-screen | Locked 60 fps to a 1080p/4K TV (dynamic render scale on 4K) |
| Simulation | Fixed 120 Hz physics tick + render interpolation, so feel is identical at any framerate |
| Input | Raw mouse (no smoothing); configurable stick response curves + deadzones |
| Hitches | Zero allocation-driven stutter in gameplay: pool projectiles/effects/decals, precompile shaders at load |

## 4. Movement (the core)

### 4.1 Kit

| Move | Input (Xbox / KB+M) | Summary |
|---|---|---|
| Walk / sprint | LS + L3 toggle / WASD + hold Shift | Walk 6 m/s by default; sprint 10 m/s forward only. Aiming drops you to a walk. Optional auto-sprint setting. |
| Jump | A / Space | Variable height. Includes coyote time and a jump buffer. |
| Double jump | A in air / Space | Redirects you toward your input direction. Recharges when you touch the ground or a wall. |
| Slide | B / Ctrl or C (hold; release to stand) | Enter from sprint only (≥7 m/s). Friction is low and slopes speed you up. The camera drops. |
| Slide-hop | A during slide | Jumping out of a slide keeps your speed and adds a small boost with diminishing returns. |
| Air strafe | LS + look | Steer in the air without losing speed. You can't gain unlimited speed from it. |
| Wall-run | Automatic on glancing wall contact while airborne and moving forward | Gravity pulls harder the longer you run. Chain wall to wall. The camera tilts away from the wall. |
| Wall-kick | A while wall-running or climbing | Push off away from the wall. The direction blends the wall's normal with where you're looking. |
| Wall-climb | Automatic on head-on wall contact while airborne | Short vertical climb, Mirror's Edge style. A pushes you off backwards. |
| Mantle / vault | Automatic | Ledge within reach while moving toward it → mantle. Waist-high cover while fast → vault without losing speed. |
| Grapple | LB / Q | Cooldown ability. Pulls you toward the hit point and keeps your momentum when released. |
| Melee | R3 / F | Short lunge. |

### 4.2 Anti-jank rules (how features avoid stepping on each other)

1. **One velocity vector, one owner.** Every ability adds to, redirects, or caps a single velocity. Nothing teleports the player or silently overwrites their speed.
2. **Explicit state machine.** States: `Ground`, `Air`, `Slide`, `WallRun`, `WallClimb`, `Mantle`, `Grapple`. Each state lists the inputs it responds to and the states it can transition to. There's no hidden logic spread across the codebase.
3. **Every transition has a momentum rule.** Each one states whether speed is *kept*, *added to*, or *capped*, and that rule is written in the transition table in code.
4. **Soft caps, not walls.** Speed above a cap decays over time rather than being clamped. Skilled chaining is rewarded without sudden stops.
5. **Forgiveness windows.** Coyote time, jump buffering, a wall-attach assist, ledge magnetism, and auto-mantle. The game reads what you meant to do.
6. **The camera shows the state.** Wall-run tilt, slide drop, speed-scaled FOV, and landing dip are always eased, never snapped.
7. **All numbers live in one tuning resource** (`MovementTuning`), which can be edited live from an in-game debug panel.

### 4.3 Conflict resolution (initial rules, tuned in Milestone 1)

- **Wall-run vs wall-climb:** decided by approach angle. Hitting the wall within ~30° of head-on gives a climb. A glancing hit gives a wall-run.
- **Mantle vs wall-climb:** a ledge within mantle reach always wins.
- **Priority when several apply:** Mantle > Grapple > WallRun/WallClimb > Slide > Air > Ground.
- **Wall-climb limit:** one climb per wall per airtime; a different wall allows another (chimneys work).
- **Wall coyote:** jumping within the coyote window after running off a wall's end still wall-kicks.
- **Wall-run needs forward input:** no accidental attaches when drifting past walls.
- **Double jump refresh:** touching the ground or a wall refreshes it. Releasing the grapple doesn't, so grappling can't be spammed into unlimited air mobility.
- **Grapple while wall-running:** allowed. It detaches you from the wall and keeps your momentum.
- **Slide-hop boost:** diminishing returns on consecutive hops. The slide itself soft-caps, so speed stays expressive but bounded.

### 4.4 Surface language (Mirror's Edge "runner vision")

Surfaces carry tags, and a shared material colors them automatically:

| Tag | Color | Meaning |
|---|---|---|
| Route wall | Warm accent (red/orange) | The intended wall-run/climb route. Any wall is runnable (fun > realism); color marks the flow line |
| Grapple point | Cyan highlight | Strong grapple target, with aim magnetism |
| Launch / boost | Yellow | Jump pads, boost strips |
| Hazard | Striped / magenta | Kill volumes, crushers |
| Neutral | Clean white/gray | Everything else |

## 5. Gunplay

- **Feel targets:** short time-to-kill, snappy readable recoil (patterned, not random), and instant weapon swaps.
- **Movement synergy:** hip-fire spread tightens while sliding and wall-running, and ADS is fast. You're never penalized for moving.
- **Feedback stack:** hitmarkers (body vs head), distinct kill confirm sound, a 1–3 frame freeze on kills, enemy flinch and ragdoll, and short screen shake only when you fire (never when you're hit).
- **Aim assist (gamepad only):** slowdown near targets plus light rotational assist while you're moving. It can be tuned per player and turned off. Split-screen FFA uses a lighter preset.
- **Viewmodel:** sway, bob, and tilt driven by movement state, so the gun visibly reacts to wall-runs and slides.

### Initial roster (original designs, inspired by the reference)

| Weapon | Role |
|---|---|
| Rifle | Full-auto hitscan all-rounder |
| SMG | High fire rate, best hip-fire while in motion |
| Shotgun | Close range, rewards sliding in |
| Rail sniper | Projectile with travel time; one-shot headshots |
| Sidearm | Fast draw backup |
| Boost launcher | Arcing explosive whose knockback also works as a movement tool (rocket-jumps) |

Later: a lock-on pistol, a charge rifle, energy melee, grenades/ordnance slot.

## 6. AI enemies (single-player & co-op)

- **Roster:** Grunt (rifle), Rusher (fast melee), Sniper (laser telegraph), Drone (flying), Shield, Heavy. The late-game elite is a *Hunter* that uses parkour itself.
- **Speed matters:** enemy accuracy drops against fast targets, which rewards staying in motion.
- **Navigation:** navmesh plus hand-placed traversal links for verticality. Only Hunters traverse the way the player does.
- **Readability:** every attack is telegraphed (muzzle glow, laser, audio cue) so players can react at speed.
- **Architecture:** behavior trees with a utility layer for target and position choice.

## 7. Levels

### 7.1 Level design principles

- **At least 3 traversal layers:** ground, mid (walls/rails), and high (rooftops/grapple). Routes go over, through, and under.
- **Every space has 2+ routes,** and the fastest one needs skill.
- **Metrics-driven:** wall-run length, jump distance, and mantle height from Milestone 1 become the grid used to build every level.
- **Moving geometry reshapes routes over time:** timing windows, trains that briefly create bridges, walls that open shortcuts.
- **Split-screen fairness:** vertical cover breaks long sightlines, and spawns are protected.

### 7.2 Dynamic geometry toolkit

A shared framework for things that move: path movers (trains, platforms), rotators, elevators, sliding walls, and conveyors.
- The player picks up the platform's velocity when leaving it, so jumping off a train carries the train's speed.
- Moving surfaces count as walls for wall-running.
- Everything is deterministic and loops on a cycle, so a course plays out the same on every run.

### 7.3 Map concepts

Each map is its own place with its own palette and lighting. They're tied together by the shared surface language (§4.4) and the same traversal metrics. **Every map serves two uses:** a looping, vertical arena for couch play, plus a timed single-player course threaded through it with checkpoints and enemies.

| Map | Hook |
|---|---|
| **Rooftops** | Classic Mirror's Edge city: white rooftops, cranes, rotating billboards |
| **Transit** | Elevated rail lines; trains pass on a cycle; ride them, wall-run on them, fight on them |
| **Foundry** | Conveyors, stamping presses, house-sized blocks moving through a factory |
| **Spire** | Vertical atrium tower: elevators, rotating rings, fall-to-escape routes |
| **Gyre** | Giant rotating structures: turning bridges and turbine blades |
| **Shift** | The arena reconfigures itself every 60 s with sliding walls and rising blocks |

### 7.4 Traversal metrics (from the M1 tuning; build every level to these)

| Move | Distance / height |
|---|---|
| Walk jump gap | ≤ 4 m |
| Sprint jump gap | ≤ 6.5 m (flat) |
| Sprint + double jump gap | ≤ 10–11 m (flat); 8 m with a 2 m climb |
| Slide-hop + double jump gap | ≤ 14 m |
| Wall-run length (one wall) | 12–18 m |
| Standing mantle / jump-mantle | ≤ 1.4 m / ≤ 3.1 m |
| Wall-climb + mantle | ≤ 6 m ledge |
| Grapple range | 45 m |
| Street width (must-not-jump-casually) | 12 m: needs sprint + double jump, a wall-run, or a grapple |

### 7.5 Flagship map: Rooftops

**Place:** a near-future city block at mid-afternoon. White and pale concrete, blue-tinted glass, warm sun, long shadows. Accents: red route walls, cyan grapple points, yellow boost pads. There's a haze-blue skyline beyond the map edge.

**Footprint:** about 120 × 120 m, heights 0–40 m. A crossroads (two 12 m streets) splits it into four blocks, each with its own character:

```
                 N (−Z)
   ┌──────────────┐ │ │ ┌──────────────┐
   │ NW  OFFICE   │ │ │ │ NE  CONSTRUCTION│
   │ roof 16 m    │ │S│ │ open-frame tower│
   │ tall wing 28m│ │T│ │ 36 m + tower    │
   │ water tower  │ │R│ │ crane (swings)  │
   └──────────────┘ │E│ └──────────────┘
 W ═════════════ STREET (E–W) ═════════════ E
   ┌──────────────┐ │E│ ┌──────────────┐
   │ SW RESIDENTIAL│ │T│ │ SE BILLBOARD │
   │ stepped roofs │ │ │ │ roof 20 m     │
   │ 8/12/16 m,    │ │ │ │ rotating      │
   │ fire escapes  │ │ │ │ billboard,    │
   └──────────────┘ │ │ │ skybridge→NE  │
                 S (+Z)
```

**Three layers:**
- **Street (0 m):** alleys, parked vans, fire-escape stairs going up. It's slow but safe.
- **Mid roofs (8–20 m):** the main fighting layer.
- **High (28–40 m):** tower tops and the crane, with power positions that take skill to reach.

**Dynamic set pieces:**
1. **Tower crane (NE):** the jib slowly swings about 110° on a 20 s cycle. Its tip carries a grapple point, and the jib itself is a moving bridge between the NE tower and the NW tall wing when it's aligned.
2. **Rotating billboard (SE):** a 14 × 6 m panel turning around its vertical axis on a 10 s cycle. Wall-run it when it's edge-on to your path; it blocks or opens a sightline to the street.
3. **Window-washer lift (NW tall wing):** a platform riding the facade from street to 28 m and back (a pause at each end, 14 s cycle). It's the fast way up from the street.
4. **Container on a cable (NE site):** a shipping container sliding back and forth over the E–W street on a 12 s cycle, forming a temporary bridge and moving cover.

**Single-player course "Rooftops Run":**
1. Start in the SW street.
2. Mantle up the fire-escape stairs.
3. Slide across the terraces.
4. Wall-run the SE billboard gap.
5. Take the skybridge wall-run into the construction tower.
6. Climb the open-frame floors (chimney).
7. Grapple the crane tip.
8. Swing-release to the NW tall wing.
9. Drop down the water-tower route to the finish.

There are 5–6 checkpoints, targets and enemies along the route, and a par time around 75 s.

**Couch arena:** 8+ spawns spread across all three layers, protected by line-of-sight checks. The crane and the billboard make the power positions change over time.

## 8. Modes

### Single-player courses
Checkpointed combat courses. Scoring combines **time**, **kills**, and **style** (air kills, wall-run kills, long chains without touching the ground). Includes medals, ghost replays of your best run, and a local leaderboard.

### Couch (split-screen, 1–4)
Modes are data-driven rule sets (spawns, loadout, scoring, win condition), so adding one is cheap.

- **Free-for-all deathmatch**
- **Race:** everyone runs the same course at once
- **Co-op courses:** single-player courses with enemies scaled to player count
- **Team deathmatch (2v2)**
- **More:** Gun Game (weapon ladder), King of the Moving Hill (the hill is on a train), Tag (pure parkour chase), Capture the Flag, Elimination, Horde co-op

### Modifiers (for variety)
Toggles you can combine on any mode: low gravity, instagib, grapple-only, pistols-only, infinite double jump, speed-demon (higher caps), big-head.

## 9. Visual & audio direction

- **Look:** clean and high-contrast. Bright minimal architecture, strong color language, crisp AO, subtle bloom. It should look intentional without a large art team. Each map has its own palette and lighting (§7.3).
- **Player character:** a sleek human runner in a fitted tech suit with a helmet/visor (Mirror's Edge meets Titanfall pilot). The suit accent is the player's color: P1 orange, P2 cyan, P3 lime, P4 magenta. It comes from a CC0 rigged human with an animation library. The animation state follows the movement state (run, sprint, slide, wall-run left/right, climb, mantle, grapple, airborne). Other players see your full body; you see your own weapon.
- **Assets:** geometry built from primitives, shaders (triplanar grid, surface-tag coloring), and CC0 libraries (e.g. Kenney, Quaternius) for props and viewmodels. Everything is swappable for commissioned art later.
- **Audio:** punchy layered gunfire, footstep and wind audio that scales with speed, distinct audio cues for every move and for hits. Sounds are sourced from CC0 libraries. Music will be adaptive to intensity (later).

## 10. Technical architecture (summary)

- **Players are never singletons.** A `PlayerSlot` owns a device ID, camera, HUD, and settings. All input goes through a per-player `InputRouter`, never the global `Input`.
- **Split-screen:** a `SubViewport` per player with its own HUD layer. First-person viewmodels are on per-player render layers, so you never see someone else's gun floating in your view.
- **Player:** `CharacterBody3D` with a custom state machine (§4.2), plus components for Motor, Abilities, WeaponHolder, and CameraRig.
- **Data-driven resources:** `MovementTuning`, `WeaponData`, `EnemyData`, `GameModeRules`, `Modifier`.
- **Moving geometry:** `AnimatableBody3D` synced to physics, with platform velocity inheritance.
- **Pooling:** projectiles, tracers, impact effects, decals.

## 11. Risks

| Risk | Mitigation |
|---|---|
| Feel needs many iterations, and the builder can't play | You're the playtester. Live tuning panel, fast turnaround on notes, a feel checklist per milestone |
| Split-screen performance with AI and moving geometry | Budget from day one; a 4-viewport perf test in each milestone |
| AI on vertical, moving maps | Navmesh + traversal links; the platforms enemies stand on move predictably |
| 4 Xbox pads on macOS | Verify 4 simultaneous pads in Milestone 1 |
| Scope creep | Roadmap gates: a feature doesn't merge until it meets the no-jank bar |
