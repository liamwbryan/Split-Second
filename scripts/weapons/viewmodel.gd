class_name Viewmodel
extends Node3D
## Procedural first-person weapon plus its motion: sway from look, bob from
## running, tilt on wall-runs, drop on landing, kick on fire. Rendered only to
## its owner's camera via a per-player layer.
## Carry (WeaponData.one_hand_hip): SMG style = one hand at the hip, pumping
## with the right arm while sprinting; `support` (0..1) brings the second hand
## on for aiming. Rifle style = two hands always.
## Updated by the camera rig (update()) right before the first-person arms.
##
## One node carries every weapon: each WeaponData's model is built once and
## cached (set_weapon() just shows another), and its grip positions come from
## the data (hip / one-hand / ADS / sprint), so the arms IK to whatever is held.
## Blades are held like a pistol grip (the mount stands the blade up out of the
## fist) and animate through swing arcs: hand position + blade direction keys,
## with the edge leading the motion.

const RIFLE_MODEL := preload("res://assets/models/agent_rifle.glb")  # art/blender/rifle.py
## One-handed sprint pump (camera space): the gun rides the right hand's swing.
const PUMP_FWD := 0.09
const PUMP_UP := 0.05
const PUMP_PITCH := deg_to_rad(14.0)
## Blade swing arcs (camera space): windup, strike, follow-through, each
## [hand position, blade direction]. 0 forehand (right to left), 1 backhand
## (left to right, rising), 2 overhead chop.
const SWINGS := [
	[[Vector3(0.32, -0.12, -0.24), Vector3(0.9, 0.25, 0.35)], [Vector3(0.06, -0.14, -0.42), Vector3(0.0, -0.05, -1.0)], [Vector3(-0.22, -0.2, -0.36), Vector3(-0.9, -0.2, -0.2)]],
	[[Vector3(-0.16, -0.2, -0.3), Vector3(-0.9, -0.1, 0.2)], [Vector3(0.02, -0.1, -0.45), Vector3(0.0, 0.1, -1.0)], [Vector3(0.3, -0.06, -0.3), Vector3(0.9, 0.35, -0.1)]],
	[[Vector3(0.14, 0.04, -0.25), Vector3(0.1, 0.9, 0.3)], [Vector3(0.04, -0.12, -0.45), Vector3(0.0, -0.2, -1.0)], [Vector3(0.02, -0.32, -0.38), Vector3(0.0, -0.95, -0.2)]],
]
const BLADE_IDLE_DIR := Vector3(-0.25, 0.75, -0.6)

var player: Player
var muzzle: Node3D
## Hand sockets on the weapon (from the Blender model): the first-person arms IK to these.
var grip_r: Node3D
var grip_l: Node3D
var ads_amount: float = 0.0
var support: float = 1.0          ## 1 = second hand on the gun (aiming / rifle carry)
var data: WeaponData
## 0 = up, 1 = lowered out of view (weapon switch). Set by the Loadout.
var lower: float = 0.0
## Blade swing: -1 = none, else 0..1 through `swing_index`'s arc.
var swing_t: float = -1.0
var swing_index: int = 0
## Quick melee: the blade comes up from below the frame instead of the hip.
var swing_from_low: bool = false
## Bolt/charge cycle after a shot: 1 → 0 over the cycle.
var cycle: float = 0.0
## True while a scoped weapon is fully zoomed: the gun and arms hide.
var scoped_in: bool = false
var model_root: Node3D  ## the current weapon's model
var trail: SlashTrail   ## blade trail, sampled after each pose

var _sway: Vector2 = Vector2.ZERO
var _last_yaw: float = 0.0
var _last_pitch: float = 0.0
var _kick: float = 0.0
var _kick_vel: float = 0.0
var _land: float = 0.0
var _land_vel: float = 0.0
var _tilt: float = 0.0
var _sprint: float = 0.0
var _pose_pos: Vector3 = Vector3.ZERO  # traversal pose offsets (slide, mantle, vault...)
var _pose_rot: Vector3 = Vector3.ZERO
var _flash: MeshInstance3D
var _flash_light: OmniLight3D
var _flash_time: float = 0.0
var _layer: int = 0
var _models: Dictionary = {}  ## WeaponData -> model Node3D (built once)
var _mount: Basis = Basis.IDENTITY


func setup(p_player: Player, layer_bit: int) -> void:
	player = p_player
	_layer = layer_bit
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	set_process(false)  # the camera rig calls update() in order
	muzzle = Node3D.new()  # placeholder until set_weapon() picks a model
	add_child(muzzle)

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
	add_child(_flash)

	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.75, 0.45)
	_flash_light.omni_range = 6.0
	_flash_light.light_energy = 0.0
	_flash_light.shadow_enabled = false
	add_child(_flash_light)

	player.motor.landed.connect(func(impact: float) -> void:
		_land_vel -= clampf(impact, 0.0, 25.0) * 0.012)
	player.motor.jumped.connect(func(_k: int) -> void:
		_land_vel += 0.12)


