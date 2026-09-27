# Art Direction: "Mirror's Edge bones, cyberpunk skin"

> Written 2026-09-26 from Liam's direction:
> - "No more simple blocky shape models and designs. I'd like it to look more AAA in its models and objects."
> - City maps take cues from **The Ascent** and **Ghostrunner**.
> - "Seamlessly blend more detailed looks from games like that with the Mirror's Edge look."
>
> Read with `DESIGN.md` §4.4 (surface language) and §9, `MAP_BRIEFS.md` §0 and §3, and `CLAUDE.md` (efficiency rules).

## 1. The blend in one sentence

**The route is Mirror's Edge; everything around the route is The Ascent / Ghostrunner.**

The surfaces you run, climb, grapple and fight on are clean, bright and readable: pale composite, strong key light, and the runner-vision colors (RUN orange-red, GRAPPLE cyan, BOOST yellow, HAZARD magenta). Everything *around* that line is dense, layered, lived-in cyberpunk: machinery, pipes and cable runs, vents and fans, signage and holo ads, grates and catwalks, undersides full of structure, and neon at night.

The player always reads the route first, then the world's richness.

| | Mirror's Edge layer (route, readability) | Ascent / Ghostrunner layer (dressing, richness) |
|---|---|---|
| Where | Floors, run walls, climb faces, ledges, cover tops, beacons, pads | Walls above/below the route, ceilings, undersides, backs of buildings, rooftops' machinery, skyline, signage |
| Form | Large clean planes, crisp chamfered edges, restrained panel seams | Layered, greebled, stacked: base form + trim + greeble + cables |
| Color | White/pale grey structure + saturated route colors | Gunmetal, dark composite, grime; neon accents (magenta, cyan, amber) in signs only |
| Light | Clean key light (sun or moon), soft AO | Emissive signage, light strips, glowing windows, haze and fog layers |
| Density | Low: the route must read at 18 m/s | High: no bare wall or empty roof ("big but full", MAP_BRIEFS §0.4) |

**Day maps** (Rooftops, Pendulum Hall) lean Mirror's Edge: bright, clean, sunlit, with neon signage present but secondary. **Night city maps** (SPIRAL, Neon Canyon, Crosstrack) lean Ghostrunner: dark structure, neon-drenched dressing, while route surfaces stay pale and lit so they still pop.

## 2. Visual system

- **Shape language:** no raw box edges anywhere the player can see up close. Every edge is chamfered or rounded. Forms are **layered**: a base volume, a trim/frame band, recessed panels, then greebles (vents, bolts, conduits, sensor pods). Architecture has a rhythm: a rib, seam or pillar every 2–4 m, so scale reads at a glance.
- **Silhouettes:** props read by silhouette at 20 m. A hover car is a car shape (canopy, nacelles, fins), not a box; a barrier has a profile (a jersey or tapered base); a crate has corner guards and ribs.
- **Value structure:** route surfaces are the brightest mid-tones in the frame at day and the best-lit at night. Dressing sits darker, a step down in value, except the emissives.
- **Palette roles:**
  - Structure: white `#E6E4DC`, pale grey `#C8CACC`, gunmetal `#3A3F46`, dark composite `#1C1F24`.
  - Route: RUN `#F2542A`, GRAPPLE `#26D1FF`, BOOST `#FFD11A`, HAZARD `#F2268C`.
  - Neon accents, dressing only: magenta `#FF3BB0`, cyan `#3BE8FF`, amber `#FFB347`, warm white `#FFE9C7`.
  - Player colors appear on the player only (lenses and lights).
- **Materials:** painted composite (satin), brushed and gunmetal metal, dark glass, emissive glass, concrete. Wear is subtle: edge highlights, a height grime gradient near floors, and streaks under vents. There's no photoreal grime noise (budget).
- **Signage:** holo and neon signs are shapes (glyph panels, arrows, logos, pictograms) plus Label3D for the few legible words. Kanji- and hangul-style glyph panels come from modeled strokes, not fonts. Unshaded emissive, no real lights.
- **Exclusions:** bare untextured boxes as finished art, per-pixel noise/fbm, video textures, real-time lights per sign, clutter on the route line, and neon on route surfaces (it competes with the route colors).

