# Map Briefs: directions for the map-building session

> Written 2026-09-26 from design brainstorms with Liam. **Read `CLAUDE.md`, `docs/HANDOFF.md` and `docs/DESIGN.md` §4 and §7 first.**
> This file tells you what to build and why. How to build it follows the patterns in `scripts/maps/rooftops.gd`.
> When a map is approved, move its row into DESIGN §7.3 and mark it built here.

## 0. Liam's direction (the non-negotiables)

1. **Fun beats realism, always.** Steep ramps, 800 m towers, giant pendulums, trains threading through skyscrapers and floating platforms are all fine. Never reject a fun idea because it isn't realistic. Ask "is it fun to move through and fight in?"
2. **Futuristic.** Every map is set in a near-to-far future world: megacities, arcologies, maglev, holo-signage, flying traffic, orbital tethers. Maps can each have their own style (clean white utopia, neon night city, industrial megastructure, sky-palace luxury), but futuristic is the through-line.
3. **Scale and depth.** Liam finds the current Rooftops (120 × 120 m, 0–40 m tall) *small*. The world has to feel **huge**: you're fighting 300 m up the side of a megatower, with a city dropping away below you and bigger towers rising around you. That applies to the city maps especially. Interiors can be tighter, but they still get depth (shafts, voids, windows onto the megacity). §3 covers how to do this cheaply.
4. **The maps exist to show off the movement.** Every space asks "how fast can you get through here?" and every fight happens on the flow line, never in stop-and-pop rooms.

**Working rules:**
- Before editing any file, run `git status`. If another session has uncommitted changes in it (often `scripts/player/*`, `scripts/maps/rooftops.gd`, `tests/*`, `docs/HANDOFF.md`), don't touch it; ask Liam. New map files are always safe.
- Design questions go to Liam (§7). Decide everything else yourself.
- Efficiency rules from `CLAUDE.md` apply: static geometry through `LevelBuilder`, heavy effects behind `Graphics` presets, Liam's target is a mid-range Windows PC. Scale must come from cheap tricks (§3), not from expensive geometry.
- Keep windowed runs short (the Mac runs hot) and close what you launch. Liam plays the exported builds, so run `tools/build.sh all` before telling him a map is ready.

## 1. The numbers (build to these)

From DESIGN §7.4 and `MovementTuning`. **Re-read the live tuning before building**, because values change.

| Thing | Value |
|---|---|
| Walk / sprint | 6 / 10 m/s |
| Soft speed cap | 18 m/s. Anything above bleeds off at 7 m/s². The hard cap is 40. |
| Jump gaps | Walk 4 m. Sprint 6.5 m. Sprint + double jump 10–11 m. Slide-hop + double jump 14 m. |
| Mantle | 1.4 m standing (jump-mantle). 1.9 m ledge above the feet in the air. Wall-climb + mantle up to 6 m. |
| Vault | Cover ≤ 1.25 m high while moving ≥ 6.5 m/s: you vault it without losing speed. |
| Wall-run | Up to 2.2 s, targets 11 m/s, which is **12–18 m per wall**. Needs forward input and a glancing contact (within 35° of head-on becomes a climb instead). |
| Wall touch | **Refreshes the double jump.** Releasing the grapple doesn't. |
| Grapple | 45 m range, 24 m/s max pull, **4 s cooldown**, 1.8 s max hold |
| Gap that can't be jumped casually | 12 m |
| Floor vs wall | Surfaces steeper than **50°** are walls (`Player.floor_max_angle`). |
| Max fall speed | 45 m/s. No fall damage. |

### Engine facts that shape levels (checked in code)

