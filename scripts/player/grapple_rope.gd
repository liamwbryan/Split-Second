class_name GrappleRope
extends Node3D
## The grapple cable, purely cosmetic. It shoots from the launcher with a claw
## hook (a quick whip in the line), sits taut or hangs slack with the swing,
## and reels back in on release.
## Two copies of the line, each built from a few segments on the CPU only while
## visible: the owner's starts at the first-person launcher's muzzle, and
## everyone else's starts at the third-person bracer. The hook is one world
## mesh everyone sees.

const SHOOT_TIME := 0.1
const RETRACT_TIME := 0.16
const SEGMENTS := 14
const SIDES := 5
const RADIUS := 0.0075
const HOOK_SCALE := 2.2  ## the claw is 5 cm; scaled up so it reads at 20 m
const BRACER_FALLBACK := Vector3(-0.3, 1.3, -0.25)  ## body space, if the avatar has no hand bone

enum Phase { IDLE, SHOOT, ATTACHED, RETRACT }

var player: Player
var phase: Phase = Phase.IDLE
var _t: float = 0.0
var _anchor: Vector3
var _retract_from: Vector3
var _owner_line: MeshInstance3D
var _world_line: MeshInstance3D
var _owner_mesh: ImmediateMesh
var _world_mesh: ImmediateMesh
var _hook: Node3D
var _mat: StandardMaterial3D
var _hand_bone: int = -1
var _sag_drawn: float = 0.0  ## eased, so the line never pops between taut and slack


func setup(p_player: Player) -> void:
	player = p_player
	name = "GrappleRope%d" % (player.player_index + 1)
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var color := RunnerAvatar.PLAYER_COLORS[player.player_index % RunnerAvatar.PLAYER_COLORS.size()]
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.03, 0.032, 0.036)
	_mat.roughness = 0.45
	_mat.metallic = 0.4
	_mat.emission_enabled = true
	_mat.emission = color
	_mat.emission_energy_multiplier = 0.2  # a faint glow in the player's color
	_owner_mesh = ImmediateMesh.new()
	_world_mesh = ImmediateMesh.new()
	_owner_line = _line(_owner_mesh, player.camera_rig.viewmodel_layer_bit())
	_world_line = _line(_world_mesh, player.avatar_layer_bit())
	_hook = _build_hook(color)
	visible = false
	if player.avatar and player.avatar.skeleton:
		_hand_bone = player.avatar.skeleton.find_bone("hand_l")
	var m := player.motor
	m.grapple_attached.connect(func(point: Vector3) -> void:
		_anchor = point
		phase = Phase.SHOOT
		_t = 0.0)
	m.grapple_released.connect(func() -> void:
		if phase != Phase.IDLE:
			_retract_from = _head_position()
			phase = Phase.RETRACT
			_t = 0.0)


