class_name LevelBuilder
extends RefCounted
## Builds levels from code with the surface language from DESIGN §4.4.
##
## Efficiency: every block gets its own StaticBody3D with one box shape
## (cheap for physics, and separate blocks stay separate walls for the
## wall-run rules), but the *visuals* of all static blocks are merged into a
## few large meshes per material and 48 m chunk (few draw calls, and chunks
## off-screen are culled). Call finalize() once after building.

## Route tags (RUN/GRAPPLE/BOOST/HAZARD) are painted, saturated surfaces.
## NEUTRAL/DARK are concrete; FACADE is a building with windows; ASPHALT and
## METAL are dressing.
enum Tag { NEUTRAL, DARK, RUN, GRAPPLE, BOOST, HAZARD, FACADE, ASPHALT, METAL }
enum Kind { PAINT, CONCRETE, FACADE, ASPHALT, METAL }

const COLORS := {
	Tag.NEUTRAL: Color(0.9, 0.89, 0.86),
	Tag.DARK: Color(0.58, 0.6, 0.62),
	Tag.RUN: Color(0.95, 0.33, 0.16),
	Tag.GRAPPLE: Color(0.15, 0.82, 1.0),
	Tag.BOOST: Color(1.0, 0.82, 0.1),
	Tag.HAZARD: Color(0.95, 0.15, 0.55),
	Tag.FACADE: Color(0.88, 0.87, 0.84),
	Tag.ASPHALT: Color(0.52, 0.52, 0.51),
	Tag.METAL: Color(0.42, 0.45, 0.48),
}
const KINDS := {
	Tag.NEUTRAL: Kind.CONCRETE, Tag.DARK: Kind.CONCRETE, Tag.FACADE: Kind.FACADE,
	Tag.ASPHALT: Kind.ASPHALT, Tag.METAL: Kind.METAL,
}
const GLOW := {Tag.RUN: 0.06, Tag.GRAPPLE: 0.25, Tag.BOOST: 0.18, Tag.HAZARD: 0.12}  # COLOR.a (x2 in shader)
const CHUNK := 48.0

var root: Node3D
var _batches: Dictionary = {}  # "kind|cx|cz" -> SurfaceTool
var _batch_kind: Dictionary = {}  # same key -> kind
var _grapple_mat: StandardMaterial3D


func _init(p_root: Node3D) -> void:
	root = p_root


## Axis-aligned box from its center and size.
## `tint` overrides the tag color (alpha 0 = use the tag color).
func box(center: Vector3, size: Vector3, tag: Tag = Tag.NEUTRAL, rotation_deg: Vector3 = Vector3.ZERO, tint := Color(0, 0, 0, 0)) -> StaticBody3D:
	var basis := Basis.from_euler(rotation_deg * (PI / 180.0))
	return _make_box(Transform3D(basis, center), size, tag, tint)


## Box from min corner to max corner (easier to reason about for layouts).
func block(min_corner: Vector3, max_corner: Vector3, tag: Tag = Tag.NEUTRAL) -> StaticBody3D:
	return box((min_corner + max_corner) * 0.5, (max_corner - min_corner).abs(), tag)


## Visual-only box (no collision): lane markings, trim, dressing.
func deco(center: Vector3, size: Vector3, tag: Tag = Tag.NEUTRAL, rotation_deg: Vector3 = Vector3.ZERO) -> void:
	var basis := Basis.from_euler(rotation_deg * (PI / 180.0))
	_add_static_visual(Transform3D(basis, center), size, tag, Color(0, 0, 0, 0))


## A ramp whose top surface runs along the center line from `from` to `to`.
func ramp(from: Vector3, to: Vector3, width: float, tag: Tag = Tag.NEUTRAL, thickness: float = 1.0) -> StaticBody3D:
	var f := (to - from).normalized()
	var r := f.cross(Vector3.UP).normalized()
	var u := r.cross(f).normalized()
	var basis := Basis(r, u, -f)
	var center := (from + to) * 0.5 - u * thickness * 0.5
	return _make_box(Transform3D(basis, center), Vector3(width, thickness, from.distance_to(to)), tag, Color(0, 0, 0, 0))


## A Mover whose origin is the pivot. Add shapes with attach_box().
func mover(pivot: Vector3, mode: Mover.Mode = Mover.Mode.PATH) -> Mover:
	var m := Mover.new()
	m.mode = mode
	m.position = pivot  # set before entering the tree: the mover reads its base on first physics tick
	root.add_child(m)
	return m


