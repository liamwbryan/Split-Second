extends "res://tests/movement_tests.gd"
## Dev tool: renders the first-person view at key traversal moments so arm and
## weapon animation can be checked without playing.
##   godot --path . res://tests/fp_shots.tscn -- --out=/some/dir [--only=name]
## With --headless it only prints the arm diagnostics (no window, no images).

var out_dir := "/tmp/fp_shots"
var vp: SubViewport
var jitter := false  ## --jitter: measure arm smoothness while sprinting instead of taking shots
var _jit_prev: Dictionary = {}
var _jit_prev2: Dictionary = {}
var _jit_max: Dictionary = {}
var _jit_sum: Dictionary = {}
var _jit_n: int = 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg.begins_with("--only="):
			only = arg.substr(7)
	DirAccess.make_dir_recursive_absolute(out_dir)
	jitter = OS.get_cmdline_user_args().has("--jitter")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.7, 0.82)
	env.ambient_light_color = Color(0.7, 0.72, 0.75)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-30), 0)
	sun.shadow_enabled = true
	add_child(sun)
	b = LevelBuilder.new(self)
	_build_course()
	b.finalize()
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	# Show what's being captured (otherwise the window is an empty gray screen).
	var layer := CanvasLayer.new()
	add_child(layer)
	var view := TextureRect.new()
	view.texture = vp.get_texture()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.add_child(view)
	router = InputRouter.new(PlayerSettings.new())
	router.scripted = true
	router.use_kbm = false
	player = Player.new()
	add_child(player)
	player.setup(0, router, MovementTuning.new(), vp)
	player.motor.state_changed.connect(func(_f: int, to: int) -> void: states_seen.append(to))
	if jitter:
		await _measure_jitter()
	else:
		await _capture_all()
	get_tree().quit()


func shot(name: String) -> void:
	if only != "" and not name.begins_with(only):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":  # headless: diagnostics only
		vp.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("SHOT ", name, " state=", player.motor.state_name())
	await _diag()


## Camera-space positions of the arm chain vs. its IK targets (reach error in cm).
## Modifier results only exist during skeleton_updated, so read them there.
func _diag() -> void:
	var sk := player.camera_rig.fp_body.skeleton
	sk.skeleton_updated.connect(_print_arms, CONNECT_ONE_SHOT)
	await get_tree().process_frame
	await get_tree().process_frame


func _print_arms() -> void:
	var body := player.camera_rig.fp_body
	var sk := body.skeleton
	var cam_inv := player.camera_rig.camera.global_transform.affine_inverse()
	for side in ["r", "l"]:
		var sh := cam_inv * (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("upperarm_" + side)).origin)
		var hand := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand_" + side)).origin
		var target := (body.get_node("Target" + side.to_upper()) as Node3D).global_position
		var hb := (sk.global_transform.basis * sk.get_bone_global_pose(sk.find_bone("hand_" + side)).basis).orthonormalized()
		var tb := (body.get_node("Target" + side.to_upper()) as Node3D).global_basis.orthonormalized()
		var cb := player.camera_rig.camera.global_basis.inverse()
		print("    hand axes cam-space X=%s Y=%s Z=%s | target X=%s Y=%s Z=%s" % [_v(cb * hb.x), _v(cb * hb.y), _v(cb * hb.z), _v(cb * tb.x), _v(cb * tb.y), _v(cb * tb.z)])
		var reach := (cam_inv * target).distance_to(sh) / (0.547 * FPPoseModifier.ARM_STRETCH)  # arm length
		print("  %s shoulder=%s hand=%s target=%s err=%.1fcm reach=%d%%" % [side, _v(sh), _v(cam_inv * hand), _v(cam_inv * target), hand.distance_to(target) * 100.0, reach * 100.0])
	print("  root=%s pelvis=%s" % [_v(cam_inv * body.global_position), _v(cam_inv * (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("pelvis")).origin))])


static func _v(v: Vector3) -> String:
	return "(%.2f %.2f %.2f)" % [v.x, v.y, v.z]


func wait_state(state: int, extra: float, timeout: float = 3.0) -> bool:
	var t := 0.0
	while player.motor.state != state and t < timeout:
		await get_tree().physics_frame
		t += 1.0 / 120.0
	if player.motor.state != state:
		return false
	await seconds(extra)
	return true


