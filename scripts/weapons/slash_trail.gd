class_name SlashTrail
extends MeshInstance3D
## A short ribbon behind a swinging blade (base → tip over the last ~0.1 s),
## drawn in camera space with the viewmodel's FOV so it sits on the blade.
## One ImmediateMesh rebuilt only while a swing is on screen.

const MAX_SAMPLES := 10
const LIFE := 0.11

var viewmodel: Viewmodel
var _mesh := ImmediateMesh.new()
var _base: PackedVector3Array = []
var _tip: PackedVector3Array = []
var _age: PackedFloat32Array = []


func setup(p_viewmodel: Viewmodel, layer_bit: int, color: Color) -> void:
	viewmodel = p_viewmodel
	mesh = _mesh
	layers = layer_bit
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	extra_cull_margin = 4.0
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/slash_trail.gdshader")
	m.set_shader_parameter(&"color", color)
	m.set_shader_parameter(&"fp_fov_deg", FPBody.FP_FOV)
	material_override = m


## Called after the viewmodel has been posed this frame.
func sample(delta: float) -> void:
	for i in _age.size():
		_age[i] += delta
	while _age.size() > 0 and (_age[0] > LIFE or _age.size() > MAX_SAMPLES):
		_age.remove_at(0)
		_base.remove_at(0)
		_tip.remove_at(0)
	var swinging := viewmodel.is_blade() and viewmodel.swing_t > 0.08 and viewmodel.swing_t < 0.75 and viewmodel.model_root and viewmodel.model_root.visible
	if swinging:
		var pts := viewmodel.blade_points()
		if pts.size() == 2:
			var inv := get_parent_node_3d().global_transform.affine_inverse()  # camera space
			_base.append(inv * pts[0])
			_tip.append(inv * pts[1])
			_age.append(0.0)
	_mesh.clear_surfaces()
	visible = _age.size() >= 2
	if not visible:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _age.size():
		var a := clampf(1.0 - _age[i] / LIFE, 0.0, 1.0) * float(i + 1) / _age.size()
		_mesh.surface_set_color(Color(1, 1, 1, a))
		_mesh.surface_set_uv(Vector2(0.0, 0.0))
		_mesh.surface_add_vertex(_base[i])
		_mesh.surface_set_color(Color(1, 1, 1, a))
		_mesh.surface_set_uv(Vector2(0.0, 1.0))
		_mesh.surface_add_vertex(_tip[i])
	_mesh.surface_end()
