extends Node3D
## Headless movement regression tests. Each scenario drives a real Player with
## scripted input on purpose-built geometry and asserts on the outcome.
##
## Run: godot --headless --path . --fixed-fps 120 res://tests/movement_tests.tscn

const A := InputRouter.Action
const S := PlayerMotor.State
const T := LevelBuilder.Tag

var player: Player
var router: InputRouter
var b: LevelBuilder
var failures: PackedStringArray = []
var passes: int = 0
var states_seen: Array = []
var jumps_seen: Array = []
var only: String = ""
var movers: Dictionary = {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr(7)
	b = LevelBuilder.new(self)
	_build_course()
	var vp := SubViewport.new()
	add_child(vp)
	router = InputRouter.new(PlayerSettings.new())
	router.scripted = true
	router.use_kbm = false
	player = Player.new()
	add_child(player)
	player.setup(0, router, MovementTuning.new(), vp)
	player.motor.state_changed.connect(func(_f: int, to: int) -> void: states_seen.append(to))
	player.motor.jumped.connect(func(k: int) -> void: jumps_seen.append(k))
	await _run_all()
	print("\n%d passed, %d failed" % [passes, failures.size()])
	for f in failures:
		print("  FAIL ", f)
	get_tree().quit(failures.size())


# Each lane sits at its own x offset so tests never interfere.
func _build_course() -> void:
	b.block(Vector3(-50, -1, -400), Vector3(2400, 0, 50))
	# 100: wall-run wall on the right (plane x=101.2), 60 m long.
	b.block(Vector3(101.2, 0, -70), Vector3(101.8, 7, -5), T.RUN)
	# 200: climb wall 4.2 m tall facing +Z at z=-3.
	b.block(Vector3(195, 0, -30), Vector3(205, 4.2, -3), T.RUN)
	# 300: 1.4 m ledge at z=-2.
	b.block(Vector3(295, 0, -30), Vector3(305, 1.4, -2))
	# 400: thin 1.0 m hurdle at z=-15.
	b.block(Vector3(395, 0, -15.4), Vector3(405, 1.0, -15))
	# 500: slide-under bar at 1.15 m, z=-20.
	b.block(Vector3(495, 1.15, -22), Vector3(505, 3, -20))
	# 600: grapple point 10 m up, 20 m ahead.
	b.grapple_point(Vector3(600, 10, -20))
	# 700: two same-side walls with a 3 m gap (plane x=701.2).
	b.block(Vector3(701.2, 0, -20), Vector3(701.8, 7, -5), T.RUN)
	b.block(Vector3(701.2, 0, -38), Vector3(701.8, 7, -23), T.RUN)
	# 800: a 3 m ledge to walk off (top at 3, edge at z=-10).
	b.block(Vector3(795, 0, -10), Vector3(805, 3, 5))
	# 900: slide ramp 6 m down over 24 m.
	b.block(Vector3(895, 0, 0), Vector3(905, 6, 6))
	b.ramp(Vector3(900, 6, 0), Vector3(900, 0, -24), 10.0)
	# 1000: chimney, walls 3.5 m apart facing each other along z.
	b.block(Vector3(995, 0, -8.75), Vector3(1005, 14, -7), T.RUN)
	b.block(Vector3(995, 0, -3.5), Vector3(1005, 14, -1.75), T.RUN)
	# 1100: waist-high cover (1.0 m) directly ahead at z=-3 (walk into it slowly).
	b.block(Vector3(1095, 0, -4), Vector3(1105, 1.0, -3))
	# 1200: corridor, left wall then right wall (planes x=1197.5 and x=1202.5).
	b.block(Vector3(1196.9, 0, -24), Vector3(1197.5, 7, -2), T.RUN)
	b.block(Vector3(1202.5, 0, -44), Vector3(1203.1, 7, -8), T.RUN)
	# 1300: grapple point above a 6 m rooftop edge (roof starts at z=-24).
	b.block(Vector3(1295, 0, -60), Vector3(1305, 6, -24))
	b.grapple_point(Vector3(1300, 8.5, -26))
	# 1400: short wall (ends at z=-12) for the wall-coyote kick.
	b.block(Vector3(1401.2, 0, -12), Vector3(1401.8, 7, -3), T.RUN)
	# 1600: a target dummy 10 m ahead.
	var dummy := TargetDummy.new()
	add_child(dummy)
	dummy.global_position = Vector3(1600, 0, -10)
	# 2000: lift rising 6 m (starts after a 1 s pause at the bottom).
	var lift := b.mover(Vector3(2000, 0, -6))
	movers["lift"] = lift
	lift.points = PackedVector3Array([Vector3.ZERO, Vector3(0, 6, 0)])
	lift.move_time = 2.0
	lift.pause_time = 1.0
	b.attach_box(lift, Vector3(0, 0.25, 0), Vector3(4, 0.5, 4), T.BOOST)
	# 2100: platform sliding along x at ~6 m/s mid-leg.
	var slider := b.mover(Vector3(2100, 0, 0))
	movers["slider"] = slider
	slider.points = PackedVector3Array([Vector3.ZERO, Vector3(20, 0, 0)])
	slider.move_time = 4.0
	slider.pause_time = 0.0
	b.attach_box(slider, Vector3(0, 0.25, 0), Vector3(4, 0.5, 4), T.BOOST)
	# 2200: long wall sliding along -z (its own tangent) at up to ~5 m/s, plane x=2201.2.
	var wall_mover := b.mover(Vector3(2201.5, 0, -30))
	movers["wall"] = wall_mover
	wall_mover.points = PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -40)])
	wall_mover.move_time = 8.0
	wall_mover.pause_time = 0.0
	b.attach_box(wall_mover, Vector3(0, 3.5, 0), Vector3(0.6, 7, 50), T.RUN)
	# 1900: tall climb wall (8 m) facing +Z at z=-3.
	b.block(Vector3(1895, 0, -30), Vector3(1905, 8, -3), T.RUN)
	# 1500: long wall on the right to run beside on the ground.
	b.block(Vector3(1500.6, 0, -60), Vector3(1501.2, 7, 5))


