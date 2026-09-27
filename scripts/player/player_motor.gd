class_name PlayerMotor
extends Node
## Movement state machine. The motor is the single owner of the player's
## velocity (DESIGN §4.2): every ability adds to it, redirects it, or caps it,
## and every transition documents what happens to momentum.
##
## Priority when several moves apply (DESIGN §4.3):
##   Mantle > Grapple > WallRun/WallClimb > Slide > Air > Ground

signal state_changed(from: State, to: State)
signal jumped(kind: JumpKind)
signal landed(impact_speed: float)
signal mantled(is_vault: bool)
signal slide_started
signal grapple_attached(point: Vector3)
signal grapple_released
signal grapple_missed
## Momentum prototype feedback: a chained move (meter after it) and a speed
## boost it paid out (m/s). Presentation only; the motor never listens.
signal momentum_linked(flow: float)
signal momentum_boosted(amount: float)

enum State { GROUND, AIR, SLIDE, WALLRUN, WALLCLIMB, MANTLE, GRAPPLE }
enum JumpKind { GROUND, DOUBLE, WALL_KICK, CLIMB_KICK, SLIDE_HOP, CLIMB_HOP }

const STATE_NAMES: Array[String] = ["Ground", "Air", "Slide", "WallRun", "WallClimb", "Mantle", "Grapple"]

## Allowed transitions. Anything else is a bug and asserts in debug builds.
const TRANSITIONS := {
	State.GROUND: [State.AIR, State.SLIDE, State.MANTLE, State.GRAPPLE],
	State.AIR: [State.GROUND, State.SLIDE, State.WALLRUN, State.WALLCLIMB, State.MANTLE, State.GRAPPLE],
	State.SLIDE: [State.GROUND, State.AIR, State.MANTLE, State.GRAPPLE],
	State.WALLRUN: [State.AIR, State.GROUND, State.SLIDE, State.MANTLE, State.GRAPPLE],
	State.WALLCLIMB: [State.AIR, State.GROUND, State.SLIDE, State.MANTLE, State.GRAPPLE],
	State.MANTLE: [State.AIR],
	State.GRAPPLE: [State.AIR, State.GROUND, State.SLIDE, State.MANTLE],
}

const CAPSULE_RADIUS := 0.4
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.0
const QUERY_RADIUS := 0.36  # slightly thinner than the capsule so queries ignore walls we're touching
const WORLD_MASK := 1
const UP := Vector3.UP

const CHEST_HEIGHT := 1.1
const HEAD_HEIGHT := 1.6
const KNEE_HEIGHT := 0.5

var player: Player
var tuning: MovementTuning
var router: InputRouter

var state: State = State.AIR
var state_time: float = 0.0
var crouched: bool = false

var double_jump_ready: bool = true
var time_since_ground: float = 0.0
var jumped_since_ground: bool = false

var wall_normal: Vector3 = Vector3.ZERO
## +1 wall on the right, -1 on the left (for camera tilt). 0 when not on a wall.
var wall_side: int = 0

var grapple_cooldown_left: float = 0.0
var grapple_point: Vector3 = Vector3.ZERO

## Read-only contact data for presentation (first-person hands, camera).
## Movement never reads these back.
var wall_point: Vector3 = Vector3.ZERO      ## current wall contact (wall-run / climb)
var ledge_point: Vector3 = Vector3.ZERO     ## lip of the ledge being mantled/vaulted
var ledge_dir: Vector3 = Vector3.FORWARD    ## horizontal direction over the ledge
var mantle_is_vault: bool = false

## Momentum flow meter 0..1 (prototype, tuning.momentum_enabled). Chained moves
## fill it; standing around drains it. See docs/MOMENTUM.md.
var flow: float = 0.0

var _clock: float = 0.0
var _pre_move_vy: float = 0.0
var _jump_cut_armed: bool = false
var _sprint_toggled: bool = false

var _blocked_wall_id: int = 0
var _last_climb_wall_id: int = 0  # one climb per wall per airtime; a different wall allows another
var _blocked_wall_normal: Vector3 = Vector3.ZERO
var _wall_cooldown: float = 0.0
var _wall_coyote_left: float = 0.0  # jump shortly after running off a wall still wall-kicks
var _coyote_wall: Dictionary = {}
var _wall_away_time: float = 0.0

var _slide_chain: int = 0
var _last_slide_time: float = -INF

var _mantle_from: Vector3
var _mantle_to: Vector3
var _mantle_duration: float = 0.2
var _mantle_exit_velocity: Vector3
var _mantle_is_vault: bool = false
var _mantle_node: Node3D  # ledge owner; the destination rides along if it moves
var _mantle_local_to: Vector3

## Velocity of the moving surface we're attached to (wall-run/climb), so the
## run is computed relative to the wall and a moving wall carries you.
var _surface_vel: Vector3 = Vector3.ZERO

var _grapple_node: Node3D
var _grapple_local: Vector3

var _shape_node: CollisionShape3D
var _capsule: CapsuleShape3D
var _stand_query: CapsuleShape3D
var _crouch_query: CapsuleShape3D
var _ray_query: PhysicsRayQueryParameters3D
var _shape_query: PhysicsShapeQueryParameters3D


func setup(p_player: Player, p_shape_node: CollisionShape3D) -> void:
	player = p_player
	tuning = p_player.tuning
	router = p_player.router
	_shape_node = p_shape_node
	_capsule = CapsuleShape3D.new()
	_capsule.radius = CAPSULE_RADIUS
	_capsule.height = STAND_HEIGHT
	_shape_node.shape = _capsule
	_shape_node.position.y = STAND_HEIGHT * 0.5
	_stand_query = CapsuleShape3D.new()
	_stand_query.radius = QUERY_RADIUS
	_stand_query.height = STAND_HEIGHT - 0.04
	_crouch_query = CapsuleShape3D.new()
	_crouch_query.radius = QUERY_RADIUS
	_crouch_query.height = CROUCH_HEIGHT - 0.04
	_ray_query = PhysicsRayQueryParameters3D.new()
	_ray_query.collision_mask = WORLD_MASK
	_ray_query.exclude = [player.get_rid()]
	_shape_query = PhysicsShapeQueryParameters3D.new()
	_shape_query.collision_mask = WORLD_MASK
	_shape_query.exclude = [player.get_rid()]


