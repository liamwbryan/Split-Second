extends Node
## SPIRAL route regression tests: drive the real map's player with scripted
## input and check the set pieces still work after layout or movement changes.
##   godot --headless --path . --fixed-fps 120 res://tests/spiral_tests.tscn

const A := InputRouter.Action
var level: LevelBase
var p: Player
var router: InputRouter
var failures := 0


func _ready() -> void:
	level = load("res://scenes/spiral.tscn").instantiate()
	add_child(level)
	await get_tree().physics_frame
	p = level.players[0]
	router = p.router
	router.scripted = true
	router.use_kbm = false
	if level.course:
		level.course.save_records = false
	# Pads: where a standing launch lands (level, and a box it must land in).
	await _pad("pit E pad → deck 3", Vector3(10.5, 0, -3), 12.0, Rect2(18.5, -10, 19, 14))
	await _pad("pit W pad → deck 3", Vector3(-10.5, 0, -3), 12.0, Rect2(-37.5, -10, 19, 14))
	await _pad("sky dock pad → traffic ring", Vector3(24, 45.62, -34), 46.0, Rect2(55, -20, 10, 12))
	await _pad("ring pad → roof", Vector3(59, 46.12, -10.5), 42.0, Rect2(18, -30, 20, 40))
	await _express()
	await _drop_in()
	await _outer_car()
	await _corner_grapple("SE beacon → deck 3", Vector3(17.0, 0, 17.0), Vector3(17.3, 14.5, 17.3), 12.0, Vector2(1, 1))
	await _corner_grapple("SW beacon → deck 4", Vector3(-17.0, 0, 17.0), Vector3(-17.3, 20.5, 17.3), 18.0, Vector2(-1, 1))
	print("\nspiral: %d failures" % failures)
	get_tree().quit(failures)


func _check(name: String, ok: bool, detail: String) -> void:
	print("  %s %s  %s" % ["ok  " if ok else "FAIL", name, detail])
	if not ok:
		failures += 1


func _clear() -> void:
	for i in InputRouter.ACTION_COUNT:
		router.scripted_held[i] = false
	router.scripted_move = Vector2.ZERO


func _pad(label: String, at: Vector3, want_y: float, area: Rect2) -> void:
	_clear()
	p.spawn(at + Vector3(0, 0.2, 0), 0.0)
	var was_air := false
	for i in 600:
		await get_tree().physics_frame
		if not p.is_on_floor():
			was_air = true
		elif was_air and i > 10:
			var q := p.global_position
			_check(label, absf(q.y - want_y) < 0.3 and area.has_point(Vector2(q.x, q.z)), "landed at %s" % q.snappedf(0.1))
			return
	_check(label, false, "never landed (at %s)" % p.global_position.snappedf(0.1))


## Steer like a player looking around the curve: aim a little inside the
## tangent, more when drifting out (increasing-angle travel).
func _steer(lead_deg: float) -> void:
	var pos := p.global_position
	var a := atan2(pos.z, pos.x)
	var r := Vector2(pos.x, pos.z).length()
	p.yaw = PI - (a + deg_to_rad(clampf(lead_deg + 8.0 * (r - 15.5), -25.0, 35.0)))


func _express() -> void:
	_clear()
	router.scripted_held[A.SPRINT] = true
	p.spawn(Vector3(15.5, 42.1, 1.0), PI)
	router.scripted_move = Vector2(0, 1)
	for i in 110:
		_steer(4.0)
		await get_tree().physics_frame
	router.scripted_held[A.CROUCH] = true
	var states := {}
	var top := 0.0
	for i in 1200:
		_steer(4.0)
		await get_tree().physics_frame
		states[p.motor.state_name()] = true
		top = maxf(top, p.horizontal_speed())
		if p.global_position.y < 0.4:
			_check("Express: roof to deck 1 in one slide", states.keys() == ["Slide"] and top > 17.0 and p.horizontal_speed() > 16.0,
				"%.2f s, top %.1f, exit %.1f m/s, states %s" % [i / 120.0, top, p.horizontal_speed(), states.keys()])
			return
	_check("Express: roof to deck 1 in one slide", false, "stuck at %s, states %s" % [p.global_position.snappedf(0.1), states.keys()])


func _drop_in() -> void:
	_clear()
	p.spawn(Vector3(-15.5, 42.1, 0.0), PI)  # on the catwalk, facing south
	router.scripted_move = Vector2(0, 0.6)  # step off the edge (by distance: pad sprint is a toggle)
	for i in 120:
		await get_tree().physics_frame
		if p.global_position.z > 1.4:
			break
	router.scripted_move = Vector2.ZERO
	p.velocity = Vector3(0, p.velocity.y, minf(p.velocity.z, 5.0))
	for i in 400:
		await get_tree().physics_frame
		if p.is_on_floor():
			var q := p.global_position
			_check("drop-in from the catwalk lands on the Express", q.y > 17.0 and q.y < 24.5 and Vector2(q.x, q.z).length() < 18.2, "landed at %s" % q.snappedf(0.1))
			return
	_check("drop-in from the catwalk lands on the Express", false, "never landed")


func _outer_car() -> void:
	_clear()
	level.outer_car.restart()
	await get_tree().physics_frame
	p.spawn(Vector3(43, 1.4, 43), PI * 0.5)
	await get_tree().create_timer(4.5).timeout  # 2 s dock pause + 2.5 s into the leg
	var rode := p.global_position.x < 10.0
	router.scripted_held[A.JUMP] = true
	await get_tree().create_timer(0.1).timeout
	router.scripted_held[A.JUMP] = false
	var top := 0.0
	for i in 60:
		await get_tree().physics_frame
		top = maxf(top, p.horizontal_speed())
	_check("outside hover car carries you and launches you", rode and top > 22.0, "rode=%s top %.1f m/s" % [rode, top])


## Grapple a corner beacon from below, steer outward, and end up on the deck
## just above it (the "grapple up the void" leg of Spiral Run).
func _corner_grapple(label: String, at: Vector3, anchor: Vector3, deck_y: float, out: Vector2) -> void:
	_clear()
	p.motor.grapple_cooldown_left = 0.0
	p.spawn(at + Vector3(0, 0.1, 0), atan2(-out.x, -out.y))  # face outward: forward = (-sin yaw, -cos yaw)
	await get_tree().physics_frame
	var eye := p.global_position + Vector3.UP * p.tuning.eye_height
	var d := anchor - eye
	p.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	p.yaw = atan2(-d.x, -d.z)
	router.scripted_held[A.GRAPPLE] = true
	for i in 90:
		await get_tree().physics_frame
		if p.global_position.y > anchor.y - 1.5:
			break
	p.yaw = atan2(-out.x, -out.y)
	p.pitch = 0.0
	router.scripted_move = Vector2(0, 1)
	for i in 30:
		await get_tree().physics_frame
	router.scripted_held[A.GRAPPLE] = false
	for i in 240:
		await get_tree().physics_frame
		if p.is_on_floor() and i > 20:
			break
	var q := p.global_position
	_check("corner grapple: " + label, absf(q.y - deck_y) < 0.3 and (absf(q.x) >= 18.0 or absf(q.z) >= 18.0), "ended at %s state %s" % [q.snappedf(0.1), p.motor.state_name()])
