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
> **Built 2026-09-26** (`art/blender/city_kit.py` → `assets/models/kit_*.glb`, placed through `Props`; `art/blender/kit_sheet.py` renders a contact sheet). Tri counts are in brackets.

1. ✅ **Hover car** [2.6k]: a lofted wedge hull, a teardrop glass canopy, four nacelles with thrust rings, underglow, head and tail light blades, intakes and canards. Paint is per instance (`KitPaint`). It's used for SPIRAL's parked cars and, stretched to their boxes, the mover cars (`Props.paint_node`).
2. ✅ **Railing module** [528]: posts, a white top rail, a cyan strip, a mid rail, **slim balusters** and a kick plate with an amber glow. *Deviation:* the smoked-glass infill read as a solid black band in game, so it's balusters (see-through, opaque, no transparency pass). The SPIRAL helix rail is still LevelBuilder geometry.
3. ✅ **Jersey barrier** [404]: a tapered profile, hazard stripe, amber light bar, lift slots and metal end caps. Scaled to each footprint.
4. ✅ **Cargo crate** [968]: 1.2 m, corner guards, ribs, handles, a stencil plate and a status LED; paint per instance. *Left:* the 2.4 m long crate.
5. ✅ **Kiosk** [948], plus two SPIRAL deck-cover pieces: the **holo pylon** [712] and the **charging pod** [744]. Screens and ad panels are `KitSign`, glowing in a per-instance colour (`shaders/kit_sign.gdshader`).
6. ✅ **Neon sign rigs**: blade sign [624], banner [392] and glyph panel [92], all with modeled pseudo-kanji glyph strokes and per-instance colour. *Left:* arrow signs.
7. ✅ **Pipe run** [668] (twin pipes on brackets), **duct** [324] (ceiling-hung) and **cable bundle** [488] (stretched between any two anchors). *Left:* elbow and T pieces.
8. ✅ **Vent grille** [152], **fan** [536], **junction box** [224]. *Left:* AC units restyled to match (`rooftop_props.py`).
9. ✅ **Lamp** [292] (it replaces every `street_light`), **bench** [488], **planter** [1,076] and **bollard** [436]. *Left:* roof access door, antenna cluster, dish.
10. ⬜ **Structural trims**: pillar caps and bases, beam brackets, ceiling light fixtures, grated catwalk module.
11. ⬜ **Training dummy**: a sleek target robot to replace the capsule dummy (pairs with the weapons work).

Also left for a later pass: Rooftops' vans are still boxes; SPIRAL's two roof blocks; the planter trees are stylized blobs (they want a proper foliage card or leaf clusters).

**Cost:** visibility ranges are 70–120 m for small dressing, 250 m for railings and lamps, and 400–600 m for cover and signs, so cover never disappears. Small dressing casts no shadows. Rooftops' draw calls on High went from 286 to 405 (each model is 4–8 material surfaces), so merging the kit's fixed materials into one atlas material is the next cost lever if a mid-range PC needs it.

### Museum kit (Pendulum Hall)
Plinth with sculpture, display case (glass and gold trim), holo pedestal, gallery railing (gold), bench, a modeled fossil skeleton, and the orbital planet frame.

## 5. Process

1. **Hero first:** the hover car and railing module, judged in-engine at gameplay scale in SPIRAL (day and night) before building the rest.
2. **Families:** the rest of the city kit reuses the hero's materials, bevel widths (1–3 cm small, 4–8 cm large) and emissive style.
3. **Integrate** by swapping primitive calls in `Props`/maps for kit placements. Collision stays simple boxes (the same numbers, so the lint and route tests keep passing).
4. **Validate:** screenshots of every station (`--shots`), `--bench` Low and High, `tests/run_tests.sh`.
5. **Record** every model's script and settings in `art/blender`, and add any CC0 source to `docs/ASSET_SOURCES.md`.
