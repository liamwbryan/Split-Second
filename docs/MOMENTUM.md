# Momentum prototype

Liam asked (2026-09-26) whether momentum mechanics would make movement more fun: building speed as you wall-run and jump, then falling into a slide to gain more. This is a prototype for comparing. It's **off by default**, so the tuned M1 feel is untouched until Liam turns it on.

**Try it:** open the Movement Gym, go to the **Momentum Lane** station (`[ ]`), open the tuning panel (backtick), and tick `momentum_enabled` in the Movement tab under **Momentum**. Sprint off the deck, chain the three alternating walls (wall-run, kick, wall-run...), then drop onto the yellow ramp **holding crouch**. Watch the speed and the new bar under it. Then turn it off and run the lane again to compare. The O readout shows the meter and the current soft cap.

## How it works

Code: `PlayerMotor` (the `momentum` section), with the tunables in `MovementTuning` → Momentum. The motor still owns velocity; every rule goes through the existing transitions.

1. **Flow meter (0–1).** Every chained move adds `momentum_link_gain` (0.2): entering a wall-run, a wall or climb kick, a slide-hop, a slide landing, and letting go of the grapple in the air. The meter drains slowly in the air (`momentum_air_decay`, 0.15/s), not at all on walls, in slides or on the grapple, and quickly once you've been on foot for `momentum_ground_grace` (0.2 s) at `momentum_ground_decay` (2/s). A bunny hop or slide landing never touches the grace window, so it keeps your chain.
2. **Higher speed ceiling.** The soft speed cap (18 m/s) rises by up to `momentum_cap_bonus` (+7, so 25 at a full meter). The hard cap (40) is unchanged.
3. **Kicks push you faster.** Wall kicks, climb kicks and grapple releases add `momentum_kick_speed × meter` (up to +1.5 m/s), never past the raised soft cap. Only "push-off" moves pay speed. Slide-hops only fill the meter, so hopping on flat ground can't farm speed (there's a test for this).
4. **Wall-runs keep their entry speed.** Above the 11 m/s wall-run target, the usual overspeed bleed (1.5 m/s²) is cut by `momentum_wallrun_keep × meter` (80% at a full meter). Enter a wall fast and you leave it fast.
5. **Slide landings turn falls into speed.** Landing into a slide converts `momentum_land_convert` (60%) of the fall speed above `momentum_land_min_impact` (9 m/s) into forward slide speed, capped at `momentum_land_max` (+6 m/s). A slide-hop lands at about 8 m/s, so ordinary hops get nothing. A 4 m drop adds about 3.3 m/s, and a drop off a wall-run adds more. The bonus is applied after the normal slide boost, so the slide boost's own cap doesn't eat it.

## Feedback (so it feels like it's building)

- **HUD:** a thin bar under the speed readout fills with the meter, going orange to gold as it fills. It only shows while the prototype is on.
- **Camera:** the view widens by up to `momentum_fov_add` (4°) as the meter fills, and a boost (slide landing or kick) punches the FOV out by `momentum_boost_fov_kick` (4°) and lets it settle.
- **Audio:** each chained move plays a soft chime that climbs in pitch with the meter (`momentum_link_sound_db`, −15 dB; set it to −40 to mute). A boost adds a whoosh on top of the move's own sound. Wind gets a little louder with a full meter.

## Tunables (MovementTuning → Momentum)

| Tunable | Default | What it does |
|---|---|---|
| `momentum_enabled` | off | Master toggle. Off = the old behavior exactly (tested). |
| `momentum_link_gain` | 0.2 | Meter per chained move. 5 links = full. |
| `momentum_air_decay` | 0.15 /s | Drain while airborne. |
| `momentum_ground_decay` | 2.0 /s | Drain on foot, after the grace time. |
| `momentum_ground_grace` | 0.2 s | Time on foot before draining. |
| `momentum_cap_bonus` | 7 m/s | Soft cap raise at a full meter. |
| `momentum_kick_speed` | 1.5 m/s | Kick/grapple-release speed at a full meter. |
| `momentum_wallrun_keep` | 0.8 | Share of wall-run overspeed bleed removed at a full meter. |
| `momentum_land_min_impact` | 9 m/s | Fall speed a slide landing must beat. |
| `momentum_land_convert` | 0.6 | Share of the fall speed above that turned into slide speed. |
| `momentum_land_max` | 6 m/s | Most one slide landing can add. |
| `momentum_fov_add` | 4° | Extra FOV at a full meter. |
| `momentum_boost_fov_kick` | 4° | FOV punch on a boost. |
| `momentum_link_sound_db` | −15 dB | Chain chime volume (−40 = off). |

**Suggested experiments:** if it feels too subtle, try `momentum_kick_speed` 2.5 and `momentum_cap_bonus` 10. If maps start to feel small at 25 m/s, drop `momentum_cap_bonus` to 4. If losing the meter feels punishing, raise `momentum_ground_grace` to 0.4.

## Open questions for Liam

- Is a visible meter fun (it gamifies chaining), or should momentum be felt only through speed?
- Should the meter reset on taking damage (for M3 couch FFA), or only on stopping?
- If it stays, levels should expect speeds of 20–25 m/s on chained routes, so gaps and wall spacing on the fast line can open up.

## Ideas for making basic moves more satisfying

Liam's priority is that every move feels satisfying, including the ordinary ones. These are cheap and don't need the momentum toggle:

1. **Landing:** scale the landing dip, the thump volume and a tiny controller rumble with impact speed, and add a short "stick the landing" window. Pressing jump or crouch within ~80 ms of touchdown gives a clean chime and keeps 100% of your speed (skill feedback without new rules).
2. **Slide start and double jump:** a quick FOV punch (2–3°) and a 1–2 frame camera squash on slide start, plus a crisp air-puff sound and a faint ring particle under your feet on the double jump (pooled, off on Low). Right now both moves are only audible, and a visual beat on the exact frame sells them.

## Swing grapple (2026-09-26)

The grapple is now a rope you can swing on (DESIGN §4.1). It pairs with the meter: a swing release is a chained move like before, and swing speed bleeds at only 30% of the normal soft-cap rate (`grapple_swing_cap_decay`). So a well-timed swing is one of the ways to carry an over-cap speed into the next wall-run. If momentum stays, grapple anchors on maps should sit so that a swing's low point skims just above the floor. That's where the swing is fastest, and it's the most satisfying line.