func _run_all() -> void:
	var tests := [
		"walk_and_sprint", "jump_height", "double_jump", "slide", "slide_hop_bounded",
		"wallrun", "wallrun_needs_forward", "wallrun_gap_reattach", "climb_mantle",
		"jump_mantle", "vault_keeps_speed", "slow_walk_no_vault", "slide_under_bar",
		"grapple", "coyote_jump", "jump_buffer_bhop", "ramp_slide_accel", "chimney",
		"corridor_chain", "grapple_into_mantle", "wall_coyote_kick", "ground_wall_no_snag",
		"shoot_dummy", "slide_release_stands", "ride_lift", "jump_off_moving_platform", "wallrun_moving_wall", "keyboard_bindings", "keyboard_grapple", "grapple_release", "grapple_tap_yank",
		"fp_arms", "course_run", "climb_jump_direction", "mantle_lift_gentle",
	]
	for t in tests:
		if only != "" and t != only:
			continue
		await call("test_" + t)


# --------------------------------------------------------------------------- helpers

func reset(pos: Vector3, yaw: float = 0.0) -> void:
	for i in InputRouter.ACTION_COUNT:
		router.scripted_held[i] = false
	router.scripted_move = Vector2.ZERO
	router.scripted_held[A.SPRINT] = true  # most scenarios sprint; walk_and_sprint turns it off
	player.spawn(pos + Vector3.UP * 0.05, yaw)
	await ticks(6)
	states_seen.clear()
	jumps_seen.clear()


func ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func seconds(s: float) -> void:
	await ticks(int(s * 120.0))


func hold(action: int, on: bool = true) -> void:
	router.scripted_held[action] = on


func tap(action: int) -> void:
	hold(action, true)
	await ticks(2)
	hold(action, false)


## Runs for `s` seconds, returning the max of a sampled value.
func track_max(s: float, sample: Callable) -> float:
	var best := -INF
	for i in int(s * 120.0):
		await get_tree().physics_frame
		best = maxf(best, sample.call())
	return best


func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		passes += 1
		print("  ok   ", name)
	else:
		failures.append("%s  %s" % [name, detail])
		print("  FAIL ", name, "  ", detail)


func saw(state: int) -> bool:
	return states_seen.has(state)


func hs() -> float:
	return player.horizontal_speed()


# --------------------------------------------------------------------------- tests

func test_walk_and_sprint() -> void:
	await reset(Vector3(0, 0, 0))
	hold(A.SPRINT, false)
	router.scripted_move = Vector2(0, 1)
	await seconds(1.0)
	var t := player.tuning
	check("default movement is walk speed", absf(hs() - t.walk_speed) < 0.3, "speed %.2f" % hs())
	hold(A.CROUCH)
	await ticks(3)
	check("no slide from a walk", player.motor.state != S.SLIDE, player.motor.state_name())
	hold(A.CROUCH, false)
	await ticks(10)
	hold(A.SPRINT)
	await seconds(1.0)
	check("holding sprint reaches sprint speed", absf(hs() - t.sprint_speed) < 0.3, "speed %.2f" % hs())
	hold(A.ADS)
	await seconds(0.5)
	check("aiming drops to walk speed", absf(hs() - t.walk_speed) < 0.4, "speed %.2f" % hs())
	hold(A.ADS, false)
	hold(A.SPRINT, false)
	await seconds(0.6)
	check("releasing sprint returns to walk", absf(hs() - t.walk_speed) < 0.4, "speed %.2f" % hs())
	check("still grounded", player.motor.state == S.GROUND, player.motor.state_name())


func test_jump_height() -> void:
	await reset(Vector3(0, 0, 20))
	var y0 := player.global_position.y
	await tap(A.JUMP)
	var apex := await track_max(1.0, func() -> float: return player.global_position.y)
	check("jump apex ~ jump_height", absf(apex - y0 - player.tuning.jump_height) < 0.12, "apex %.2f" % (apex - y0))
	check("jump lands on ground", player.motor.state == S.GROUND, player.motor.state_name())


func test_double_jump() -> void:
	await reset(Vector3(0, 0, 40))
	var y0 := player.global_position.y
	await tap(A.JUMP)
	await seconds(0.3)
	await tap(A.JUMP)
	var apex := await track_max(1.0, func() -> float: return player.global_position.y)
	check("double jump fired", jumps_seen.has(PlayerMotor.JumpKind.DOUBLE))
	check("double jump height", apex - y0 > player.tuning.jump_height + 0.8, "apex %.2f" % (apex - y0))


