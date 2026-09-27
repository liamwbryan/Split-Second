class_name FPBody
extends Node3D
## First-person body, Mirror's Edge style (docs/research/fp_body_animation.md).
## A second copy of the agent that only its owner's camera renders:
##  - legs come from the same locomotion clips as the third-person avatar
##  - the arms are driven by two-bone IK: normally onto the gun's grip
##    sockets, and onto world contact points during traversal (ledge,
##    obstacle, wall, floor, grapple direction)
## Control flows camera -> gun -> hands; the body is placed under the camera.

const MODEL := preload("res://assets/models/fp_mannequin.glb")  # art/blender/fp_mannequin.py
const FP_FOV := 68.0              ## vertical FOV of arms + gun (shared with the gun's materials)
## Eye position relative to the neck bone, looking level (rotates with pitch,
## so looking down swings the body back and shows the legs).
const NECK_TO_EYE := Vector3(0.0, 0.19, -0.06)
## Where the neck sits in the body (the pose modifier moves the pelvis to put it
## there). Standing on flat ground this puts the feet on the floor.
const NECK_BODY := Vector3(0.0, 1.43, 0.0)
const BACK_DOWN := 0.06           ## extra push back when looking straight down
const FLOAT_MAX := 0.04           ## on the ground, feet never hover more than this
const TARGET_RATE := 26.0         ## how fast a hand settles after a target switch (1/s)
const ARM_REACH := 0.59           ## shoulder to wrist, arm straight (stretched FP arm, a hair short of locked)
const MANTLE_HUNCH := deg_to_rad(28.0)  ## chest leans over the ledge while the hands push

## Hand orientations relative to the gun (columns = hand bone X, Y, Z).
## Bone axes on this rig: +Y along the fingers, +Z toward the thumb; the palm
## faces -X on the right hand and +X on the left (measured from the rest pose).
const GRIP_R_BASIS := Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1))
const GRIP_L_BASIS := Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))
## Wrist offsets from the grip sockets, in gun space.
const WRIST_R := Vector3(0.03, 0.065, 0.02)
const WRIST_L := Vector3(-0.055, -0.03, 0.07)  ## hand sits at the back of the handguard
## Left hand on the grapple launcher's grip (launcher space): a pistol grip,
## fingers down and wrapped, thumb forward, the wrist behind and above it.
const GRAPPLE_GRIP_BASIS := Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1))
const WRIST_GRAPPLE := Vector3(-0.03, 0.06, 0.03)

var player: Player
var rig: CameraRig
var viewmodel: Viewmodel
var skeleton: Skeleton3D
var anim: AnimationPlayer
var active: bool = true

var _model: Node3D
var _pose: FPPoseModifier
var _ik_r: TwoBoneIK3D
var _ik_l: TwoBoneIK3D
var _hand_rot: CopyTransformModifier3D
var _target_r: Marker3D
var _target_l: Marker3D
var _pole_r: Marker3D
var _pole_l: Marker3D
var _current_clip: StringName = &""
var _land_time: float = 0.0
var _pump: float = 0.0             ## free-arm swing amplitude (0 standing .. 1 sprint)
var _air: float = 0.0              ## free arm out for balance while airborne
var _prev_state: int = -1
var _shoulder_l: int
var _shoulder_r: int
var _shoulder_l_local: Vector3 = Vector3(-0.2, 1.4, 0.0)  ## posed shoulders, body space
var _shoulder_r_local: Vector3 = Vector3(0.2, 1.4, 0.0)
var _slide_w: float = 0.0          ## slide: caps how far the pelvis may lift (feet stay down)
## Inertialized hand targets: the hand follows its target exactly, plus an
## offset (camera space) captured when the target switches, which decays away.
## Smoothing the target itself would make hands trail behind a moving body.
var _off_r: Transform3D = Transform3D.IDENTITY
var _off_l: Transform3D = Transform3D.IDENTITY
var _drawn_r: Transform3D = Transform3D.IDENTITY  ## last drawn target, camera space
var _drawn_l: Transform3D = Transform3D.IDENTITY
var _key_r: int = -1               ## which target source each hand is on
var _key_l: int = -1


