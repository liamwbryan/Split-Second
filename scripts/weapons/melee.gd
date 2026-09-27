class_name Melee
extends Node
## Blade attacks (DESIGN §5): swings with a 2–3 hit combo, a lunge that
## closes on a target in front of you, and style multipliers for slide and air
## melee. Hits are a cone check against `aim_target` nodes (no physics bodies),
## with a line-of-sight ray. Feel: per-player hit-stop (the owner's movement
## freezes for a few frames), camera punch, a slash trail, meaty sound.
##
## The lunge is a motor state (PlayerMotor.State.LUNGE), so the motor stays the
## only owner of velocity; the swing waits at its windup until the lunge lands.

signal swung(combo_index: int)
signal hit_landed(killed: bool, damage: float, style: StringName)
signal finished

const LOS_MASK := 1  ## world only

var player: Player
var rig: CameraRig
var viewmodel: Viewmodel
var data: WeaponData            ## the blade being swung
var busy: bool = false
var hitstop_left: float = 0.0
var combo_index: int = 0
## Lunge target the HUD can show (in lunge range and in the cone), or null,
## for the blade the next melee press would use (set by the Loadout).
var preview_target: Node3D
var preview_data: WeaponData

var _t: float = 0.0             ## 0..1 through the swing
var _struck: bool = false
var _lunging: bool = false
var _queued: bool = false
var _queued_quick: bool = false
var _since_end: float = 99.0
var _next_combo: int = 0
var _style: StringName = &""
var _style_mult: float = 1.0
var _preview_tick: int = 0
var _ray := PhysicsRayQueryParameters3D.new()


func setup(p_player: Player, p_rig: CameraRig, p_viewmodel: Viewmodel) -> void:
	player = p_player
	rig = p_rig
	viewmodel = p_viewmodel
	_ray.collision_mask = LOS_MASK
	_ray.exclude = [player.get_rid()]
	player.motor.lunge_finished.connect(func(_reached: bool) -> void: _lunging = false)


func cancel() -> void:
	busy = false
	_lunging = false
	_queued = false
	hitstop_left = 0.0
	viewmodel.swing_t = -1.0
	_since_end = 99.0


## Start a swing with blade `d` (quick = a quick melee from a gun: the blade
## comes up from below). Pressing again during a swing buffers the next hit of
## the combo (it starts the moment this one ends). Returns true if a new swing
## started.
func swing(d: WeaponData, quick: bool) -> bool:
	if busy:
		_queued = true
		_queued_quick = quick
		return false
	data = d
	combo_index = _next_combo if _since_end <= d.combo_window else 0
	combo_index = combo_index % maxi(d.combo_count, 1)
	var motor := player.motor
	_style = &""
	_style_mult = 1.0
	if motor.state == PlayerMotor.State.SLIDE:
		_style = &"slide"
		_style_mult = d.slide_melee_mult
	elif motor.state in [PlayerMotor.State.AIR, PlayerMotor.State.WALLRUN, PlayerMotor.State.GRAPPLE]:
		_style = &"air"
		_style_mult = d.air_melee_mult
	busy = true
	_t = 0.0
	_struck = false
	_queued = false
	_lunging = false
	var target := find_lunge_target(d)
	if target and _chest_distance(target) > d.melee_range * 0.85:
		if motor.start_lunge(target, d.lunge_speed, d.lunge_stop_distance, d.lunge_max_time, d.lunge_exit_keep):
			_lunging = true
			Sfx.play(&"lunge", -6.0, 0.05)
			rig.add_trauma(0.08)
	viewmodel.swing_index = combo_index
	viewmodel.swing_from_low = quick
	viewmodel.swing_t = 0.0
	Sfx.play(&"slash", -7.0, 0.08, 1.0 + combo_index * 0.07)
	swung.emit(combo_index)
	return true