func test_slide() -> void:
	await reset(Vector3(20, 0, 0))
	router.scripted_move = Vector2(0, 1)
	await seconds(0.8)
	var before := hs()
	hold(A.CROUCH)
	await ticks(3)
	check("slide entered", player.motor.state == S.SLIDE, player.motor.state_name())
	check("slide boosts speed", hs() > before + 2.0, "%.2f -> %.2f" % [before, hs()])
	check("slide lowers capsule", player.motor.crouched)
	await seconds(2.5)
	check("slide ends when slow", player.motor.state == S.GROUND, player.motor.state_name())
	hold(A.CROUCH, false)
	await ticks(4)
	check("stands after slide", not player.motor.crouched)


func test_slide_hop_bounded() -> void:
	await reset(Vector3(40, 0, 0))
	router.scripted_move = Vector2(0, 1)
	await seconds(0.8)
	hold(A.CROUCH)
	await ticks(3)
	var top := 0.0
	for i in 8:
		await tap(A.JUMP)
		await ticks(10)
		while player.motor.state == S.AIR and player.global_position.y > 0.25:
			top = maxf(top, hs())
			await get_tree().physics_frame
	await ticks(1)
	check("slide-hop keeps speed above sprint", hs() > player.tuning.sprint_speed, "speed %.2f" % hs())
	check("slide-hop bounded by caps", top < player.tuning.soft_speed_cap + 1.0, "top %.2f" % top)
	hold(A.CROUCH, false)


func test_wallrun() -> void:
	await reset(Vector3(100, 0, -7))
	router.scripted_move = Vector2(0.3, 1)  # angle in toward the wall
	await seconds(0.5)
	await tap(A.JUMP)
	await seconds(0.3)
	router.scripted_move = Vector2(0, 1)
	check("wallrun entered", player.motor.state == S.WALLRUN, player.motor.state_name())
	await seconds(0.8)
	check("wallrun sustains", player.motor.state == S.WALLRUN, player.motor.state_name())
	check("wallrun speed", hs() > 9.0, "speed %.2f" % hs())
	check("wallrun height held", player.global_position.y > 0.8, "y %.2f" % player.global_position.y)
	check("wall on the right", player.motor.wall_side == 1, str(player.motor.wall_side))
	await tap(A.JUMP)
	await ticks(3)
	check("wall kick leaves wall", player.velocity.x < -3.0, "vx %.2f" % player.velocity.x)
	check("wall kick keeps forward speed", -player.velocity.z > 7.0, "vz %.2f" % player.velocity.z)
	check("wall kick fired", jumps_seen.has(PlayerMotor.JumpKind.WALL_KICK))


func test_wallrun_needs_forward() -> void:
	await reset(Vector3(100.65, 0, -7))
	router.scripted_move = Vector2(0, 1)
	await seconds(0.5)
	router.scripted_move = Vector2.ZERO
	await tap(A.JUMP)
	await seconds(0.5)
	check("no wallrun without forward input", not saw(S.WALLRUN))


func test_wallrun_gap_reattach() -> void:
	await reset(Vector3(700.5, 0, -6))
	router.scripted_move = Vector2(0.2, 1)
	await seconds(0.25)
	await tap(A.JUMP)
	await seconds(2.4)
	var runs := states_seen.count(S.WALLRUN)
	check("reattaches to next wall segment", runs >= 2, "wallruns %d  states %s" % [runs, str(states_seen)])


func test_climb_mantle() -> void:
	await reset(Vector3(200, 0, 0))
	router.scripted_move = Vector2(0, 1)
	await seconds(0.12)
	await tap(A.JUMP)
	await seconds(1.6)
	check("climb happened", saw(S.WALLCLIMB), str(states_seen))
	check("mantled at top", saw(S.MANTLE), str(states_seen))
	check("standing on 4.2 m wall", absf(player.global_position.y - 4.2) < 0.15 and player.motor.state == S.GROUND,
		"y %.2f state %s" % [player.global_position.y, player.motor.state_name()])


func test_jump_mantle() -> void:
	await reset(Vector3(300, 0, 0))
	router.scripted_move = Vector2(0, 1)
	await ticks(10)
	await tap(A.JUMP)
	await seconds(0.8)
	check("jump into 1.4 m ledge mantles", saw(S.MANTLE), str(states_seen))
	check("on top of ledge", absf(player.global_position.y - 1.4) < 0.15, "y %.2f" % player.global_position.y)


func test_vault_keeps_speed() -> void:
	await reset(Vector3(400, 0, 0))
	router.scripted_move = Vector2(0, 1)
	await seconds(2.0)
	check("vaulted hurdle", saw(S.MANTLE), str(states_seen))
	check("past the hurdle", player.global_position.z < -16.0, "z %.2f" % player.global_position.z)
	check("vault keeps speed", hs() > player.tuning.sprint_speed - 1.0, "speed %.2f" % hs())