func setup(p_player: Player, p_rig: CameraRig, p_viewmodel: Viewmodel) -> void:
	player = p_player
	rig = p_rig
	viewmodel = p_viewmodel
	name = "FPBody%d" % (player.player_index + 1)
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_model = MODEL.instantiate()
	add_child(_model)
	_model.rotation.y = PI
	skeleton = _model.find_child("Skeleton3D") as Skeleton3D
	anim = AnimationPlayer.new()
	_model.add_child(anim)
	anim.root_node = anim.get_path_to(_model)
	anim.add_animation_library(&"", RunnerAvatar.base_library())
	anim.add_animation_library(&"x", RunnerAvatar.extra_library())
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE

	# Arms share the gun's shader (own FOV + anti-clip depth); the legs use the
	# true projection so they land on the real floor.
	var shader := preload("res://shaders/viewmodel.gdshader")
	for part in ["FP_Arms", "FP_Body"]:
		var mi := _model.find_child(part) as MeshInstance3D
		var fov_weight := 1.0 if part == "FP_Arms" else 0.0
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			var joint := src != null and src.resource_name == "M_Joints"
			var m := _vm_mat(shader, Color(0.13, 0.14, 0.15) if joint else Color(0.035, 0.038, 0.042), 0.35 if joint else 0.58, 0.7 if joint else 0.15)
			m.set_shader_parameter(&"fp_fov_weight", fov_weight)
			m.set_shader_parameter(&"fp_fov_deg", FP_FOV)
			mi.set_surface_override_material(s, m)
		mi.layers = rig.viewmodel_layer_bit()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # the 3rd-person body casts your shadow
		mi.extra_cull_margin = 1.5  # IK can stretch limbs beyond the rest-pose bounds

	_target_r = _marker("TargetR")
	_target_l = _marker("TargetL")
	_pole_r = _marker("PoleR")
	_pole_l = _marker("PoleL")

	# Modifier order = child order: pose (head/spine/fingers) -> IK R -> IK L -> hand rotation.
	_pose = FPPoseModifier.new()
	skeleton.add_child(_pose)
	_pose.setup(skeleton, RunnerAvatar.base_library().get_animation(&"Pistol_Aim_Neutral"))
	_pose.body = self
	_ik_r = _arm_ik("upperarm_r", "lowerarm_r", "hand_r", _target_r, _pole_r)
	_ik_l = _arm_ik("upperarm_l", "lowerarm_l", "hand_l", _target_l, _pole_l)
	_hand_rot = CopyTransformModifier3D.new()
	skeleton.add_child(_hand_rot)
	_hand_rot.set_setting_count(2)
	for i in 2:
		_hand_rot.set_apply_bone_name(i, "hand_r" if i == 0 else "hand_l")
		_hand_rot.set_reference_type(i, BoneConstraint3D.REFERENCE_TYPE_NODE)
		_hand_rot.set_reference_node(i, _hand_rot.get_path_to(_target_r if i == 0 else _target_l))
		_hand_rot.set_copy_position(i, false)
		_hand_rot.set_copy_rotation(i, true)
		_hand_rot.set_copy_scale(i, false)
		_hand_rot.set_relative(i, false)
	_shoulder_r = skeleton.find_bone("upperarm_r")
	_shoulder_l = skeleton.find_bone("upperarm_l")
	skeleton.skeleton_updated.connect(_on_skeleton_updated)
	player.motor.landed.connect(func(impact: float) -> void:
		if impact > 7.0:
			_land_time = 0.22)


func _marker(n: String) -> Marker3D:
	var m := Marker3D.new()
	m.name = n
	m.top_level = true
	add_child(m)
	return m


func _arm_ik(root: String, mid: String, end: String, target: Node3D, pole: Node3D) -> TwoBoneIK3D:
	var ik := TwoBoneIK3D.new()
	skeleton.add_child(ik)
	ik.set_setting_count(1)
	ik.set_root_bone_name(0, root)
	ik.set_middle_bone_name(0, mid)
	ik.set_end_bone_name(0, end)
	ik.set_target_node(0, ik.get_path_to(target))
	ik.set_pole_node(0, ik.get_path_to(pole))
	ik.set_pole_direction(0, SkeletonModifier3D.SECONDARY_DIRECTION_MINUS_Z)
	return ik


