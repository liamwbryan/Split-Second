extends Node
## Autoload. Pooled world effects (tracers, impacts). Nothing is instantiated
## during gameplay, so shooting never causes allocation hitches.

const TRACER_COUNT := 48
const IMPACT_COUNT := 32
const TRACER_LIFE := 0.07
const TRACER_SPEED := 450.0

var _tracers: Array[MeshInstance3D] = []
var _tracer_age: PackedFloat32Array = []
var _tracer_len: PackedFloat32Array = []
var _tracer_from: PackedVector3Array = []
var _tracer_dir: PackedVector3Array = []
var _tracer_i: int = 0

var _impacts: Array[CPUParticles3D] = []
var _flashes: Array[MeshInstance3D] = []
var _flash_age: PackedFloat32Array = []
var _impact_i: int = 0
var _world_mat: StandardMaterial3D
var _hit_mat: StandardMaterial3D


func _ready() -> void:
	var tracer_shader := Shader.new()
	tracer_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled;
instance uniform float fade = 1.0;
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.5, 1.0);
void fragment() {
	ALBEDO = color.rgb * 2.5;
	ALPHA = fade;
}
"""
	var tracer_mat := ShaderMaterial.new()
	tracer_mat.shader = tracer_shader
	var tracer_mesh := BoxMesh.new()
	tracer_mesh.size = Vector3(0.018, 0.018, 1.0)
	for i in TRACER_COUNT:
		var mi := MeshInstance3D.new()
		mi.mesh = tracer_mesh
		mi.material_override = tracer_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(mi)
		_tracers.append(mi)
		_tracer_age.append(99.0)
		_tracer_len.append(0.0)
		_tracer_from.append(Vector3.ZERO)
		_tracer_dir.append(Vector3.FORWARD)

	_world_mat = _spark_mat(Color(1.0, 0.85, 0.55))
	_hit_mat = _spark_mat(Color(1.0, 0.3, 0.2))
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.025, 0.025, 0.025)
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.12
	flash_mesh.height = 0.24
	flash_mesh.radial_segments = 8
	flash_mesh.rings = 4
	for i in IMPACT_COUNT:
		var p := CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = 10
		p.lifetime = 0.28
		p.explosiveness = 1.0
		p.mesh = spark_mesh
		p.direction = Vector3(0, 0, 1)
		p.spread = 55.0
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 9.0
		p.gravity = Vector3(0, -18, 0)
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.4
		p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		p.local_coords = false
		add_child(p)
		_impacts.append(p)
		var f := MeshInstance3D.new()
		f.mesh = flash_mesh
		f.visible = false
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(f)
		_flashes.append(f)
		_flash_age.append(99.0)


func tracer(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.5:
		return
	var i := _tracer_i
	_tracer_i = (_tracer_i + 1) % TRACER_COUNT
	_tracer_age[i] = 0.0
	_tracer_len[i] = length
	_tracer_from[i] = from
	_tracer_dir[i] = (to - from) / length
	_tracers[i].visible = true
	_update_tracer(i)


func impact(point: Vector3, normal: Vector3, on_target: bool) -> void:
	var i := _impact_i
	_impact_i = (_impact_i + 1) % IMPACT_COUNT
	var p := _impacts[i]
	var up := Vector3.UP if absf(normal.y) < 0.95 else Vector3.RIGHT
	p.global_transform = Transform3D(Basis.looking_at(-normal, up), point + normal * 0.02)
	p.material_override = _hit_mat if on_target else _world_mat
	p.restart()
	var f := _flashes[i]
	f.material_override = p.material_override
	f.global_position = point + normal * 0.03
	f.visible = true
	f.scale = Vector3.ONE * (1.2 if on_target else 0.8)
	_flash_age[i] = 0.0


func _process(delta: float) -> void:
	for i in TRACER_COUNT:
		if _tracer_age[i] >= TRACER_LIFE:
			continue
		_tracer_age[i] += delta
		if _tracer_age[i] >= TRACER_LIFE:
			_tracers[i].visible = false
		else:
			_update_tracer(i)
	for i in IMPACT_COUNT:
		if _flash_age[i] > 0.06:
			continue
		_flash_age[i] += delta
		if _flash_age[i] > 0.06:
			_flashes[i].visible = false


func _update_tracer(i: int) -> void:
	# A streak that travels from the muzzle to the hit, fading as it goes.
	var age := _tracer_age[i]
	var head := minf(_tracer_len[i], age * TRACER_SPEED + 6.0)
	var tail := maxf(0.0, head - 7.0)
	var mid := _tracer_from[i] + _tracer_dir[i] * ((head + tail) * 0.5)
	var seg := maxf(0.05, head - tail)
	var mi := _tracers[i]
	var up := Vector3.UP if absf(_tracer_dir[i].y) < 0.98 else Vector3.RIGHT
	var b := Basis.looking_at(_tracer_dir[i], up)
	b.z *= seg
	mi.global_transform = Transform3D(b, mid)
	mi.set_instance_shader_parameter(&"fade", 1.0 - age / TRACER_LIFE)


func _spark_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.0
	return m