func reset_to(_position: Vector3) -> void:
	player.global_position = _position
	player.velocity = Vector3.ZERO
	_set_crouched(false)
	double_jump_ready = true
	grapple_cooldown_left = 0.0
	_blocked_wall_id = 0
	_last_climb_wall_id = 0
	flow = 0.0
	state = State.AIR
	state_time = 0.0


# --------------------------------------------------------------------------- step

func physics_step(delta: float) -> void:
	_clock += delta
	state_time += delta
	_wall_cooldown = maxf(0.0, _wall_cooldown - delta)
	_wall_coyote_left = maxf(0.0, _wall_coyote_left - delta)
	if state != State.GRAPPLE:
		grapple_cooldown_left = maxf(0.0, grapple_cooldown_left - delta)
	if not player.is_on_floor():
		time_since_ground += delta
	_update_toggles()
	_decay_flow(delta)

	match state:
		State.GROUND: _tick_ground(delta)
		State.AIR: _tick_air(delta)
		State.SLIDE: _tick_slide(delta)
		State.WALLRUN: _tick_wallrun(delta)
		State.WALLCLIMB: _tick_wallclimb(delta)
		State.MANTLE: _tick_mantle(delta)
		State.GRAPPLE: _tick_grapple(delta)

	if state == State.MANTLE:
		return  # mantle drives position directly along a path we already verified is clear
	_apply_speed_caps(delta)
	_pre_move_vy = player.velocity.y
	player.move_and_slide()


# --------------------------------------------------------------------------- states

func _tick_ground(delta: float) -> void:
	if not player.is_on_floor():
		# Walked off a ledge. Momentum: kept. Coyote time starts.
		_set_state(State.AIR)
		return
	_refresh_on_ground()
	if _try_grapple():
		return
	var wish := _wish_dir()
	var h_speed := _h(player.velocity).length()

	if router.buffered(InputRouter.Action.JUMP, tuning.jump_buffer):
		router.consume(InputRouter.Action.JUMP)
		# Jumping into a ledge you couldn't clear mantles straight onto it.
		if wish.length() > 0.3 and _try_mantle(wish, tuning.ground_mantle_max_height, false, _jump_velocity(tuning.jump_height)):
			return
		_do_ground_jump(JumpKind.GROUND)
		return

	if router.just_pressed(InputRouter.Action.CROUCH) and h_speed >= tuning.slide_min_start_speed:
		_enter_slide()
		return

	# Fast into waist-high cover = vault (speed kept). Any speed into a knee-high step = step up.
	if wish.length() > 0.3 and router.move_vector().y > 0.3:
		var vault_h := tuning.vault_max_height if h_speed >= tuning.vault_min_speed else 0.55
		if _try_mantle(wish, vault_h, true, 0.0):
			return

	_set_crouched(_crouch_intent())
	_ground_move(delta, wish)


func _tick_air(delta: float) -> void:
	var v := player.velocity
	if player.is_on_floor() and v.y <= 0.01:
		_land()
		return
	if _try_grapple():
		return
	var wish := _wish_dir()

	if router.buffered(InputRouter.Action.JUMP, tuning.jump_buffer):
		if not jumped_since_ground and time_since_ground <= tuning.coyote_time:
			router.consume(InputRouter.Action.JUMP)
			_do_ground_jump(JumpKind.GROUND)
			return
		if _wall_coyote_left > 0.0:
			router.consume(InputRouter.Action.JUMP)
			wall_normal = _coyote_wall.normal
			_do_wall_kick(_coyote_wall)
			return
		var wall := _probe_wall(tuning.wall_attach_distance * 0.5)
		if not wall.is_empty() and not _is_blocked_wall(wall):
			router.consume(InputRouter.Action.JUMP)
			wall_normal = wall.normal
			_do_wall_kick(wall)
			return
		if double_jump_ready:
			router.consume(InputRouter.Action.JUMP)
			_do_double_jump(wish)
			return
		# Otherwise the press stays buffered: landing inside the window jumps instantly.

	if router.move_vector().y > 0.3 and _try_mantle(wish, tuning.mantle_max_height, false, v.y):
		return
	if _wall_cooldown <= 0.0 and _try_wall_attach():
		return

	if _jump_cut_armed:
		if v.y <= 0.0:
			_jump_cut_armed = false
		elif router.just_released(InputRouter.Action.JUMP):
			v.y *= tuning.jump_cut_mult
			_jump_cut_armed = false
			player.velocity = v

	_air_move(delta, wish, 1.0)
	_apply_gravity(delta, 1.0)