func physics_step(delta: float) -> void:
	_since_end += delta
	_preview_tick += 1
	if _preview_tick % 4 == 0:
		preview_target = find_lunge_target(preview_data) if preview_data else null
	if not busy:
		return
	if _lunging and player.motor.state == PlayerMotor.State.LUNGE:
		# Hold at the windup until the lunge lands, then strike.
		_t = minf(_t + delta / data.swing_time, data.strike_at * 0.7)
		viewmodel.swing_t = _t
		return
	_lunging = false
	_t += delta / data.swing_time
	viewmodel.swing_t = minf(_t, 1.0)
	if not _struck and _t >= data.strike_at:
		_struck = true
		_strike()
	if _t >= 1.0:
		busy = false
		viewmodel.swing_t = -1.0
		_since_end = 0.0
		_next_combo = (combo_index + 1) % maxi(data.combo_count, 1)
		if _queued:
			_queued = false
			swing(data, _queued_quick)
		else:
			finished.emit()


## The best target to lunge at: in range, inside the (pad: wider) cone, in
## sight. Null if none.
func find_lunge_target(d: WeaponData) -> Node3D:
	if d == null or d.lunge_range <= 0.0:
		return null
	var eye := player.eye_position()
	var fwd := -rig.camera.global_basis.z
	var cone := d.lunge_cone_pad_deg if player.router.last_device_was_pad else d.lunge_cone_deg
	var cos_cone := cos(deg_to_rad(maxf(cone, d.melee_cone_deg * 0.5)))
	var best: Node3D = null
	var best_score := INF
	for n in player.get_tree().get_nodes_in_group(AimAssist.GROUP):
		var t := n as Node3D
		if t == null or t == player or not _targetable(t):
			continue
		var p := _aim_point(t)
		var to := p - eye
		var dist := to.length()
		if dist > d.lunge_range + 1.0 or dist < 0.01:
			continue
		var c := fwd.dot(to / dist)
		if c < cos_cone:
			continue
		var score := dist * (2.0 - c)
		if score < best_score and _in_sight(eye, p):
			best = t
			best_score = score
	return best


func _strike() -> void:
	var eye := player.eye_position()
	var fwd := -rig.camera.global_basis.z
	var cos_cone := cos(deg_to_rad(data.melee_cone_deg * 0.5))
	var finisher := data.combo_count > 1 and combo_index == data.combo_count - 1
	var dmg := data.melee_damage * _style_mult * (data.combo_finisher_mult if finisher else 1.0)
	var hits := 0
	var any_kill := false
	for n in player.get_tree().get_nodes_in_group(AimAssist.GROUP):
		var t := n as Node3D
		if t == null or t == player or not _targetable(t):
			continue
		var p := _aim_point(t)
		var to := p - eye
		var dist := to.length()
		if dist > data.melee_range or dist < 0.01:
			continue
		if fwd.dot(to / dist) < cos_cone and dist > 1.0:  # point-blank always connects
			continue
		if not _in_sight(eye, p):
			continue
		var killed: bool = t.take_hit(dmg, p, to / dist, player)
		any_kill = any_kill or killed
		hits += 1
		Fx.impact(p - to / dist * 0.3, -to / dist, true)
		hit_landed.emit(killed, dmg, _style)
	if hits > 0:
		hitstop_left = data.hitstop * (1.6 if any_kill else 1.0)
		rig.punch(deg_to_rad(-1.2 if combo_index == 2 else 0.6), deg_to_rad(1.4 if combo_index == 0 else -1.4))
		rig.add_trauma(0.22 if any_kill else 0.14)
		Sfx.play(&"slash_hit", -2.0, 0.06, 0.9 if finisher else 1.0)
		if any_kill:
			Sfx.play(&"kill", -4.0)


func _chest_distance(t: Node3D) -> float:
	return (_aim_point(t) - player.eye_position()).length()


func _in_sight(eye: Vector3, p: Vector3) -> bool:
	_ray.from = eye
	_ray.to = p
	return player.get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()


static func _aim_point(t: Node3D) -> Vector3:
	return t.aim_point() if t.has_method(&"aim_point") else t.global_position + Vector3.UP * 1.2


static func _targetable(t: Node3D) -> bool:
	return t.is_targetable() if t.has_method(&"is_targetable") else true