static func _vm_mat(shader: Shader, color: Color, rough: float, metal: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter(&"albedo", color)
	m.set_shader_parameter(&"roughness", rough)
	m.set_shader_parameter(&"metallic", metal)
	return m


## Called by the camera rig every frame after it has placed the camera.
func sync(delta: float) -> void:
	visible = active
	anim.active = active
	for m in [_pose, _ik_r, _ik_l, _hand_rot]:
		(m as SkeletonModifier3D).active = active
	if not active:
		return
	var motor := player.motor
	var cam := rig.camera.global_transform
	var yaw_basis := Basis(Vector3.UP, player.yaw)
	var forward := yaw_basis * Vector3.FORWARD
	var right := yaw_basis * Vector3.RIGHT

	# Hang the body from the eyes by its animated neck, so the shoulders sit in
	# the same place under the camera whatever the clip does (crouch, slide,
	# sprint lean). The eye pivots around the neck with the view pitch.
	var down := clampf(-player.pitch / deg_to_rad(60.0), 0.0, 1.0)
	var eye := Basis(Vector3.RIGHT, player.pitch) * NECK_TO_EYE
	var neck_world := cam.origin - yaw_basis * (eye - Vector3.BACK * BACK_DOWN * down)
	global_transform = Transform3D(yaw_basis, neck_world - yaw_basis * NECK_BODY)
	_pose.neck_target = (skeleton.global_transform.affine_inverse() * global_transform) * NECK_BODY
	# In a slide the clip lies back (its neck sits low); lifting the pelvis all
	# the way would float the legs, so cap the lift to keep the feet down.
	_slide_w = lerpf(_slide_w, 1.0 if motor.state == PlayerMotor.State.SLIDE else 0.0, 1.0 - exp(-12.0 * delta))
	var feet_y := player.get_global_transform_interpolated().origin.y
	_pose.max_lift = feet_y + FLOAT_MAX - global_position.y
	_pose.lift_cap_weight = _slide_w
	_pose.pitch = player.pitch

	# Legs: same clip logic as the third-person body.
	_land_time = maxf(0.0, _land_time - delta)
	var pick := RunnerAvatar.pick_clip(player, _land_time > 0.0)
	if pick[0] != _current_clip:
		anim.play(pick[0], RunnerAvatar.BLEND)
		_current_clip = pick[0]
	anim.speed_scale = pick[1]

	# --- hand targets ---------------------------------------------------------
	var gun := viewmodel.global_transform
	var grip_r := Transform3D(gun.basis * GRIP_R_BASIS, viewmodel.grip_r.global_position + gun.basis * WRIST_R)
	var grip_l := Transform3D(gun.basis * GRIP_L_BASIS, viewmodel.grip_l.global_position + gun.basis * WRIST_L)
	var want_r := grip_r
	var free_l := _free_left(global_transform * _shoulder_l_local, forward, right, delta)  # what the left hand does when it's not on the gun
	var left_open := 0.5 * _air
	var state := motor.state
	var key_r := state
	var key_l := state
	var hunch := 0.0
	var shoulder_l := global_transform * _shoulder_l_local
	var shoulder_r := global_transform * _shoulder_r_local
	var hands_busy := false  ## both hands needed (ledge, climb): the gun can't take the support hand

	# World contacts are pre-warped so, drawn at the arms' FOV, they land on the
	# real point, and held within reach (a ledge far below is pushed toward,
	# not stretched to).
	match state:
		PlayerMotor.State.MANTLE:  # hands slap onto the lip and push down as the body rises
			var t := motor.mantle_progress()
			var along := motor.ledge_dir.cross(Vector3.UP).normalized()  # points to the player's right
			var plant_w := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.7, 0.95, t))
			var ledge_l := _reach(_prewarp(_palm_down(motor.ledge_point - along * 0.2 + Vector3.UP * 0.03, motor.ledge_dir, false), cam), shoulder_l)
			free_l = _blend(grip_l, ledge_l, plant_w)
			left_open = plant_w
			hunch = MANTLE_HUNCH * plant_w
			hands_busy = true
			if not motor.mantle_is_vault:
				var ledge_r := _reach(_prewarp(_palm_down(motor.ledge_point + along * 0.2 + Vector3.UP * 0.03, motor.ledge_dir, true), cam), shoulder_r)
				want_r = _blend(grip_r, ledge_r, plant_w)
		PlayerMotor.State.WALLRUN:
			if motor.wall_side < 0:  # wall on the left: the free hand glides along it, fingertips dragging
				var p := motor.wall_point + motor.wall_normal * 0.03
				p += forward * ((shoulder_l - p).dot(forward) + 0.45)  # abreast of the shoulder, then ahead
				p.y = shoulder_l.y + 0.1 + 0.025 * sin(motor.state_time * 9.0)
				free_l = _reach(_prewarp(_palm_to(p, -motor.wall_normal, (Vector3.UP * 0.6 + forward * 0.4).normalized(), false), cam), shoulder_l)
				left_open = 1.0
		PlayerMotor.State.SLIDE:  # balance arm out front-left, gun held out one-handed
			var p := shoulder_l + forward * 0.45 - right * 0.15 + Vector3.UP * 0.02
			free_l = _palm_to(p, (Vector3.DOWN + right * 0.3).normalized(), (forward - right * 0.3).normalized(), false)
			left_open = 1.0
		PlayerMotor.State.WALLCLIMB:  # hand over hand up the wall
			var reach := 0.35 + 0.25 * sin(motor.state_time * 18.0)
			var reach_r := 0.35 + 0.25 * sin(motor.state_time * 18.0 + PI)
			var base := motor.wall_point + motor.wall_normal * 0.04
			var side := motor.wall_normal.cross(Vector3.UP).normalized()
			free_l = _reach(_prewarp(_palm_to(base + Vector3.UP * reach + side * 0.18, -motor.wall_normal, Vector3.UP, false), cam), shoulder_l)
			want_r = _reach(_prewarp(_palm_to(base + Vector3.UP * reach_r - side * 0.18, -motor.wall_normal, Vector3.UP, true), cam), shoulder_r)
			left_open = 1.0
			hands_busy = true

	# Grapple: the free hand holds the launcher while it's up (it takes the
	# hand off the rifle's handguard too).
	var gg := rig.grapple_gun
	var gun_hold := 0.0
	if gg and gg.raise > 0.0 and gg.grip and not hands_busy:
		gun_hold = gg.raise * gg.raise * (3.0 - 2.0 * gg.raise)
		var g := gg.global_transform
		var hold := Transform3D(g.basis * GRAPPLE_GRIP_BASIS, gg.grip.global_position + g.basis * WRIST_GRAPPLE)
		free_l = _blend(free_l, hold, gun_hold)
		left_open *= 1.0 - gun_hold

	# Support hand: onto the handguard for aiming (or always, rifle carry).
	var sup := 0.0 if hands_busy else viewmodel.support * (1.0 - gun_hold)
	sup = sup * sup * (3.0 - 2.0 * sup)
	var want_l := _blend(free_l, grip_l, sup)
	left_open *= 1.0 - sup
	# Keep a hint of bend: a two-bone IK at full stretch flips the elbow on
	# tiny target moves (visible shaking).
	want_r = _reach(want_r, shoulder_r)
	want_l = _reach(want_l, shoulder_l)
	_pose.left_grip = move_toward(_pose.left_grip, 1.0 - left_open, delta * 10.0)
	_pose.support = sup
	_pose.extra_hunch = move_toward(_pose.extra_hunch, hunch, delta * 6.0)

	var cam_inv := cam.affine_inverse()
	var decay := exp(-TARGET_RATE * (1.8 if state == PlayerMotor.State.MANTLE else 1.0) * delta)  # mantles are short: slap on fast
	var local_r := cam_inv * want_r
	var local_l := cam_inv * want_l
	if key_r != _key_r:
		_off_r = _capture(_drawn_r, local_r, _key_r < 0)
		_key_r = key_r
	if key_l != _key_l:
		_off_l = _capture(_drawn_l, local_l, _key_l < 0)
		_key_l = key_l
	_off_r = _decay(_off_r, decay)
	_off_l = _decay(_off_l, decay)
	_drawn_r = Transform3D(_off_r.basis * local_r.basis, local_r.origin + _off_r.origin)
	_drawn_l = Transform3D(_off_l.basis * local_l.basis, local_l.origin + _off_l.origin)
	_target_r.global_transform = cam * _drawn_r
	_target_l.global_transform = cam * _drawn_l

	# Elbows point down and out.
	_pole_r.global_position = shoulder_r + right * 0.35 - Vector3.UP * 0.5 + forward * -0.25
	_pole_l.global_position = shoulder_l - right * 0.35 - Vector3.UP * 0.5 + forward * -0.25


