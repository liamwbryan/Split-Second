class_name Viewmodel
extends Node3D
## Procedural first-person rifle plus its motion: sway from look, bob from
## running, tilt on wall-runs, drop on landing, kick on fire, lowered while
## sprinting. Rendered only to its owner's camera via a per-player layer.

const MODEL := preload("res://assets/models/agent_rifle.glb")  # art/blender/rifle.py
const MODEL_SCALE := 0.9
## Positions of the gun's grip (model origin) in camera space.
const HIP_POS := Vector3(0.16, -0.19, -0.4)
const ADS_POS := Vector3(0.0, -0.132, -0.19)  # puts the sight line (0, 0.147, -0.06) * scale on the view axis
const SPRINT_POS := Vector3(0.13, -0.24, -0.34)

var player: Player
var muzzle: Node3D
## Hand sockets on the gun (from the Blender model): the first-person arms IK to these.
var grip_r: Node3D
var grip_l: Node3D
var ads_amount: float = 0.0

var _sway: Vector2 = Vector2.ZERO
var _last_yaw: float = 0.0
var _last_pitch: float = 0.0
var _kick: float = 0.0
var _kick_vel: float = 0.0
var _land: float = 0.0
var _land_vel: float = 0.0
var _tilt: float = 0.0
var _sprint: float = 0.0
var _bob_phase: float = 0.0
var _pose_pos: Vector3 = Vector3.ZERO  # traversal pose offsets (slide, mantle, vault...)
var _pose_rot: Vector3 = Vector3.ZERO
var _flash: MeshInstance3D
var _flash_light: OmniLight3D
var _flash_time: float = 0.0
var _layer: int = 0


func setup(p_player: Player, layer_bit: int) -> void:
	player = p_player
	_layer = layer_bit
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	position = HIP_POS
	scale = Vector3.ONE * MODEL_SCALE
	_build_model()

	_flash = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	_flash.mesh = quad
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flash_mat.albedo_color = Color(1.0, 0.75, 0.4, 1.0)
	flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flash_mat.no_depth_test = true
	_flash.material_override = flash_mat
	_flash.layers = _layer
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	muzzle.add_child(_flash)

	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.75, 0.45)
	_flash_light.omni_range = 6.0
	_flash_light.light_energy = 0.0
	_flash_light.shadow_enabled = false
	muzzle.add_child(_flash_light)

	player.motor.landed.connect(func(impact: float) -> void:
		_land_vel -= clampf(impact, 0.0, 25.0) * 0.012)
	player.motor.jumped.connect(func(_k: int) -> void:
		_land_vel += 0.12)


func kick(strength: float) -> void:
	_kick_vel += 3.5 * strength
	_flash.visible = true
	_flash.rotation.z = randf() * TAU
	_flash.scale = Vector3.ONE * randf_range(0.8, 1.25)
	_flash_light.light_energy = 2.5
	_flash_time = 0.035


