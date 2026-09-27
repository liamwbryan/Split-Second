# First-person body animation: research and plan

Goal: give first-person movement the physical feel of Mirror's Edge. That means hands planting on ledges and obstacles, legs visible in slides and vaults, the gun swinging with the arms while sprinting and held out during slides, and a hand on the wall during wall-runs. The target is Godot 4.7.2 on mid-range PCs, including 4-player split-screen at 60 fps.

Legend: **[S]** means a public source says it. **[V]** means I verified it on the installed engine (`godot 4.7.2.stable.official.ed1daf0bf`). **[R]** means it is my recommendation or a starting value to tune, not a quoted industry number.

---

## 1. How the reference games do it

### 1.1 Two approaches

| Approach | Who | What the player sees | Cost |
|---|---|---|---|
| **True first person / "body awareness"**: one animated full body with the camera on the head | Mirror's Edge (2008) and Catalyst, Crysis, Tarkov-style sims | Arms, torso and legs, all from the same animation. Shadows and reflections match for free. | The camera inherits body motion, which risks motion sickness, so every clip must be tuned for the view. |
| **Separate FP rig**: arms (plus sometimes legs) rendered only for the owner, with a hidden world-space body for shadows and other players | Titanfall 1/2, Apex, CoD, Overwatch, Dying Light (arms, "sometimes feet"), UE5 FP template | Arms and weapon posed for the screen. Legs only when a move calls for them. | Two representations to keep in sync. The shadow comes from the hidden world body. |