func _on_skeleton_updated() -> void:
	if active:
		var to_body := global_transform.affine_inverse() * skeleton.global_transform
		_shoulder_l_local = to_body * skeleton.get_bone_global_pose(_shoulder_l).origin
		_shoulder_r_local = to_body * skeleton.get_bone_global_pose(_shoulder_r).origin


## Offset (camera space) from a newly chosen target back to where the hand was
## drawn, so switching targets eases over instead of snapping.
static func _capture(drawn: Transform3D, want: Transform3D, first: bool) -> Transform3D:
	if first:
		return Transform3D.IDENTITY
	return Transform3D(drawn.basis.orthonormalized() * want.basis.orthonormalized().inverse(), drawn.origin - want.origin)


static func _decay(off: Transform3D, k: float) -> Transform3D:
	var q := off.basis.get_rotation_quaternion()
	return Transform3D(Basis(Quaternion.IDENTITY.slerp(q, k)), off.origin * k)


## Moves a world target so that, rendered with the arms' narrower FOV, the hand
## appears exactly where the world point is (screen offsets shrink by k).
func _prewarp(t: Transform3D, cam: Transform3D) -> Transform3D:
	var k := tan(deg_to_rad(rig.camera.fov) * 0.5) / tan(deg_to_rad(FP_FOV) * 0.5)
	var local := cam.affine_inverse() * t.origin
	local.x /= k
	local.y /= k
	return Transform3D(t.basis, cam * local)