func _tick_slide(delta: float) -> void:
	if not player.is_on_floor():
		# Slid off a ledge. Momentum: kept. Coyote jump still works (slide-hop off edges).
		_set_state(State.AIR)
		return
	_refresh_on_ground()
	if _try_grapple():
		return
	var v := player.velocity
	var h := _h(v)
	var speed := h.length()

	if router.buffered(InputRouter.Action.JUMP, tuning.jump_buffer):
		# Slide-hop. Momentum: full horizontal speed kept (no ground friction tick).
		router.consume(InputRouter.Action.JUMP)
		_do_ground_jump(JumpKind.SLIDE_HOP)
		return
	if speed < tuning.slide_exit_speed:
		_set_state(State.GROUND)
		return
	if state_time >= tuning.slide_min_time and not _crouch_intent() and _can_stand():
		_set_state(State.GROUND)
		return

	var dir := h / maxf(speed, 0.001)
	var wish := _wish_dir()
	if wish.length() > 0.2:
		dir = _rotate_toward(dir, wish.normalized(), tuning.slide_steer * delta)
	speed = maxf(0.0, speed - tuning.slide_decel * delta)
	# Gravity along the floor plane: downhill speeds you up, uphill slows you down.
	var n := player.get_floor_normal()
	var g := Vector3.DOWN * tuning.gravity
	var along := _h(g - n * g.dot(n)) * tuning.slide_slope_mult
	h = dir * speed + along * delta
	player.velocity = Vector3(h.x, v.y - tuning.gravity * delta, h.z)


func _tick_wallrun(delta: float) -> void:
	var v := player.velocity
	if player.is_on_floor():
		_land()
		return
	if _try_grapple():
		return
	var wall := _probe_wall_dir(-wall_normal, tuning.wall_attach_distance + 0.25)
	if wall.is_empty() or wall.normal.dot(wall_normal) < 0.7:
		# Ran off the end of the wall. Momentum: kept (minus the press into the wall).
		_coyote_wall = {"normal": wall_normal, "collider_id": _blocked_wall_id}
		_leave_wall(0.0)
		_wall_coyote_left = tuning.coyote_time
		return
	wall_normal = wall.normal
	wall_point = wall.point
	_block_wall(wall)
	var wall_vel: Vector3 = wall.velocity
	v -= _surface_vel  # work in the wall's frame

	if router.buffered(InputRouter.Action.JUMP, tuning.jump_buffer):
		router.consume(InputRouter.Action.JUMP)
		_do_wall_kick(wall)
		return
	if router.just_pressed(InputRouter.Action.CROUCH):
		_leave_wall(1.5)
		return
	var wish := _wish_dir()
	_wall_away_time = _wall_away_time + delta if wish.dot(wall_normal) > tuning.wallrun_detach_input else 0.0
	if _wall_away_time > 0.08 or state_time >= tuning.wallrun_max_time:
		_leave_wall(1.5)
		return

	var tangent := _wall_tangent(wall_normal, _h(v))
	if _try_mantle(tangent, tuning.mantle_max_height, false, v.y):
		return

	var along := _h(v).dot(tangent)
	if along < tuning.wallrun_min_speed * 0.6:
		_leave_wall(1.0)
		return
	var fwd := router.move_vector().y
	if along < tuning.wallrun_target_speed and fwd > 0.2:
		along = move_toward(along, tuning.wallrun_target_speed, tuning.wallrun_accel * delta)
	elif along > tuning.wallrun_target_speed:
		along = maxf(tuning.wallrun_target_speed, along - tuning.wallrun_overspeed_decel * (1.0 - _flow_amount() * tuning.momentum_wallrun_keep) * delta)
	if fwd < -0.3:
		along = maxf(0.0, along - 12.0 * delta)
	var g := lerpf(tuning.wallrun_gravity_start, tuning.wallrun_gravity_end, clampf(state_time / tuning.wallrun_gravity_ramp, 0.0, 1.0))
	var vy := maxf(v.y - g * delta, -tuning.wallrun_max_fall)
	var h := tangent * along - wall_normal * 1.0  # slight press into the wall keeps contact
	player.velocity = Vector3(h.x, vy, h.z) + wall_vel
	_surface_vel = wall_vel
	wall_side = _side_of(wall_normal, tangent)


func _tick_wallclimb(delta: float) -> void:
	if player.is_on_floor():
		_land()
		return
	if _try_grapple():
		return
	# Topping out: mantle takes priority over everything else here.
	if _try_mantle(-wall_normal, tuning.mantle_max_height, false, -INF):
		return
	var wall := _probe_wall_dir(-wall_normal, tuning.wall_attach_distance + 0.3)
	if wall.is_empty():
		_leave_wall(0.0)
		return
	wall_normal = wall.normal
	wall_point = wall.point
	_block_wall(wall)

	if router.buffered(InputRouter.Action.JUMP, tuning.jump_buffer):
		router.consume(InputRouter.Action.JUMP)
		if router.move_vector().y > 0.3 and not _wall_behind():
			# Still pushing into the wall with open air behind: you want up, not
			# off. Hop up the face (no push-off, no turn); the air mantle grabs the
			# lip if it's in reach. With a wall behind (a chimney), kick across.
			var hop := -wall_normal * 1.0
			player.velocity = Vector3(hop.x, maxf(player.velocity.y, tuning.climb_hop_up), hop.z) + wall.velocity
			_set_state(State.AIR)
			jumped.emit(JumpKind.CLIMB_HOP)
			return
		# Climb kick: push straight back off the wall and (optionally) turn 180.
		var out := wall_normal * tuning.climb_kick_out
		player.velocity = Vector3(out.x, tuning.climb_kick_up, out.z)
		_momentum_link(true)
		_wall_cooldown = tuning.wall_reattach_delay
		if tuning.climb_kick_auto_turn:
			player.request_turn_to(wall_normal, tuning.climb_turn_time)
		_set_state(State.AIR)
		jumped.emit(JumpKind.CLIMB_KICK)
		return
	if router.just_pressed(InputRouter.Action.CROUCH) or state_time >= tuning.climb_time:
		_leave_wall(0.8)
		return

	var vy := tuning.climb_speed * (1.0 - state_time / tuning.climb_time)
	var press := -wall_normal * 0.5
	var wall_vel: Vector3 = wall.velocity
	player.velocity = Vector3(press.x, vy, press.z) + wall_vel
	_surface_vel = wall_vel