## Shows `d`'s model (building it the first time) and takes its sockets.
func set_weapon(d: WeaponData) -> void:
	data = d
	if not _models.has(d):
		_models[d] = _build_model(d.model if d.model else RIFLE_MODEL, d)
	for m: Node3D in _models.values():
		m.visible = m == _models[d]
	model_root = _models[d]
	scale = Vector3.ONE * d.model_scale
	_mount = Basis.from_euler(d.model_rot_deg * (PI / 180.0))
	model_root.basis = _mount
	grip_r = model_root.find_child("GripR") as Node3D
	grip_l = model_root.find_child("GripL") as Node3D
	if grip_l == null:
		grip_l = grip_r  # blades: one hand
	muzzle = model_root.find_child("Muzzle") as Node3D
	if muzzle == null:
		muzzle = model_root.find_child("Tip") as Node3D
	if muzzle == null:
		muzzle = model_root
	_flash.reparent(muzzle, false)
	_flash_light.reparent(muzzle, false)
	_flash.position = Vector3.ZERO
	_flash_light.position = Vector3.ZERO


func is_blade() -> bool:
	return data != null and data.kind == WeaponData.Kind.MELEE


## World-space blade base and tip (for the slash trail), or empty if no blade.
func blade_points() -> PackedVector3Array:
	if model_root == null:
		return PackedVector3Array()
	var base := model_root.find_child("Base") as Node3D
	var tip := model_root.find_child("Tip") as Node3D
	if base == null or tip == null:
		return PackedVector3Array()
	return PackedVector3Array([base.global_position, tip.global_position])


func kick(strength: float) -> void:
	_kick_vel += 3.5 * strength
	_flash.visible = true
	_flash.rotation.z = randf() * TAU
	_flash.scale = Vector3.ONE * randf_range(0.8, 1.25)
	_flash_light.light_energy = 2.5
	_flash_time = 0.035


func update(delta: float) -> void:
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

	# Second hand: on for aiming (or always, with a rifle carry).
	var two_hands := data == null or not data.one_hand_hip or ads_amount > 0.0
	support = move_toward(support, 1.0 if two_hands else 0.0, delta / (data.support_time if data else 0.1))
	var sup := support * support * (3.0 - 2.0 * support)

	var bobbing := motor.state == PlayerMotor.State.GROUND and speed > 1.0
	var phase := player.camera_rig.stride_phase
	var bob_amt := (0.012 if bobbing else 0.0) * clampf(speed / player.tuning.sprint_speed, 0.0, 1.2) * (1.0 - ads_amount * 0.85)
	var bob := Vector3(cos(phase) * bob_amt, -absf(sin(phase)) * bob_amt, 0.0)

	var ease_ads := ads_amount * ads_amount * (3.0 - 2.0 * ads_amount)
	var base_two := data.hip_pos.lerp(data.sprint_pos, _sprint)
	var base_one := data.hip1_pos.lerp(data.sprint1_pos, _sprint)
	var base := base_one.lerp(base_two, sup).lerp(data.ads_pos, ease_ads)

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

	# Sprint. Two hands: the rifle swings side to side with the stride. One
	# hand: the gun rides the right arm's pump (forward and up on the forward
	# swing, muzzle dipping on the back swing), in phase with the free arm.
	var stride := _sprint * (1.0 - ease_ads)
	var s := sin(phase)
	var swing_two := Vector3(s * 0.03, 0.0, 0.0)
	var swing_one := Vector3(0.0, PUMP_UP * s, -PUMP_FWD * s)
	var swing := swing_one.lerp(swing_two, sup) * stride
	var rot_two := Vector3(0.0, s * deg_to_rad(4.0), cos(phase * 2.0) * deg_to_rad(3.0))
	var rot_one := Vector3(PUMP_PITCH * s, 0.0, 0.0)
	var swing_rot := rot_one.lerp(rot_two, sup) * stride
	# Carry angle: rifle port-arms (turned in) vs one hand (muzzle down, canted).
	var carry_two := Vector3(deg_to_rad(-8.0), deg_to_rad(28.0), 0.0)
	var carry_one := Vector3(deg_to_rad(-12.0), deg_to_rad(4.0), deg_to_rad(-4.0))
	var carry := carry_one.lerp(carry_two, sup) * _sprint

	var sway_pos := Vector3(-_sway.x * 0.35, _sway.y * 0.25 + _land, _kick * 0.06)
	# Switch: drop the weapon down and roll it away (and back up on the raise).
	var low := lower * lower * (3.0 - 2.0 * lower)
	var lower_pos := Vector3(0.05, -0.3, 0.12) * low
	var lower_rot := Basis.from_euler(Vector3(deg_to_rad(-45.0), deg_to_rad(10.0), deg_to_rad(-20.0)) * low)
	if is_blade():
		# Blades: the swing arc drives the pose; sway, bob and the run pump ride on top.
		var pose := _blade_pose()
		var ride := Basis.from_euler(Vector3(_sway.y * 0.6 + PUMP_PITCH * s * stride * 0.5, _sway.x * 0.8, _tilt * 0.5 + _sway.x * 0.4))
		transform = Transform3D(lower_rot * ride * pose.basis, pose.origin + bob + _pose_pos * 0.5 + sway_pos + lower_pos + swing_one * stride * 0.5)
	else:
		# Bolt cycle: the gun rolls and dips while the bolt is worked.
		var cyc := sin(PI * clampf(1.0 - cycle, 0.0, 1.0)) if cycle > 0.0 else 0.0
		cyc *= 1.0 - ease_ads * 0.6
		var cycle_rot := Vector3(deg_to_rad(-6.0), deg_to_rad(4.0), deg_to_rad(22.0)) * cyc
		position = base + bob + swing + _pose_pos + sway_pos + lower_pos + Vector3(0.0, -0.03, 0.02) * cyc
		var toward_center := deg_to_rad(2.5) * (1.0 - ease_ads)  # hip: muzzle angled slightly toward the crosshair
		rotation = Vector3(_kick * 0.35, toward_center + _sway.x * 0.8, _tilt + _sway.x * 0.4) + carry + swing_rot + _pose_rot + cycle_rot
		basis = lower_rot * basis
	scale = Vector3.ONE * data.model_scale
	scoped_in = data.scoped and ads_amount >= data.scope_in_at
	if model_root:
		model_root.visible = not scoped_in

	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			_flash.visible = false
			_flash_light.light_energy = 0.0
	if trail:
		trail.sample(delta)


