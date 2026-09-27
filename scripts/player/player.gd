class_name Player
extends CharacterBody3D
## One local player. Never a singleton: everything per-player (input, camera,
## HUD, viewmodel layer) hangs off this node, so 1-4 can coexist.

signal respawned

var player_index: int = 0
var router: InputRouter
var tuning: MovementTuning
var settings: PlayerSettings

## Look angles (radians). Written by the camera rig from input every frame,
## read by the motor every physics tick.
var yaw: float = 0.0
var pitch: float = 0.0

var motor: PlayerMotor
var camera_rig: CameraRig
var weapon: HitscanWeapon
var hud: PlayerHud
var avatar: RunnerAvatar

var spawn_position: Vector3 = Vector3.ZERO
var spawn_yaw: float = 0.0

var _turn_active: bool = false
var _turn_from: float = 0.0
var _turn_to: float = 0.0
var _turn_elapsed: float = 0.0
var _turn_duration: float = 0.2


func setup(index: int, p_router: InputRouter, p_tuning: MovementTuning, view_root: Node) -> void:
	player_index = index
	router = p_router
	settings = router.settings
	tuning = p_tuning
	name = "Player%d" % (index + 1)
	collision_layer = 1 << 1  # player
	collision_mask = 1        # world
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.35
	floor_constant_speed = true
	floor_block_on_wall = true
	max_slides = 6
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_VELOCITY
	wall_min_slide_angle = deg_to_rad(10.0)

	var shape_node := CollisionShape3D.new()
	add_child(shape_node)
	motor = PlayerMotor.new()
	motor.name = "Motor"
	add_child(motor)
	motor.setup(self, shape_node)

	camera_rig = CameraRig.new()
	view_root.add_child(camera_rig)
	camera_rig.setup(self)

	weapon = HitscanWeapon.new()
	camera_rig.add_child(weapon)
	weapon.setup(self, camera_rig, preload("res://scripts/weapons/rifle.tres"))
	camera_rig.attach_fp_body(weapon.viewmodel)

	avatar = RunnerAvatar.new()
	add_child(avatar)
	avatar.setup(self, avatar_layer_bit())

	var rope := GrappleRope.new()
	view_root.add_child(rope)
	rope.setup(self)

	hud = PlayerHud.new()
	view_root.add_child(hud)
	hud.setup(self)

	InputHub.register(router)
	PlayerFeedback.new().attach(self)


func _exit_tree() -> void:
	if router:
		InputHub.unregister(router)


func spawn(at: Vector3, facing_yaw: float) -> void:
	spawn_position = at
	spawn_yaw = facing_yaw
	respawn()


func respawn() -> void:
	motor.reset_to(spawn_position)
	yaw = spawn_yaw
	pitch = 0.0
	_turn_active = false
	reset_physics_interpolation()
	camera_rig.snap()
	respawned.emit()


func _physics_process(delta: float) -> void:
	router.tick(delta)
	if router.just_pressed(InputRouter.Action.RESET):
		respawn()
		return
	motor.physics_step(delta)
	weapon.physics_step(delta)
	if global_position.y < -60.0:
		respawn()


## Apply look input (called by the camera rig each render frame).
func apply_look(delta_look: Vector2, delta: float) -> void:
	if _turn_active:
		_turn_elapsed += delta
		var t := clampf(_turn_elapsed / _turn_duration, 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)
		yaw = lerp_angle(_turn_from, _turn_to, t)
		if t >= 1.0:
			_turn_active = false
		# Look input during the turn still applies on top, so it never feels locked.
		_turn_to -= delta_look.x
	else:
		yaw -= delta_look.x
	yaw = wrapf(yaw, -PI, PI)
	pitch = clampf(pitch - delta_look.y, deg_to_rad(-88.0), deg_to_rad(88.0))


## Smoothly turn to face a horizontal direction (used by the wall-climb kick).
func request_turn_to(direction: Vector3, duration: float) -> void:
	var target := atan2(-direction.x, -direction.z)
	_turn_from = yaw
	_turn_to = yaw + wrapf(target - yaw, -PI, PI)
	_turn_elapsed = 0.0
	_turn_duration = maxf(duration, 0.01)
	_turn_active = true


## Render layers 16-19 hold player bodies; each camera hides its own.
func avatar_layer_bit() -> int:
	return 1 << (15 + player_index)


func eye_position() -> Vector3:
	var eye := tuning.crouch_eye_height if motor.crouched else tuning.eye_height
	return global_position + Vector3.UP * eye


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()