func _tick_mantle(_delta: float) -> void:
	var carry := Vector3.ZERO
	if _mantle_node and is_instance_valid(_mantle_node):
		_mantle_to = _mantle_node.to_global(_mantle_local_to)
		carry = _surface_velocity(_mantle_node, _mantle_to)
	var p := clampf(state_time / _mantle_duration, 0.0, 1.0)
	var up_p := mantle_lift_curve(p, tuning.mantle_lift_ease)
	# Over the edge (smoothstep) only once the lift is ~60% done, so the path
	# hugs the wall face and never cuts through the lip. A gentler lift starts
	# the forward move later to keep that clearance.
	var fwd_p := smoothstep(lerpf(0.25, 0.4, tuning.mantle_lift_ease), 1.0, p)
	var pos := Vector3(
		lerpf(_mantle_from.x, _mantle_to.x, fwd_p),
		lerpf(_mantle_from.y, _mantle_to.y, up_p),
		lerpf(_mantle_from.z, _mantle_to.z, fwd_p))
	player.global_position = pos
	if p >= 1.0:
		# Momentum: vault keeps entry speed; mantle exits at max(exit speed, kept fraction).
		player.velocity = _mantle_exit_velocity + carry + Vector3.DOWN * 2.0
		_set_state(State.AIR)


func _tick_grapple(delta: float) -> void:
	var anchor := _grapple_world_point()
	var eye := player.global_position + UP * 1.0
	var to := anchor - eye
	var dist := to.length()
	# Hold to stay attached, release to let go. A quick tap still gets a short yank.
	var released := not router.is_held(InputRouter.Action.GRAPPLE) and state_time >= tuning.grapple_min_time
	if released or not _grapple_valid():
		_end_grapple()
		return
	if router.buffered(InputRouter.Action.JUMP, tuning.jump_buffer):
		# Jump releases; it spends the double jump if you have one (no free refresh).
		router.consume(InputRouter.Action.JUMP)
		_end_grapple()
		if double_jump_ready:
			_do_double_jump(_wish_dir())
		return
	if dist < tuning.grapple_release_distance or state_time >= tuning.grapple_max_time:
		_end_grapple()
		return
	if _try_mantle(_h(to), tuning.mantle_max_height, false, -INF):
		return
	var los := _ray(eye, anchor)
	if not los.is_empty() and eye.distance_to(los.position) < dist - 0.75:
		_end_grapple()
		return

	var dir := to / dist
	var v := player.velocity
	v += dir * tuning.grapple_pull_accel * delta
	var radial := v.dot(dir)
	if radial > tuning.grapple_max_speed:
		v -= dir * (radial - tuning.grapple_max_speed)
	player.velocity = v
	_air_move(delta, _wish_dir(), tuning.grapple_air_control)
	_apply_gravity(delta, tuning.grapple_gravity_mult)
	grapple_point = anchor


# --------------------------------------------------------------------------- transitions

func _set_state(next: State) -> void:
	if next == state:
		state_time = 0.0
		return
	assert(TRANSITIONS[state].has(next), "Illegal movement transition %s -> %s" % [STATE_NAMES[state], STATE_NAMES[next]])
	var prev := state
	# Exit rules
	match prev:
		State.GRAPPLE:
			grapple_cooldown_left = tuning.grapple_cooldown
			_grapple_node = null
			grapple_released.emit()
		State.WALLRUN, State.WALLCLIMB:
			wall_side = 0
			_wall_away_time = 0.0
			_surface_vel = Vector3.ZERO
	state = next
	state_time = 0.0
	# Enter rules
	match next:
		State.SLIDE:
			_set_crouched(true)
		State.AIR, State.WALLRUN, State.WALLCLIMB, State.GRAPPLE:
			_set_crouched(false)
	state_changed.emit(prev, next)


func _land() -> void:
	var impact := maxf(0.0, -_pre_move_vy)
	_refresh_on_ground()
	landed.emit(impact)
	var speed := _h(player.velocity).length()
	var fall_bonus := _slide_landing_bonus(impact)
	if _crouch_intent() and speed + fall_bonus >= tuning.slide_min_start_speed and speed > 1.0:
		# Landing into a slide. Momentum: kept, plus the (diminishing) slide boost,
		# plus (momentum prototype) part of a hard fall's speed.
		_enter_slide()
		if fall_bonus > 0.0:  # after the slide boost, so its cap doesn't eat the bonus
			var h := _h(player.velocity)
			h = h.normalized() * (h.length() + fall_bonus)
			player.velocity = Vector3(h.x, player.velocity.y, h.z)
			momentum_boosted.emit(fall_bonus)
		_momentum_link(false)
		if router.buffered(InputRouter.Action.JUMP, tuning.jump_buffer):
			router.consume(InputRouter.Action.JUMP)
			_do_ground_jump(JumpKind.SLIDE_HOP)
		return
	if router.buffered(InputRouter.Action.JUMP, tuning.jump_buffer):
		# Bunny hop: buffered jump fires on the landing tick, before any friction.
		router.consume(InputRouter.Action.JUMP)
		_set_state(State.GROUND)
		_do_ground_jump(JumpKind.GROUND)
		return
	_set_state(State.GROUND)


func _refresh_on_ground() -> void:
	time_since_ground = 0.0
	jumped_since_ground = false
	double_jump_ready = true
	_blocked_wall_id = 0
	_last_climb_wall_id = 0


func _do_ground_jump(kind: JumpKind) -> void:
	var v := player.velocity
	v.y = _jump_velocity(tuning.jump_height)
	player.velocity = v
	jumped_since_ground = true
	_jump_cut_armed = kind == JumpKind.GROUND
	_set_state(State.AIR)
	if kind == JumpKind.SLIDE_HOP:
		_momentum_link(false)
	jumped.emit(kind)