## 3. How it stays cheap (mid-range Windows PC)

| Technique | Where | Cost control |
|---|---|---|
| Chamfered block visuals | `LevelBuilder` (all static blocks) | ~44 tris per block instead of 12, still merged into chunked meshes; collision stays boxes |
| Procedural panel seams, edge wear, height grime | `surface.gdshader` | Arithmetic on world position (step/fract), no textures or noise; scaled per kind |
| Modeled prop kit | `art/blender/*_kit.py` → `assets/models/kit_*.glb` | One MultiMesh per model (`Props.finalize`), `visibility_range_end` per prop size (small props vanish at 60–90 m), 1–3 materials per model from a shared kit palette |
| Hero props (hover cars, cranes) | Separate GLBs, attached to movers | 5–15k tris, no more than a dozen on screen |
| Distance | `Backdrop` layers, `facade_far.gdshader` | No textures past 150 m |
| Light | Emissive materials + glow | No per-prop lights; a handful of OmniLights only on High/Ultra |

**Budgets (triangles):** small prop 200–1,500; medium (barrier, crate stack, kiosk, AC) 1–4k; large (hover car, vending machine, sign rig) 4–12k; hero set piece up to 30k. Materials per prop: no more than 3 (kit materials `KitPaint`, `KitMetal`, `KitDark`, `KitGlass`, `KitGlow`, plus `Accent` where it applies). Textures reuse the Poly Haven sets already in `assets/textures`; new sets are 1k.

**Performance gate:** each map's `--bench` on Low and High must stay within 10% of its pre-kit numbers, or the kit's visibility ranges or density come down.

## 4. Kit manifest (priority order)

### City kit (Rooftops, SPIRAL, later city maps)
1. **Hover car** (parked, with a variant on movers): canopy, nacelles, underglow, paint slot. It replaces SPIRAL's box cars. *Hero asset, approve first.*
2. **Railing module** (2 m): posts, twin rails, glass or mesh infill, light strip. Replaces flat rail boxes.
3. **Jersey barrier** (futuristic): tapered profile, hazard light bar, lift points.
4. **Cargo crate family** (1.2 m and a 2.4 m long crate): corner guards, ribs, stencil panel, handles.
5. **Kiosk / vending machine** (2.4 m): screen, lit panel, canopy lip, vents.
6. **Neon sign rigs**: vertical blade sign, horizontal banner, glyph panels, arrow signs; bracket and cable mounts.
7. **Pipe and duct runs**: straight, elbow and T pieces plus brackets (wall dressing); **cable bundles** (drape between points).
8. **Wall machinery**: vent grilles, fan housings, junction boxes, conduit boxes; the AC units upgraded to match.
9. **Street and roof furniture**: lamp post (futuristic), bench, planter (sculpted), bollards, roof access door, antenna cluster, dish.
10. **Structural trims**: pillar caps and bases, beam brackets, ceiling light fixtures, grated catwalk module.
11. **Training dummy**: a sleek target robot. It replaces the capsule dummy and matches the weapons work.

### Museum kit (Pendulum Hall)
Plinth with sculpture, display case (glass and gold trim), holo pedestal, gallery railing (gold), bench, a modeled fossil skeleton, and the orbital planet frame.

## 5. Process

1. **Hero first:** the hover car and railing module, judged in-engine at gameplay scale in SPIRAL (day and night) before building the rest.
2. **Families:** the rest of the city kit reuses the hero's materials, bevel widths (1–3 cm small, 4–8 cm large) and emissive style.
3. **Integrate** by swapping primitive calls in `Props`/maps for kit placements. Collision stays simple boxes (the same numbers, so the lint and route tests keep passing).
4. **Validate:** screenshots of every station (`--shots`), `--bench` Low and High, `tests/run_tests.sh`.
5. **Record** every model's script and settings in `art/blender`, and add any CC0 source to `docs/ASSET_SOURCES.md`.