## Adds a box (collision + mesh) to an existing body at a local offset.
func attach_box(body: CollisionObject3D, local_center: Vector3, size: Vector3, tag: Tag = Tag.NEUTRAL, local_rot_deg: Vector3 = Vector3.ZERO) -> void:
	var xform := Transform3D(Basis.from_euler(local_rot_deg * (PI / 180.0)), local_center)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.transform = xform
	body.add_child(shape)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_box(st, xform, size, _color_for(tag, Color(0, 0, 0, 0)), _uv2_for(tag, local_center))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = SurfaceMaterials.get_material(KINDS.get(tag, Kind.PAINT))
	body.add_child(mi)


## A grapple point that rides along with a (moving) parent node.
func attach_grapple_point(parent: Node3D, local_pos: Vector3) -> Node3D:
	var marker := grapple_point(Vector3.ZERO)
	marker.get_parent().remove_child(marker)
	parent.add_child(marker)
	marker.position = local_pos
	return marker


func grapple_point(pos: Vector3) -> Node3D:
	var marker := Node3D.new()
	marker.name = "GrapplePoint"
	marker.add_to_group(&"grapple_point")
	root.add_child(marker)
	marker.global_position = pos
	if _grapple_mat == null:
		_grapple_mat = StandardMaterial3D.new()
		_grapple_mat.albedo_color = COLORS[Tag.GRAPPLE]
		_grapple_mat.emission_enabled = true
		_grapple_mat.emission = COLORS[Tag.GRAPPLE]
		_grapple_mat.emission_energy_multiplier = 1.5
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.45
	mesh.height = 0.9
	mesh.radial_segments = 16
	mesh.rings = 8
	mi.mesh = mesh
	mi.material_override = _grapple_mat
	marker.add_child(mi)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.45
	shape.shape = sphere
	body.add_child(shape)
	marker.add_child(body)
	return marker


func label(pos: Vector3, text: String, size: int = 64, yaw_deg: float = 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.005
	l.outline_size = 12
	l.modulate = Color(0.12, 0.13, 0.16)
	l.outline_modulate = Color(1, 1, 1, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	root.add_child(l)
	l.global_position = pos
	l.rotation.y = deg_to_rad(yaw_deg)
	return l


## Merges all static visuals into chunked meshes. Call once after building.
func finalize() -> void:
	for key: String in _batches:
		var st: SurfaceTool = _batches[key]
		var mi := MeshInstance3D.new()
		mi.name = "Batch_" + key.replace("|", "_")
		mi.mesh = st.commit()
		mi.material_override = SurfaceMaterials.get_material(_batch_kind[key])
		root.add_child(mi)
	_batches.clear()
	_batch_kind.clear()


func _make_box(xform: Transform3D, size: Vector3, tag: Tag, tint: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	root.add_child(body)
	body.global_transform = xform
	body.set_meta(&"surface", tag)
	_add_static_visual(xform, size, tag, tint)
	return body


func _add_static_visual(xform: Transform3D, size: Vector3, tag: Tag, tint: Color) -> void:
	var kind: int = KINDS.get(tag, Kind.PAINT)
	var c := xform.origin
	var key := "%d|%d|%d" % [kind, floori(c.x / CHUNK), floori(c.z / CHUNK)]
	var st: SurfaceTool = _batches.get(key)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[key] = st
		_batch_kind[key] = kind
	_append_box(st, xform, size, _color_for(tag, tint), _uv2_for(tag, c))


func _color_for(tag: Tag, tint: Color) -> Color:
	var c: Color = tint if tint.a > 0.0 else COLORS[tag]
	return Color(c.r, c.g, c.b, GLOW.get(tag, 0.0))


func _uv2_for(tag: Tag, center: Vector3) -> Vector2:
	var seed_value := fposmod(center.x * 0.37 + center.z * 0.71 + center.y * 0.13, 97.0)
	return Vector2(1.0 if tag == Tag.HAZARD else 0.0, seed_value)


const _FACES := [
	# normal, u axis, v axis (unit cube faces)
	[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
	[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
	[Vector3.BACK, Vector3.LEFT, Vector3.UP], [Vector3.FORWARD, Vector3.RIGHT, Vector3.UP],
]


## Appends a box (12 triangles) with per-vertex color and uv2 to a batch.
static func _append_box(st: SurfaceTool, xform: Transform3D, size: Vector3, color: Color, uv2: Vector2) -> void:
	var h := size * 0.5
	for f in _FACES:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var center := n * h
		var du := u * h
		var dv := v * h
		var corners := [center - du - dv, center + du - dv, center + du + dv, center - du + dv]
		var wn := (xform.basis * n).normalized()
		for i: int in [0, 1, 2, 0, 2, 3]:  # clockwise from outside = front face in Godot
			st.set_normal(wn)
			st.set_color(color)
			st.set_uv2(uv2)
			st.add_vertex(xform * (corners[i] as Vector3))