func test_slow_walk_no_vault() -> void:
	await reset(Vector3(1100, 0, 0))
	router.scripted_move = Vector2(0, 0.4)  # slow walk into waist-high cover
	await seconds(1.5)
	check("no auto-vault when walking into cover", not saw(S.MANTLE), str(states_seen))


func test_slide_under_bar() -> void:
	await reset(Vector3(500, 0, 0))
	router.scripted_move = Vector2(0, 1)
	await seconds(0.9)
	hold(A.CROUCH)
	await seconds(2.2)
	check("slid under bar", player.global_position.z < -22.5, "z %.2f" % player.global_position.z)
	hold(A.CROUCH, false)
	await seconds(0.5)
	check("stands up after bar", not player.motor.crouched)


func test_grapple() -> void:
	await reset(Vector3(600, 0, 0))
	player.pitch = atan2(10.0 - player.tuning.eye_height, 20.0)
	var d0 := player.global_position.distance_to(Vector3(600, 10, -20))
	hold(A.GRAPPLE)
	await ticks(4)
	check("grapple attached", saw(S.GRAPPLE), str(states_seen))
	var closest := INF
	for i in 180:
		await get_tree().physics_frame
		closest = minf(closest, player.global_position.distance_to(Vector3(600, 10, -20)))
	hold(A.GRAPPLE, false)
	check("grapple pulled close while held", closest < 3.5, "closest %.2f from %.2f" % [closest, d0])
	check("grapple on cooldown", player.motor.grapple_cooldown_left > 0.0 or player.motor.state == S.GRAPPLE)
	await tap(A.GRAPPLE)
	await ticks(2)
	check("grapple denied on cooldown", player.motor.state != S.GRAPPLE)


func test_coyote_jump() -> void:
	await reset(Vector3(800, 3, 0))
	router.scripted_move = Vector2(0, 1)
	var left_at := -1
	for i in 240:
		await get_tree().physics_frame
		if player.motor.state == S.AIR:
			left_at = i
			break
	check("walked off ledge", left_at >= 0)
	await ticks(8)  # ~67 ms late
	await tap(A.JUMP)
	check("coyote jump is a ground jump", jumps_seen.has(PlayerMotor.JumpKind.GROUND), str(jumps_seen))
	check("double jump still available", player.motor.double_jump_ready)


func test_jump_buffer_bhop() -> void:
	await reset(Vector3(60, 0, 0))
	router.scripted_move = Vector2(0, 1)
	await seconds(0.8)
	await tap(A.JUMP)
	await ticks(12)
	await tap(A.JUMP)  # double jump
	# Press jump while still falling, before landing.
	while player.velocity.y > 0.0 or player.global_position.y > 0.6:
		await get_tree().physics_frame
	await tap(A.JUMP)
	var ground_ticks := 0
	var jumped_again := false
	for i in 60:
		await get_tree().physics_frame
		if player.motor.state == S.GROUND:
			ground_ticks += 1
		if jumps_seen.count(PlayerMotor.JumpKind.GROUND) >= 2 or jumps_seen.has(PlayerMotor.JumpKind.SLIDE_HOP):
			jumped_again = true
			break
	check("buffered jump fires on landing", jumped_again, str(jumps_seen))
	check("no ground friction tick on bhop", ground_ticks <= 1, "ground ticks %d" % ground_ticks)


func test_ramp_slide_accel() -> void:
	await reset(Vector3(900, 6, 3))
	router.scripted_move = Vector2(0, 1)
	await seconds(0.4)
	hold(A.CROUCH)
	var top := await track_max(2.0, hs)
	check("downhill slide accelerates", top > 13.0, "top %.2f" % top)
	hold(A.CROUCH, false)


func test_chimney() -> void:
	# Face the far wall (-Z), climb it, kick back (auto-turn), climb the other.
	await reset(Vector3(1000, 0, -4.0))
	router.scripted_move = Vector2(0, 1)
	await seconds(0.12)
	await tap(A.JUMP)
	await seconds(0.45)
	check("chimney first climb", saw(S.WALLCLIMB), str(states_seen))
	await tap(A.JUMP)
	await seconds(0.6)
	var climbs := states_seen.count(S.WALLCLIMB)
	check("chimney second climb on other wall", climbs >= 2, "climbs %d states %s" % [climbs, str(states_seen)])
	check("chimney gaining height", player.global_position.y > 4.0, "y %.2f" % player.global_position.y)


func test_corridor_chain() -> void:
	# Run up the left wall, kick right, catch the right wall.
	await reset(Vector3(1198.3, 0, -1))
	router.scripted_move = Vector2(-0.3, 1)
	await seconds(0.25)
	await tap(A.JUMP)
	router.scripted_move = Vector2(0, 1)
	await seconds(0.5)
	check("corridor: on left wall", player.motor.state == S.WALLRUN and player.motor.wall_side == -1, "%s side %d" % [player.motor.state_name(), player.motor.wall_side])
	player.yaw = deg_to_rad(-40.0)  # look toward the right wall as you kick
	await tap(A.JUMP)
	await seconds(0.7)
	check("corridor: caught right wall", states_seen.count(S.WALLRUN) >= 2, str(states_seen))
	check("corridor: speed carried", hs() > 9.0, "speed %.2f" % hs())