func _do_double_jump(wish: Vector3) -> void:
	# Momentum: speed kept (or raised to air speed), direction bends toward input.
	double_jump_ready = false
	var v := player.velocity
	var h := _h(v)
	var speed := h.length()
	if wish.length() > 0.2:
		var wdir := wish.normalized()
		var dir := h / speed if speed > 0.1 else wdir
		var blended := dir.lerp(wdir, tuning.double_jump_redirect)
		dir = blended.normalized() if blended.length() > 0.05 else wdir
		h = dir * maxf(speed, tuning.air_speed * wish.length())
	v = Vector3(h.x, maxf(v.y, _jump_velocity(tuning.double_jump_height)), h.z)
	player.velocity = v
	_jump_cut_armed = false
	jumped.emit(JumpKind.DOUBLE)


func _do_wall_kick(wall: Dictionary) -> void:
	# Momentum: along-wall speed kept, plus an outward push; direction blends toward look.
	var n := wall_normal
	var v := player.velocity
	var h := _h(v)
	var along_dir := h.normalized() if h.length() > 0.5 else _wall_tangent(n, _look_h())
	along_dir = (along_dir - n * along_dir.dot(n))
	along_dir = along_dir.normalized() if along_dir.length() > 0.05 else Vector3.ZERO
	var speed := maxf(h.dot(along_dir), tuning.wallkick_min_speed * 0.7)
	var base := along_dir * speed + n * tuning.wallkick_out
	var magnitude := maxf(base.length(), tuning.wallkick_min_speed)
	var dir := base.normalized().lerp(_look_h(), tuning.wallkick_look_blend)
	dir = _ensure_away(dir, n, tuning.wallkick_min_out_dot)
	var out := dir * magnitude
	player.velocity = Vector3(out.x, tuning.wallkick_up, out.z)
	_momentum_link(true)
	_block_wall(wall)
	_wall_cooldown = tuning.wall_reattach_delay
	_wall_coyote_left = 0.0
	_set_state(State.AIR)
	jumped.emit(JumpKind.WALL_KICK)


func _leave_wall(push: float) -> void:
	var v := player.velocity
	v -= wall_normal * minf(0.0, v.dot(wall_normal))  # never carry the wall press into the next surface
	player.velocity = v + wall_normal * push
	# Running off the end (push 0) can grab the next wall right away; letting go can't.
	_wall_cooldown = tuning.wall_reattach_delay if push > 0.0 else 0.0
	_set_state(State.AIR)


func _enter_slide() -> void:
	var v := player.velocity
	var h := _h(v)
	var speed := h.length()
	if _clock - _last_slide_time > tuning.slide_boost_chain_window:
		_slide_chain = 0
	var boost := tuning.slide_boost * pow(tuning.slide_boost_chain_mult, _slide_chain)
	var boosted := minf(speed + boost, maxf(speed, tuning.slide_boost_max_speed))
	if speed > 0.1:
		h = h / speed * boosted
	_slide_chain += 1
	_last_slide_time = _clock
	player.velocity = Vector3(h.x, v.y, h.z)
	_set_state(State.SLIDE)
	slide_started.emit()


func _try_wall_attach() -> bool:
	if router.move_vector().y < 0.2:
		return false  # hold forward to wall-run or climb: no accidental attaches
	var wall := _probe_wall(tuning.wall_attach_distance)
	if wall.is_empty() or _is_blocked_wall(wall):
		return false
	var n: Vector3 = wall.normal
	var v := player.velocity
	var h := _h(v)
	if h.dot(n) > 1.0:
		return false  # moving away from it
	if _height_above_ground() < tuning.wallrun_min_height:
		return false
	var into := -n
	var look_h := _look_h()
	# Head-on = climb, glancing = wall-run (DESIGN §4.3).
	if wall.collider_id != _last_climb_wall_id and look_h.dot(into) >= cos(deg_to_rad(tuning.climb_angle)) and v.y > -tuning.climb_max_fall:
		_enter_wallclimb(wall)
		return true
	var tangent := _wall_tangent(n, h if h.length() > 0.5 else look_h)
	if h.dot(tangent) >= tuning.wallrun_min_speed:
		_enter_wallrun(wall, tangent)
		return true
	return false


func _enter_wallrun(wall: Dictionary, tangent: Vector3) -> void:
	# Momentum: horizontal speed magnitude kept and redirected along the wall;
	# falls are arrested, big upward speed is capped.
	wall_normal = wall.normal
	wall_point = wall.point
	_block_wall(wall)
	var wall_vel: Vector3 = wall.velocity
	var v := player.velocity - wall_vel
	var h := tangent * maxf(_h(v).length(), tuning.wallrun_min_speed)
	player.velocity = Vector3(h.x, clampf(v.y, tuning.wallrun_entry_min_vy, tuning.wallrun_entry_max_up), h.z) + wall_vel
	_surface_vel = wall_vel
	double_jump_ready = true
	wall_side = _side_of(wall_normal, tangent)
	_set_state(State.WALLRUN)
	_momentum_link(false)


func _enter_wallclimb(wall: Dictionary) -> void:
	# Momentum: horizontal speed spent on the climb; vertical set by the climb curve.
	wall_normal = wall.normal
	wall_point = wall.point
	_block_wall(wall)
	_last_climb_wall_id = wall.collider_id
	double_jump_ready = true
	player.velocity = Vector3(0.0, tuning.climb_speed, 0.0) + wall.velocity
	_surface_vel = wall.velocity
	_set_state(State.WALLCLIMB)