func _line(mesh: ImmediateMesh, layer_bits: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.layers = layer_bits
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 1.0
	add_child(mi)
	return mi


func _build_hook(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Hook"
	add_child(root)
	var src: Node3D = GrappleGun.MODEL.instantiate()
	var hook := src.find_child("Hook") as MeshInstance3D
	if hook:
		var mi := MeshInstance3D.new()
		mi.mesh = hook.mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3.ONE * HOOK_SCALE
		for i in hook.mesh.get_surface_count():
			var mat := hook.mesh.surface_get_material(i) as BaseMaterial3D
			if mat and mat.resource_name == "Accent":
				var accent := StandardMaterial3D.new()
				accent.albedo_color = color
				accent.emission_enabled = true
				accent.emission = color
				accent.emission_energy_multiplier = 3.0
				mi.set_surface_override_material(i, accent)
		root.add_child(mi)
	src.free()
	root.visible = false
	return root


func _process(delta: float) -> void:
	var motor := player.motor
	match phase:
		Phase.IDLE:
			if visible:
				visible = false
				_set_gun_hook(false)
			return
		Phase.SHOOT:
			if _t == 0.0:
				_sag_drawn = 0.0
			_t += delta
			_anchor = motor.grapple_point
			if _t >= SHOOT_TIME:
				phase = Phase.ATTACHED
		Phase.ATTACHED:
			_anchor = motor.grapple_point
			if motor.state != PlayerMotor.State.GRAPPLE:  # released without the signal (respawn)
				_retract_from = _anchor
				phase = Phase.RETRACT
				_t = 0.0
		Phase.RETRACT:
			_t += delta
			if _t >= RETRACT_TIME:
				phase = Phase.IDLE
				visible = false
				_set_gun_hook(false)
				return
	visible = true
	_set_gun_hook(true)
	var head := _head_position()
	var owner_start := _owner_start()
	var world_start := _bracer_position()
	_sag_drawn = lerpf(_sag_drawn, _sag(world_start, head), 1.0 - exp(-10.0 * delta))
	var sag := _sag_drawn
	var wave := 0.0
	if phase == Phase.SHOOT:
		wave = 0.18 * (1.0 - _t / SHOOT_TIME)
	_owner_line.visible = owner_start.is_finite()
	if _owner_line.visible:
		_build(_owner_mesh, owner_start, head, sag, wave)
	_build(_world_mesh, world_start, head, sag, wave)
	# The claw rides the head of the line, pointing along it.
	var dir := (head - world_start).normalized()
	if phase == Phase.RETRACT:
		dir = -dir  # reeling in: it trails back toward the launcher
	_hook.visible = true
	if dir.length() > 0.01:
		var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		_hook.global_transform = Transform3D(Basis.looking_at(dir, up), head - dir * 0.05 * HOOK_SCALE)


## Where the hook is along its flight.
func _head_position() -> Vector3:
	var start := _bracer_position()
	match phase:
		Phase.SHOOT:
			var f := clampf(_t / SHOOT_TIME, 0.0, 1.0)
			return start.lerp(_anchor, 1.0 - (1.0 - f) * (1.0 - f))  # ease out: fired fast, bites in
		Phase.RETRACT:
			var f := clampf(_t / RETRACT_TIME, 0.0, 1.0)
			return _retract_from.lerp(start, f * f)  # reels in, accelerating
	return _anchor


## A slack rope hangs; a taut one is straight. Reeling in whips it slack.
func _sag(start: Vector3, head: Vector3) -> float:
	var motor := player.motor
	var chord := start.distance_to(head)
	match phase:
		Phase.ATTACHED:
			if motor.state != PlayerMotor.State.GRAPPLE or not player.tuning.grapple_swing:
				return 0.0
			# A dead band: a rope a few cm short of taut still looks straight.
			var slack := maxf(0.0, motor.grapple_rope_length - (player.global_position + Vector3.UP).distance_to(_anchor) - 0.3)
			return minf(sqrt(3.0 * chord * slack / 8.0), 3.0) * (1.0 - motor.grapple_zip)
		Phase.RETRACT:
			return minf(chord * 0.12, 1.5) * (1.0 - _t / RETRACT_TIME)
	return 0.0


## The owner's line starts at the launcher's muzzle (INF: no first-person view).
func _owner_start() -> Vector3:
	var gun := player.camera_rig.grapple_gun
	if gun == null or not gun.visible:
		return Vector3.INF
	return gun.apparent_muzzle()


func _bracer_position() -> Vector3:
	var avatar := player.avatar
	if avatar and avatar.skeleton and _hand_bone >= 0:
		return avatar.skeleton.global_transform * avatar.skeleton.get_bone_global_pose(_hand_bone).origin
	return player.global_position + Basis(Vector3.UP, player.yaw) * BRACER_FALLBACK


func _set_gun_hook(out: bool) -> void:
	var gun := player.camera_rig.grapple_gun
	if gun:
		gun.hook_out = out
	if not out and _hook:
		_hook.visible = false


## A thin tube along a sagging, optionally whipping curve.
func _build(mesh: ImmediateMesh, a: Vector3, b: Vector3, sag: float, wave: float) -> void:
	mesh.clear_surfaces()
	var chord := b - a
	var length := chord.length()
	if length < 0.05:
		return
	var fwd := chord / length
	var side := fwd.cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
	var up := side.cross(fwd).normalized()
	var pts: PackedVector3Array = []
	for i in SEGMENTS + 1:
		var s := float(i) / SEGMENTS
		var p := a + chord * s + Vector3.DOWN * sag * 4.0 * s * (1.0 - s)
		if wave > 0.0:
			p += side * wave * sin(s * PI * 3.0 + _t * 60.0) * sin(s * PI)
		pts.append(p)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat)
	var prev_ring: PackedVector3Array = []
	var prev_norm: PackedVector3Array = []
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var x := t.cross(up)
		x = x.normalized() if x.length() > 0.01 else side
		var y := x.cross(t).normalized()
		var ring: PackedVector3Array = []
		var norm: PackedVector3Array = []
		for k in SIDES:
			var ang := TAU * k / SIDES
			var n := x * cos(ang) + y * sin(ang)
			norm.append(n)
			ring.append(pts[i] + n * RADIUS)
		if i > 0:
			for k in SIDES:
				var k2 := (k + 1) % SIDES
				_tri(mesh, prev_ring[k], ring[k], ring[k2], prev_norm[k], norm[k], norm[k2])
				_tri(mesh, prev_ring[k], ring[k2], prev_ring[k2], prev_norm[k], norm[k2], prev_norm[k2])
		prev_ring = ring
		prev_norm = norm
	mesh.surface_end()


static func _tri(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	# Godot front faces are clockwise seen from outside; flip if this one isn't.
	if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
		var tv := b
		b = c
		c = tv
		var tn := nb
		nb = nc
		nc = tn
	mesh.surface_set_normal(na)
	mesh.surface_add_vertex(a)
	mesh.surface_set_normal(nb)
	mesh.surface_add_vertex(b)
	mesh.surface_set_normal(nc)
	mesh.surface_add_vertex(c)
