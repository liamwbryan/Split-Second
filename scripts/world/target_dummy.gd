class_name TargetDummy
extends Node3D
## Shootable practice target with body + head hitboxes. Flashes on hit,
## topples on death, stands back up. Optionally strafes back and forth.

const HITBOX_LAYER := 1 << 2

@export var max_health: float = 100.0
@export var move_axis: Vector3 = Vector3.ZERO  ## world direction * half-distance; zero = static
@export var move_period: float = 3.0

var health: float = 100.0
var _body_mat: StandardMaterial3D
var _head_mat: StandardMaterial3D
var _flash: float = 0.0
var _dead_time: float = -1.0
var _pivot: Node3D
var _origin: Vector3
var _origin_set: bool = false
var _t: float = 0.0

const BASE_COLOR := Color(0.2, 0.22, 0.26)
const HEAD_COLOR := Color(1.0, 0.45, 0.15)


func _ready() -> void:
	health = max_health
	_t = randf() * move_period
	_pivot = Node3D.new()
	add_child(_pivot)
	_body_mat = _mat(BASE_COLOR)
	_head_mat = _mat(HEAD_COLOR)

	var body := _hitbox_capsule(0.38, 1.45, Vector3(0, 0.78, 0), _body_mat, false)
	var head := _hitbox_sphere(0.19, Vector3(0, 1.72, 0), _head_mat)
	_pivot.add_child(body)
	_pivot.add_child(head)

	var stand := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.45
	cyl.height = 0.08
	stand.mesh = cyl
	stand.material_override = _mat(Color(0.3, 0.32, 0.36))
	stand.position.y = 0.04
	add_child(stand)


func take_hit(damage: float, _point: Vector3, _dir: Vector3, _attacker: Node) -> bool:
	if _dead_time >= 0.0:
		return false
	health -= damage
	_flash = 1.0
	if health <= 0.0:
		_dead_time = 0.0
		return true
	return false


func _physics_process(delta: float) -> void:
	if not _origin_set:
		# Read home on the first physics frame, after any placement by the spawner.
		_origin = global_position
		_origin_set = true
		_clamp_path()
	if move_axis != Vector3.ZERO and _dead_time < 0.0:
		_t += delta
		global_position = _origin + move_axis * sin(_t / move_period * TAU)


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 8.0)
	_body_mat.emission_energy_multiplier = _flash * 2.0
	_head_mat.emission_energy_multiplier = 0.4 + _flash * 2.0
	if _dead_time >= 0.0:
		_dead_time += delta
		var fall := clampf(_dead_time / 0.3, 0.0, 1.0)
		_pivot.rotation.x = -PI * 0.5 * (1.0 - pow(1.0 - fall, 3.0))
		if _dead_time > 2.0:
			var rise := clampf((_dead_time - 2.0) / 0.35, 0.0, 1.0)
			_pivot.rotation.x = -PI * 0.5 * (1.0 - rise)
			if rise >= 1.0:
				_dead_time = -1.0
				health = max_health


## Shortens the strafe path so the dummy never walks into level geometry.
func _clamp_path() -> void:
	if move_axis == Vector3.ZERO:
		return
	var space := get_world_3d().direct_space_state
	var dir := move_axis.normalized()
	var reach := move_axis.length()
	var limit := reach
	for side: float in [1.0, -1.0]:
		for h: float in [0.3, 1.0, 1.7]:
			var from := _origin + Vector3.UP * h
			var q := PhysicsRayQueryParameters3D.create(from, from + dir * side * (reach + 0.5), 1)
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				limit = minf(limit, from.distance_to(hit.position) - 0.5)
	move_axis = dir * maxf(limit, 0.0)


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	m.emission_enabled = true
	m.emission = Color(1, 1, 1) if color == BASE_COLOR else color
	m.emission_energy_multiplier = 0.0
	return m


func _hitbox_capsule(radius: float, height: float, pos: Vector3, mat: Material, is_head: bool) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = HITBOX_LAYER
	b.collision_mask = 0
	b.position = pos
	b.set_meta(&"hit_owner", self)
	b.set_meta(&"is_head", is_head)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = height
	cs.shape = cap
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mi.mesh = mesh
	mi.material_override = mat
	b.add_child(mi)
	return b


func _hitbox_sphere(radius: float, pos: Vector3, mat: Material) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = HITBOX_LAYER
	b.collision_mask = 0
	b.position = pos
	b.set_meta(&"hit_owner", self)
	b.set_meta(&"is_head", true)
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	cs.shape = sphere
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mi.mesh = mesh
	mi.material_override = mat
	b.add_child(mi)
	return b