- **Slopes only add speed above about 11°.** Net horizontal slide acceleration is roughly `12·sin2θ − 4.5` m/s²: about 1.5 at 15°, 3.2 at 20°, 4.7 at 25° and 5.9 at 30°. **Speed ramps should be 18–30°.** Gentle ramps (< 11°) *bleed* slide speed. `LevelBuilder.ramp()` is flat, so build curves from several ramp segments that overlap slightly at the seams, then run a slide across every seam to check it doesn't snag or launch you.
- **Leaving a mover keeps its velocity** (`PLATFORM_ON_LEAVE_ADD_VELOCITY` in `player.gd`), and wall-runs, climbs and mantles read `Mover.velocity_at()`. Movers are launchers.
- **SWING mover peak speed:** `v = amplitude_rad · 2π / period · arm_length` (sinusoidal, see `mover.gd sample()`). A platform on a swing tilts by the swing angle, so keep standable parts below ±45°.
- **PATH movers ease in and out on every leg** (smoothstep), so a multi-point path stops at every point. The peak speed on a leg is 1.5 × leg length ÷ `move_time`. Trains need a constant-speed option: add a `linear` flag to `Mover`, with a test.
- **Separate blocks are separate walls.** Wall-run chaining and the one-climb-per-wall rule key off the collider. A long wall-run wall should be one block.
- **Mover visuals are not merged.** `attach_box` on a mover makes its own mesh. Keep movers to a few boxes each. Big moving structures need a merged-visuals feature in `LevelBuilder` first.
- **Camera far plane is 1500 m** (`camera_rig.gd`). Backdrops beyond that need the far plane raised or a painted/impostor layer (§3).
- **Available now:** `checkpoint()`, `hazard()`, `pad()` (jump pad plus a BOOST floor), `target()` (a `TargetDummy`, optionally strafing), `grapple_point()` / `attach_grapple_point()` (these ride movers), `label()`, and `Props` (parapet, ac_unit, vent, bulkhead, water_tower, van, street_light, `skyline`, which is one MultiMesh draw).
- **Courses:** `LevelBase.make_course(id, title, par)`, then `course.set_start()`, `add_gate()` for each checkpoint in order, `set_finish()` and `course.finalize()`. `Course` (`scripts/world/course.gd`) handles the clock, splits, medals and saved bests, and the level lint checks every gate. Copy `rooftops.gd _course()`. (Committed on 2026-09-26 in `264e846`.)
- **Not available yet:** AI enemies (M4). Place `target()` dummies where enemies will go, and mark enemy nests with `# ENEMY:` comments giving the intended type (DESIGN §6).

## 2. The five movement levers every map should pull

1. **Walls refuel you.** Touching a wall gives the double jump back, so wall spacing sets how long players stay off the ground. Dense walls mean you never land; sparse ones force a landing. Use that on purpose.
2. **Movers are free speed.** A fast mover gives about 1 s of above-cap speed nothing else can. Put movers where that burst crosses a gap or starts a fight.
3. **Height is stored speed, and 18–30° slopes cash it in.** Every descent on the fast route should be slideable. Every climb should use a wall, the grapple, a lift or a pad, never a staircase.
4. **The grapple is a punctuation mark.** One grapple point every 4–6 s of the route, at the gaps walls can't bridge. Grapple points on movers are the most exciting ones.
5. **Cover is something you vault over.** Enemies miss fast targets, and your spread tightens while you slide or wall-run. Most cover should be 1.0–1.25 m, so a fast player vaults it while shooting. Tall cover (> 1.9 m) is for breaking sightlines.

Also, from DESIGN §7.1: ≥ 3 traversal layers, 2+ routes through every space (the fastest one needing skill), and protected spawns on every layer for couch play.

## 3. Scale toolkit: huge-feeling worlds on a mid-range PC

The **playable** space stays a size that plays well: about 10–20 s to cross at speed, and dense enough for the flow. The **world around it** is enormous. You get the scale from where the play space sits and what you can see, not from more collision.

1. **Play high up.** Put the play space 150–400 m above a visible ground: the city floor, a maglev canyon, cloud. The drop *is* the depth. Put a `hazard()` reset about 40 m below the lowest playable surface, but let the visuals keep going down. Looking over an edge should give vertigo.
2. **Tower over the player.** Megatowers rising 300–1000 m around and *above* the play space, close enough (100–400 m) that you have to look up at them. Scale matters more upward than outward.
3. **Three depth bands**, each with its own fog tint and density:
   - **Near (0–150 m):** real playable geometry.
   - **Mid (150–600 m):** non-colliding megatower silhouettes with facade windows, one `MultiMesh` like `Props.skyline`. Scale that helper up or add a `megaskyline()` with heights 150–900 m and tiered/stepped forms (a base box plus 1–2 setback boxes per tower).
   - **Far (600–1400 m):** flat-shaded silhouettes that fade into haze.