func test_grapple_into_mantle() -> void:
	await reset(Vector3(1300, 0, -8))
	player.pitch = atan2(8.5 - player.tuning.eye_height, 18.0)
	router.scripted_move = Vector2(0, 1)
	hold(A.GRAPPLE)
	await seconds(1.8)
	hold(A.GRAPPLE, false)
	check("grapple then mantle", saw(S.GRAPPLE) and saw(S.MANTLE), str(states_seen))
	check("on the roof", player.global_position.y > 5.8, "y %.2f" % player.global_position.y)


func test_wall_coyote_kick() -> void:
	await reset(Vector3(1400.3, 0, -2))
	router.scripted_move = Vector2(0.25, 1)
	await seconds(0.15)
	await tap(A.JUMP)
	router.scripted_move = Vector2(0, 1)
	# wait until we run off the end of the wall
	for i in 240:
		await get_tree().physics_frame
		if saw(S.WALLRUN) and player.motor.state == S.AIR:
			break
	await ticks(6)  # 50 ms late
	await tap(A.JUMP)
	check("late jump after wall end is a wall kick", jumps_seen.has(PlayerMotor.JumpKind.WALL_KICK), str(jumps_seen))
	check("double jump kept for later", player.motor.double_jump_ready)


func test_ground_wall_no_snag() -> void:
	await reset(Vector3(1500.1, 0, 0))
	router.scripted_move = Vector2(0.3, 1)  # hug the wall while sprinting
	await seconds(1.5)
	check("no wallrun from the ground", not saw(S.WALLRUN) and not saw(S.WALLCLIMB), str(states_seen))
	check("full speed along wall", hs() > player.tuning.sprint_speed - 0.8, "speed %.2f" % hs())


func test_shoot_dummy() -> void:
	await reset(Vector3(1600, 0, 0))
	player.pitch = atan2(0.9 - player.tuning.eye_height, 10.0)
	var hits := [0, 0]  # [hits, kills]
	var on_hit := func(_head: bool, killed: bool) -> void:
		hits[0] += 1
		if killed:
			hits[1] += 1
	player.weapon.hit_confirmed.connect(on_hit)
	hold(A.FIRE)
	await seconds(0.9)
	hold(A.FIRE, false)
	check("rifle hits dummy", hits[0] >= 5, "hits %d" % hits[0])
	check("rifle kills dummy", hits[1] == 1, "kills %d" % hits[1])
	hold(A.FIRE)
	await seconds(3.0)
	hold(A.FIRE, false)
	check("auto reload when empty", player.weapon.reloading or player.weapon.ammo == player.weapon.data.magazine,
		"ammo %d reloading %s" % [player.weapon.ammo, player.weapon.reloading])
	player.weapon.hit_confirmed.disconnect(on_hit)


## Real key events through Godot's Input -> InputHub -> router (not scripted input).
func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func test_keyboard_bindings() -> void:
	await reset(Vector3(1700, 0, 0))
	router.scripted = false
	router.use_kbm = true
	var binds := {
		KEY_SPACE: A.JUMP, KEY_CTRL: A.CROUCH, KEY_C: A.CROUCH, KEY_Q: A.GRAPPLE,
		KEY_R: A.RELOAD, KEY_V: A.MELEE, KEY_1: A.SWAP, KEY_T: A.RESET,
	}
	for code: Key in binds:
		var action: int = binds[code]
		_key(code, true)
		var seen := false
		for i in 4:
			await ticks(1)
			seen = seen or router.is_held(action)
		_key(code, false)
		await ticks(2)
		check("key %s -> %s" % [OS.get_keycode_string(code), InputRouter.Action.keys()[action]], seen)
		await reset(Vector3(1700, 0, 0))
	router.scripted = true
	router.use_kbm = false



func test_keyboard_grapple() -> void:
	await reset(Vector3(600, 0, 0))
	router.scripted = false
	router.use_kbm = true
	player.pitch = atan2(10.0 - player.tuning.eye_height, 20.0)
	_key(KEY_Q, true)
	await ticks(3)
	_key(KEY_Q, false)
	check("pressing Q grapples", saw(S.GRAPPLE), str(states_seen))
	await seconds(1.5)
	router.scripted = true
	router.use_kbm = false


func test_grapple_release() -> void:
	await reset(Vector3(600, 0, 0))
	player.pitch = atan2(10.0 - player.tuning.eye_height, 20.0)
	hold(A.GRAPPLE)
	await seconds(0.4)
	check("still attached while held", player.motor.state == S.GRAPPLE, player.motor.state_name())
	hold(A.GRAPPLE, false)
	await ticks(2)
	check("releasing lets go", player.motor.state != S.GRAPPLE, player.motor.state_name())
	check("momentum kept on release", player.velocity.length() > 8.0, "speed %.2f" % player.velocity.length())


func test_grapple_tap_yank() -> void:
	await reset(Vector3(600, 0, 0))
	player.pitch = atan2(10.0 - player.tuning.eye_height, 20.0)
	await tap(A.GRAPPLE)
	var peak := await track_max(0.3, func() -> float: return player.velocity.length())
	check("tap still grapples briefly", saw(S.GRAPPLE), str(states_seen))
	check("tap ends after min time", player.motor.state != S.GRAPPLE, player.motor.state_name())
	check("tap gives a yank", peak > 4.5, "peak %.2f" % peak)


