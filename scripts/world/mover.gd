class_name Mover
extends AnimatableBody3D
## Deterministic moving level geometry (DESIGN §7.2): path movers (lifts,
## sliding containers), continuous rotators (billboards) and swings (crane
## jibs). Movement is a pure function of time, so every cycle is identical and
## routes can be learned. The node's origin is the pivot; attach collision and
## meshes as children at an offset.
##
## Players standing on a mover ride it (CharacterBody platform handling), and
## the motor reads velocity_at() so wall-runs, climbs and mantles stay glued to
## moving surfaces.

enum Mode { PATH, ROTATE, SWING }

var mode: Mode = Mode.PATH

## PATH: offsets from the start transform, visited in order.
var points: PackedVector3Array = PackedVector3Array([Vector3.ZERO])
var move_time: float = 3.0   ## seconds per leg
var pause_time: float = 1.0  ## seconds held at each point
var ping_pong: bool = true   ## A→B→A… instead of looping back to the first point

## ROTATE / SWING
var axis: Vector3 = Vector3.UP  ## local axis
var rotate_speed_deg: float = 30.0
var swing_amplitude_deg: float = 45.0
var period: float = 10.0

## 0..1 cycle offset so several movers can be staggered.
var phase: float = 0.0

var linear_velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO

var _base: Transform3D
var _t: float = 0.0
var _started: bool = false


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0


## Reset the cycle to t=0 (course restarts, tests).
func restart() -> void:
	_t = 0.0
	if _started:
		global_transform = sample(0.0)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


## World-space velocity of the surface at `point` (for wall-runs, climbs, mantles).
func velocity_at(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)


## Transform at time t (seconds since the level started).
func sample(t: float) -> Transform3D:
	match mode:
		Mode.ROTATE:
			return Transform3D(_base.basis * Basis(axis.normalized(), deg_to_rad(rotate_speed_deg) * t), _base.origin)
		Mode.SWING:
			var angle := deg_to_rad(swing_amplitude_deg) * sin(TAU * (t / period + phase))
			return Transform3D(_base.basis * Basis(axis.normalized(), angle), _base.origin)
		_:
			return Transform3D(_base.basis, _base.origin + _base.basis * _path_offset(t))


func cycle_length() -> float:
	match mode:
		Mode.ROTATE:
			return 360.0 / maxf(absf(rotate_speed_deg), 0.001)
		Mode.SWING:
			return period
		_:
			return _leg_count() * (move_time + pause_time)


func _physics_process(delta: float) -> void:
	if not _started:
		_base = global_transform
		_started = true
	var prev := sample(_t)
	_t += delta
	var next := sample(_t)
	global_transform = next
	linear_velocity = (next.origin - prev.origin) / delta
	var dq := Quaternion(next.basis.orthonormalized()) * Quaternion(prev.basis.orthonormalized()).inverse()
	var angle := dq.get_angle()
	angular_velocity = dq.get_axis() * (angle / delta) if angle > 0.00001 else Vector3.ZERO


func _leg_count() -> int:
	var n := points.size()
	if n < 2:
		return 1
	return (n - 1) * 2 if ping_pong else n


func _path_offset(t: float) -> Vector3:
	var n := points.size()
	if n < 2:
		return points[0] if n == 1 else Vector3.ZERO
	var leg_len := move_time + pause_time
	var cycle := _leg_count() * leg_len
	var tt := fposmod(t + phase * cycle, cycle)
	var leg := mini(int(tt / leg_len), _leg_count() - 1)
	var lt := tt - leg * leg_len
	var a := _point_for_leg(leg)
	var b := _point_for_leg(leg + 1)
	if lt < pause_time:
		return a
	var f := clampf((lt - pause_time) / move_time, 0.0, 1.0)
	return a.lerp(b, f * f * (3.0 - 2.0 * f))  # ease in/out: no jarring starts and stops


func _point_for_leg(i: int) -> Vector3:
	var n := points.size()
	if ping_pong:
		var cycle := (n - 1) * 2
		i = i % cycle
		return points[i] if i < n else points[cycle - i]
	return points[i % n]
