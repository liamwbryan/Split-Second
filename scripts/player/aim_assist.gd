class_name AimAssist
extends RefCounted
## Gamepad aim assist (DESIGN §5), one per player, tuned in PlayerSettings:
##  - Slowdown: look-stick speed drops while the reticle is near a target.
##  - Rotational: while you're using the look stick, the view follows part of
##    the target's angular motion relative to you (its strafe, or yours).
## Only the stick's share of the look delta is touched, so mouse aim is never
## assisted, and an idle stick gets nothing: it never aims for you.
##
## Targets are nodes in the `aim_target` group (optional aim_point() and
## is_targetable()). Picking a target and its line-of-sight ray run every few
## ticks; the picked target's angle is sampled every 120 Hz tick so its
## angular rate is exact. The render-frame apply() scales by delta, so the
## pull is the same at any frame rate.

const GROUP := &"aim_target"
const SCAN_TICKS := 3        ## re-pick the target / re-check line of sight this often
const RATE_SMOOTHING := 25.0  ## 1/s low-pass on the target's angular rate (kills step jitter)
const CHEST := 1.2            ## aim point height for targets without aim_point()

var player: Player
var target: Node3D
var target_visible: bool = false

var _slow: float = 0.0        ## 0..0.9 look-stick scale-down right now
var _track: float = 0.0       ## share of the target's angular rate to follow right now
var _rate: Vector2 = Vector2.ZERO  ## target's (yaw, pitch) rate from the eye, rad/s
var _prev_angles: Vector2
var _has_prev: bool = false
var _tick: int = 0
var _ray := PhysicsRayQueryParameters3D.new()


func setup(p_player: Player) -> void:
	player = p_player
	_ray.collision_mask = 1  # world only: hitboxes and players don't block sight
	_ray.exclude = [player.get_rid()]


func reset() -> void:
	target = null
	target_visible = false
	_has_prev = false
	_rate = Vector2.ZERO
	_slow = 0.0
	_track = 0.0


func physics_step(delta: float) -> void:
	var s := player.settings
	var strength: float = PlayerSettings.AIM_ASSIST_SCALE[s.aim_assist]
	if strength <= 0.0:
		reset()
		return
	var eye := player.eye_position()
	_tick += 1
	if _tick % SCAN_TICKS == 0 or not _valid(target):
		_pick(eye)
	_slow = 0.0
	_track = 0.0
	if target == null:
		return
	var to := aim_point(target) - eye
	var dist := to.length()
	if dist > s.aim_assist_range or dist < 0.5:
		reset()
		return
	# Angular rate of the target as seen from the eye (covers both its motion and yours).
	var angles := Vector2(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))
	if _has_prev:
		var raw := Vector2(wrapf(angles.x - _prev_angles.x, -PI, PI), angles.y - _prev_angles.y) / delta
		_rate = _rate.lerp(raw, 1.0 - exp(-RATE_SMOOTHING * delta))
	_prev_angles = angles
	_has_prev = true
	if not target_visible:
		return
	# Full strength inside half the cone, fading to zero at its edge.
	var err := _aim_forward().angle_to(to)
	var w := clampf((1.0 - err / _cone(dist)) * 2.0, 0.0, 1.0)
	var ads := lerpf(s.aim_assist_hip_mult, 1.0, player.weapon.ads_t) if player.weapon else 1.0
	_slow = minf(s.aim_assist_slowdown * strength * w * ads, 0.9)
	_track = s.aim_assist_rotational * strength * w * ads


## Render frame: adjusts the router's look delta (radians, x yaw right, y pitch down).
func apply(look: Vector2, delta: float) -> Vector2:
	var router := player.router
	var mag := router.last_stick_mag
	if mag <= 0.0 or (_slow <= 0.0 and _track <= 0.0):
		return look
	look -= router.last_stick_look * _slow
	var activity := clampf(mag / maxf(player.settings.aim_assist_stick_full, 0.01), 0.0, 1.0)
	var rate := _rate.limit_length(deg_to_rad(player.settings.aim_assist_max_rate))
	# Yaw grows to the left and pitch grows upward, the opposite of look's axes.
	look -= rate * _track * activity * delta
	return look


static func aim_point(node: Node3D) -> Vector3:
	return node.aim_point() if node.has_method(&"aim_point") else node.global_position + Vector3.UP * CHEST


func _pick(eye: Vector3) -> void:
	var s := player.settings
	var fwd := _aim_forward()
	var best: Node3D = null
	var best_score := INF
	for n in player.get_tree().get_nodes_in_group(GROUP):
		var node := n as Node3D
		if not _valid(node):
			continue
		var to := aim_point(node) - eye
		var dist := to.length()
		if dist > s.aim_assist_range or dist < 0.5:
			continue
		var score := fwd.angle_to(to) / _cone(dist)
		if score < 1.0 and score < best_score:
			best_score = score
			best = node
	if best != target:
		reset()
		target = best
	if target:
		_ray.from = eye
		_ray.to = aim_point(target)
		target_visible = player.get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()


func _valid(node: Node3D) -> bool:
	if node == null or not is_instance_valid(node) or node == player or not node.is_inside_tree():
		return false
	return not node.has_method(&"is_targetable") or node.is_targetable()


func _cone(dist: float) -> float:
	var s := player.settings
	return maxf(deg_to_rad(s.aim_assist_cone), atan2(s.aim_assist_target_radius, dist))


func _aim_forward() -> Vector3:
	return Basis(Vector3.UP, player.yaw) * Basis(Vector3.RIGHT, player.pitch) * Vector3.FORWARD
