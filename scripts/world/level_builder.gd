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
## METAL are dressing. LIGHT is a white emissive light strip (dressing only).
enum Tag { NEUTRAL, DARK, RUN, GRAPPLE, BOOST, HAZARD, FACADE, ASPHALT, METAL, LIGHT }
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
	Tag.LIGHT: Color(0.92, 0.96, 1.0),
}
const KINDS := {
	Tag.NEUTRAL: Kind.CONCRETE, Tag.DARK: Kind.CONCRETE, Tag.FACADE: Kind.FACADE,
	Tag.ASPHALT: Kind.ASPHALT, Tag.METAL: Kind.METAL,
}
const GLOW := {Tag.RUN: 0.06, Tag.GRAPPLE: 0.25, Tag.BOOST: 0.18, Tag.HAZARD: 0.12, Tag.LIGHT: 1.0}  # COLOR.a (x2 in shader)
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


## Collision-only box (the visual comes from elsewhere, e.g. a prop model).
func collider(center: Vector3, size: Vector3, tag: Tag = Tag.NEUTRAL, rotation_deg: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	root.add_child(body)
	body.global_transform = Transform3D(Basis.from_euler(rotation_deg * (PI / 180.0)), center)
	body.set_meta(&"surface", tag)
	return body


## Visual-only box (no collision): lane markings, trim, dressing.
## `tint` overrides the tag color (e.g. a colored LIGHT strip).
func deco(center: Vector3, size: Vector3, tag: Tag = Tag.NEUTRAL, rotation_deg: Vector3 = Vector3.ZERO, tint := Color(0, 0, 0, 0)) -> void:
	var basis := Basis.from_euler(rotation_deg * (PI / 180.0))
	_add_static_visual(Transform3D(basis, center), size, tag, tint)


## A ramp whose top surface runs along the center line from `from` to `to`.
func ramp(from: Vector3, to: Vector3, width: float, tag: Tag = Tag.NEUTRAL, thickness: float = 1.0) -> StaticBody3D:
	var f := (to - from).normalized()
	var r := f.cross(Vector3.UP).normalized()
	var u := r.cross(f).normalized()
	var basis := Basis(r, u, -f)
	var center := (from + to) * 0.5 - u * thickness * 0.5
	return _make_box(Transform3D(basis, center), Vector3(width, thickness, from.distance_to(to)), tag, Color(0, 0, 0, 0))


## A smooth helical ramp (a spiral slide lane) around the vertical axis
## through `center`. Its top is a helicoid (every radial line is level), so a
## slide carries through the curve with no seams: box ramps can't do this,
## because each flat segment tilts sideways at its ends and the joins leave
## 10–25 cm lips. Angles are degrees from +x toward +z; the lane starts at
## `start_deg` at height `y_top` and drops `drop` over `sweep_deg` (either
## sign). One trimesh collider for the whole lane, visuals merged like blocks.
## `collide = false` makes it dressing only (e.g. a light strip along a lane).
func helix_ramp(center: Vector3, r_in: float, r_out: float, y_top: float, start_deg: float, sweep_deg: float, drop: float, tag: Tag = Tag.NEUTRAL, thickness: float = 0.6, step_deg: float = 2.0, tint := Color(0, 0, 0, 0), collide: bool = true) -> StaticBody3D:
	var n := maxi(2, ceili(absf(sweep_deg) / step_deg))
	var top_in: PackedVector3Array = []
	var top_out: PackedVector3Array = []
	for i in n + 1:
		var f := float(i) / n
		var a := deg_to_rad(start_deg + sweep_deg * f)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var y := y_top - drop * f
		top_in.append(center + dir * r_in + Vector3.UP * y)
		top_out.append(center + dir * r_out + Vector3.UP * y)
	var down := Vector3.DOWN * thickness
	var faces: PackedVector3Array = []
	var color := _color_for(tag, tint)
	var mid := center + Vector3.UP * (y_top - drop * 0.5)
	var st := _batch_for(KINDS.get(tag, Kind.PAINT), mid)
	var uv2 := _uv2_for(tag, mid)
	for i in n:
		var a0 := top_in[i]
		var a1 := top_in[i + 1]
		var b0 := top_out[i]
		var b1 := top_out[i + 1]
		var outward := ((b0 + b1) - (a0 + a1)).normalized()
		_quad(st, faces, a0, b0, b1, a1, Vector3.UP, color, uv2)                            # top
		_quad(st, faces, a0 + down, b0 + down, b1 + down, a1 + down, Vector3.DOWN, color, uv2)  # underside
		_quad(st, faces, b0, b1, b1 + down, b0 + down, outward, color, uv2)                 # outer edge
		_quad(st, faces, a0, a1, a1 + down, a0 + down, -outward, color, uv2)                # inner edge
	for k: int in [0, n]:  # end caps
		var i0 := top_in[k]
		var o0 := top_out[k]
		var along := (top_in[mini(k + 1, n)] - top_in[maxi(k - 1, 0)]) * (-1.0 if k == 0 else 1.0)
		_quad(st, faces, i0, o0, o0 + down, i0 + down, along, color, uv2)
	if not collide:
		return null
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var tri := ConcavePolygonShape3D.new()
	tri.backface_collision = true
	tri.set_faces(faces)
	shape.shape = tri
	body.add_child(shape)
	root.add_child(body)
	body.set_meta(&"surface", tag)
	return body


## Appends a quad (two triangles) facing `facing` to a visual batch and to a
## collision face list. Winding is chosen per triangle from `facing`.
static func _quad(st: SurfaceTool, faces: PackedVector3Array, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, facing: Vector3, color: Color, uv2: Vector2) -> void:
	for t: Array in [[p0, p1, p2], [p0, p2, p3]]:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-10:
			continue
		if n.dot(facing) > 0.0:  # Godot front faces are clockwise seen from the front
			var tmp := b
			b = c
			c = tmp
			n = -n
		var wn := -n.normalized()
		for v: Vector3 in [a, b, c]:
			st.set_normal(wn)
			st.set_color(color)
			st.set_uv2(uv2)
			st.add_vertex(v)
			faces.append(v)


## A Mover whose origin is the pivot. Add shapes with attach_box().
func mover(pivot: Vector3, mode: Mover.Mode = Mover.Mode.PATH) -> Mover:
	var m := Mover.new()
	m.mode = mode
	m.position = pivot  # set before entering the tree: the mover reads its base on first physics tick
	root.add_child(m)
	return m


## Adds a box (collision + mesh) to an existing body at a local offset.
## `visual = false` adds only the collision (a model draws that part).
func attach_box(body: CollisionObject3D, local_center: Vector3, size: Vector3, tag: Tag = Tag.NEUTRAL, local_rot_deg: Vector3 = Vector3.ZERO, visual: bool = true) -> void:
	var xform := Transform3D(Basis.from_euler(local_rot_deg * (PI / 180.0)), local_center)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.transform = xform
	body.add_child(shape)
	if visual:
		attach_deco(body, local_center, size, tag, local_rot_deg)


## Visual-only box riding an existing (moving) body: no collision.
func attach_deco(body: Node3D, local_center: Vector3, size: Vector3, tag: Tag = Tag.NEUTRAL, local_rot_deg: Vector3 = Vector3.ZERO) -> void:
	var xform := Transform3D(Basis.from_euler(local_rot_deg * (PI / 180.0)), local_center)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_box(st, xform, size, _color_for(tag, Color(0, 0, 0, 0)), _uv2_for(tag, local_center))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = SurfaceMaterials.get_material(KINDS.get(tag, Kind.PAINT))
	body.add_child(mi)


## A Blender model (visual only, no collision) under `parent` at a local
## transform. Use it for one-off models on movers; static repeated props go
## through Props (one MultiMesh per model). Pair it with attach_box(visual =
## false) or collider() so collision stays simple boxes.
func model(parent: Node3D, scene: PackedScene, local_xform: Transform3D = Transform3D.IDENTITY) -> Node3D:
	var node := scene.instantiate() as Node3D
	parent.add_child(node)
	node.transform = local_xform
	return node


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
	var st := _batch_for(KINDS.get(tag, Kind.PAINT), xform.origin)
	_append_box(st, xform, size, _color_for(tag, tint), _uv2_for(tag, xform.origin))


func _batch_for(kind: int, c: Vector3) -> SurfaceTool:
	var key := "%d|%d|%d" % [kind, floori(c.x / CHUNK), floori(c.z / CHUNK)]
	var st: SurfaceTool = _batches.get(key)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[key] = st
		_batch_kind[key] = kind
	return st


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


## Edge chamfer on block visuals (m). Collision stays an exact box; the
## chamfers catch light so edges read crisp instead of greybox-sharp
## (ART_DIRECTION §2). Capped at a quarter of the block's thinnest side.
const BEVEL := 0.06
## The chamfer actually used (LevelBase sets 0 on the Low preset).
static var bevel_width: float = BEVEL


## Appends a box with per-vertex color and uv2 to a batch: chamfered (44
## triangles) when it's thick enough, else a plain 12-triangle box.
static func _append_box(st: SurfaceTool, xform: Transform3D, size: Vector3, color: Color, uv2: Vector2) -> void:
	var c := minf(bevel_width, minf(size.x, minf(size.y, size.z)) * 0.25)
	if c < 0.004:
		_append_plain_box(st, xform, size, color, uv2)
		return
	var h := size * 0.5
	var ax := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var hc := h - Vector3(c, c, c)
	# The inset vertex of face (axis a, sign s) at the corner with signs sg.
	var fv := func(a: int, sg: Vector3) -> Vector3:
		var p := sg * hc
		p[a] = sg[a] * h[a]
		return p
	# Faces: inset rectangles.
	for a in 3:
		for s: float in [-1.0, 1.0]:
			var b := (a + 1) % 3
			var t := (a + 2) % 3
			var q: Array[Vector3] = []
			for sb_st: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var sg := Vector3.ZERO
				sg[a] = s
				sg[b] = sb_st.x
				sg[t] = sb_st.y
				q.append(fv.call(a, sg))
			var n: Vector3 = ax[a] * s
			_tri_out(st, xform, q[0], q[1], q[2], n, color, uv2)
			_tri_out(st, xform, q[0], q[2], q[3], n, color, uv2)
	# Edges: a chamfer strip between two faces, along the third axis.
	for a in 3:
		var b := (a + 1) % 3
		var t := (a + 2) % 3
		for sa: float in [-1.0, 1.0]:
			for sb: float in [-1.0, 1.0]:
				var q: Array[Vector3] = []
				for st_: float in [-1.0, 1.0]:
					var sg := Vector3.ZERO
					sg[a] = sa
					sg[b] = sb
					sg[t] = st_
					q.append(fv.call(a, sg))
					q.append(fv.call(b, sg))
				var n: Vector3 = ((ax[a] as Vector3) * sa + (ax[b] as Vector3) * sb).normalized()
				_tri_out(st, xform, q[0], q[1], q[3], n, color, uv2)
				_tri_out(st, xform, q[0], q[3], q[2], n, color, uv2)
	# Corners.
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var sg := Vector3(sx, sy, sz)
				_tri_out(st, xform, fv.call(0, sg), fv.call(1, sg), fv.call(2, sg), sg.normalized(), color, uv2)


## One triangle facing local `n` (winding picked so it's a front face).
static func _tri_out(st: SurfaceTool, xform: Transform3D, a: Vector3, b: Vector3, c: Vector3, n: Vector3, color: Color, uv2: Vector2) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:  # Godot front faces are clockwise from the front
		var tmp := b
		b = c
		c = tmp
	var wn := (xform.basis * n).normalized()
	for v: Vector3 in [a, b, c]:
		st.set_normal(wn)
		st.set_color(color)
		st.set_uv2(uv2)
		st.add_vertex(xform * v)


static func _append_plain_box(st: SurfaceTool, xform: Transform3D, size: Vector3, color: Color, uv2: Vector2) -> void:
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
