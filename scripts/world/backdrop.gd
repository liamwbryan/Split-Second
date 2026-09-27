class_name Backdrop
extends Node3D
## The world around a map's play space (MAP_BRIEFS §3): huge-feeling scale for
## almost no cost. Nothing here collides or casts shadows, and every layer is
## a single MultiMesh (one draw per layer) or a handful of boxes.
##   - city_floor(): the megacity far below, glowing street grids (one quad)
##   - city(): the mid-rise city on that floor (lit windows at night)
##   - megatowers(): tiered 150–1100 m towers in the mid band
##   - silhouettes(): flat towers fading into haze in the far band
##   - traffic_lane(): flying traffic scrolled on the GPU (hidden on Low)
##   - spire(): a hero landmark with a slowly turning ring
## Add it to the level, call the builders, then finalize().

var _traffic: Array[GeometryInstance3D] = []
var _lights: PackedVector3Array = []
var _rings: Array[Node3D] = []
var _ring_speeds: PackedFloat32Array = []
var _silhouette_mat: StandardMaterial3D
static var _far_mat: ShaderMaterial


func _ready() -> void:
	Graphics.changed.connect(_apply_quality)
	_apply_quality()


func _process(delta: float) -> void:
	for i in _rings.size():
		_rings[i].rotate_object_local(Vector3.UP, _ring_speeds[i] * delta)


## The city floor: one big unshaded quad at height `y`.
func city_floor(y: float, size: float = 4000.0) -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	mi.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/city_floor.gdshader")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = Vector3(0, y, 0)


## Mid-rise city blocks standing on the floor at `floor_y`, between radii
## `inner` and `outer` around `center` (skipping anything inside `keep_out`).
func city(center: Vector3, floor_y: float, inner: float, outer: float, count: int, h_min: float, h_max: float, seed_value: int, keep_out: Array[AABB] = []) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var xforms: Array[Transform3D] = []
	var colors: PackedColorArray = []
	var tries := 0
	while xforms.size() < count and tries < count * 4:
		tries += 1
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf_range(inner * inner, outer * outer))  # even density by area
		var w := rng.randf_range(20.0, 55.0)
		var d := rng.randf_range(20.0, 55.0)
		var h := rng.randf_range(h_min, h_max)
		var p := center + Vector3(cos(a) * r, 0.0, sin(a) * r)
		p.y = floor_y + h * 0.5
		if _blocked(p, Vector3(w, h, d), keep_out):
			continue
		xforms.append(Transform3D(Basis(Vector3.UP, rng.randi_range(0, 3) * PI * 0.5).scaled(Vector3(w, h, d)), p))
		var shade := rng.randf_range(0.55, 0.85)
		colors.append(Color(shade, shade * 1.02, shade * 1.08, 0.0))
	_facade_multimesh(xforms, colors)


## Megatowers: a base shaft plus one or two setback tiers, heights measured
## from `floor_y`. The tallest get aircraft warning lights.
func megatowers(center: Vector3, floor_y: float, inner: float, outer: float, count: int, h_min: float, h_max: float, seed_value: int, keep_out: Array[AABB] = []) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var xforms: Array[Transform3D] = []
	var colors: PackedColorArray = []
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 6:
		tries += 1
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf_range(inner * inner, outer * outer))
		var w := rng.randf_range(45.0, 90.0)
		var d := rng.randf_range(45.0, 90.0)
		var h := rng.randf_range(h_min, h_max)
		var base := center + Vector3(cos(a) * r, floor_y, sin(a) * r)
		if _blocked(base + Vector3.UP * h * 0.5, Vector3(w, h, d), keep_out):
			continue
		placed += 1
		var yaw := rng.randf_range(-0.3, 0.3)
		var shade := rng.randf_range(0.6, 0.9)
		var col := Color(shade * 0.95, shade, shade * 1.1, 0.0)
		# Tier 1: 55–70% of the height at full footprint, then setbacks.
		var tiers := rng.randi_range(1, 3)
		var y0 := 0.0
		var fw := w
		var fd := d
		for t in tiers:
			var th := h - y0 if t == tiers - 1 else h * rng.randf_range(0.45, 0.65) - y0
			th = maxf(th, 20.0)
			var c := base + Vector3(0, y0 + th * 0.5, 0)
			xforms.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(fw, th, fd)), c))
			colors.append(col)
			y0 += th
			fw *= rng.randf_range(0.6, 0.8)
			fd *= rng.randf_range(0.6, 0.8)
		if h > h_min + (h_max - h_min) * 0.35:
			_lights.append(base + Vector3.UP * (y0 + 2.0))
	_facade_multimesh(xforms, colors)


## Far towers: flat dark boxes that dissolve into the haze (cheapest shader).
func silhouettes(center: Vector3, floor_y: float, inner: float, outer: float, count: int, h_min: float, h_max: float, color: Color, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = count
	var box := BoxMesh.new()
	mm.mesh = box
	for i in count:
		var a := rng.randf() * TAU
		var r := rng.randf_range(inner, outer)
		var w := rng.randf_range(60.0, 140.0)
		var h := rng.randf_range(h_min, h_max)
		var p := center + Vector3(cos(a) * r, floor_y + h * 0.5, sin(a) * r)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(w, h, w * rng.randf_range(0.6, 1.4))), p))
	if _silhouette_mat == null:
		_silhouette_mat = StandardMaterial3D.new()
		_silhouette_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_silhouette_mat.albedo_color = color
	_add_multimesh(mm, _silhouette_mat)