func test_slide_release_stands() -> void:
	await reset(Vector3(80, 0, 0))
	router.scripted_move = Vector2(0, 1)
	await seconds(0.8)
	hold(A.CROUCH)
	await seconds(0.4)
	check("sliding while held", player.motor.state == S.SLIDE, player.motor.state_name())
	hold(A.CROUCH, false)
	await ticks(3)
	check("release ends slide", player.motor.state == S.GROUND and not player.motor.crouched,
		"%s crouched %s" % [player.motor.state_name(), player.motor.crouched])


func test_ride_lift() -> void:
	movers["lift"].restart()
	await reset(Vector3(2000, 0.6, -6))
	await seconds(3.5)
	check("lift carries player up", player.global_position.y > 5.5, "y %.2f" % player.global_position.y)
	check("grounded on the lift", player.motor.state == S.GROUND, player.motor.state_name())


func test_jump_off_moving_platform() -> void:
	movers["slider"].restart()
	await reset(Vector3(2100, 0.6, 0))
	# Wait until the platform is mid-leg (fast), then jump straight up.
	var fastest := 0.0
	for i in 480:
		await get_tree().physics_frame
		if player.get_platform_velocity().x > 6.0:
			fastest = player.get_platform_velocity().x
			break
	check("riding a moving platform", fastest > 6.0, "platform vx %.2f" % fastest)
	await tap(A.JUMP)
	await ticks(6)
	check("jump inherits platform velocity", player.velocity.x > 4.0, "vx %.2f" % player.velocity.x)


func test_wallrun_moving_wall() -> void:
	# Wall slides toward -z (same direction we run); we should stay attached and carried.
	movers["wall"].restart()
	await reset(Vector3(2200, 0, -10))
	await seconds(1.5)  # wall is now accelerating mid-leg
	router.scripted_move = Vector2(0.3, 1)
	await seconds(0.3)
	await tap(A.JUMP)
	await seconds(0.25)
	router.scripted_move = Vector2(0, 1)
	check("wallrun on a moving wall", player.motor.state == S.WALLRUN, "%s %s" % [player.motor.state_name(), str(states_seen)])
	await seconds(0.8)
	check("still on the moving wall", player.motor.state == S.WALLRUN, player.motor.state_name())
	check("carried by wall (faster than run speed)", -player.velocity.z > player.tuning.wallrun_target_speed + 1.0, "vz %.2f" % player.velocity.z)


# --------------------------------------------------------------------------- first-person arms

var _arms: Dictionary = {}
var _shoulder_track: PackedVector3Array = []


func _track_shoulder() -> void:
	var sk := player.camera_rig.fp_body.skeleton
	var cam_inv := player.camera_rig.camera.global_transform.affine_inverse()
	_shoulder_track.append(cam_inv * (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("upperarm_r")).origin))


## Camera-space arm data from the posed skeleton (modifier results only exist
## during skeleton_updated). Keys: hand_r/l, err_r/l (m), shoulder_r/l.
func arm_sample() -> Dictionary:
	var sk := player.camera_rig.fp_body.skeleton
	sk.skeleton_updated.connect(_grab_arms, CONNECT_ONE_SHOT)
	await get_tree().process_frame
	await get_tree().process_frame
	return _arms


func _grab_arms() -> void:
	var body := player.camera_rig.fp_body
	var sk := body.skeleton
	var cam_inv := player.camera_rig.camera.global_transform.affine_inverse()
	for side in ["r", "l"]:
		var hand := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand_" + side)).origin
		var target := (body.get_node("Target" + side.to_upper()) as Node3D).global_position
		_arms["hand_" + side] = cam_inv * hand
		_arms["err_" + side] = hand.distance_to(target)
		_arms["shoulder_" + side] = cam_inv * (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("upperarm_" + side)).origin)