func _capture_all() -> void:
	await reset(Vector3(0, 0, 20))
	await seconds(0.3)
	await shot("01_idle")
	hold(A.ADS)
	await seconds(0.3)
	await shot("01b_ads")
	hold(A.ADS, false)
	await seconds(0.3)
	player.pitch = deg_to_rad(-60)
	await seconds(0.2)
	await shot("02_look_down")
	player.pitch = deg_to_rad(-82)
	await seconds(0.2)
	await shot("02b_look_feet")
	player.pitch = 0.0

	await reset(Vector3(20, 0, 0))
	router.scripted_move = Vector2(0, 1)
	await seconds(0.7)
	await shot("03_sprint")
	# The free arm peaks when sin(stride) = -1: wait for it.
	var t := 0.0
	while sin(player.camera_rig.stride_phase) > -0.97 and t < 1.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await shot("03b_sprint_pump")
	hold(A.CROUCH)
	await seconds(0.25)
	await shot("04_slide")
	player.pitch = deg_to_rad(-35)
	await seconds(0.05)
	await shot("05_slide_look_down")
	player.pitch = 0.0
	hold(A.CROUCH, false)

	await reset(Vector3(400, 0, 0))
	router.scripted_move = Vector2(0, 1)
	if await wait_state(S.MANTLE, 0.08):
		await shot("06_vault")

	await reset(Vector3(300, 0, 0))
	router.scripted_move = Vector2(0, 1)
	await ticks(10)
	await tap(A.JUMP)
	if await wait_state(S.MANTLE, 0.0):
		await shot("07a_mantle")  # shots are ~4 frames apart: the plant, the push, the top-out
		await shot("07b_mantle")
		await shot("07c_mantle")

	await reset(Vector3(200, 0, 0))
	router.scripted_move = Vector2(0, 1)
	await seconds(0.12)
	await tap(A.JUMP)
	if await wait_state(S.WALLCLIMB, 0.1):
		await shot("08_climb")

	await reset(Vector3(1198.3, 0, -1))
	router.scripted_move = Vector2(-0.3, 1)
	await seconds(0.25)
	await tap(A.JUMP)
	router.scripted_move = Vector2(0, 1)
	if await wait_state(S.WALLRUN, 0.35):
		await shot("09_wallrun_left")

	await reset(Vector3(600, 0, 0))
	player.pitch = atan2(10.0 - player.tuning.eye_height, 20.0)
	hold(A.GRAPPLE)
	await seconds(0.3)
	await shot("10_grapple")
	hold(A.GRAPPLE, false)

	# Swing: hanging under a high anchor, looking ahead (the cable runs up out
	# of view), then glancing up the cable.
	await _start_swing()
	player.pitch = deg_to_rad(-8.0)
	await seconds(0.45)
	await shot("10b_swing")
	player.pitch = deg_to_rad(35.0)
	await seconds(0.12)
	await shot("10c_swing_look_up")
	hold(A.GRAPPLE, false)
	await seconds(0.08)
	await shot("10d_release")
	# Third person (what other players see): the cable from the bracer, the claw.
	if only == "" or "10e".begins_with(only) or only.begins_with("10e"):
		await _start_swing()
		player.camera_rig.third_person = true
		player.pitch = deg_to_rad(20.0)
		await seconds(0.4)
		await shot("10e_swing_third")
		player.camera_rig.third_person = false
		hold(A.GRAPPLE, false)

	# Grip close-ups: arms tinted light so the fingers read against the dark gun,
	# seen from the right and from the front-left by a side camera.
	await reset(Vector3(0, 0, 20))
	await seconds(0.3)
	var arms := player.camera_rig.fp_body.find_child("FP_Arms", true, false) as MeshInstance3D
	for i in arms.get_surface_override_material_count():
		(arms.get_surface_override_material(i) as ShaderMaterial).set_shader_parameter(&"albedo", Color(0.85, 0.62, 0.5))
	var eye := player.camera_rig.camera
	var side := Camera3D.new()
	side.cull_mask = eye.cull_mask
	side.fov = 40.0
	vp.add_child(side)
	for view: Array in [["11_grip_right", Vector3(0.55, 0.05, 0.05)], ["12_grip_front_left", Vector3(-0.35, 0.1, -0.5)]]:
		var gun := player.camera_rig.fp_body.viewmodel.global_position
		side.global_position = gun + eye.global_basis * (view[1] as Vector3)
		side.look_at(gun, Vector3.UP)
		side.make_current()
		await shot(view[0])
	eye.make_current()


## Frame-to-frame jerk (second difference, camera space) of hands and elbows
## over 1.5 s of sprinting and 1 s of standing. Smooth motion stays ~1-2 mm;
## IK pops and update-order lag show up as spikes.
func _measure_jitter() -> void:
	await reset(Vector3(20, 0, 0))
	router.scripted_move = Vector2(0, 1)
	await seconds(0.8)
	var sk := player.camera_rig.fp_body.skeleton
	sk.skeleton_updated.connect(_sample_jitter)
	await seconds(1.5)
	sk.skeleton_updated.disconnect(_sample_jitter)
	for k: String in _jit_max:
		print("JITTER sprint %-10s max %.1f mm  mean %.2f mm" % [k, _jit_max[k] * 1000.0, _jit_sum[k] / _jit_n * 1000.0])


func _sample_jitter() -> void:
	var sk := player.camera_rig.fp_body.skeleton
	var cam_inv := player.camera_rig.camera.global_transform.affine_inverse()
	_jit_n += 1
	var body := player.camera_rig.fp_body
	for bone in ["hand_r", "hand_l", "lowerarm_r", "lowerarm_l", "TargetR", "upperarm_r", "gun", "root", "neck_01", "pelvis", "spine_03"]:
		var world: Vector3
		if bone == "root":
			world = body.global_position
		elif bone == "TargetR":
			world = (body.get_node("TargetR") as Node3D).global_position
		elif bone == "gun":
			world = body.viewmodel.grip_r.global_position
		else:
			world = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin
		var p := cam_inv * world
		if _jit_prev2.has(bone):
			var j: float = (p - 2.0 * (_jit_prev[bone] as Vector3) + (_jit_prev2[bone] as Vector3)).length()
			_jit_max[bone] = maxf(_jit_max.get(bone, 0.0), j)
			_jit_sum[bone] = _jit_sum.get(bone, 0.0) + j
		if _jit_prev.has(bone):
			_jit_prev2[bone] = _jit_prev[bone]
		_jit_prev[bone] = p