- **Mirror's Edge (2008)** used a full body with a first-person camera. DICE's GDC talk is "Creating First Person Movement for Mirror's Edge" (Tobias Dahl and Mikael Lagre, GDC 2009) [S] (https://gdcvault.com/play/1012172/Creating-First-Person-Movement-for). The animators hand-keyed everything except cutscenes and some AI run cycles, and wrote their own Maya tools [S]. Attaching the camera to a motion-captured head "didn't work out", and "good old animator talent was the solution" [S] (https://www.gameanim.com/2010/11/05/creating-first-person-movement-for-mirrors-edge/). Their guiding rule: *"animate what you perceive and not exactly how things move in real life, i.e. what your eyes do, not your head and body"* [S] (https://www.awn.com/vfxworld/mirrors-edge-leap-faith). The body was built only for the first-person view, so it looks wrong from third person [S] (Wikipedia, https://en.wikipedia.org/wiki/Mirror%27s_Edge).
- **Mirror's Edge Catalyst**: the same Faith animations drive the first-person view, the shadow and the reflections, so nothing is authored twice. Raw mocap on the rig did not show the arms and feet enough, so "every animation" was reworked for first person, including the camera. They kept the camera "as still as possible" in basic locomotion (running, crouching, sliding). Their tools for selling physicality are the shadow, limbs interacting with objects at the right moments, and restrained camera animation (Erik Söderholm, animation director) [S] (https://ctrl500.com/developers-corner/mirrors-edge-catalyst-keeping-the-camera-in-your-face/).
- **Titanfall 1/2** use a viewmodel with arms and weapon and do not show legs. Lead animator Mark Grigsby on wall-runs: *"they'll have their gun in one hand and with the other they'll be caressing the wall."* The view tilts as you jump at a wall, before the run starts, so the player can anticipate it (Todd Alderman). Adding a landing viewmodel dip "made landing feel way more real, even though the … movement code was identical" (Rayme Vinson) [S] (https://www.gamedeveloper.com/design/designer-interview-getting-i-titanfall-i-s-controls-just-right). Respawn animators capture reference with a phone held at mouth height, because that angle matches game FP cameras better than eye height (Apex) [S] (https://www.gamedeveloper.com/art/the-secret-to-apex-legends-gorgeous-first-person-animation-mouth-cameras).
- **Dying Light (Techland)**: *"we just have the main character's two arms, and sometimes his feet, as the main visual on screen. So we had to get these limb animations… perfected."* They reduced motion sickness through HUD placement, motion blur, and parkour animation speed [S] (https://mcvuk.com/development-news/the-vaulting-dead-implementing-first-person-parkour-in-dying-light/). Ledge detection used more than 200 raycasts per frame, batched into parallel groups [S] (https://gdconf.com/article/speaker-q-a-dying-light-dev-bartosz-kulon-on-making-first-person-movement-feel-good/). The GDC talk is "Parkour: How to Improve Freedom of Movement in First-Person Games in 20 Simple Steps" [S] (https://www.gdcvault.com/play/1025208/). Dying Light 2 has more than 3,000 parkour animations [S] (https://www.gamedeveloper.com/programming/climbing-to-new-heights-with-dying-light-2-s-improved-parkour-system). We cannot match that count, so our version has to be procedural.
- **Overwatch** (Matt Boehm, GDC 2017): first-person animation cheats freely. Limbs stretch, arms clip in third person, and reloads were moved to the other hand so they don't cover the view or the reticle [S] (https://www.invenglobal.com/articles/1187/how-overwatchs-first-person-animation-breathed-life-into-heroes, https://gdcvault.com/play/1024319/). See also Ryan Duffin, "Giving Purpose to First-Person Animation" (GDC 2013) [S] (https://www.gdcvault.com/play/1017633/).
- **Unreal Engine 5.5+ First Person Rendering** is the current engine-level version of the "separate FP rig" approach. Primitives tagged `FirstPerson` render with their own FOV and are scaled toward the camera so they can't clip into walls. Primitives tagged `WorldSpaceRepresentation` are hidden from the owner but still cast shadows and appear in ray-traced reflections. The template uses `FirstPersonFieldOfView = 70` (horizontal degrees), `FirstPersonScale = 0.6`, the camera attached to the FP mesh's `head` bone, `SetOnlyOwnerSee(true)` on the FP mesh, and `SetOwnerNoSee(true)` + `bCastHiddenShadow = true` on the full-body mesh [S] (https://dev.epicgames.com/documentation/unreal-engine/first-person-rendering, https://dev.epicgames.com/documentation/unreal-engine/coder-04-adding-a-firstperson-camera-mesh-and-animation). The docs say to scale down "only as much as is required for it to be contained in the player bounds", or the geometry disappears behind the near plane.

### 1.2 Camera stabilization
- Do not let a mocap or animated head drive the camera directly. It failed at DICE [S]. Catalyst keeps locomotion camera motion minimal [S]. Léna Piquet's true-FP guide for UE4 constrains the head during authoring to look at a far fixed point so the view stays steady, clamps pitch and yaw, and asks for run and walk cycles to be "as steady as possible" [S] (https://www.froyok.fr/blog/2018-06-true-first-person-camera-in-unreal-engine-4/).
- In practice the camera stays **gameplay-driven and stable**. The body is placed under the camera, and camera "animation" is a small additive layer (dip, roll, punch, bob). We already have that in `CameraRig` [R].

### 1.3 Hand and foot contacts
- AAA games use mocap plus **motion warping**: named warp windows in a montage bend root motion so the hand-plant frame lines up with the detected ledge. UE docs: *"ensure your starting warp region covers the area when the character places their hand"* [S] (https://dev.epicgames.com/documentation/en-us/unreal-engine/motion-warping-in-unreal-engine). Limb IK then snaps the hands and feet onto the exact surface.
- Our movement is fully procedural (the motor lerps the capsule), so the equivalent is **world-locked IK targets**. When the move starts, fix the hand target at the ledge or wall point in world space and let the body move past it. A hand that stays still while the camera moves is what makes it read as "planted" [R].
- For timing and anticipation, the hand has to arrive on or before the frame where the body starts rising (Titanfall's tilt-before-wall-run follows the same idea) [S/R].

### 1.4 The weapon in motion
- Sprint: the weapon is lowered or canted, and the arms and weapon sway with the stride (our `Viewmodel.SPRINT_POS` already lowers it). For the Mirror's Edge feel, let the **off hand leave the weapon and pump** with the run cycle while the gun hand swings in phase [R, consistent with Titanfall's one-hand wall-run pose].
- Slide: the gun is held forward in the main hand, rolled 10–20°. The off hand may drag on the floor. The camera lowers and rolls slightly [R].
- Wall-run: gun in one hand, the other hand on the wall (Titanfall) [S].

### 1.5 When limbs are visible (the "moments")
Mirror's Edge, Catalyst and Dying Light all describe the same thing. Limbs appear when they **do something to the world**: planting on a ledge, pushing off an obstacle, kicking, sliding feet-first, landing or rolling, touching a wall. Otherwise they stay out of view so the screen is readable [S]. Legs appear when you look down, and in slides, vaults, kicks and landings.

### 1.6 Avoiding views of the inside of the body
- **Hide the head and neck.** Collapse the Head bone to ~0 scale, or use a mesh without the head. In UE the full body is hidden with OwnerNoSee and a separate FP mesh is used [S].
- **Push the body back** behind the camera by 10–25 cm, and further when looking down, so the camera never sits inside the chest or collarbones [R, common true-FP practice].
- **Pitch the spine with the view**, split across spine_01–03 and clamped, so looking down shows chest, belly and legs from outside [R].
- **Near plane**: keep it small (our current 0.05 m is fine), and rely on the body offset rather than a tiny near plane [R].
- **Separate arm FOV plus depth range**: arms and weapon render with a fixed FOV and a squashed depth range so they neither stretch at wide FOV nor clip into walls (UE: 70° horizontal, scale 0.6) [S]. Our `shaders/viewmodel.gdshader` already squashes depth.
- **Shadows** come from the world body (UE: `bCastHiddenShadow`), never from the FP mesh, whose FOV warp would distort them [S].

---

## 2. What Godot 4.7.2 provides (verified on the installed engine)

Verification: I ran scripts with `godot --headless --path . -s <abs path>` from the scratchpad, and changed nothing in the project. Checks: `ClassDB.class_exists`, `class_get_property_list`, `class_get_method_list`, plus live tests on the UAL mannequin.

### 2.1 Class availability [V]
| Class | Exists | Parent |
|---|---|---|
| `SkeletonModifier3D` | yes | Node3D |
| `IKModifier3D` | yes | SkeletonModifier3D |
| `TwoBoneIK3D` | yes | IKModifier3D |
| `ChainIK3D` / `IterateIK3D` | yes | IKModifier3D / ChainIK3D |
| `FABRIK3D`, `CCDIK3D`, `JacobianIK3D` | yes | IterateIK3D |
| `SplineIK3D` | yes | ChainIK3D |
| `LookAtModifier3D` | yes | SkeletonModifier3D |
| `BoneConstraint3D` | yes | SkeletonModifier3D |
| `CopyTransformModifier3D`, `ConvertTransformModifier3D`, `AimModifier3D` | yes | BoneConstraint3D |
| `ModifierBoneTarget3D` | yes | SkeletonModifier3D |
| `BoneTwistDisperser3D` | yes | SkeletonModifier3D |
| `LimitAngularVelocityModifier3D` | yes | SkeletonModifier3D |
| `SpringBoneSimulator3D`, `RetargetModifier3D`, `PhysicalBoneSimulator3D`, `XRBodyModifier3D` | yes | SkeletonModifier3D |
| `SkeletonIK3D` (old, deprecated FABRIK) | yes | SkeletonModifier3D |
| `JointLimitation3D`, `JointLimitationCone3D` | yes | Resource |
| `SingleBoneIK3D` | **no** | — |

IK returned in Godot 4.6 (https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/).

### 2.2 `SkeletonModifier3D` (base for custom modifiers) [V]
- Properties: `active: bool` and `influence: float 0..1`. The engine blends by influence, so write poses at full strength. Signal: `modification_processed`.
- Virtuals: `_process_modification()` and **`_process_modification_with_delta(delta)`**, both present in 4.7. Also `_skeleton_changed(old, new)` and `_validate_bone_names()`. Helper: `get_skeleton()`.
- Modifiers must be **children of the Skeleton3D**, and they run **in child order after the AnimationMixer** (https://godotengine.org/article/design-of-the-skeleton-modifier-3d/).
- `Skeleton3D.modifier_callback_mode_process` accepts Physics, Idle or Manual. The default is **Idle** [V]. `Skeleton3D.advance(delta)` exists for Manual mode.
- Live test [V]: a GDScript modifier using `_process_modification_with_delta` ran every frame and set `Head` scale to 0.001 (confirmed in the final pose) and rotated `spine_02`.
- **Gotcha [V]:** reading `get_bone_global_pose()` in `_process` gives the **pre-modifier** pose, because modifier results are temporary and the animation re-applies each frame. Read final poses (hand position, muzzle) in `Skeleton3D.skeleton_updated`. Set IK targets in `_process`; modifiers run after it in the same frame.

### 2.3 `TwoBoneIK3D` (use this for arms and legs) [V]
Settings-array API: `setting_count`, and per-index setters such as `set_x(index, value)`. Editor-visible properties are `settings/<i>/...`:
- `target_node: NodePath`, `pole_node: NodePath`. **Targets are nodes only; there is no Transform property.** At runtime you move `Marker3D`s. Make them `top_level = true` to world-lock contacts.
- `root_bone_name` / `middle_bone_name` / `end_bone_name` (plus int `*_bone` variants).
- `pole_direction` (None, ±X, ±Y, ±Z, Custom) and `pole_direction_vector`.
- `use_virtual_end`, `extend_end_bone`, `end_bone/direction`, `end_bone/length`.
- Inherited: `mutable_bone_axes`, `reset()`, `clear_settings()`, and node-level `influence`. **There is no per-setting weight on IK**, so use **one TwoBoneIK3D node per limb** to blend each arm independently.

Live test on `UAL1_Standard.glb`, right arm, Sprint playing [V]:
- The wrist reached the target exactly (error 0.0000 m) for every pole direction.
- The elbow always lies in the plane toward the pole node. `pole_direction` only chooses **which local axis of the middle bone faces the pole**, which sets forearm twist. On this rig the bones point along **+Y** (±Y triggers a "colinear" warning). Rest axes in model space: `lowerarm_r/l` local +Z points to model front, and `calf_r` local +Z points to model back. So use **`pole_direction = SECONDARY_DIRECTION_MINUS_Z`** for arms (elbow back) and **`SECONDARY_DIRECTION_MINUS_Z`** for legs (knee forward). Place the pole node below, behind and outside the elbow, or in front of the knee.
- **Hand orientation is not solved.** It stays as animated, 96–175° off the target. Add a `CopyTransformModifier3D` after the IK with `copy_rotation = true`, `copy_position = false`, `reference_type = REFERENCE_TYPE_NODE` pointing at the target, and `relative = false`. The hand then matched the target rotation exactly (0.00°) without breaking the position. Its per-setting `amount` works as a blend weight.
- Cost: animation plus skeleton with two IK modifiers ran within noise of no modifiers, a few µs per frame for the whole update on the M-series Mac with 20,000 iterations. IK is not a performance concern.
- Rig measurements: upper arm 0.274 m, forearm 0.273 m (reach about 0.55 m shoulder to wrist). Thigh 0.40 m, calf 0.43 m. Head bone at 1.569 m, shoulders (upperarm) at 1.441 m, in T-pose rest.

### 2.4 Other useful modifiers [V]
- **`CopyTransformModifier3D`**: per setting `amount`, `apply_bone_name`, `reference_type` (Bone/Node), `reference_bone_name`/`reference_node`, `copy` flags (position/rotation/scale), `axes`, `invert`, `relative`, `additive`. Uses: hand orientation, and pinning the weapon hand to the gun's grip socket.
- **`AimModifier3D`**: `forward_axis`, `use_euler`, `primary_rotation_axis`, `use_secondary_rotation`, `relative`, plus the BoneConstraint3D fields. Uses: aim the hand or forearm at the grapple anchor.
- **`LookAtModifier3D`**: `target_node`, `bone_name`, `forward_axis`, `primary_rotation_axis`, `use_secondary_rotation`, `origin_*`, **`duration` + `transition_type` + `ease_type`** (built-in smoothing), angle limits with damping. Uses: spine or chest following camera pitch.
- **`BoneTwistDisperser3D`**: spreads end-bone twist along the chain (`root_bone`, `end_bone`, `disperse_mode` Even/Weighted/Custom, `damping_curve`). The UAL rig has **no twist bones**, so run this after CopyTransform to hide wrist "candy-wrapping".
- **`LimitAngularVelocityModifier3D`**: `max_angular_velocity` (deg/s), `chain_count`/`joint_count`, `exclude`. A safety net against IK pops when a target teleports.
- `IterateIK3D` (FABRIK/CCD/Jacobian) adds `max_iterations`, `min_distance`, `angular_delta_limit`, `deterministic`, and per-joint `JointLimitation3D`. Not needed for two-bone limbs.
- `BoneAttachment3D` (`bone_name`, `override_pose`, `use_external_skeleton`) is already used for gear.

### 2.5 AnimationTree layering [V]
- Nodes: `AnimationNodeBlend2`, `AnimationNodeAdd2`, `AnimationNodeOneShot` (`mix_mode` Blend/Add, `fadein_time`, `fadeout_time`, curves, `request` FIRE/ABORT/FADE_OUT), `AnimationNodeTransition` (`xfade_time`, `input_count`), `AnimationNodeTimeScale`, **`AnimationNodeTimeSeek`** (drive clip time from mantle progress), `AnimationNodeBlendSpace1D/2D`, `AnimationNodeStateMachine`, and `AnimationNodeAnimation` (`use_custom_timeline`, `timeline_length`, `stretch_time_scale`, `start_offset`, `loop_mode`).
- **Per-bone filters** (on any AnimationNode): `filter_enabled = true` and `set_filter_path(NodePath("Armature/Skeleton3D:upperarm_r"), true)`. Paths are relative to the mixer's `root_node`; for UAL the tracks are `Armature/Skeleton3D:<bone>` [V]. In Blend2/OneShot, filtered tracks take the blend and unfiltered tracks pass input 0 through. `AnimationNode.FilterAction`: IGNORE, PASS, STOP, BLEND [V].
- `AnimationMixer.callback_mode_process`: Physics, Idle or Manual [V]. Use Idle for the FP body so it follows the per-frame interpolated camera.

### 2.6 Rendering controls [V]
- `Camera3D`: `fov` (vertical by default, `keep_aspect` = KEEP_HEIGHT), `near` (default 0.05), `cull_mask`. The project uses vertical 80° + up to 12° speed FOV, near 0.05.
- `GeometryInstance3D.cast_shadow`: OFF, ON, DOUBLE_SIDED, **SHADOWS_ONLY**. `layers`, `extra_cull_margin`, `custom_aabb`. Use `custom_aabb` or `extra_cull_margin` on the FP mesh so IK-stretched limbs aren't frustum-culled.
- `Light3D.shadow_caster_mask` exists.
- Godot has no built-in per-object FOV. Emulate UE's FP FOV in the vertex shader (§3.4). **Avoid a second SubViewport camera**: it doubles scene rendering, loses lights and shadows, and multiplies by 4 in split-screen.

---

## 3. Recommended architecture

### 3.1 Summary
```
Player
 ├─ RunnerAvatar (existing TP body): other players' cameras + everyone's SHADOW (incl. owner)
 └─ CameraRig (existing, stable, gameplay-driven)
     └─ FPBody (new; yaw-follows camera, not pitch; layer = owner's viewmodel layer)
         ├─ UAL mannequin instance (own AnimationTree, Idle callback)
         │   └─ Skeleton3D
         │       ├─ FPPoseModifier (GDScript SkeletonModifier3D): hide Head/neck, spine pitch share, body offset tweaks
         │       ├─ ArmIK_R  (TwoBoneIK3D, 1 setting)   ← target: gun grip (normally)
         │       ├─ ArmIK_L  (TwoBoneIK3D, 1 setting)   ← target: handguard / ledge / wall / floor / grapple
         │       ├─ HandRot  (CopyTransformModifier3D, 2 settings: hand_l, hand_r rotation from targets)
         │       ├─ TwistFix (BoneTwistDisperser3D, 2 settings: lowerarm→hand)
         │       └─ (later) LegIK (TwoBoneIK3D) for foot-on-obstacle in vaults
         ├─ Targets (top_level Marker3Ds): HandTarget_L/R, Pole_L/R
         └─ Weapon (existing Viewmodel procedural pose; exposes GripR / HandguardL sockets)
```
One extra skinned mannequin per local player (at most 4) plus about 4 cheap modifiers. There are no new render passes.

### 3.2 Direction of control: camera → gun → hands, with the body under them
1. **Camera stays the authority.** `CameraRig` already gives stable, interpolated, per-frame motion with dip, roll and punch. Do not parent the camera to the head bone; DICE found that doesn't work [S].
2. **The weapon keeps its procedural pose** from `Viewmodel` (sway, bob, kick, sprint-lower, wall tilt, land drop), and every existing feel test stays valid. Add two child nodes: `GripR` (right palm on the grip) and `HandguardL` (left palm under the handguard).
3. **Hands IK to the gun sockets** by default. The gun leads and the arms follow, which is the standard modern FPS setup. For traversal moments the **left-hand target lerps from the handguard to a world contact point**, and the gun pose moves to a one-handed pose.
4. **The body is positioned from the camera.** Set `FPBody` yaw to the camera yaw, and its origin to `camera_pos - Head_bone_offset - back_offset`. The legs come from locomotion clips, and the spine pitches with the view.

### 3.3 The FP body instance
- **Mesh**: the same `UAL1_Standard.glb`. In a custom modifier set `Head` and `neck_01` scale to 0.001 [V: works]. Do not attach the helmet or jump-kit, and keep the owner-only layer (the existing viewmodel layer 11–14 via `CameraRig.viewmodel_layer_bit()`).
  - *Better, later*: split the mesh in `art/blender/` into `FP_Arms` (clavicle→fingers vertex groups) and `FP_Body` (pelvis→spine_02 + legs), both skinned to the same Skeleton3D. Arms get the viewmodel shader (FOV + depth squash). The body gets the normal suit material and no FOV warp, because feet must stay on the real floor. Drop the head, neck and upper chest entirely.
- **Offsets** [R, starting values to put in `MovementTuning` / the debug panel]:
  - Body back offset: **0.15 m** when level, blending to **0.30 m** at 60° look-down (lerp on `-pitch`). This keeps the camera outside the collarbones and shows the legs.
  - Eye alignment: put the camera about **0.08 m above and 0.10 m forward of the `Head` bone**, then apply the back offset. At the rig's 1.569 m Head bone that gives an eye height of ~1.65 m, versus 1.62 m in tuning, so scale the root by ~0.98 or lower the body by 3 cm.
  - Spine pitch share: **pitch × 0.15 / 0.2 / 0.25** on spine_01/02/03, clamped to ±35° in total. The rest stays on the camera.
  - Crouch and slide: the body follows `crouch_eye_height` because it is placed from the camera. The Slide clip handles the legs.
- **Near plane**: keep **0.05 m** (current). The arm depth-squash shader means the arms never clip walls, so there's no need to go lower.
- **Culling**: set `extra_cull_margin` of ~1 m (or `custom_aabb`) on the FP mesh.
- **Shadows**: FP body `cast_shadow = OFF`. The existing `RunnerAvatar` already casts the owner's shadow (camera cull masks don't stop shadow casting; **check with `--shots`**). Because of that, `RunnerAvatar.needed` must stay true in single-player whenever sun shadows are on. Right now `level_base.gd:279` sets it false with one player, which would freeze your own shadow. The alternative is to switch it to cheap mode (lower `AnimationMixer` rate), not off.

### 3.4 Arm FOV (UE-style, in our existing viewmodel shader)
Arms and gun should keep a **fixed FOV** regardless of the player's FOV slider and the +12° speed FOV. Otherwise they shrink and stretch when sprinting.
```glsl
uniform float fp_fov_deg = 55.0;     // vertical; ≈ 86° horizontal at 16:9
uniform float fp_fov_weight = 1.0;   // blend to 0 during world contacts (see below)
void vertex() {
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float k = (1.0 / tan(radians(fp_fov_deg) * 0.5)) / PROJECTION_MATRIX[1][1];
	POSITION.xy *= mix(1.0, k, fp_fov_weight);       // re-project at fixed FOV
	POSITION.z = mix(POSITION.z, POSITION.w, 0.92);    // existing anti-clip depth squash
}
```
- Numbers: UE's template uses 70° horizontal (~43° vertical at 16:9) [S]. Source games use viewmodel FOVs around 54–68 (4:3 horizontal) [general knowledge]. Our camera is wider (80–92° vertical), so start at **55° vertical, tunable 45–70** [R].
- **Contact caveat** [R]: the FOV warp moves arm pixels by factor k in view space, so a hand "on the ledge" would draw off the ledge. Either (a) blend `fp_fov_weight → 0` over ~0.1 s while a hand is world-locked (mantle, vault, wall touch, floor drag), or (b) pre-warp the IK target: in view space, `target.xy /= k` at the same depth, and the rendered hand lands exactly on the world point. (a) is simpler, so start there.
- Don't put the FOV warp on the legs or body mesh. Do put it on the gun and the arms together, because they must share one projection or the hands slide off the grip.

### 3.5 Animation layering on the FP body (AnimationTree)
The UAL set has **no rifle clips**, so the upper body is mostly procedural.
- **Lower body** (filter: pelvis, thighs, calves, feet, ball): a state machine or Transition over `Idle / Walk / Jog_Fwd / Sprint` (speed-matched, as in `RunnerAvatar.CLIP_SPEED`), `Crouch_*`, `Slide_Start → Slide → Slide_Exit`, `Jump_Start / Jump / NinjaJump_Idle`, `Jump_Land / NinjaJump_Land / Roll` (hard landing), and `ClimbUp_1m` for mantle and vault legs.
  - Mantle and vault: feed `ClimbUp_1m` through **`AnimationNodeTimeSeek`** with `seek = motor_progress × clip_length`. This time-warps the clip to the motor's lerp, which is the procedural equivalent of motion warping.
- **Upper body base pose** (filter: spine_02 up, clavicles, arms, fingers): `Pistol_Aim_Neutral` frozen through TimeSeek. It gives the IK a sensible start pose, raised elbows, and **closed grip fingers**.
- **Left-hand fingers**: Blend2 filtered to the `*_l` finger bones between the grip pose and an open-palm pose (for example `Push` or `Idle_Rail`, frozen), driven by "hand is planting".
- **Sprint arm pump**: during Sprint, fade **ArmIK_L.influence → 0** (0.12 s) so the Sprint clip's own left-arm swing shows (Blend2 lets the Sprint clip through on the left arm). The gun hand stays on IK, and the gun gets a small yaw and roll swing on the footstep phase: ±4° yaw, ±3° roll, 3 cm lateral [R]. This is the "gun swinging with the arms" look.
- Blend times [R]: locomotion crossfades **0.12–0.15 s** (the existing `BLEND = 0.14`). IK influence in **0.06–0.08 s**, out **0.12–0.18 s**. Hand-plant reach **≤ 0.08 s** (it must land before the body rises). Smooth targets with a critically-damped spring (ω≈25–35 rad/s), not lerp.

### 3.6 Per-state targets (from motor data)
Motor data needed (read-only, since `_mantle_*` is private today): `ledge_point`, `ledge_normal` (edge direction), `mantle_progress`, `is_vault`, `wall_point`, `wall_normal` (exists), `wall_side` (exists), `grapple_point` (exists). Adding getters leaves movement logic untouched [R].

| State / moment | Left hand (ArmIK_L) | Right hand + gun | Legs / body | Camera extra |
|---|---|---|---|---|
| Ground run | Handguard socket | Grip socket | Jog/Walk clip, speed-matched | existing bob |
| Sprint | **IK off → clip arm pump** | Gun lowered + stride swing | Sprint clip | — |
| Slide | **Floor point**: raycast down at body-left, ~0.35 m left, ~0.25 m forward of hip, palm down, trailing (world-locked, re-plant every ~0.25 s) or just hovering 5 cm off the floor | Gun **held out**: forward +0.1 m, rolled 15° toward center, one-handed | Slide clip; feet visible ahead when looking down | lower (existing), roll 3–5° |
| Vault (`is_vault`) | **Obstacle top**: ledge_point offset 0.15–0.25 m left along edge, world-locked. Weight 0→1 in first 20% of move, hold to ~60%, release by 80% | Gun swung out-right/up, one-handed | ClimbUp_1m (time-seeked) or Jump tucked; legs swing under and are visible below | small roll toward plant hand, 2–4° |
| Mantle | **Both hands** (ArmIK_R too, gun lowered/tucked or hidden briefly) at ledge_point ± 0.2 m along edge, world-locked, planted at progress 0 and pushed "down" as the body rises | Gun: dropped 0.15 m and rotated away, then back by the end | ClimbUp_1m time-seeked | existing dip |
| Wall-run, wall on left | **Wall point**: wall_point + 0.35 m forward, shoulder height, 2 cm off the wall, palm facing −wall_normal. Re-plant forward every ~0.3 s (or slide along) | Gun canted away from wall | Sprint clip (hips lean) | roll (existing) |
| Wall-run, wall on right | v1: gun canted toward wall, left hand stays on gun. v2: mirror the grip so the left hand holds the gun and the right hand touches the wall (Titanfall's "gun in one hand, other on wall") | — | — | — |
| Wall-climb | Alternating hand-over-hand plants on the wall above (IK_L, IK_R), gun lowered | — | ClimbUp_1m slowed | — |
| Grapple | **Arm extended toward anchor**: target = shoulder + dir(anchor) × 0.52 m, AimModifier3D on hand; rope starts at `hand_l` (read in `skeleton_updated`) | Gun one-handed | NinjaJump_Idle / Jump | — |
| Air | Handguard, or spread slightly | Grip | Jump / NinjaJump_Idle | — |
| Hard landing | Both hands dip, or `Roll` | Gun drop (existing) | Jump_Land / Roll | existing dip |

Pole placement [R]: arm pole = shoulder + (−0.3 m forward, −0.5 m down, ±0.3 m outward) in body space. Leg pole = knee + 0.5 m forward.

Timing [R]: the motor's `_mantle_duration` default is 0.2 s, which is very short for a visible hand plant. Start the reach on detection (`mantled` signal), make contact by t≈0.04 s, and consider 0.3–0.4 s mantles as a feel test. Mirror's Edge mantles are visibly longer.

### 3.7 Efficiency
- CPU: one AnimationTree plus about 5 modifiers per local player. IK measured below noise on this Mac. Gate the whole FP body on the local camera existing (`needed`-style).
- GPU: one extra skinned mannequin per local player (≤ 4). Godot skins on the GPU. No second viewport, no extra shadow caster (FP `cast_shadow = OFF`), no transparent materials.
- Tick: FP body AnimationTree and Skeleton in **Idle** mode (it follows the interpolated camera). All motor-derived data comes from the 120 Hz tick and gets interpolated.
- Avoid per-frame raycasts for contacts except the slide floor probe (one ray at ≤ 30 Hz is enough). Ledge and wall points come from the motor.

### 3.8 Build order [R]
1. FP body instance on the owner's viewmodel layer: head hidden, yaw follows camera, back offset, legs from clips. Tune with `--shots`.
2. Arm FOV + depth-squash shader shared by gun and arms. Grip and handguard sockets on the gun. TwoBoneIK3D ×2 + CopyTransform + TwistDisperser.
3. Traversal contacts: mantle and vault hands, then wall-run hand, slide gun-out plus floor hand, grapple arm.
4. Sprint arm pump and gun swing. Spine pitch. Landing and roll.
5. Tests: IK reach error < 1 cm for each contact state (read in `skeleton_updated`). No FP body when third-person. Benchmark at 4-player split-screen.

---

## Sources
- DICE, *Creating First Person Movement for Mirror's Edge*, GDC 2009 — https://gdcvault.com/play/1012172/Creating-First-Person-Movement-for
- Game Anim summary — https://www.gameanim.com/2010/11/05/creating-first-person-movement-for-mirrors-edge/
- AWN, *Mirror's Edge: A Leap of Faith* — https://www.awn.com/vfxworld/mirrors-edge-leap-faith
- CONTROL500, *Mirror's Edge Catalyst: Keeping the camera in your face* (Erik Söderholm) — https://ctrl500.com/developers-corner/mirrors-edge-catalyst-keeping-the-camera-in-your-face/
- Game Developer, *Designer Interview: Getting Titanfall's controls just right* — https://www.gamedeveloper.com/design/designer-interview-getting-i-titanfall-i-s-controls-just-right
- Game Developer, *Apex Legends… mouth cameras* — https://www.gamedeveloper.com/art/the-secret-to-apex-legends-gorgeous-first-person-animation-mouth-cameras
- MCV, *The Vaulting Dead: Implementing first-person parkour in Dying Light* — https://mcvuk.com/development-news/the-vaulting-dead-implementing-first-person-parkour-in-dying-light/
- GDC Q&A, Bartosz Kulon — https://gdconf.com/article/speaker-q-a-dying-light-dev-bartosz-kulon-on-making-first-person-movement-feel-good/
- GDC Vault, *Parkour: How to Improve Freedom of Movement…* — https://www.gdcvault.com/play/1025208/Parkour-How-to-Improve-Freedom
- Game Developer, Dying Light 2 parkour — https://www.gamedeveloper.com/programming/climbing-to-new-heights-with-dying-light-2-s-improved-parkour-system
- Overwatch FP animation (Boehm, GDC 2017) — https://gdcvault.com/play/1024319/ , https://www.invenglobal.com/articles/1187/how-overwatchs-first-person-animation-breathed-life-into-heroes
- Ryan Duffin, *Giving Purpose to First-Person Animation*, GDC 2013 — https://www.gdcvault.com/play/1017633/
- Léna Piquet, *True First Person Camera in UE4* — https://www.froyok.fr/blog/2018-06-true-first-person-camera-in-unreal-engine-4/
- Epic, *First Person Rendering* — https://dev.epicgames.com/documentation/unreal-engine/first-person-rendering
- Epic, *Adding a First-Person Camera, Mesh, and Animation* — https://dev.epicgames.com/documentation/unreal-engine/coder-04-adding-a-firstperson-camera-mesh-and-animation
- Epic, *Motion Warping* — https://dev.epicgames.com/documentation/en-us/unreal-engine/motion-warping-in-unreal-engine
- Godot, *Design of the Skeleton Modifier 3D* — https://godotengine.org/article/design-of-the-skeleton-modifier-3d/
- Godot, *Inverse Kinematics Returns to Godot 4.6* — https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/
- Godot docs, TwoBoneIK3D — https://docs.godotengine.org/en/latest/classes/class_twoboneik3d.html