## `vy` is the current vertical speed: if you would clear the ledge anyway,
## no mantle (never slow down a jump that was going to make it).
func _try_mantle(dir: Vector3, max_height: float, is_vault: bool, vy: float) -> bool:
	dir = _h(dir)
	if dir.length() < 0.1:
		return false
	dir = dir.normalized()
	var ledge := _find_ledge(dir, max_height)
	if ledge.is_empty():
		return false
	var ledge_h: float = ledge.height
	if vy > 0.0:
		var apex := vy * vy / (2.0 * tuning.gravity)
		if apex >= ledge_h + 0.3:
			return false
	var v := player.velocity
	var speed_in := _h(v).length()
	_mantle_from = player.global_position
	_mantle_to = ledge.dest
	_mantle_node = ledge.node
	_mantle_local_to = _mantle_node.to_local(_mantle_to) if _mantle_node else _mantle_to
	_mantle_is_vault = is_vault
	mantle_is_vault = is_vault
	ledge_point = ledge.lip
	ledge_dir = dir
	if is_vault:
		_mantle_duration = tuning.vault_time * clampf(ledge_h / 1.0, 0.5, 1.2)
		_mantle_exit_velocity = dir * speed_in
	else:
		_mantle_duration = tuning.mantle_time_base + tuning.mantle_time_per_meter * maxf(ledge_h, 0.0)
		_mantle_exit_velocity = dir * maxf(tuning.mantle_exit_speed, speed_in * tuning.mantle_speed_keep)
	_set_state(State.MANTLE)
	mantled.emit(is_vault)
	return true


func _try_grapple() -> bool:
	if not router.just_pressed(InputRouter.Action.GRAPPLE):
		return false
	if grapple_cooldown_left > 0.0:
		grapple_missed.emit()
		return false
	var target := _find_grapple_target()
	if target.is_empty():
		grapple_cooldown_left = tuning.grapple_miss_cooldown
		grapple_missed.emit()
		return false
	_grapple_node = target.node
	_grapple_local = _grapple_node.to_local(target.point) if _grapple_node else target.point
	grapple_point = target.point
	var v := player.velocity
	if player.is_on_floor():
		v.y = maxf(v.y, tuning.grapple_ground_lift)
	player.velocity = v
	_set_state(State.GRAPPLE)
	grapple_attached.emit(grapple_point)
	return true


## External impulse from level features (jump pads). Momentum: replaced by
## the pad's launch velocity; double jump refreshed.
func launch(launch_velocity: Vector3) -> void:
	if state == State.MANTLE:
		return
	player.velocity = launch_velocity
	double_jump_ready = true
	jumped_since_ground = true
	_jump_cut_armed = false
	_set_state(State.AIR)
	jumped.emit(JumpKind.GROUND)


func _end_grapple() -> void:
	_set_state(State.GROUND if player.is_on_floor() else State.AIR)
	if state == State.AIR:
		_momentum_link(true)


# --------------------------------------------------------------------------- momentum (prototype)

## Current meter, or 0 while the prototype is off.
func _flow_amount() -> float:
	return flow if tuning.momentum_enabled else 0.0


## Soft speed cap, raised by the flow meter.
func soft_speed_cap() -> float:
	return tuning.soft_speed_cap + _flow_amount() * tuning.momentum_cap_bonus


## A chained move: fills the meter; `kick` moves also push you faster (scaled by
## the meter, never past the raised soft cap).
func _momentum_link(kick: bool) -> void:
	if not tuning.momentum_enabled:
		return
	flow = minf(1.0, flow + tuning.momentum_link_gain)
	momentum_linked.emit(flow)
	if not kick:
		return
	var v := player.velocity
	var h := _h(v)
	var speed := h.length()
	if speed < 0.5:
		return
	var boosted := minf(speed + tuning.momentum_kick_speed * flow, maxf(speed, soft_speed_cap()))
	h = h / speed * boosted
	player.velocity = Vector3(h.x, v.y, h.z)
	if boosted - speed > 0.3:
		momentum_boosted.emit(boosted - speed)


## Speed a slide landing gains from a fall this fast (0 for ordinary hops).
func _slide_landing_bonus(impact: float) -> float:
	if not tuning.momentum_enabled:
		return 0.0
	return minf((impact - tuning.momentum_land_min_impact) * tuning.momentum_land_convert, tuning.momentum_land_max) if impact > tuning.momentum_land_min_impact else 0.0


## Chains live in the air and on walls; a little time on foot drains them.
func _decay_flow(delta: float) -> void:
	if not tuning.momentum_enabled:
		flow = 0.0
		return
	match state:
		State.GROUND:
			if state_time > tuning.momentum_ground_grace:
				flow = maxf(0.0, flow - tuning.momentum_ground_decay * delta)
		State.AIR:
			flow = maxf(0.0, flow - tuning.momentum_air_decay * delta)


# --------------------------------------------------------------------------- movement helpers

func _ground_move(delta: float, wish: Vector3) -> void:
	var v := player.velocity
	var h := _h(v)
	var speed := h.length()
	var max_speed := _max_ground_speed()
	if wish.length() > 0.01:
		if speed > max_speed + 0.01:
			# Overspeed (e.g. landed from a slide-hop): bleed off gradually and steer.
			var dir := _rotate_toward(h / speed, wish.normalized(), tuning.overspeed_turn_rate * delta)
			h = dir * maxf(max_speed, speed - tuning.overspeed_decel * delta)
		else:
			h = h.move_toward(wish * max_speed, tuning.ground_accel * delta)
	else:
		h = h.move_toward(Vector3.ZERO, tuning.ground_decel * delta)
	player.velocity = Vector3(h.x, v.y - tuning.gravity * delta, h.z)


func _max_ground_speed() -> float:
	if crouched:
		return tuning.crouch_speed
	var mv := router.move_vector()
	if mv.length() < 0.05:
		return tuning.walk_speed
	var forwardness := mv.normalized().y
	var sprinting := player.settings.auto_sprint or router.is_held(InputRouter.Action.SPRINT) or _sprint_toggled
	if router.is_held(InputRouter.Action.ADS):
		sprinting = false  # aiming drops you to walk speed (Titanfall)
	return tuning.sprint_speed if sprinting and forwardness > 0.64 else tuning.walk_speed