func _process(delta: float) -> void:
	var motor := player.motor
	var speed := player.horizontal_speed()

	# Sway: gun lags behind look motion.
	var dyaw := wrapf(player.yaw - _last_yaw, -PI, PI)
	var dpitch := player.pitch - _last_pitch
	_last_yaw = player.yaw
	_last_pitch = player.pitch
	var sway_scale := lerpf(1.0, 0.25, ads_amount)
	_sway += Vector2(dyaw, dpitch) * 0.6 * sway_scale
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-12.0 * delta))
	_sway = _sway.limit_length(0.08)

	# Kick and landing springs.
	var ks := Springs.step(_kick, _kick_vel, 260.0, 26.0, delta)
	_kick = ks.x
	_kick_vel = ks.y
	var ls := Springs.step(_land, _land_vel, 120.0, 18.0, delta)
	_land = ls.x
	_land_vel = ls.y

	var sprinting := motor.state == PlayerMotor.State.GROUND and speed > player.tuning.walk_speed + 0.5 and ads_amount < 0.1
	_sprint = lerpf(_sprint, 1.0 if sprinting else 0.0, 1.0 - exp(-10.0 * delta))

	var tilt_target := 0.0
	if motor.state == PlayerMotor.State.WALLRUN:
		tilt_target = deg_to_rad(12.0) * motor.wall_side
	elif motor.state == PlayerMotor.State.SLIDE:
		tilt_target = deg_to_rad(10.0)
	_tilt = lerpf(_tilt, tilt_target * (1.0 - ads_amount), 1.0 - exp(-9.0 * delta))

	var bobbing := motor.state == PlayerMotor.State.GROUND and speed > 1.0
	if bobbing:
		_bob_phase += delta * speed * 1.25
	var bob_amt := (0.012 if bobbing else 0.0) * clampf(speed / player.tuning.sprint_speed, 0.0, 1.2) * (1.0 - ads_amount * 0.85)
	var bob := Vector3(cos(_bob_phase) * bob_amt, -absf(sin(_bob_phase)) * bob_amt, 0.0)

	var ease_ads := ads_amount * ads_amount * (3.0 - 2.0 * ads_amount)
	var base := HIP_POS.lerp(SPRINT_POS, _sprint).lerp(ADS_POS, ease_ads)

	# Traversal poses: the gun makes room for the hands (DESIGN: "hands come out").
	var pose_pos := Vector3.ZERO
	var pose_rot := Vector3.ZERO
	match motor.state:
		PlayerMotor.State.SLIDE:  # held out one-handed, canted toward center
			pose_pos = Vector3(-0.05, 0.05, -0.08)
			pose_rot = Vector3(deg_to_rad(4.0), deg_to_rad(6.0), deg_to_rad(8.0))
		PlayerMotor.State.MANTLE:
			if motor.mantle_is_vault:  # swung out right, one-handed
				pose_pos = Vector3(0.1, -0.02, 0.04)
				pose_rot = Vector3(deg_to_rad(10.0), deg_to_rad(-25.0), deg_to_rad(-25.0))
			else:  # dropped out of the way: both hands are on the ledge
				pose_pos = Vector3(0.08, -0.26, 0.1)
				pose_rot = Vector3(deg_to_rad(-40.0), deg_to_rad(25.0), deg_to_rad(-10.0))
		PlayerMotor.State.WALLCLIMB:
			pose_pos = Vector3(0.1, -0.24, 0.08)
			pose_rot = Vector3(deg_to_rad(-35.0), deg_to_rad(20.0), 0.0)
		PlayerMotor.State.GRAPPLE:
			pose_pos = Vector3(0.03, -0.03, 0.03)
	var pose_rate := 1.0 - exp(-(20.0 if pose_pos != Vector3.ZERO else 12.0) * delta)
	_pose_pos = _pose_pos.lerp(pose_pos * (1.0 - ease_ads), pose_rate)
	_pose_rot = _pose_rot.lerp(pose_rot * (1.0 - ease_ads), pose_rate)

	# Sprint stride: the gun swings with the arms instead of floating.
	var stride := _sprint * (1.0 - ease_ads)
	var swing := Vector3(sin(_bob_phase) * 0.03 * stride, 0.0, 0.0)
	var swing_rot := Vector3(0.0, sin(_bob_phase) * deg_to_rad(4.0) * stride, cos(_bob_phase * 2.0) * deg_to_rad(3.0) * stride)

	position = base + bob + swing + _pose_pos + Vector3(-_sway.x * 0.35, _sway.y * 0.25 + _land, _kick * 0.06)
	var toward_center := deg_to_rad(2.5) * (1.0 - ease_ads)  # hip: muzzle angled slightly toward the crosshair
	rotation = Vector3(_kick * 0.35 + _sprint * deg_to_rad(-8.0), toward_center + _sway.x * 0.8 + _sprint * deg_to_rad(28.0), _tilt + _sway.x * 0.4) + swing_rot + _pose_rot

	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			_flash.visible = false
			_flash_light.light_energy = 0.0


## Instances the Blender carbine and converts its materials to the viewmodel
## shader (depth-squashed so the gun never clips into walls). "Accent" parts
## glow in the player's color.
func _build_model() -> void:
	var model: Node3D = MODEL.instantiate()
	add_child(model)
	var shader := preload("res://shaders/viewmodel.gdshader")
	var color := RunnerAvatar.PLAYER_COLORS[player.player_index % RunnerAvatar.PLAYER_COLORS.size()]
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.name.begins_with("Stock"):
			mi.visible = false  # tucked into the shoulder: off-screen in first person
			continue
		mi.layers = _layer
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
	grip_r = model.find_child("GripR") as Node3D
	grip_l = model.find_child("GripL") as Node3D
	muzzle = model.find_child("Muzzle") as Node3D
	if muzzle == null:
		muzzle = Node3D.new()
		muzzle.position = Vector3(0, 0.07, -0.73)
		model.add_child(muzzle)
