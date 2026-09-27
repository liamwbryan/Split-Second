extends Node3D
## Headless aim assist tests: a real Player with scripted stick/mouse look
## against target dummies. Each scenario compares look with and without the
## assist, so the numbers don't depend on the stick curve.
##
## Run: godot --headless --path . --fixed-fps 120 res://tests/aim_assist_tests.tscn

const P := PlayerSettings.AimAssistPreset

var player: Player
var router: InputRouter
var settings: PlayerSettings
var b: LevelBuilder
var failures: PackedStringArray = []
var passes: int = 0
var only: String = ""
var strafer: TargetDummy


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr(7)
	b = LevelBuilder.new(self)
	_build()
	var vp := SubViewport.new()
	add_child(vp)
	settings = PlayerSettings.new()
	router = InputRouter.new(settings)
	router.scripted = true
	router.use_kbm = false
	player = Player.new()
	add_child(player)
	player.setup(0, router, MovementTuning.new(), vp)
	for t in ["off_means_off", "mouse_not_assisted", "idle_stick_no_assist", "slowdown_near_target",
			"line_of_sight_blocks", "rotational_tracks_strafer", "dead_target_ignored"]:
		if only == "" or t == only:
			await call("test_" + t)
	print("\n%d passed, %d failed" % [passes, failures.size()])
	for f in failures:
		print("  FAIL ", f)
	get_tree().quit(failures.size())


# Lanes: 0 = static dummy 10 m ahead, 100 = same behind a wall,
# 200 = strafing dummy 8 m ahead, 300 = empty (no targets).
func _build() -> void:
	b.block(Vector3(-50, -1, -100), Vector3(400, 0, 50))
	_dummy(Vector3(0, 0, -10), Vector3.ZERO)
	_dummy(Vector3(100, 0, -10), Vector3.ZERO)
	b.block(Vector3(95, 0, -5.4), Vector3(105, 3, -5))
	strafer = _dummy(Vector3(200, 0, -8), Vector3(0.8, 0, 0))


func _dummy(pos: Vector3, move: Vector3) -> TargetDummy:
	var d := TargetDummy.new()
	d.move_axis = move
	d.position = pos
	add_child(d)
	return d


# --------------------------------------------------------------------------- helpers

## Stand at a lane facing -z, aiming at a dummy chest `dist` ahead.
func stand(x: float, dist: float, preset: int) -> void:
	settings.aim_assist = preset as PlayerSettings.AimAssistPreset
	router.scripted_look = Vector2.ZERO
	router.scripted_mouse = Vector2.ZERO
	player.spawn(Vector3(x, 0.05, 0), 0.0)
	await frames(8)
	aim_at(Vector3(x, 1.15, -dist))
	await frames(4)  # let the assist pick the target and check line of sight


func aim_at(p: Vector3) -> void:
	var to := p - player.eye_position()
	player.yaw = atan2(-to.x, -to.z)
	player.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Size of the yaw change (degrees) over n frames with the given scripted look input.
func turn(n: int, stick: Vector2, mouse: Vector2 = Vector2.ZERO) -> float:
	router.scripted_look = stick
	router.scripted_mouse = mouse
	var y0 := player.yaw
	await frames(n)
	router.scripted_look = Vector2.ZERO
	router.scripted_mouse = Vector2.ZERO
	return absf(rad_to_deg(wrapf(player.yaw - y0, -PI, PI)))


func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		passes += 1
		print("  ok   ", name)
	else:
		failures.append("%s  %s" % [name, detail])
		print("  FAIL ", name, "  ", detail)


# --------------------------------------------------------------------------- tests

const STICK := Vector2(0.3, 0.0)  # small right-stick nudge (about 15 deg/s)


func test_off_means_off() -> void:
	await stand(300, 10, P.OFF)
	var free := await turn(12, STICK)
	await stand(0, 10, P.OFF)
	var on_target := await turn(12, STICK)
	check("off: stick turns the same on a target", absf(on_target - free) < 0.001,
		"%.4f vs %.4f deg" % [on_target, free])
	await stand(200, 8, P.OFF)
	var y0 := player.yaw
	router.scripted_look = Vector2(0.0, 0.4)
	await frames(240)
	router.scripted_look = Vector2.ZERO
	check("off: no rotational pull on a strafer", player.yaw == y0,
		"moved %.4f deg" % rad_to_deg(player.yaw - y0))