4. **One hero landmark per map,** visible from everywhere, which also helps players find their way. Examples: a 2 km arcology spire, an orbital elevator tether vanishing into the sky, a giant rotating ring, a floating mega-billboard. It's non-colliding and a handful of boxes or a Blender mesh. It can sit beyond 1500 m if you raise `camera.far` for that map (then measure the cost).
5. **Moving life at a distance:** flying traffic lanes and maglev trains in the mid band. Use **one MultiMesh per lane**, updated with a cheap per-frame offset or a vertex-shader scroll (no per-car nodes). Only update it when some player can see it (`RunnerAvatar.needed` pattern), and turn it off on Low.
6. **Scale cues next to the player:** railings, doors, drones and signage of known size right beside a 400 m drop or a 20 m-tall hologram. The eye needs a known size to judge the huge one.
7. **Light sells height:** height fog (dense below, clear above), a sun low enough to throw long shadows down the canyons, emissive window grids on the megatowers (the facade shader already has procedural windows), and aircraft warning lights on tower tops.
8. **Budget rules:** backdrops cast no shadows, have no collision, use shared materials and are merged or MultiMeshed. `directional_shadow_max_distance` stays at the preset value (the sun only shadows the near band). Check `--bench` at `--quality=0` and `3`. Low can thin out the mid band and drop moving life.

### Futuristic language (shared across maps)
Clean composite and white panels, dark glass, light strips tracing edges, hologram signage (unlit, additive and cheap), maglev rails, drone rigs, sky gardens, suspended walkways, antigrav pads (the boost pads re-skinned as glowing discs). The surface language keeps working: RUN walls are warm light-strip panels, GRAPPLE points are cyan anchor beacons, BOOST pads are yellow antigrav plates, HAZARD is magenta energy.

## 4. How to build a map (recipe)

1. **Script:** `scripts/maps/<name>.gd` does `extends LevelBase`. Set `stations` in `_init()`. Build in `build_level()`, one function per area like `rooftops.gd`, plus a `_backdrop()` for the §3 layers. Override `build_environment()` for the map's palette and fog (template: `LevelBase._default_environment()`; `Graphics.apply_to_level` scales it down). Override `intro_hint()`.
2. **Scene:** `scenes/<name>.tscn` is just a `Node3D` with the script, copied from `scenes/rooftops.tscn`.
3. **Menu:** add a row to `LEVELS` in `scripts/ui/main_menu.gd`.
4. **Lint:** add the scene to `LEVELS` in `tests/level_lint.gd`.
5. **Stations:** at least 6, one per set piece and layer, plus one **"vista" station** looking out over the drop, which is how you check the scale.
6. **Headless import** for new `class_name` scripts: `godot --headless --path . --import`.
7. **Verify** (keep windowed runs short):
   - `tests/run_tests.sh` passes.
   - `godot --path . res://scenes/<name>.tscn -- --shots=DIR` produces one screenshot per station. Look at every one. Does it feel huge? Add `--third` for a third-person view.
   - `-- --bench` and `-- --bench --quality=0` show frame times. Stay in the Rooftops range (see HANDOFF).
   - Add a test in `tests/movement_tests.gd` for any new movement rule or mover feature (check `git status` first).
8. **Prototype risky mechanics first** in a throwaway `scenes/proto_<thing>.tscn` (halfpipe seams, pendulum riding, trains). Keep them out of the menu and delete them once proven.
9. `tools/build.sh all`, then tell Liam which stations to try first.

## 5. Map briefs (in build order)

Each brief gives the fantasy, the **scale hook**, the layout, set pieces with starting numbers, the signature moment, course and arena notes, and what to check. The numbers are starting points: tune them until the signature moment works, then show Liam.

---

### 5.1 SPIRAL: sky garage on the side of an arcology (build first: existing tech only)

**Fantasy:** a spiralling parking structure for flying cars, bolted to the flank of a 900 m arcology at night. Hover-car bays, light-strip lane markings, dock doors opening onto empty sky.

