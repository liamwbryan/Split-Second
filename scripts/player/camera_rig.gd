class_name CameraRig
extends Node3D
## First-person camera. Lives in the player's SubViewport (so it renders there)
## but follows the player's *interpolated* transform every render frame, so
## the 120 Hz simulation looks smooth at any refresh rate. Mouse look is
## applied per frame, never smoothed.
##
## Everything here is eased, never snapped (DESIGN §4.2 rule 6).

const WORLD_LAYERS := 0x3FF  # render layers 1-10
const AVATAR_LAYERS := 0xF << 15  # render layers 16-19 (one per player)

var player: Player
var camera: Camera3D
var fp_body: FPBody

## Set by the weapon: FOV multiplier while aiming down sights.
var ads_fov_mult: float = 1.0
## Debug/spectate view from behind the player (P). Shows your own body.
var third_person: bool = false:
	set(value):
		third_person = value
		_update_cull_mask()
		if fp_body:
			fp_body.active = not value

var _eye: float = 1.62
var _roll: float = 0.0
var _speed_fov: float = 0.0
var _flow_fov: float = 0.0
var _boost_fov: float = 0.0  # decaying FOV punch from momentum boosts (degrees)
var _dip: float = 0.0
var _dip_vel: float = 0.0
var _bob_phase: float = 0.0
## Shared stride clock (radians): one arm-swing cycle = two footfalls. The head
## bob, the gun and both arms all read this so they never drift apart.
var stride_phase: float:
	get: return _bob_phase
var _bob_weight: float = 0.0
var _punch: Vector2 = Vector2.ZERO  # visual-only recoil (pitch, yaw) radians
var _punch_vel: Vector2 = Vector2.ZERO
var _trauma: float = 0.0
var _noise_t: float = 0.0


func setup(p_player: Player) -> void:
	player = p_player
	name = "CameraRig%d" % (player.player_index + 1)
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera = Camera3D.new()
	camera.near = 0.05
	camera.far = 1500.0
	add_child(camera)
	_update_cull_mask()
	camera.current = true
	player.motor.landed.connect(_on_landed)
	player.motor.momentum_boosted.connect(func(amount: float) -> void:
		_boost_fov = maxf(_boost_fov, player.tuning.momentum_boost_fov_kick * clampf(amount / 3.0, 0.4, 1.0)))


func _update_cull_mask() -> void:
	if camera == null:
		return
	var own_body := player.avatar_layer_bit()
	var mask := WORLD_LAYERS | (AVATAR_LAYERS & ~own_body)
	if third_person:
		mask |= own_body
	else:
		mask |= viewmodel_layer_bit()
	camera.cull_mask = mask


## Creates the owner-only first-person body once the weapon exists.
func attach_fp_body(viewmodel: Viewmodel) -> void:
	fp_body = FPBody.new()
	add_child(fp_body)
	fp_body.setup(player, self, viewmodel)
	fp_body.active = not third_person


func viewmodel_layer_bit() -> int:
	return 1 << (10 + player.player_index)


func snap() -> void:
	_eye = player.tuning.eye_height
	_roll = 0.0
	_dip = 0.0
	_dip_vel = 0.0
	_punch = Vector2.ZERO
	_punch_vel = Vector2.ZERO
	_update_transform(0.0)


## Visual-only kick, springs back on its own.
func punch(pitch_rad: float, yaw_rad: float) -> void:
	_punch_vel += Vector2(pitch_rad, yaw_rad) * 60.0