## The free left arm: swings with the stride opposite the gun arm (same clock
## as the head bob and the gun's pump), rising into view at a sprint, a loose
## fist; out and up for balance in the air. Body space, so looking down shows it.
func _free_left(shoulder: Vector3, forward: Vector3, right: Vector3, delta: float) -> Transform3D:
	var motor := player.motor
	var running := motor.state == PlayerMotor.State.GROUND or motor.state == PlayerMotor.State.WALLRUN
	var a := 0.0
	if running:
		a = clampf((player.horizontal_speed() - 1.0) / maxf(player.tuning.sprint_speed - 1.0, 0.1), 0.0, 1.0)
	_pump = lerpf(_pump, a, 1.0 - exp(-6.0 * delta))
	var airborne := motor.state == PlayerMotor.State.AIR or motor.state == PlayerMotor.State.GRAPPLE
	_air = lerpf(_air, 1.0 if airborne else 0.0, 1.0 - exp(-8.0 * delta))
	var t := 0.5 - 0.5 * sin(rig.stride_phase)  # 1 = left arm fully forward (the gun arm is back)
	# Sprinters bring the hand up to chin height on the forward swing, which
	# is where it enters the bottom of the view.
	var fwd := lerpf(0.1, lerpf(-0.08, 0.4, t), _pump)
	var up := lerpf(-0.44, lerpf(-0.46, 0.04, pow(t, 1.5)), _pump)
	var inward := lerpf(0.04, lerpf(0.02, 0.03, t), _pump)
	fwd = lerpf(fwd, 0.22, _air)
	up = lerpf(up, -0.26, _air)
	inward = lerpf(inward, -0.12, _air)
	var p := shoulder + forward * fwd + Vector3.UP * up + right * inward
	var fingers := (forward + Vector3.UP * lerpf(-0.3, 0.45, t * _pump)).normalized()  # knuckles lead
	return _palm_to(p, right, fingers, false)  # palm faces the body's midline


static func _reach(t: Transform3D, shoulder: Vector3) -> Transform3D:
	var d := t.origin - shoulder
	return Transform3D(t.basis, shoulder + d.limit_length(ARM_REACH))


## Wrist transform for a palm-down plant with fingers pointing along `fwd`.
static func _palm_down(point: Vector3, fwd: Vector3, is_right: bool) -> Transform3D:
	var f := Vector3(fwd.x, 0, fwd.z).normalized()
	return _palm_to(point - f * 0.07 + Vector3.UP * 0.03, Vector3.DOWN, f, is_right)


## Wrist transform with the palm facing `palm_dir` and fingers toward `fingers`.
static func _palm_to(wrist: Vector3, palm_dir: Vector3, fingers: Vector3, is_right: bool) -> Transform3D:
	var y := (fingers - palm_dir * fingers.dot(palm_dir)).normalized()
	var x := -palm_dir if is_right else palm_dir  # right palm faces -X, left palm faces +X
	x = (x - y * x.dot(y)).normalized()
	return Transform3D(Basis(x, y, x.cross(y)), wrist)


static func _blend(a: Transform3D, b: Transform3D, w: float) -> Transform3D:
	if w <= 0.0:
		return a
	if w >= 1.0:
		return b
	return a.interpolate_with(b, w)