## Blade pose (camera space) along the current swing arc, or at rest.
## Keys: rest → windup → strike (at strike_at) → follow-through → rest. The
## blade's edge leads the motion.
func _blade_pose() -> Transform3D:
	var rest_pos := data.hip_pos
	var rest_dir := BLADE_IDLE_DIR.normalized()
	if swing_t < 0.0:
		return _blade_basis(rest_pos, rest_dir, Vector3(-1, 0, 0))
	var keys: Array = SWINGS[swing_index % SWINGS.size()]
	var start_pos := rest_pos + (Vector3(0.05, -0.35, 0.1) if swing_from_low else Vector3.ZERO)
	var poses := [[start_pos, rest_dir], keys[0], keys[1], keys[2], [rest_pos, rest_dir]]
	var times := [0.0, minf(0.14, data.strike_at * 0.5), data.strike_at, minf(data.strike_at + 0.25, 0.9), 1.0]
	var p := _sample(poses, times, swing_t)
	var ahead := _sample(poses, times, minf(swing_t + 0.03, 1.0))
	var edge: Vector3 = (ahead[1] as Vector3) - (p[1] as Vector3)
	return _blade_basis(p[0], p[1], edge if edge.length() > 0.01 else Vector3(-1, 0, 0))


static func _sample(poses: Array, times: Array, t: float) -> Array:
	for i in times.size() - 1:
		if t <= times[i + 1] or i == times.size() - 2:
			var f := clampf((t - times[i]) / maxf(times[i + 1] - times[i], 0.001), 0.0, 1.0)
			f = f * f * (3.0 - 2.0 * f)
			var a: Array = poses[i]
			var b: Array = poses[i + 1]
			var da := (a[1] as Vector3).normalized()
			var db := (b[1] as Vector3).normalized()
			var dir := da.slerp(db, f) if da.dot(db) > -0.99 else da.lerp(db, f).normalized()
			return [(a[0] as Vector3).lerp(b[0], f), dir]
	return poses[-1]


## Viewmodel basis that points the mounted blade along `dir` with its edge
## toward `edge` (the blade stands out of the fist at the mount angle).
func _blade_basis(pos: Vector3, dir: Vector3, edge: Vector3) -> Transform3D:
	var d := dir.normalized()
	var e := edge - d * edge.dot(d)
	if e.length() < 0.01:
		e = Vector3.UP - d * d.y
	var m := _mount * Vector3.FORWARD  # blade direction in the viewmodel frame
	var em := _mount * Vector3.UP       # edge direction in the viewmodel frame
	var want := Basis.looking_at(d, e.normalized())
	var have := Basis.looking_at(m, em)
	return Transform3D(want * have.inverse(), pos)


## Instances a weapon model and converts its materials to the viewmodel
## shader (depth-squashed so it never clips into walls). "Accent" parts glow
## in the player's color.
func _build_model(scene: PackedScene, d: WeaponData) -> Node3D:
	var model: Node3D = scene.instantiate()
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
	if d.kind == WeaponData.Kind.HITSCAN and model.find_child("Muzzle") == null:
		var mz := Node3D.new()
		mz.name = "Muzzle"
		mz.position = Vector3(0, 0.07, -0.73)
		model.add_child(mz)
	return model