## Quake-style air acceleration: steer and strafe without gaining speed by
## holding forward. The soft cap stops strafe speed from running away.
func _air_move(delta: float, wish: Vector3, control: float) -> void:
	var mag := wish.length()
	if mag < 0.01:
		return
	var v := player.velocity
	var wdir := wish / mag
	var wish_speed := tuning.air_speed * mag
	var add := wish_speed - _h(v).dot(wdir)
	if add <= 0.0:
		return
	var accel := minf(tuning.air_accel * control * wish_speed * delta, add)
	player.velocity = v + wdir * accel


func _apply_gravity(delta: float, mult: float) -> void:
	var v := player.velocity
	var g := tuning.gravity * mult
	if v.y < 0.0:
		g *= tuning.fall_gravity_mult
	v.y = maxf(v.y - g * delta, -tuning.max_fall_speed)
	player.velocity = v


func _apply_speed_caps(delta: float) -> void:
	var v := player.velocity
	var h := _h(v)
	var speed := h.length()
	var cap := soft_speed_cap()
	if speed <= cap:
		return
	var capped := minf(maxf(cap, speed - tuning.soft_cap_decay * delta), tuning.hard_speed_cap)
	h = h / speed * capped
	player.velocity = Vector3(h.x, v.y, h.z)


func _update_toggles() -> void:
	# Sprint: Shift is hold; pad L3 is a toggle that lasts until you stop or back off.
	if router.just_pressed(InputRouter.Action.SPRINT) and router.last_device_was_pad:
		_sprint_toggled = not _sprint_toggled
	if router.move_vector().length() < 0.1 or router.move_vector().y < 0.0:
		_sprint_toggled = false


## Crouch/slide is always hold: hold to slide, release to stand (like the grapple).
func _crouch_intent() -> bool:
	return router.is_held(InputRouter.Action.CROUCH)


func _jump_velocity(height: float) -> float:
	return sqrt(2.0 * tuning.gravity * height)


# --------------------------------------------------------------------------- queries

func _wish_dir() -> Vector3:
	var mv := router.move_vector()
	var basis := Basis(UP, player.yaw)
	return basis * Vector3(mv.x, 0.0, -mv.y)


func _look_h() -> Vector3:
	return Basis(UP, player.yaw) * Vector3.FORWARD


func look_dir() -> Vector3:
	return Basis(UP, player.yaw) * Basis(Vector3.RIGHT, player.pitch) * Vector3.FORWARD