**Scale hook:** the garage hangs at **300 m**. Its open outer sides look straight down onto a glowing megacity, with flying traffic lanes streaming past at deck level and the arcology wall rising another 600 m above the roof. The hero landmark is a neighbouring spire with a rotating ring, 400 m away.

**Layout:** a square structure about 70 × 70 m with seven decks 6 m apart, plus the roof. The centre is an open **void about 26 × 26 m**. The decks are rings about 20 m wide. Outer edges have 1.1 m glass rails (vaultable) and open to the sky; falling past them resets you (a hazard 40 m down).

**Set pieces:**
- **The Express:** a steep slide lane (5 m wide, 20–24°) circling the void one deck per side, with chamfered corners (two 45° turns). It's separated from the decks by vaultable rails. Prototype this first: a slide from the roof should reach the soft cap and hold it.
- **The Void:** RUN-tagged pillars around the void for kick-to-kick chimney drops, plus grapple beacons hanging in the void. Up is grapple, climb and mantle; down is jump in.
- **Hover-car docks:** `PATH` movers. Parked hover cars pull out of their bays, drift along the outer edge and dock again, as moving cover and moving platforms. One car loops *outside* the structure over the drop: ride it for a speed boost to the far side.
- **Traffic lane jump:** an antigrav pad on the roof launches you across to a platform on the neighbouring spire's ring (a short bonus area). It's the power position, exposed to everyone.
- **Parked cars** (1.2 m) as vault cover, with slide lanes between them.

**Signature moment:** sliding down three decks of the Express while trading shots across the void, with the city 300 m below over the rail.

**Course "Spiral Run":** start on the roof, drop the void to deck 4, slide the Express to deck 1, ride the outside hover car, grapple back up the void, wall-run the outer arcology wall, finish on the roof pad. **Arena:** spawns on every deck, never facing each other across the void.

**Checks:** the Express seams and corner carry, pillar spacing, and the vista station (does 300 m read as 300 m?).

---

### 5.2 PENDULUM HALL: museum of the future, in a megatower atrium

**Fantasy:** a gleaming science museum filling a 150 m-tall atrium halfway up a megatower. White composite, gold light strips, floating holographic exhibits, one entire wall of glass looking out over the city.

**Scale hook:** the glass wall shows the city at 500 m altitude with megatowers eye-to-eye, and a skylight shows the tower continuing up into cloud. The hero landmark is an orbital elevator tether outside, climbing out of sight.

**Layout:** a hall about 90 m long, 50 m wide and 150 m tall (play space up to about 60 m; the rest is looming volume). Galleries along both long walls at 10, 20 and 30 m. Floating exhibit platforms (static, antigrav-looking) at mid-height, and a mezzanine bridge at 20 m.

**Set pieces:**
- **The pendulum:** a colossal `SWING` mover pivoting about 100 m up, 90 m arm, bob about 10 m above the floor. Start with **amplitude 30°, period 10 s**, which gives about 30 m/s at the bottom (well above the soft cap: a real slingshot). The bob is a 7 m energy disc with a grapple beacon. Jumping off at the bottom, or grappling it and releasing, launches you across the hall. Keep the amplitude ≤ 40° so its top stays standable.
- **Floating fossils and hologram exhibits:** giant skeletons and a planet model hanging on energy tethers, all with grapple beacons.
- **Gallery rails:** 45 m RUN walls on every level, split by pillars into chained wall-runs.
- **The mezzanine** crosses the pendulum's path, so dropping onto the bob from it is a route.

**Signature moment:** releasing off the pendulum at 30 m/s and landing a flying kill on the top gallery, with the city behind the glass.

**Course:** floor, gallery wall-runs, mezzanine, pendulum, top gallery, fossil grapple chain, finish on the skylight catwalk. **Arena:** the pendulum is the power play and the most exposed position, and its cycle moves the hot zone.