func test_mouse_not_assisted() -> void:
	var px := Vector2(3, 0)
	await stand(300, 10, P.STRONG)
	var free := await turn(12, Vector2.ZERO, px)
	await stand(0, 10, P.STRONG)
	var on_target := await turn(12, Vector2.ZERO, px)
	check("mouse: no slowdown on a target", absf(on_target - free) < 0.001,
		"%.4f vs %.4f deg" % [on_target, free])
	await stand(200, 8, P.STRONG)
	var y0 := player.yaw
	router.scripted_mouse = Vector2(0.001, 0)  # mouse active but ~still
	await frames(240)
	router.scripted_mouse = Vector2.ZERO
	check("mouse: no rotational pull on a strafer", absf(rad_to_deg(player.yaw - y0)) < 0.1,
		"moved %.3f deg" % rad_to_deg(player.yaw - y0))


func test_idle_stick_no_assist() -> void:
	await stand(200, 8, P.STRONG)
	var y0 := player.yaw
	var p0 := player.pitch
	await frames(360)
	check("idle stick: view never moves by itself", player.yaw == y0 and player.pitch == p0,
		"yaw %.4f pitch %.4f deg" % [rad_to_deg(player.yaw - y0), rad_to_deg(player.pitch - p0)])


func test_slowdown_near_target() -> void:
	await stand(300, 10, P.STANDARD)
	var free := await turn(12, STICK)
	await stand(0, 10, P.STANDARD)
	check("assist picked the target", player.aim_assist.target != null and player.aim_assist.target_visible)
	var on_target := await turn(12, STICK)
	check("slowdown: stick turns slower on a target", on_target < free * 0.85 and on_target > 0.0,
		"%.3f vs %.3f deg" % [on_target, free])
	router.scripted_held[InputRouter.Action.ADS] = true
	await stand(0, 10, P.STANDARD)
	await frames(24)  # finish raising the sights
	var ads := await turn(12, STICK)
	router.scripted_held[InputRouter.Action.ADS] = false
	check("slowdown: ADS is stronger than hip", ads < on_target, "%.3f vs %.3f deg" % [ads, on_target])
	await stand(0, 10, P.STRONG)
	var strong := await turn(12, STICK)
	check("slowdown: Strong beats Standard", strong < on_target, "%.3f vs %.3f deg" % [strong, on_target])


func test_line_of_sight_blocks() -> void:
	await stand(300, 10, P.STANDARD)
	var free := await turn(12, STICK)
	await stand(100, 10, P.STANDARD)
	check("wall: target is not visible", not player.aim_assist.target_visible)
	var blocked := await turn(12, STICK)
	check("wall: no slowdown through a wall", absf(blocked - free) < 0.001,
		"%.4f vs %.4f deg" % [blocked, free])


func test_rotational_tracks_strafer() -> void:
	# The stick wiggles up and down (net zero), so the player is "aiming" but
	# never steers sideways: any sideways tracking comes from the assist.
	var errors: Array[float] = []
	var follow: Array[float] = []
	for preset: int in [P.OFF, P.STANDARD]:
		await stand(200, 8, preset)
		var yaws := 0.0
		var target_moves := 0.0
		var total := 0.0
		var n := 360
		var prev_yaw := player.yaw
		var prev_x := strafer.global_position.x
		for i in n:
			router.scripted_look = Vector2(0.0, 0.45 if (i / 6) % 2 == 0 else -0.45)
			await get_tree().physics_frame
			var fwd := Basis(Vector3.UP, player.yaw) * Basis(Vector3.RIGHT, player.pitch) * Vector3.FORWARD
			total += fwd.angle_to(strafer.aim_point() - player.eye_position())
			# Yaw grows to the left (-x): correlate the turn with the dummy's motion.
			yaws += -(player.yaw - prev_yaw) * (strafer.global_position.x - prev_x)
			target_moves += absf(strafer.global_position.x - prev_x)
			prev_yaw = player.yaw
			prev_x = strafer.global_position.x
		router.scripted_look = Vector2.ZERO
		errors.append(rad_to_deg(total / n))
		follow.append(yaws)
	check("rotational: view follows the strafer", follow[1] > 0.0 and absf(follow[0]) < 1e-9,
		"follow off %.6f standard %.6f" % [follow[0], follow[1]])
	check("rotational: tracking error drops", errors[1] < errors[0] * 0.9,
		"mean error off %.2f deg, standard %.2f deg" % [errors[0], errors[1]])


func test_dead_target_ignored() -> void:
	await stand(0, 10, P.STANDARD)
	var dummy: TargetDummy = player.aim_assist.target
	check("dead: has a target first", dummy != null)
	if dummy == null:
		return
	dummy.take_hit(1000.0, Vector3.ZERO, Vector3.FORWARD, player)
	await frames(4)
	check("dead: toppled dummy is dropped", player.aim_assist.target == null)
	await frames(360)  # let it stand back up before other tests