static func _h(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _rotate_toward(from: Vector3, to: Vector3, max_angle: float) -> Vector3:
	var angle := from.signed_angle_to(to, UP)
	return from.rotated(UP, clampf(angle, -max_angle, max_angle))


static func _wall_tangent(n: Vector3, reference: Vector3) -> Vector3:
	var t := n.cross(UP).normalized()
	return t if t.dot(reference) >= 0.0 else -t


static func _side_of(n: Vector3, tangent: Vector3) -> int:
	var right := tangent.cross(UP)
	return 1 if n.dot(right) < 0.0 else -1


static func _ensure_away(dir: Vector3, n: Vector3, min_dot: float) -> Vector3:
	dir = _h(dir).normalized()
	var d := dir.dot(n)
	if d >= min_dot:
		return dir
	var lateral := dir - n * d
	lateral = lateral.normalized() if lateral.length() > 0.01 else Vector3.ZERO
	return (lateral * sqrt(1.0 - min_dot * min_dot) + n * min_dot).normalized()


## A wall behind you while climbing (within kick range): a chimney.
func _wall_behind() -> bool:
	var from := player.global_position + UP * CHEST_HEIGHT
	var hit := _ray(from, from + wall_normal * tuning.climb_chimney_reach)
	return not hit.is_empty() and absf(hit.normal.y) < 0.3


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	_ray_query.from = from
	_ray_query.to = to
	return player.get_world_3d().direct_space_state.intersect_ray(_ray_query)


func _shape_blocked(shape: Shape3D, feet: Vector3, height: float) -> bool:
	_shape_query.shape = shape
	_shape_query.transform = Transform3D(Basis.IDENTITY, feet + UP * (height * 0.5 + 0.02))
	return not player.get_world_3d().direct_space_state.intersect_shape(_shape_query, 1).is_empty()


func _can_stand() -> bool:
	return not _shape_blocked(_stand_query, player.global_position, STAND_HEIGHT)


func _set_crouched(value: bool) -> void:
	if value == crouched:
		return
	if not value and not _can_stand():
		return
	crouched = value
	var height := CROUCH_HEIGHT if value else STAND_HEIGHT
	_capsule.height = height
	_shape_node.position.y = height * 0.5


## Wall = near-vertical surface covering chest height and (knee or head).
## Low cover never counts, floating panels at head height do.
func _probe_wall(reach: float) -> Dictionary:
	var best := {}
	var best_d := INF
	var dirs: Array[Vector3] = []
	for i in 8:
		dirs.append(Vector3.FORWARD.rotated(UP, player.yaw + i * TAU / 8.0))
	var h := _h(player.velocity)
	if h.length() > 0.5:
		dirs.append(h.normalized())
	for d in dirs:
		var hit := _probe_wall_dir(d, reach)
		if hit.is_empty():
			continue
		if hit.distance < best_d:
			best_d = hit.distance
			best = hit
	return best


func _probe_wall_dir(dir: Vector3, reach: float) -> Dictionary:
	var feet := player.global_position
	var length := CAPSULE_RADIUS + reach
	var chest_from := feet + UP * CHEST_HEIGHT
	var chest := _ray(chest_from, chest_from + dir * length)
	if chest.is_empty() or absf(chest.normal.y) > 0.3:
		return {}
	var ok := false
	for height in [KNEE_HEIGHT, HEAD_HEIGHT]:
		var from: Vector3 = feet + UP * height
		var hit := _ray(from, from + dir * length)
		if not hit.is_empty() and absf(hit.normal.y) <= 0.3:
			ok = true
			break
	if not ok:
		return {}
	var n := _h(chest.normal).normalized()
	# Confirm the face is really beside us: a ray straight into it (along -n)
	# must hit the same surface. This rejects a wall's thin end cap caught by a
	# diagonal probe when the capsule would never touch it.
	var perp := _ray(chest_from, chest_from - n * length)
	if perp.is_empty() or perp.collider_id != chest.collider_id or _h(perp.normal).normalized().dot(n) < 0.9:
		return {}
	return {
		"normal": n,
		"point": perp.position,
		"collider_id": chest.collider_id,
		"distance": chest_from.distance_to(perp.position),
		"velocity": _surface_velocity(chest.collider, perp.position),
	}


static func _surface_velocity(collider: Object, point: Vector3) -> Vector3:
	if collider is Mover:
		return (collider as Mover).velocity_at(point)
	return Vector3.ZERO


func _block_wall(wall: Dictionary) -> void:
	_blocked_wall_id = wall.collider_id
	_blocked_wall_normal = wall.normal


func _is_blocked_wall(wall: Dictionary) -> bool:
	return wall.collider_id == _blocked_wall_id and wall.normal.dot(_blocked_wall_normal) > 0.9


func _height_above_ground() -> float:
	var feet := player.global_position
	var hit := _ray(feet + UP * 0.05, feet + Vector3.DOWN * 6.0)
	return INF if hit.is_empty() else feet.y - hit.position.y


## Finds a ledge top in `dir` within [mantle_min_height, max_height] above the
## feet, with a real face below it and room for the player on top.
func _find_ledge(dir: Vector3, max_height: float) -> Dictionary:
	var feet := player.global_position
	var probe := feet + dir * (CAPSULE_RADIUS + tuning.mantle_reach)
	var top := _ray(probe + UP * (max_height + 0.05), probe + UP * tuning.mantle_min_height)
	if top.is_empty() or top.normal.y < 0.7:
		return {}
	var ledge_y: float = top.position.y
	var ledge_h := ledge_y - feet.y
	if ledge_h < tuning.mantle_min_height or ledge_h > max_height:
		return {}
	# A near-vertical face just below the lip: this is a ledge, not a slope.
	var face_from := feet + UP * (ledge_h - 0.08)
	face_from.y = maxf(face_from.y, feet.y + 0.05)
	var face := _ray(face_from, face_from + dir * (CAPSULE_RADIUS + tuning.mantle_reach + 0.1))
	if face.is_empty() or absf(face.normal.y) > 0.35:
		return {}
	var dest: Vector3 = face.position + dir * (CAPSULE_RADIUS + 0.12)
	dest.y = ledge_y + 0.03
	# Room to rise straight up in place, and room at the destination.
	var lifted := Vector3(feet.x, dest.y, feet.z)
	if _shape_blocked(_crouch_query, lifted, CROUCH_HEIGHT):
		return {}
	if _shape_blocked(_crouch_query, dest, CROUCH_HEIGHT):
		return {}
	var head := _ray(feet + UP * (STAND_HEIGHT - 0.1), lifted + UP * (CROUCH_HEIGHT - 0.1))
	if not head.is_empty():
		return {}
	var lip: Vector3 = face.position
	lip.y = ledge_y
	return {"height": ledge_h, "dest": dest, "node": top.collider as Node3D, "lip": lip}


func _find_grapple_target() -> Dictionary:
	var eye := player.eye_position()
	var dir := look_dir()
	var best := {}
	var best_angle := deg_to_rad(tuning.grapple_magnet_angle)
	for node in player.get_tree().get_nodes_in_group(&"grapple_point"):
		var p: Vector3 = (node as Node3D).global_position
		var to := p - eye
		var dist := to.length()
		if dist > tuning.grapple_range or dist < 1.0:
			continue
		var angle := dir.angle_to(to)
		if angle > best_angle:
			continue
		var los := _ray(eye, p)
		if not los.is_empty() and los.position.distance_to(p) > 0.6:
			continue
		best_angle = angle
		best = {"point": p, "node": node}
	if not best.is_empty():
		return best
	var hit := _ray(eye, eye + dir * tuning.grapple_range)
	if hit.is_empty():
		return {}
	return {"point": hit.position, "node": hit.collider as Node3D}


func _grapple_valid() -> bool:
	return _grapple_node == null or is_instance_valid(_grapple_node)


func _grapple_world_point() -> Vector3:
	if _grapple_node and is_instance_valid(_grapple_node):
		return _grapple_node.to_global(_grapple_local)
	return grapple_point


## Height fraction of a mantle at progress `p`. The lift finishes at 70% of the
## mantle. `lift_ease` 0 is an ease-out (half the height in the first ~15%, so the
## ledge drops out of frame fast); 1 is an ease-in-out that keeps the lip and
## the hand plants in view longer. Total time is the same either way.
static func mantle_lift_curve(p: float, lift_ease: float) -> float:
	var x := clampf(p / 0.7, 0.0, 1.0)
	return lerpf(1.0 - (1.0 - x) * (1.0 - x), x * x * (3.0 - 2.0 * x), lift_ease)


## 0..1 through the current mantle/vault (0 outside a mantle).
func mantle_progress() -> float:
	return clampf(state_time / _mantle_duration, 0.0, 1.0) if state == State.MANTLE else 0.0


func state_name() -> String:
	return STATE_NAMES[state]