func test_fp_arms() -> void:
	await reset(Vector3(20, 0, 0))
	await seconds(0.3)
	var a := await arm_sample()
	check("fp: idle hands on their targets", a.err_r < 0.02 and a.err_l < 0.02, "err r %.3f l %.3f" % [a.err_r, a.err_l])
	# SMG carry: one hand at the hip, the support hand joins to aim.
	var vm := player.camera_rig.fp_body.viewmodel
	var cam_inv := player.camera_rig.camera.global_transform.affine_inverse()
	var off_gun: float = a.hand_l.distance_to(cam_inv * vm.grip_l.global_position)
	check("fp: hip carry is one-handed", off_gun > 0.2, "left hand %.2f m from the handguard" % off_gun)
	hold(A.ADS)
	await seconds(0.35)
	a = await arm_sample()
	cam_inv = player.camera_rig.camera.global_transform.affine_inverse()
	var on_gun: float = a.hand_l.distance_to(cam_inv * vm.grip_l.global_position)
	hold(A.ADS, false)
	check("fp: aiming brings the support hand on", on_gun < 0.12 and a.err_l < 0.02, "left hand %.2f m from the handguard, err %.3f" % [on_gun, a.err_l])
	await seconds(0.3)
	# Regression: targets smoothed in world space trailed a moving body by
	# speed / rate, so at sprint speed the hands fell behind the camera.
	router.scripted_move = Vector2(0, 1)
	await seconds(0.7)
	a = await arm_sample()
	check("fp: sprinting right hand stays on the grip", a.err_r < 0.02, "err %.3f" % a.err_r)
	check("fp: sprinting right hand in front of the eye", a.hand_r.z < -0.25, "z %.2f" % a.hand_r.z)
	# Regression: the neck anchor read the clip's neck a frame late, so the
	# sprint clip's bounce shook the shoulders (and arms) against the camera.
	_shoulder_track.clear()
	var sk := player.camera_rig.fp_body.skeleton
	sk.skeleton_updated.connect(_track_shoulder)
	await seconds(0.4)
	sk.skeleton_updated.disconnect(_track_shoulder)
	var worst := 0.0
	for i in range(2, _shoulder_track.size()):
		worst = maxf(worst, (_shoulder_track[i] - 2.0 * _shoulder_track[i - 1] + _shoulder_track[i - 2]).length())
	check("fp: shoulders steady against the camera while sprinting", _shoulder_track.size() > 10 and worst < 0.001, "jerk %.1f mm over %d frames" % [worst * 1000.0, _shoulder_track.size()])
	hold(A.CROUCH)
	await seconds(0.25)
	a = await arm_sample()
	hold(A.CROUCH, false)
	check("fp: slide keeps shoulders under the eye", a.shoulder_l.y > -0.45 and a.shoulder_r.y > -0.45, "y %.2f / %.2f" % [a.shoulder_l.y, a.shoulder_r.y])
	check("fp: slide gun hand reaches", a.err_r < 0.06, "err %.3f" % a.err_r)

	await reset(Vector3(600, 0, 0))
	player.pitch = atan2(10.0 - player.tuning.eye_height, 20.0)
	hold(A.GRAPPLE)
	await seconds(0.3)
	a = await arm_sample()
	hold(A.GRAPPLE, false)
	check("fp: grapple arm reaches out in view", a.err_l < 0.02 and a.hand_l.z < -0.35, "err %.3f z %.2f" % [a.err_l, a.hand_l.z])
	player.pitch = 0.0

	await reset(Vector3(1198.3, 0, -1))
	router.scripted_move = Vector2(-0.3, 1)
	await seconds(0.25)
	await tap(A.JUMP)
	router.scripted_move = Vector2(0, 1)
	var t := 0.0
	while player.motor.state != S.WALLRUN and t < 2.0:
		await get_tree().physics_frame
		t += 1.0 / 120.0
	await seconds(0.3)
	a = await arm_sample()
	check("fp: wall-run hand on the wall ahead", player.motor.state == S.WALLRUN and a.err_l < 0.03 and a.hand_l.z < -0.25, "%s err %.3f z %.2f" % [player.motor.state_name(), a.err_l, a.hand_l.z])


# --------------------------------------------------------------------------- course

func place(pos: Vector3) -> void:
	player.motor.reset_to(pos)
	await ticks(2)


func test_course_run() -> void:
	# 1800: start, two gates straight ahead, finish.
	var c := Course.new()
	add_child(c)
	c.setup("test_course", "Test", 10.0)
	c.save_records = false
	c.best_time = 0.0
	c.best_splits = PackedFloat32Array()
	c.set_start(Vector3(1800, 0, 0), 0.0, 2.0)
	c.add_gate("A", Vector3(1800, 0, -10), 2.0)
	c.add_gate("B", Vector3(1800, 0, -20), 2.0)
	c.set_finish(Vector3(1800, 0, -30), 2.0)
	c.finalize()
	c.add_player(player)
	var run := c.run_of(player)

	c.restart(player)
	await ticks(3)
	check("course: armed in the start zone", run.state == Course.RunState.ARMED and run.time == 0.0, str(run.state))
	check("course: T restarts the run", player.restart_handler.is_valid())
	router.scripted_move = Vector2(0, 1)
	var waited := 0
	while run.state == Course.RunState.ARMED and waited < 240:
		await get_tree().physics_frame
		waited += 1
	router.scripted_move = Vector2.ZERO
	await seconds(0.3)
	check("course: clock starts on leaving the start", run.state == Course.RunState.RUNNING and run.time > 0.2, "%s %.2f" % [run.state, run.time])
	await place(Vector3(1800, 0, -20))
	check("course: gates only count in order", run.next_gate == 0, "next %d" % run.next_gate)
	await place(Vector3(1800, 0, -10))
	check("course: first gate counts", run.next_gate == 1 and run.splits.size() == 1, "next %d" % run.next_gate)
	check("course: gate is the new respawn", player.spawn_position.distance_to(Vector3(1800, 0, -10)) < 0.01)
	check("course: respawn faces the next gate", absf(player.spawn_yaw) < 0.01, "yaw %.2f" % player.spawn_yaw)
	await place(Vector3(1800, 0, -30))
	check("course: finish needs every gate", run.state == Course.RunState.RUNNING)
	await place(Vector3(1800, 0, -20))
	var t_before := run.time
	await place(Vector3(1800, 0, -30))
	check("course: finish stops the clock", run.state == Course.RunState.FINISHED and run.splits.size() == 2, str(run.state))
	check("course: first finish is the best", is_equal_approx(c.best_time, run.time) and c.best_splits.size() == 2, "%.2f vs %.2f" % [c.best_time, run.time])
	await ticks(10)
	check("course: clock stays stopped", run.time <= t_before + 0.05, "%.2f" % run.time)
	check("course: medal thresholds", Course.medal(9.9, 10.0) == "GOLD" and Course.medal(11.0, 10.0) == "SILVER" and Course.medal(20.0, 10.0) == "")
	check("course: time format", Course.format_time(75.456) == "1:15.46", Course.format_time(75.456))

	c.restart(player)
	await ticks(3)
	check("course: restart re-arms at the start", run.state == Course.RunState.ARMED and run.next_gate == 0 and player.global_position.distance_to(Vector3(1800, 0, 0)) < 0.5, str(run.state))
	router.scripted_move = Vector2(0, 1)
	await seconds(0.8)
	router.scripted_move = Vector2.ZERO
	c.on_teleport(player)
	check("course: teleporting mid-run cancels it", run.state == Course.RunState.VOID, str(run.state))
	c.restart(player)
	await ticks(3)
	c.on_teleport(player)
	await place(Vector3(1800, 0, -5))
	check("course: teleporting out of the start doesn't start the clock", run.state == Course.RunState.IDLE, str(run.state))

	player.restart_handler = Callable()
	c.queue_free()
	for n in player.hud.get_parent().get_children():
		if n is CourseHud:
			n.queue_free()