**Checks:** standing on a tilting bob, how landings feel at 30 m/s (too fast? that's a feel question for Liam), and whether a grapple on a fast point feels fair. Prototype first.

---

### 5.3 SPILLWAY: coolant canyon between arcologies

**Fantasy:** a vast dry coolant channel running along the base of a canyon between two arcologies. Pale concrete and chrome, glowing flow markers, maintenance drones, vents breathing steam.

**Scale hook:** both canyon walls are arcology faces rising **700 m** on either side, windows glowing. Maglev lines and skybridges cross the canyon far overhead, and a strip of sky shows at the top. The channel feels like the bottom of a trench, while the players are huge within it.

**Layout:** a channel about 220 m long with a 16 m flat floor. **Curved banks** are built from ramp segments (about 20°, 35° and 48°), rising 8 m, topped by a 4 m vertical RUN lip. Three bridges cross at 16 m, plus drone gantries. Tunnel mouths in the banks act as side routes. The channel descends in one direction through 20–25° chutes at the weirs.

**Set pieces:**
- **Halfpipe transfer:** carve *diagonally* up the far bank and the lip becomes a wall-run; head-on becomes a climb and mantle. That makes the diagonal carve a skill move.
- **Weirs:** speed engines, with an antigrav pad at the bottom of each returning you to bridge level.
- **Coolant surge (optional, a big fun set piece):** every 45 s a magenta energy wave (a `hazard()` on a `PATH` mover) sweeps down the channel floor. Get up the banks, or ride it out on a bridge. It clears the floor and forces everyone into the air.
- **Grates:** 1.1 m ribs across the channel as vault cover.
- **Bridges:** power positions, with grapple beacons underneath.

**Signature moment:** a halfpipe transfer ending in a mantle onto a bridge as the surge passes underneath.

**Course:** downstream race from the top weir to the outfall, with a gate under each bridge. The arena uses about 130 m of it.

**Checks:** the riskiest geometry. Prototype one bank first: seams, the 48°-to-vertical join, and whether a diagonal carve reliably triggers a wall-run. Check the surge hazard moves with its mover. If the motor can't do the carve cleanly, ask Liam before changing movement code (§7).

---

### 5.4 NEON CANYON: billboard chasm

**Fantasy:** a narrow chasm between two megatowers in a neon night city. Every surface is a giant LED billboard or hologram, with rain, colour washes and holo-koi swimming through the gap.

**Scale hook:** the chasm is **800 m deep**. The floor is a haze of light and traffic far below, and the towers vanish into cloud above. Flying traffic streams through lanes beneath the play space.

**Layout:** two facing walls about 120 m long, **6 m apart** (tune 5–8 m until a kick across plus one double jump roughly holds altitude). The play band is about 60 m tall, sitting around 400 m up. There's no floor on the main line: falling resets you at the last gate or spawn. Catwalks, cable cars and drone docks cross the gap every 15–20 m at staggered heights.

**Set pieces:**
- **Wall-run ping-pong:** every touch refreshes the double jump, so skilled players never land. Use one block per billboard.
- **Rotating billboards:** `ROTATE` movers that open and close wall segments on a beat.
- **Cable cars:** `PATH` movers gliding the length of the chasm, as moving cover and a grapple highway.
- **Holo-billboards:** see-through hologram panels with no collision. They block sight but not bullets or bodies, so you can shoot through them if you know where someone is.
- Height is gained by mantling catwalks and climbing fire-escape ladders, not by the zigzag itself.

**Signature moment:** ten wall touches without landing, shooting on every pass, 400 m above the traffic.

**Visual budget:** billboard colour through tint and emissive, animated with a few shared materials. No per-pixel noise and no video textures. The rain is a cheap GPU particle system that's off on Low.

**Checks:** measure the zigzag height loss per crossing, and ask Liam whether the fast camera-tilt flips are comfortable.

---

### 5.5 SKY HOTEL: atrium at the top of a 1 km tower

**Fantasy:** the atrium of a luxury hotel at the crown of a 1 km tower. Gold, cream, living walls of plants, glass elevators, a holographic chandelier and a gala in progress.

**Scale hook:** the atrium's glass roof and walls open onto a **sea of clouds**, with other tower crowns poking through. The hero landmark is a floating stadium or an orbital ring in the sky.

**Layout:** a 34 × 34 m void, 70 m tall (14 floors × 5 m). Each floor is a 5 m balcony ring with waist-high glass rails (vault). Suites off the balconies act as cover pockets. There's a lobby fountain at the bottom and a sky-deck terrace at the top, open to the clouds.

**Set pieces:**
- **Glass elevators:** 3 `PATH` movers up the void, staggered by `phase`. The shaft sides are RUN walls.
- **Holo-chandelier:** a `SWING` mover (about 10°, period 12 s) mid-void, with grapple beacons around its rim. It's the map's crossroads.
- **Fountain antigrav pads:** launch at about (0, 30, 0), roughly 19 m or 4 floors. Falling is the escape and the fountain is the way back.
- **Banners and living walls:** floor-to-ceiling RUN walls in the void for crossing between balconies.
- **Sky-deck terrace:** an open terrace with infinity pools and the cloud sea around it. Jump pads to a floating drone platform.

**Signature moment:** a drop through six floors shooting up at someone riding an elevator, then a fountain launch back into the fight.

**Arena:** the strongest couch map in the set. Every balcony sees the void, and the elevators and chandelier move the power positions. Protect spawns in suites.

---

### 5.6 CROSSTRACK: maglev junction between skyscrapers (needs Mover work)

**Fantasy:** a maglev interchange threaded between skyscrapers at 250 m. Chrome rails, light-strip gantries, trains whipping through tower tunnels.

**Scale hook:** the lines run *through* skyscrapers (tower tunnels) and out over the drop. Other maglev lines weave at different heights in the distance, and a huge central station tower anchors the skyline.

**Layout:** two parallel elevated maglev lines 10 m apart, a station platform, a signal gantry 10 m above, and tower portals at each end where the trains vanish.

**Set pieces:**
- **Trains:** `PATH` movers at 20–25 m/s constant speed. This **needs a `linear` option on `Mover`** (§1) plus a test. The return trip happens out of sight, inside the towers. Carriages are separate movers, or a few boxes on one mover.
- **Opposite-direction trains:** jumping between them doubles your relative speed. It's the signature move and the biggest feel risk.
- **Train sides** make 60 m wall-runs while a train passes the platform.
- **Tower tunnels:** when a train dives in, lie flat on the roof (slide) or jump off.

**Signature moment:** sprinting a train roof, leaping to the opposing train, then a flying kill on the gantry, 250 m up.

**King of the Moving Hill** (DESIGN §8): the hill is the last carriage.

**Checks (design questions for Liam, §7):** landing on a train moving the other way, what happens when a train hits a standing player, and tunnel clearance.

---

### 5.7 CORE: AI data core inside a tower spine

**Fantasy:** the cooling spine of an AI supercomputer running up the centre of a megatower. Black monoliths of server racks, blue cold light, orange heat vents, drones servicing the stacks. It's the most on-brand map for a stealth agent.

**Scale hook:** the hall is a **vertical shaft 400 m tall**. The play space is one 20 m band of it, with rings of rack monoliths receding above and below into haze, lit by pulsing data light. Service lifts streak up and down in the distance.

**Layout:** a ring hall about 80 m across around the shaft. Rack rows **3.0 m tall** (jump-mantle), so the aisles are the default layer and the rack tops the skill layer. Each rack row is **18 m long** (one wall-run), with 3 m aisles. Cable trays at 6 m with grapple beacons. An inner rim looks down the shaft.

**Set pieces:**
- **Aisles** are dead-straight slide lanes.
- **Laser sweeps:** a `hazard()` parented to a `PATH` mover (`TriggerZone.create` takes a parent; check it moves), shown with thin HAZARD `deco` beams.
- **Cooling fans:** `ROTATE` movers in the wall, with the blade gaps as timing windows.
- **The shaft drop:** jump off the inner rim, grapple a passing service lift (`PATH` mover with a beacon) and ride it to the band's other level.

**Signature moment:** a slide down a cold aisle under a laser sweep, a shotgun kill at the end, then a leap off the rim into the shaft onto a moving lift.

**Arena:** tight sightlines make it the SMG and shotgun couch map.

---

### 5.8 STORMFRONT: skyport cargo barge in a storm (needs merged mover visuals)

**Fantasy:** a floating cargo barge docking at a skyport in a lightning storm, above the clouds between megatowers. Floodlights, rain streaks, container stacks and a docking crane.

**Scale hook:** there's no ground at all. The cloud floor is lit by lightning, megatower crowns rise through it, and the skyport is a colossal ring structure the barge is docking into.

**Layout:** a deck about 150 × 32 m with container stacks 2–4 high, a bridge tower at the stern, a crane, and a docking arm connecting to a static skyport platform.

**Set pieces:**
- **The whole deck rolls:** one `SWING` mover on the long axis, **±15°, period about 10 s**. The slopes keep reversing, so the fastest slide direction flips every half cycle. Build merged mover visuals in `LevelBuilder` first.
- **Docking crane:** a `SWING` mover carrying a container that works as a moving bridge between the barge and the skyport.
- **Container corridors** are wall-run lanes.
- **Lightning:** a flash and a thunderclap on a cycle that briefly lights the whole scene. It's cosmetic, cheap and off on Low.

**Signature moment:** slide down the deck as it rolls toward you, slide-hop onto the crane container, and grapple into the skyport ring.

**Checks:** performance first (`--bench` on every preset), then how a rolling floor feels. Ask Liam about a "calm skies" comfort option.

---

### 5.9 ROOFTOPS: scale pass (propose to Liam; don't start while another session is editing `rooftops.gd`)

Rooftops is the map Liam finds small. Keep its playable layout and course, and change the world around it:
- Lift the whole block onto the **top of a 400 m megatower podium**. The four blocks become four towers on a plateau, with the streets turned into chasms 400 m deep (the street-level layer moves up onto sky decks).
- Replace the skyline with the §3 bands: megatowers at 300–900 m around it, a hero landmark, and flying traffic lanes along the old street lines.
- Make the crane a **construction crane on a 1 km tower still being built** next door, with the rest of the tower's skeleton rising above.

This keeps all the tuned routes while the map feels ten times bigger. It's a decision for Liam, and the timing needs coordinating with whichever session owns `rooftops.gd`.

## 6. Definition of done (per map)

- [ ] **It feels huge:** the vista station shows a real drop and megastructures towering above the player, and there's a hero landmark.
- [ ] It's futuristic, with the shared language from §3.
- [ ] ≥ 3 layers, 2+ routes everywhere, and the fastest route needs skill.
- [ ] The signature moment works reliably. Describe to Liam how to do it.
- [ ] Surface language is correct: RUN walls on the flow line, GRAPPLE beacons, BOOST pads, HAZARD zones.
- [ ] The course is built with `make_course` (start, ordered gates, finish), with a par time from your own clean runs plus about 15%. `# ENEMY:` markers are placed and dummies stand where enemies will go.
- [ ] Arena spawns are on every layer, and no spawn looks straight at another.
- [ ] Stations cover every set piece plus the vista. Lint and tests pass. `--bench` is in the Rooftops range on High and Low.
- [ ] `tools/build.sh all` is done, and the HANDOFF gets a line about the new map (only if no other session is editing it; otherwise tell Liam).

## 7. Design questions for Liam (ask, don't guess)

1. **Build order:** this file recommends Spiral, Pendulum Hall, then Spillway. Does Liam want a different first map, or the Rooftops scale pass (§5.9) first?
2. **Trains:** what happens when a train hits a player (push, kill, pass through), and should landing on an opposing train be smoothed?
3. **Halfpipe:** if a diagonal carve up a bank doesn't reliably wall-run, is a movement change allowed? That touches the movement kit and its tests.
4. **Motion comfort:** are Neon Canyon's fast tilt flips and Stormfront's rolling deck OK, or should there be comfort options?
5. **Launch speeds:** the Pendulum Hall slingshot reaches about 30 m/s. Is that fun-fast or too fast to land?

## 8. Later ideas (not scheduled)

- **Collapse:** a single-player escape where a megatower comes apart behind you on a fixed cycle, sections falling away into the clouds.
- **Clockwork:** the inside of a colossal clock tower. The minute hand is a slow bridge and the second hand a fast launcher; every 60 s the gears re-mesh (the "Shift" concept from DESIGN §7.3).
- **Orbital tether:** a fight up the outside of a space elevator, in low gravity, with Earth below (pairs with the low-gravity modifier).
- **Speed gates:** doors that open only while you're above about 15 m/s. They could appear in any map.
- **Mall of the future:** conveyor escalators (M5) in a floating mall atrium.