## A flying traffic lane from `from` to `to`: `count` cars in two directions,
## scrolled on the GPU. Hidden on the Low preset.
func traffic_lane(from: Vector3, to: Vector3, count: int, speed: float, seed_value: int, spread: Vector2 = Vector2(6.0, 3.0)) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var length := from.distance_to(to)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.instance_count = count
	var car := BoxMesh.new()
	car.size = Vector3(4.2, 1.0, 1.9)
	mm.mesh = car
	for i in count:
		var dir := 1.0 if i % 2 == 0 else -1.0
		# Two stacked streams: one each way, offset sideways and in height.
		var lateral := Vector3(0, rng.randf_range(-spread.y, spread.y) + dir * spread.y, rng.randf_range(-spread.x, spread.x) * 0.3 + dir * spread.x)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, lateral))
		mm.set_instance_custom_data(i, Color(rng.randf(), dir, rng.randf_range(0.85, 1.15), 0.0))
		mm.set_instance_color(i, Color(1.0, 0.92, 0.8) if dir > 0.0 else Color(1.0, 0.25, 0.2))
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/traffic.gdshader")
	mat.set_shader_parameter(&"lane_length", length)
	mat.set_shader_parameter(&"speed", speed)
	var mmi := _add_multimesh(mm, mat)
	var x := (to - from).normalized()
	var z := x.cross(Vector3.UP).normalized()
	mmi.global_transform = Transform3D(Basis(x, Vector3.UP, z).orthonormalized(), (from + to) * 0.5)
	mmi.custom_aabb = AABB(Vector3(-length * 0.5 - 5.0, -spread.y * 2.0 - 2.0, -spread.x * 2.0 - 2.0), Vector3(length + 10.0, spread.y * 4.0 + 4.0, spread.x * 4.0 + 4.0))
	_traffic.append(mmi)


## Hero landmark: a tapering spire of stacked boxes with a glowing ring that
## turns slowly around it (one node updated per frame).
func spire(base: Vector3, height: float, width: float, ring_y: float, ring_radius: float, ring_color: Color) -> void:
	var xforms: Array[Transform3D] = []
	var colors: PackedColorArray = []
	var y := 0.0
	var w := width
	var sections := 6
	for i in sections:
		var h := height / sections
		xforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(w, h, w)), base + Vector3(0, y + h * 0.5, 0)))
		colors.append(Color(0.85, 0.88, 0.95, 0.0))
		y += h
		w *= 0.78
	# Needle.
	xforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(w * 0.3, height * 0.25, w * 0.3)), base + Vector3(0, y + height * 0.125, 0)))
	colors.append(Color(0.9, 0.92, 1.0, 0.0))
	_facade_multimesh(xforms, colors)
	_lights.append(base + Vector3(0, y + height * 0.25 + 3.0, 0))

	var pivot := Node3D.new()
	add_child(pivot)
	pivot.position = base + Vector3(0, ring_y, 0)
	pivot.rotation = Vector3(deg_to_rad(12.0), 0, deg_to_rad(-6.0))
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = ring_radius - 6.0
	torus.outer_radius = ring_radius
	torus.rings = 96
	torus.ring_segments = 8
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = ring_color * 2.5
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(ring)
	# Spokes (thin boxes) so the ring reads as a structure, not a halo.
	for k in 3:
		var spoke := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(ring_radius * 2.0, 2.5, 2.5)
		spoke.mesh = bm
		spoke.material_override = SurfaceMaterials.get_material(LevelBuilder.Kind.METAL)
		spoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spoke.rotation.y = k * PI / 3.0
		pivot.add_child(spoke)
	_rings.append(pivot)
	_ring_speeds.append(deg_to_rad(4.0))


## Builds the warning-light layer. Call once after the other builders.
func finalize() -> void:
	if _lights.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = _lights.size()
	var s := SphereMesh.new()
	s.radius = 2.2
	s.height = 4.4
	s.radial_segments = 8
	s.rings = 4
	mm.mesh = s
	for i in _lights.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, _lights[i]))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.12, 0.08) * 4.0
	_add_multimesh(mm, mat)


func _apply_quality() -> void:
	for t in _traffic:
		t.visible = Graphics.quality > Graphics.Quality.LOW


func _facade_multimesh(xforms: Array[Transform3D], colors: PackedColorArray) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = xforms.size()
	mm.mesh = BoxMesh.new()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	if _far_mat == null:
		_far_mat = ShaderMaterial.new()
		_far_mat.shader = preload("res://shaders/facade_far.gdshader")
	_add_multimesh(mm, _far_mat)


func _add_multimesh(mm: MultiMesh, mat: Material) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


static func _blocked(center: Vector3, size: Vector3, keep_out: Array[AABB]) -> bool:
	var box := AABB(center - size * 0.5, size)
	for k in keep_out:
		if k.intersects(box):
			return true
	return false
