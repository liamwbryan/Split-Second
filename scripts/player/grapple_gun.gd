class_name GrappleGun
extends Node3D
## Owner-only first-person grapple launcher, a small handgun held in the free
## (left) hand. It snaps up and fires when you grapple, points along the cable,
## sways with look, stride and swing (lags behind accelerations, leans into the
## swing), and drops out of view after the cable has reeled back in.
## Drawn with the gun's shader (its own FOV, anti-clip depth), like Viewmodel.
## Updated by the camera rig (update()) right before the first-person arms.

const MODEL := preload("res://assets/models/grapple_gun.glb")  # art/blender/grapple_gun.py
## Grip position in camera space: raised and aiming / down by the hip (out of view).
const RAISED_POS := Vector3(-0.2, -0.14, -0.36)
const LOWERED_POS := Vector3(-0.26, -0.46, -0.16)
const MODEL_SCALE := 0.85
const MAX_AIM := deg_to_rad(40.0)  ## how far it turns toward the cable before the wrist gives up
const RAISE_TIME := 0.07
const LOWER_TIME := 0.22
const LINGER := 0.2                ## stays up while the cable reels back in
const TWITCH_TIME := 0.28          ## dry fire (miss / cooldown): a quick raise and click

var player: Player
var rig: CameraRig
var grip: Node3D
var muzzle: Node3D
## 0 lowered (hidden) .. 1 raised and aiming. FPBody puts the left hand on the grip by this much.
var raise: float = 0.0
## The real hook is out (flying, attached, reeling in): hide the one in the muzzle.
var hook_out: bool = false:
	set(value):
		hook_out = value
		if _hook:
			_hook.visible = not value

var _hook: Node3D
var _linger: float = 0.0
var _twitch: float = 0.0
var _kick: float = 0.0
var _kick_vel: float = 0.0
var _sway: Vector2 = Vector2.ZERO
var _last_yaw: float = 0.0
var _last_pitch: float = 0.0
var _last_vel: Vector3 = Vector3.ZERO
var _lag: Vector3 = Vector3.ZERO    ## camera-space inertia offset
var _lean: float = 0.0
var _aim: Basis = Basis.IDENTITY


func setup(p_player: Player, p_rig: CameraRig) -> void:
	player = p_player
	rig = p_rig
	name = "GrappleGun"
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	position = LOWERED_POS
	visible = false
	set_process(false)  # the camera rig calls update() in order
	_build_model()
	var m := player.motor
	m.grapple_attached.connect(func(_p: Vector3) -> void:
		_kick_vel += 4.0)
	m.grapple_released.connect(func() -> void:
		_linger = LINGER)
	m.grapple_missed.connect(func() -> void:
		_twitch = TWITCH_TIME
		_kick_vel += 1.5)


