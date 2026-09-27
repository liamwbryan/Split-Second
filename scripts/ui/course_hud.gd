class_name CourseHud
extends Control
## Per-player course overlay (inside that player's viewport): run clock,
## checkpoint count, split flash against your best, a waypoint to the next
## gate (pinned to the screen edge when it's off-screen), and the result card.

const WHITE := Color(1, 1, 1, 0.92)
const DIM := Color(1, 1, 1, 0.5)
const SHADOW := Color(0, 0, 0, 0.45)
const AHEAD := Color(0.35, 1.0, 0.5)
const BEHIND := Color(1.0, 0.35, 0.3)
const WAYPOINT := Color(1.0, 0.85, 0.25)
const MEDAL_COLORS := {"GOLD": Color(1.0, 0.8, 0.2), "SILVER": Color(0.8, 0.85, 0.9), "BRONZE": Color(0.85, 0.55, 0.3)}

var course: Course
var player: Player
var _font: Font
var _flash: String = ""
var _flash_color: Color = WHITE
var _flash_time: float = 0.0
var _result_new_best: bool = false
var _last_state: int = -1
var _state_time: float = 0.0


func setup(p_course: Course, p_player: Player) -> void:
	course = p_course
	player = p_player
	name = "CourseHud%d" % (player.player_index + 1)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	course.gate_passed.connect(_on_gate)
	course.finished.connect(_on_finished)


func _on_gate(p: Player, index: int, split: float, delta_best: float) -> void:
	if p != player:
		return
	_flash = "%s   %s" % [course.gates[index].name.to_upper(), Course.format_time(split)]
	_flash_color = WHITE
	if not is_nan(delta_best):
		_flash += "   %s%.2f" % ["+" if delta_best >= 0.0 else "−", absf(delta_best)]
		_flash_color = BEHIND if delta_best > 0.0 else AHEAD
	_flash_time = 2.5


func _on_finished(p: Player, _time: float, new_best: bool) -> void:
	if p == player:
		_result_new_best = new_best


func _process(delta: float) -> void:
	_flash_time = maxf(0.0, _flash_time - delta)
	var run := course.run_of(player)
	if run and run.state != _last_state:
		_last_state = run.state
		_state_time = 0.0
	_state_time += delta
	queue_redraw()


func _draw() -> void:
	var run := course.run_of(player)
	if run == null or size.x < 2.0 or size.y < 2.0:
		return
	var ui := clampf(size.y / 1080.0, 0.5, 2.0)
	var c := size * 0.5
	match run.state:
		Course.RunState.IDLE:
			_waypoint(course.start, "START", ui)
		Course.RunState.ARMED:
			_text_centered(Course.format_time(0.0), Vector2(c.x, 70.0 * ui), int(40 * ui), DIM)
			_text_centered("%s  ·  leave the start to begin" % course.title.to_upper(), Vector2(c.x, 100.0 * ui), int(18 * ui), DIM)
			_waypoint(course.next_target(player), "", ui)
		Course.RunState.RUNNING:
			_text_centered(Course.format_time(run.time), Vector2(c.x, 70.0 * ui), int(40 * ui), WHITE)
			var cp := "CHECKPOINT %d / %d" % [run.next_gate, course.gates.size()] if run.next_gate < course.gates.size() else "TO THE FINISH"
			_text_centered(cp, Vector2(c.x, 100.0 * ui), int(18 * ui), DIM)
			var target := course.next_target(player)
			_waypoint(target, "FINISH" if target == course.finish else "", ui)
		Course.RunState.FINISHED:
			_result_card(run, ui)
		Course.RunState.VOID:
			if _state_time < 3.0:
				_text_centered("Run cancelled (teleported)  ·  T to restart", Vector2(c.x, 90.0 * ui), int(22 * ui), DIM)
			_waypoint(course.start, "START", ui)
	if _flash_time > 0.0 and run.state == Course.RunState.RUNNING:
		var a := clampf(_flash_time / 0.4, 0.0, 1.0)
		_text_centered(_flash, Vector2(c.x, 136.0 * ui), int(26 * ui), Color(_flash_color, a))


func _result_card(run: Course.Run, ui: float) -> void:
	var c := size * 0.5
	var w := 520.0 * ui
	var h := 250.0 * ui
	draw_rect(Rect2(c.x - w * 0.5, c.y - h * 0.62, w, h), Color(0.05, 0.06, 0.08, 0.72))
	var y := c.y - h * 0.62 + 50.0 * ui
	_text_centered("FINISH", Vector2(c.x, y), int(24 * ui), DIM)
	y += 62.0 * ui
	_text_centered(Course.format_time(run.time), Vector2(c.x, y), int(60 * ui), WHITE)
	y += 44.0 * ui
	var medal := Course.medal(run.time, course.par_time)
	var line := "PAR %s" % Course.format_time(course.par_time)
	if medal != "":
		line = "%s   ·   %s" % [medal, line]
	_text_centered(line, Vector2(c.x, y), int(24 * ui), MEDAL_COLORS.get(medal, DIM))
	y += 36.0 * ui
	var best := "NEW BEST" if _result_new_best else "BEST %s" % Course.format_time(course.best_time)
	_text_centered(best, Vector2(c.x, y), int(22 * ui), AHEAD if _result_new_best else DIM)
	y += 36.0 * ui
	_text_centered("T to run again", Vector2(c.x, y), int(18 * ui), DIM)


## Diamond over the gate with its distance; pinned to the screen edge (pointing
## the way) when the gate is behind you or off-screen.
func _waypoint(gate: Course.Gate, label: String, ui: float) -> void:
	if gate == null or gate.contains(player.global_position):
		return  # you're in it (also: its marker would sit in the camera's plane)
	var cam := player.camera_rig.camera
	var vp_size := cam.get_viewport().get_visible_rect().size
	if vp_size.x < 2.0 or vp_size.y < 2.0:
		return  # viewport not laid out yet (projection would be degenerate)
	var world := gate.position + Vector3.UP * 2.0
	var local := cam.global_transform.affine_inverse() * world
	var in_front := local.z < -0.1  # only project points clearly ahead (unproject is singular in the camera plane)
	var margin := 48.0 * ui
	var c := size * 0.5
	var p := cam.unproject_position(world) if in_front else c
	if not in_front or not Rect2(Vector2.ONE * margin, size - Vector2.ONE * margin * 2.0).has_point(p):
		# Pin to the margin box, pointing the way (screen y is down).
		var dir := p - c if in_front else Vector2(local.x, -local.y)
		if dir.length_squared() < 0.0001:
			dir = Vector2.DOWN
		var half := c - Vector2.ONE * margin
		var t := minf(half.x / maxf(absf(dir.x), 0.0001), half.y / maxf(absf(dir.y), 0.0001))
		p = c + dir * t
	var r := 9.0 * ui
	var diamond := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
	draw_colored_polygon(diamond, Color(SHADOW, 0.35))
	draw_polyline(diamond + PackedVector2Array([diamond[0]]), WAYPOINT, 2.5 * ui)
	var dist := player.global_position.distance_to(gate.position)
	var text := "%d m" % roundi(dist)
	if label != "":
		text = "%s  %s" % [label, text]
	_text_centered(text, p + Vector2(0, r + 20.0 * ui), int(16 * ui), WAYPOINT)


func _text_centered(text: String, pos: Vector2, font_size: int, color: Color) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2(pos.x - w * 0.5, pos.y)
	draw_string(_font, at + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(SHADOW, SHADOW.a * color.a))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
