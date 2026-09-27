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
const EYE_HEIGHT := 1.65          ## model eye height above its feet
const BACK_LEVEL := 0.04          ## body offset behind the camera looking level
const BACK_DOWN := 0.26           ## ...and looking straight down (shows the legs)
const TARGET_RATE := 32.0         ## hand target smoothing (1/s)
const PLANT_REACH := 0.08         ## hands land within this many seconds

## Hand orientations relative to the gun (columns = hand bone X, Y, Z).
## Bone axes on this rig: +Y along the fingers, +Z toward the thumb; the palm
## faces -X on the right hand and +X on the left (measured from the rest pose).
const GRIP_R_BASIS := Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1))
const GRIP_L_BASIS := Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))
## Wrist offsets from the grip sockets, in gun space.
const WRIST_R := Vector3(0.03, 0.065, 0.02)
const WRIST_L := Vector3(-0.055, -0.03, 0.02)

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
var _left_ik: float = 1.0
var _plant_l: Transform3D          ## world-locked plant for the left hand
var _plant_r: Transform3D
var _plant_age: float = 99.0
var _prev_state: int = -1
var _shoulder_l: int
var _shoulder_r: int


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

	# Place the body under the eyes, pushed back as you look down so the legs show.
	var down := clampf(-player.pitch / deg_to_rad(60.0), 0.0, 1.0)
	var back := lerpf(BACK_LEVEL, BACK_DOWN, down)
	global_transform = Transform3D(yaw_basis, cam.origin - Vector3.UP * EYE_HEIGHT - forward * back)
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
	var want_l := grip_l
	var left_ik := 1.0
	var left_open := 0.0
	var state := motor.state
	if state != _prev_state:
		_plant_age = 99.0
		_prev_state = state
	_plant_age += delta
	var shoulder_l := skeleton.global_transform * skeleton.get_bone_global_pose(_shoulder_l).origin

	match state:
		PlayerMotor.State.MANTLE:
			var t := motor.mantle_progress()
			var along := motor.ledge_dir.cross(Vector3.UP).normalized()  # points to the player's right
			var plant_w := smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.75, 1.0, t))
			var ledge_l := _palm_down(motor.ledge_point - along * 0.2 + Vector3.UP * 0.03, motor.ledge_dir, false)
			want_l = _blend(grip_l, ledge_l, plant_w)
			left_open = plant_w
			if not motor.mantle_is_vault:
				var ledge_r := _palm_down(motor.ledge_point + along * 0.2 + Vector3.UP * 0.03, motor.ledge_dir, true)
				want_r = _blend(grip_r, ledge_r, plant_w)
		PlayerMotor.State.WALLRUN:
			if motor.wall_side < 0:  # wall on the left: the free hand brushes the wall
				if _plant_age > 0.3 or (_plant_l.origin - shoulder_l).dot(forward) < -0.1:
					var p := motor.wall_point + motor.wall_normal * 0.03 + forward * 0.45
					p.y = shoulder_l.y + 0.05
					_plant_l = _palm_to(p, -motor.wall_normal, (Vector3.UP * 0.6 + forward * 0.4).normalized(), false)
					_plant_age = 0.0
				want_l = _plant_l
				left_open = 1.0
		PlayerMotor.State.SLIDE:  # hand trails along the floor, gun held out
			var floor_y := player.global_position.y + 0.04
			var p := shoulder_l - right * 0.15 + forward * 0.25
			p.y = maxf(floor_y, shoulder_l.y - 0.55)
			want_l = _palm_down(p, forward, false)
			left_open = 1.0
		PlayerMotor.State.GRAPPLE:  # bracer arm aimed at the anchor, low-left in frame
			var dir := (motor.grapple_point - shoulder_l).normalized()
			var p := shoulder_l + dir * 0.42 - Vector3.UP * 0.1 - right * 0.08
			want_l = _palm_to(p, Vector3.DOWN, dir, false)  # palm down, fingers toward the anchor
			left_open = 0.3
		PlayerMotor.State.WALLCLIMB:  # hand over hand up the wall
			var reach := 0.35 + 0.25 * sin(motor.state_time * 18.0)
			var reach_r := 0.35 + 0.25 * sin(motor.state_time * 18.0 + PI)
			var base := motor.wall_point + motor.wall_normal * 0.04
			var side := motor.wall_normal.cross(Vector3.UP).normalized()
			want_l = _palm_to(base + Vector3.UP * reach + side * 0.18, -motor.wall_normal, Vector3.UP, false)
			want_r = _palm_to(base + Vector3.UP * reach_r - side * 0.18, -motor.wall_normal, Vector3.UP, true)
			left_open = 1.0
		PlayerMotor.State.GROUND:
			if player.horizontal_speed() > player.tuning.walk_speed + 0.5 and viewmodel.ads_amount < 0.1:
				left_ik = 0.0  # sprint: let the clip pump the free arm
	_left_ik = move_toward(_left_ik, left_ik, delta / (0.07 if left_ik > _left_ik else 0.14))
	_ik_l.influence = _left_ik
	_hand_rot.set_amount(1, _left_ik)
	_pose.left_grip = 1.0 - left_open

	# World contacts are pre-warped so, drawn at the arms' FOV, they land on the real point.
	if state in [PlayerMotor.State.MANTLE, PlayerMotor.State.WALLRUN, PlayerMotor.State.SLIDE, PlayerMotor.State.WALLCLIMB, PlayerMotor.State.GRAPPLE]:
		want_l = _prewarp(want_l, cam)
		if state == PlayerMotor.State.MANTLE or state == PlayerMotor.State.WALLCLIMB:
			want_r = _prewarp(want_r, cam)
	var rate := 1.0 - exp(-TARGET_RATE * delta)
	_target_r.global_transform = _blend(_target_r.global_transform, want_r, rate)
	_target_l.global_transform = _blend(_target_l.global_transform, want_l, rate)

	# Elbows point down and out.
	var sr := skeleton.global_transform * skeleton.get_bone_global_pose(_shoulder_r).origin
	_pole_r.global_position = sr + right * 0.35 - Vector3.UP * 0.5 + forward * -0.25
	_pole_l.global_position = shoulder_l - right * 0.35 - Vector3.UP * 0.5 + forward * -0.25


## Moves a world target so that, rendered with the arms' narrower FOV, the hand
## appears exactly where the world point is (screen offsets shrink by k).
func _prewarp(t: Transform3D, cam: Transform3D) -> Transform3D:
	var k := tan(deg_to_rad(rig.camera.fov) * 0.5) / tan(deg_to_rad(FP_FOV) * 0.5)
	var local := cam.affine_inverse() * t.origin
	local.x /= k
	local.y /= k
	return Transform3D(t.basis, cam * local)


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
