class_name PlayerHud
extends Control
## Per-player HUD, drawn inside that player's viewport: dynamic crosshair,
## hitmarkers, speed, ammo, double-jump and grapple readiness.

const WHITE := Color(1, 1, 1, 0.92)
const SHADOW := Color(0, 0, 0, 0.45)
const ACCENT := Color(1.0, 0.45, 0.15)
const GRAPPLE := Color(0.2, 0.9, 1.0)
const HEAD := Color(1.0, 0.85, 0.2)
const KILL := Color(1.0, 0.25, 0.2)

var player: Player
var _hit_time: float = 0.0
var _hit_color: Color = WHITE
var _hit_scale: float = 1.0
var _spread_px: float = 10.0
var _font: Font
var _toast: String = ""
var _toast_time: float = 0.0


func setup(p_player: Player) -> void:
	player = p_player
	name = "Hud%d" % (player.player_index + 1)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	player.weapon.hit_confirmed.connect(_on_hit)


## Short centered message (station names, hints).
func toast(text: String, duration: float = 2.0) -> void:
	_toast = text
	_toast_time = duration


func _on_hit(is_head: bool, killed: bool) -> void:
	_hit_time = 0.22 if killed else 0.14
	_hit_color = KILL if killed else (HEAD if is_head else WHITE)
	_hit_scale = 1.5 if killed else 1.0


func _process(delta: float) -> void:
	_hit_time = maxf(0.0, _hit_time - delta)
	_toast_time = maxf(0.0, _toast_time - delta)
	# Crosshair gap tracks real spread (converted from degrees to pixels).
	var cam := player.camera_rig.camera
	var spread_deg := player.weapon.current_spread()
	var px := tan(deg_to_rad(spread_deg)) / tan(deg_to_rad(cam.fov * 0.5)) * size.y * 0.5
	_spread_px = lerpf(_spread_px, maxf(px, 3.0), 1.0 - exp(-25.0 * delta))
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var ui := clampf(size.y / 1080.0, 0.5, 2.0)
	var weapon := player.weapon
	var ads := weapon.ads_t

	# Crosshair (fades out while aiming down sights; the sight takes over).
	var alpha := 1.0 - ads
	if alpha > 0.02:
		var gap := _spread_px + 3.0 * ui
		var arm := 9.0 * ui
		var col := Color(WHITE, WHITE.a * alpha)
		var sh := Color(SHADOW, SHADOW.a * alpha)
		for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
			draw_line(c + d * gap + Vector2(1, 1), c + d * (gap + arm) + Vector2(1, 1), sh, 2.0 * ui)
			draw_line(c + d * gap, c + d * (gap + arm), col, 2.0 * ui)
		draw_circle(c, 1.6 * ui, col)

	if _hit_time > 0.0:
		var a := _hit_time / 0.14
		var hc := Color(_hit_color, clampf(a, 0.0, 1.0))
		var inner := 7.0 * ui * _hit_scale
		var outer := 15.0 * ui * _hit_scale
		for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var n := d.normalized()
			draw_line(c + n * inner, c + n * outer, hc, 2.5 * ui)

	# Speed readout: the momentum meter.
	var speed := player.horizontal_speed()
	var speed_text := "%d" % roundi(speed * 3.6)
	var fs := int(34 * ui)
	var sw := _font.get_string_size(speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var sp := Vector2(c.x - sw * 0.5, size.y - 70.0 * ui)
	var speed_col := WHITE.lerp(ACCENT, clampf((speed - 10.0) / 8.0, 0.0, 1.0))
	draw_string(_font, sp + Vector2(2, 2), speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, SHADOW)
	draw_string(_font, sp, speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, speed_col)
	var unit := "km/h"
	var uw := _font.get_string_size(unit, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * ui)).x
	draw_string(_font, Vector2(c.x - uw * 0.5, size.y - 50.0 * ui), unit, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * ui), Color(1, 1, 1, 0.6))

	# Double jump pip + grapple ring, left of the speed.
	var motor := player.motor
	var pip_pos := Vector2(c.x - 90.0 * ui, size.y - 80.0 * ui)
	var dj_col := ACCENT if motor.double_jump_ready else Color(1, 1, 1, 0.2)
	draw_circle(pip_pos, 7.0 * ui, dj_col)
	var ring_pos := Vector2(c.x + 90.0 * ui, size.y - 80.0 * ui)
	var cd := motor.grapple_cooldown_left / maxf(player.tuning.grapple_cooldown, 0.01)
	var ready := cd <= 0.0 and motor.state != PlayerMotor.State.GRAPPLE
	draw_arc(ring_pos, 10.0 * ui, 0, TAU, 32, Color(1, 1, 1, 0.2), 3.0 * ui)
	if ready:
		draw_arc(ring_pos, 10.0 * ui, 0, TAU, 32, GRAPPLE, 3.0 * ui)
	else:
		var frac := 1.0 - clampf(cd, 0.0, 1.0)
		draw_arc(ring_pos, 10.0 * ui, -PI * 0.5, -PI * 0.5 + TAU * frac, 32, Color(GRAPPLE, 0.6), 3.0 * ui)

	if _toast_time > 0.0:
		var tfs := int(28 * ui)
		var tw := _font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
		var tp := Vector2(c.x - tw * 0.5, size.y * 0.22)
		var ta := clampf(_toast_time / 0.4, 0.0, 1.0)
		draw_string(_font, tp + Vector2(2, 2), _toast, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(SHADOW, SHADOW.a * ta))
		draw_string(_font, tp, _toast, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(WHITE, ta))

	# Ammo, bottom right.
	var ammo_text := "RELOADING" if weapon.reloading else "%d / %d" % [weapon.ammo, weapon.data.magazine]
	var afs := int(26 * ui)
	var aw := _font.get_string_size(ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, afs).x
	var ap := Vector2(size.x - aw - 40.0 * ui, size.y - 50.0 * ui)
	var low := weapon.ammo <= weapon.data.magazine / 4 and not weapon.reloading
	draw_string(_font, ap + Vector2(2, 2), ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, afs, SHADOW)
	draw_string(_font, ap, ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, afs, KILL if low else WHITE)