func add_trauma(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


func _process(delta: float) -> void:
	player.apply_look(player.router.consume_look(delta), delta)
	_update_transform(delta)


func _update_transform(delta: float) -> void:
	var t := player.tuning
	var s := player.settings
	var motor := player.motor
	var state := motor.state

	var eye_target := t.eye_height
	if state == PlayerMotor.State.SLIDE:
		eye_target = t.crouch_eye_height - 0.1
	elif motor.crouched:
		eye_target = t.crouch_eye_height
	_eye = _damp(_eye, eye_target, 14.0, delta)

	# Landing dip: critically-damped spring.
	var k := 180.0
	var c := 2.0 * sqrt(k)
	var ds := Springs.step(_dip, _dip_vel, k, c, delta)
	_dip = ds.x
	_dip_vel = ds.y

	# Head bob on the ground only.
	var speed := player.horizontal_speed()
	var bobbing := state == PlayerMotor.State.GROUND and speed > 1.0
	_bob_weight = _damp(_bob_weight, 1.0 if bobbing else 0.0, 10.0, delta)
	_bob_phase += delta * speed * 1.25
	var bob_amt := t.head_bob_amount * s.head_bob_scale * _bob_weight * clampf(speed / t.sprint_speed, 0.0, 1.2)
	var bob := Vector3(cos(_bob_phase) * bob_amt * 0.6, -absf(sin(_bob_phase)) * bob_amt, 0.0)

	# Roll: wall-run tilts away from the wall; strafing and sliding lean slightly.
	var roll_target := 0.0
	if state == PlayerMotor.State.WALLRUN:
		roll_target = deg_to_rad(t.wallrun_camera_tilt) * motor.wall_side
	else:
		roll_target = -player.router.move_vector().x * deg_to_rad(t.strafe_camera_tilt)
		if state == PlayerMotor.State.SLIDE:
			roll_target += deg_to_rad(t.slide_camera_tilt)
	roll_target *= s.camera_tilt_scale
	_roll = _damp(_roll, roll_target, 8.0, delta)

	# Speed widens the FOV a little: sells speed without distorting aim.
	var speed_f := clampf((speed - t.speed_fov_min) / maxf(t.speed_fov_max - t.speed_fov_min, 0.1), 0.0, 1.0)
	_speed_fov = _damp(_speed_fov, speed_f, 4.0, delta)
	# Momentum (prototype): a fuller meter opens the view a touch more, and a
	# boost punches it out and lets it settle.
	_flow_fov = _damp(_flow_fov, motor.flow * t.momentum_fov_add, 3.0, delta)
	_boost_fov = _damp(_boost_fov, 0.0, 5.0, delta)
	var fov := s.fov + (_speed_fov * t.speed_fov_add + _flow_fov + _boost_fov) * s.speed_fov_scale
	camera.fov = _damp(camera.fov, fov * ads_fov_mult, 18.0, delta) if delta > 0.0 else fov

	# Visual punch spring.
	var pk := 400.0
	var pc := 2.0 * sqrt(pk) * 0.9
	var px := Springs.step(_punch.x, _punch_vel.x, pk, pc, delta)
	var py := Springs.step(_punch.y, _punch_vel.y, pk, pc, delta)
	_punch = Vector2(px.x, py.x)
	_punch_vel = Vector2(px.y, py.y)

	_trauma = maxf(0.0, _trauma - delta * 3.0)
	_noise_t += delta * 40.0
	var shake := _trauma * _trauma * 0.012
	var shake_rot := Vector2(sin(_noise_t * 1.3) * shake, sin(_noise_t * 1.7 + 2.0) * shake)

	# Mantle nod: the view dips toward the ledge and back, so the plants read.
	var nod := 0.0
	if state == PlayerMotor.State.MANTLE:
		nod = -deg_to_rad(t.mantle_camera_nod) * sin(PI * pow(motor.mantle_progress(), 0.7))  # peaks early, as the hands land

	var origin := player.get_global_transform_interpolated().origin
	var look := Basis(Vector3.UP, player.yaw + _punch.y + shake_rot.y) \
		* Basis(Vector3.RIGHT, player.pitch + _punch.x + shake_rot.x + nod) \
		* Basis(Vector3.BACK, _roll)
	var base := origin + Vector3.UP * (_eye + _dip)
	if third_person:
		# Over-the-shoulder, pulled in if a wall is behind.
		var desired := base + look * Vector3(0.55, 0.25, 3.2)
		var q := PhysicsRayQueryParameters3D.create(base, desired, 1, [player.get_rid()])
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			desired = base.lerp(hit.position, 0.85)
		global_transform = Transform3D(look, desired)
	else:
		global_transform = Transform3D(look, base + Basis(Vector3.UP, player.yaw) * bob)
	if fp_body:
		# The gun (a camera child) would otherwise update after this, and the
		# hands would chase last frame's gun pose.
		fp_body.viewmodel.update(delta)
		fp_body.sync(delta)


func _on_landed(impact: float) -> void:
	if impact < 3.0:
		return
	_dip_vel -= minf(impact, 30.0) * player.tuning.landing_dip_scale * 25.0


static func _damp(from: float, to: float, rate: float, delta: float) -> float:
	return lerpf(from, to, 1.0 - exp(-rate * delta))
