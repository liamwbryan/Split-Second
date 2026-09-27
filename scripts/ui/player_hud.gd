class_name PlayerHud
extends Control
## Per-player HUD, drawn inside that player's viewport: dynamic crosshair,
## hitmarkers, speed, ammo, double-jump and grapple readiness, the weapon
## slots, the sniper's scope view, and callouts for long shots and blade hits.

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
var _callout: String = ""
var _callout_time: float = 0.0
var _callout_color: Color = HEAD


func setup(p_player: Player) -> void:
	player = p_player
	name = "Hud%d" % (player.player_index + 1)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	player.weapon.hit_confirmed.connect(_on_hit)
	player.weapon.hit_detail.connect(_on_hit_detail)
	player.melee.hit_landed.connect(_on_melee_hit)


## Short centered message (station names, hints).
func toast(text: String, duration: float = 2.0) -> void:
	_toast = text
	_toast_time = duration


func _on_hit(is_head: bool, killed: bool) -> void:
	_hit_time = 0.22 if killed else 0.14
	_hit_color = KILL if killed else (HEAD if is_head else WHITE)
	_hit_scale = 1.5 if killed else 1.0


## Long shots and scoped headshots get a callout with the distance.
func _on_hit_detail(is_head: bool, killed: bool, distance: float, long_shot: bool) -> void:
	var scoped := player.weapon.data.scoped
	if not ((long_shot and (is_head or killed)) or (scoped and is_head)):
		return
	_callout = "%s  %d m" % ["HEADSHOT" if is_head else "LONG SHOT", roundi(distance)]
	_callout_color = HEAD if is_head else ACCENT
	_callout_time = 1.1
	_hit_scale = 1.8
	_hit_time = 0.26


func _on_melee_hit(killed: bool, _damage: float, style: StringName) -> void:
	_on_hit(false, killed)
	_hit_scale = 1.6 if killed else 1.25
	if style != &"":
		_callout = ("SLIDE STRIKE" if style == &"slide" else "AIR STRIKE") + ("  KILL" if killed else "")
		_callout_color = ACCENT
		_callout_time = 0.9