func update(delta: float) -> void:
	var motor := player.motor
	var grappling := motor.state == PlayerMotor.State.GRAPPLE
	_linger = maxf(0.0, _linger - delta)
	_twitch = maxf(0.0, _twitch - delta)
	var up := grappling or _linger > 0.0 or _twitch > 0.0
	raise = move_toward(raise, 1.0 if up else 0.0, delta / (RAISE_TIME if up else LOWER_TIME))
	visible = raise > 0.001 and not rig.third_person
	if not visible:
		_last_yaw = player.yaw
		_last_pitch = player.pitch
		_last_vel = player.velocity
		return
	var cam := rig.camera.global_transform

	# Look sway: the launcher lags behind turns.
	var dyaw := wrapf(player.yaw - _last_yaw, -PI, PI)
	var dpitch := player.pitch - _last_pitch
	_last_yaw = player.yaw
	_last_pitch = player.pitch
	_sway += Vector2(dyaw, dpitch) * 0.7
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-10.0 * delta))
	_sway = _sway.limit_length(0.1)

	# Body sway: it trails your accelerations (swing pulls, pumps, the rope
	# catching) and leans into sideways motion, so a swing reads in the hand.
	var cam_inv := cam.basis.inverse()
	var accel := (player.velocity - _last_vel) / maxf(delta, 0.0001)
	_last_vel = player.velocity
	var lag_target := (cam_inv * accel) * -0.0016
	_lag = _lag.lerp(lag_target.limit_length(0.05), 1.0 - exp(-9.0 * delta))
	var side_speed := (cam_inv * player.velocity).x
	_lean = lerpf(_lean, clampf(-side_speed * 0.018, -0.35, 0.35), 1.0 - exp(-5.0 * delta))

	# Stride: shares the head bob / arm clock while lowering on the ground.
	var bob := Vector3.ZERO
	if motor.state == PlayerMotor.State.GROUND:
		var s := clampf(player.horizontal_speed() / player.tuning.sprint_speed, 0.0, 1.2)
		var ph := rig.stride_phase
		bob = Vector3(cos(ph) * 0.012, -absf(sin(ph)) * 0.012, 0.0) * s

	var ks := Springs.step(_kick, _kick_vel, 220.0, 20.0, delta)
	_kick = ks.x
	_kick_vel = ks.y

	# Aim along the cable, pre-warped for the launcher's FOV so it points at the
	# anchor on screen; clamped so the wrist never bends backward.
	var aim_to := Vector3.FORWARD
	if grappling or _linger > 0.0:
		var a := cam.affine_inverse() * motor.grapple_point
		var k := tan(deg_to_rad(rig.camera.fov) * 0.5) / tan(deg_to_rad(FPBody.FP_FOV) * 0.5)
		a = Vector3(a.x / k, a.y / k, a.z) - RAISED_POS
		if a.length() > 0.01:
			aim_to = a.normalized()
		var ang := Vector3.FORWARD.angle_to(aim_to)
		if ang > MAX_AIM:
			aim_to = Vector3.FORWARD.slerp(aim_to, MAX_AIM / ang)
	var want := Basis.looking_at(aim_to, Vector3.UP)
	_aim = _aim.slerp(want, 1.0 - exp(-18.0 * delta)).orthonormalized()

	var r := raise * raise * (3.0 - 2.0 * raise)
	position = LOWERED_POS.lerp(RAISED_POS, r) + bob + _lag \
		+ Vector3(-_sway.x * 0.3, _sway.y * 0.25, 0.0) + _aim * Vector3(0, 0, _kick * 0.05)
	basis = _aim * Basis.from_euler(Vector3(_kick * 0.4 + (1.0 - r) * -0.9, _sway.x * 0.6, _lean + _sway.x * 0.3))


## Where the muzzle appears to be in the world (it's drawn with the launcher's
## narrower FOV), so the cable leaves the muzzle on screen.
func apparent_muzzle() -> Vector3:
	var cam := rig.camera.global_transform
	var local := cam.affine_inverse() * muzzle.global_position
	var k := tan(deg_to_rad(rig.camera.fov) * 0.5) / tan(deg_to_rad(FPBody.FP_FOV) * 0.5)
	return cam * Vector3(local.x * k, local.y * k, local.z)


func _build_model() -> void:
	var model: Node3D = MODEL.instantiate()
	add_child(model)
	model.scale = Vector3.ONE * MODEL_SCALE
	var shader := preload("res://shaders/viewmodel.gdshader")
	var color := RunnerAvatar.PLAYER_COLORS[player.player_index % RunnerAvatar.PLAYER_COLORS.size()]
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mi.layers = rig.viewmodel_layer_bit()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i) as BaseMaterial3D
			var m := ShaderMaterial.new()
			m.shader = shader
			m.set_shader_parameter(&"fp_fov_deg", FPBody.FP_FOV)
			if src:
				m.set_shader_parameter(&"albedo", src.albedo_color)
				m.set_shader_parameter(&"roughness", src.roughness)
				m.set_shader_parameter(&"metallic", src.metallic)
				if src.resource_name == "Accent":
					m.set_shader_parameter(&"albedo", color)
					m.set_shader_parameter(&"emission", color)
					m.set_shader_parameter(&"emission_energy", 4.0)
			mi.set_surface_override_material(i, m)
	grip = model.find_child("Grip") as Node3D
	muzzle = model.find_child("Muzzle") as Node3D
	_hook = model.find_child("Hook") as Node3D
	# The model's origin is the grip: shift it so this node's origin is the hand.
	if grip:
		model.position = -grip.position * MODEL_SCALE
