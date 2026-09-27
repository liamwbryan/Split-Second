extends Node
## PENDULUM HALL checks: pads reach the galleries, the bob can be ridden
## through a full swing at ±30°, and it launches you at ~30 m/s.
##   godot --headless --path . --fixed-fps 120 res://tests/pendulum_tests.tscn

const A := InputRouter.Action
var level: LevelBase
var p: Player
var router: InputRouter
var failures := 0


func _ready() -> void:
	level = load("res://scenes/pendulum_hall.tscn").instantiate()
	add_child(level)
	await get_tree().physics_frame
	p = level.players[0]
	router = p.router
	router.scripted = true
	router.use_kbm = false
	if level.course:
		level.course.save_records = false
	await _pad("west pad → north gallery 8", Vector3(-14, 0.12, -14), 8.0, Rect2(-20, -26, 12, 6))
	await _pad("east pad → south gallery 8", Vector3(26, 0.12, 14), 8.0, Rect2(20, 20, 12, 6))
	await _ride()
	print("\npendulum: %d failures" % failures)
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
	p.spawn(at + Vector3(0, 0.1, 0), 0.0)
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


## Stand on the bob at the end of a swing, ride a full period, then jump at
## the bottom: the jump carries the bob's ~29 m/s.
func _ride() -> void:
	_clear()
	var pend: Mover = level.get("pendulum")
	pend.restart()
	for i in 3:
		await get_tree().physics_frame
	# t=0 is the bottom; wait for the east end (t = 2.5 s) and board there.
	await get_tree().create_timer(2.45).timeout
	var top := pend.global_transform * Vector3(0, -89.7, 0)
	p.spawn(top + Vector3.UP * 0.1, 0.0)
	var stayed := true
	for i in 1200:
		await get_tree().physics_frame
		var bob := pend.global_transform * Vector3(0, -89.7, 0)
		var d := p.global_position - bob
		if Vector2(d.x, d.z).length() > 4.6 or d.y < -1.0:
			stayed = false
	_check("ride the bob for a full swing", stayed, "")
	await get_tree().create_timer(2.5).timeout  # back at the bottom
	router.scripted_held[A.JUMP] = true
	await get_tree().create_timer(0.05).timeout
	router.scripted_held[A.JUMP] = false
	var top_speed := 0.0
	for i in 60:
		await get_tree().physics_frame
		top_speed = maxf(top_speed, p.horizontal_speed())
	_check("jump off the bottom of the swing ≈ 30 m/s", top_speed > 26.0, "%.1f m/s" % top_speed)