func _process(delta: float) -> void:
	_hit_time = maxf(0.0, _hit_time - delta)
	_toast_time = maxf(0.0, _toast_time - delta)
	_callout_time = maxf(0.0, _callout_time - delta)
	# Crosshair gap tracks real spread (converted from degrees to pixels).
	var cam := player.camera_rig.camera
	var spread_deg := 0.0 if player.loadout.holding_blade() else player.weapon.current_spread()
	var px := tan(deg_to_rad(spread_deg)) / tan(deg_to_rad(cam.fov * 0.5)) * size.y * 0.5
	_spread_px = lerpf(_spread_px, maxf(px, 3.0), 1.0 - exp(-25.0 * delta))
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var ui := clampf(size.y / 1080.0, 0.5, 2.0)
	var weapon := player.weapon
	var ads := weapon.ads_t
	var blade := player.loadout.holding_blade()

	if weapon.data.scoped and not blade:
		_draw_scope(c, ui, weapon)

	# Crosshair (fades out while aiming down sights; the sight takes over).
	var alpha := 1.0 - ads
	if blade:
		# Blade: a dot, and a ring that lights up when a lunge target is in reach.
		draw_circle(c, 2.2 * ui, WHITE)
		var lunge := player.melee.preview_target != null
		draw_arc(c, 16.0 * ui, 0, TAU, 32, ACCENT if lunge else Color(1, 1, 1, 0.25), (2.5 if lunge else 1.5) * ui)
	elif alpha > 0.02:
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

	# Momentum meter (prototype): a thin bar under the speed that fills as you chain.
	if player.tuning.momentum_enabled:
		var flow := player.motor.flow
		var bw := 110.0 * ui
		var bar := Rect2(c.x - bw * 0.5, size.y - 40.0 * ui, bw, 4.0 * ui)
		draw_rect(bar, Color(1, 1, 1, 0.15))
		if flow > 0.001:
			var fill := Rect2(bar.position, Vector2(bw * flow, bar.size.y))
			draw_rect(fill, ACCENT.lerp(HEAD, clampf(flow * 2.0 - 1.0, 0.0, 1.0)))

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

	if _callout_time > 0.0:
		var cfs := int(24 * ui)
		var cw := _font.get_string_size(_callout, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x
		var cp := Vector2(c.x - cw * 0.5, c.y + 70.0 * ui - (1.1 - _callout_time) * 12.0 * ui)
		var ca := clampf(_callout_time / 0.3, 0.0, 1.0)
		draw_string(_font, cp + Vector2(2, 2), _callout, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, Color(SHADOW, SHADOW.a * ca))
		draw_string(_font, cp, _callout, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, Color(_callout_color, ca))

	# Ammo, bottom right (blades: just the name).
	var afs := int(26 * ui)
	var lo := player.loadout
	if not blade:
		var ammo_text := "RELOADING" if weapon.reloading else "%d / %d" % [weapon.ammo, weapon.data.magazine]
		var aw := _font.get_string_size(ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, afs).x
		var ap := Vector2(size.x - aw - 40.0 * ui, size.y - 50.0 * ui)
		var low := weapon.ammo <= weapon.data.magazine / 4 and not weapon.reloading
		draw_string(_font, ap + Vector2(2, 2), ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, afs, SHADOW)
		draw_string(_font, ap, ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, afs, KILL if low else WHITE)
	# Weapon name and the three slots above it; the current one lit.
	var name_text := lo.current_data().display_name.to_upper()
	var nfs := int(18 * ui)
	var nw := _font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
	var np := Vector2(size.x - nw - 40.0 * ui, size.y - (86.0 if not blade else 50.0) * ui)
	draw_string(_font, np + Vector2(2, 2), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, SHADOW)
	draw_string(_font, np, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(1, 1, 1, 0.85))
	for i in lo.weapons.size():
		var sp2 := Vector2(size.x - 40.0 * ui - (lo.weapons.size() - 1 - i) * 26.0 * ui - 18.0 * ui, np.y - 26.0 * ui)
		var on := i == lo.current
		draw_rect(Rect2(sp2, Vector2(18, 4) * ui), ACCENT if on else Color(1, 1, 1, 0.25))
		var num := str(i + 1)
		draw_string(_font, sp2 + Vector2(5, -4) * ui, num, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * ui), Color(1, 1, 1, 0.9 if on else 0.4))


## Scope view: black outside a circle, a fine reticle with mil dots, fading
## in as the scope comes up to the eye.
func _draw_scope(c: Vector2, ui: float, weapon: HitscanWeapon) -> void:
	var a := clampf((weapon.ads_t - weapon.data.scope_in_at + 0.12) / 0.12, 0.0, 1.0)
	if a <= 0.0:
		return
	var r := size.y * 0.46
	var cover := size.length()  # a ring wide enough to reach every corner
	draw_arc(c, r + cover * 0.5, 0, TAU, 96, Color(0, 0, 0, a), cover)
	draw_arc(c, r + 3.0 * ui, 0, TAU, 96, Color(0.02, 0.02, 0.03, a), 8.0 * ui)
	var ret := Color(0.02, 0.02, 0.02, 0.9 * a)
	draw_line(c + Vector2(-r, 0), c + Vector2(-8 * ui, 0), ret, 1.5 * ui)
	draw_line(c + Vector2(8 * ui, 0), c + Vector2(r, 0), ret, 1.5 * ui)
	draw_line(c + Vector2(0, -r), c + Vector2(0, -8 * ui), ret, 1.5 * ui)
	draw_line(c + Vector2(0, 8 * ui), c + Vector2(0, r), ret, 1.5 * ui)
	for k in range(1, 5):
		var o := k * r * 0.12
		for d: Vector2 in [Vector2(o, 0), Vector2(-o, 0), Vector2(0, o)]:
			draw_circle(c + d, 2.2 * ui, ret)
	draw_circle(c, 1.8 * ui, Color(ACCENT, a))