func test_climb_jump_direction() -> void:
	# Holding forward into the wall, jump hops up it: no push-off, no turn
	# (Liam: the auto-turn jerked the camera around while climbing up a building).
	await reset(Vector3(1900, 0, 0))
	router.scripted_move = Vector2(0, 1)
	await seconds(0.12)
	await tap(A.JUMP)
	var t := 0.0
	while player.motor.state != S.WALLCLIMB and t < 1.5:
		await get_tree().physics_frame
		t += 1.0 / 120.0
	check("climb started on the tall wall", player.motor.state == S.WALLCLIMB, player.motor.state_name())
	await seconds(0.15)
	var yaw0 := player.yaw
	jumps_seen.clear()
	await tap(A.JUMP)
	await seconds(0.35)
	check("forward + jump hops up the wall", jumps_seen.has(PlayerMotor.JumpKind.CLIMB_HOP), str(jumps_seen))
	check("hop doesn't turn the camera", absf(wrapf(player.yaw - yaw0, -PI, PI)) < 0.05, "turned %.2f" % (player.yaw - yaw0))
	check("hop stays at the wall", player.global_position.z < -2.0, "z %.2f" % player.global_position.z)

	# Neutral + jump still kicks off and turns around.
	await reset(Vector3(1900, 0, 0))
	router.scripted_move = Vector2(0, 1)
	await seconds(0.12)
	await tap(A.JUMP)
	t = 0.0
	while player.motor.state != S.WALLCLIMB and t < 1.5:
		await get_tree().physics_frame
		t += 1.0 / 120.0
	await seconds(0.15)
	router.scripted_move = Vector2.ZERO
	jumps_seen.clear()
	await tap(A.JUMP)
	await seconds(0.4)
	check("neutral + jump kicks off the wall", jumps_seen.has(PlayerMotor.JumpKind.CLIMB_KICK), str(jumps_seen))
	check("kick turns to face away", absf(wrapf(player.yaw - PI, -PI, PI)) < 0.2, "yaw %.2f" % player.yaw)


## The mantle lift eases in (HANDOFF item 1): the body shouldn't rise half-way
## in the first few frames, or the ledge and the hand plants drop out of view.
func test_mantle_lift_gentle() -> void:
	var t := player.tuning
	check("ease 0 keeps the old ease-out curve", absf(PlayerMotor.mantle_lift_curve(0.2, 0.0) - (1.0 - pow(1.0 - 0.2 / 0.7, 2.0))) < 0.001)
	await reset(Vector3(300, 0, 0))
	router.scripted_move = Vector2(0, 1)
	await ticks(10)
	await tap(A.JUMP)
	var y0 := NAN
	var y_early := NAN
	var mantle_ticks := 0
	for i in 120:
		await get_tree().physics_frame
		if player.motor.state == S.MANTLE:
			if is_nan(y0):
				y0 = player.global_position.y
			mantle_ticks += 1
			if is_nan(y_early) and player.motor.mantle_progress() >= 0.2:
				y_early = player.global_position.y
		elif not is_nan(y0):
			break
	var lift := 1.4 - y0
	var frac := (y_early - y0) / maxf(lift, 0.01)
	check("mantle lifts < 35% in its first 20%", frac < 0.35, "frac %.2f (lift %.2f m)" % [frac, lift])
	var want := t.mantle_time_base + t.mantle_time_per_meter * 1.4
	check("mantle time unchanged", absf(mantle_ticks / 120.0 - want) < 0.15, "%.3f s vs %.3f" % [mantle_ticks / 120.0, want])
	await seconds(0.3)
	check("still ends on top", absf(player.global_position.y - 1.4) < 0.15, "y %.2f" % player.global_position.y)
