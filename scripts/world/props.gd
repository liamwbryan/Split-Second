class_name Props
extends RefCounted
## Rooftop/street props and the city kit (docs/ART_DIRECTION.md). Modeled
## props (art/blender/rooftop_props.py, city_kit.py) are drawn with one
## MultiMesh per model, built in finalize(), and keep simple box collision.
## Props that matter for movement get collision; dressing is visual only.
##
## Kit models tint per instance: material "KitPaint" takes the instance
## colour (car paint, crate colours), "KitSign" takes the custom-data colour
## (sign and screen glow, see shaders/kit_sign.gdshader). Small dressing
## fades out past its visibility range and casts no shadows.

const T := LevelBuilder.Tag
const AC_SMALL := preload("res://assets/models/prop_ac_small.glb")
const AC_BIG := preload("res://assets/models/prop_ac_big.glb")
const VENT := preload("res://assets/models/prop_vent.glb")
const WATER_TOWER := preload("res://assets/models/prop_water_tower.glb")
const KIT := {
	"hovercar": preload("res://assets/models/kit_hovercar.glb"),
	"railing": preload("res://assets/models/kit_railing.glb"),
	"barrier": preload("res://assets/models/kit_barrier.glb"),
	"crate": preload("res://assets/models/kit_crate.glb"),
	"kiosk": preload("res://assets/models/kit_kiosk.glb"),
	"holo_pylon": preload("res://assets/models/kit_holo_pylon.glb"),
	"charger": preload("res://assets/models/kit_charger.glb"),
	"sign_blade": preload("res://assets/models/kit_sign_blade.glb"),
	"sign_banner": preload("res://assets/models/kit_sign_banner.glb"),
	"glyph_panel": preload("res://assets/models/kit_glyph_panel.glb"),
	"pipe_run": preload("res://assets/models/kit_pipe_run.glb"),
	"duct": preload("res://assets/models/kit_duct.glb"),
	"cable_bundle": preload("res://assets/models/kit_cable_bundle.glb"),
	"vent_grille": preload("res://assets/models/kit_vent_grille.glb"),
	"fan": preload("res://assets/models/kit_fan.glb"),
	"junction_box": preload("res://assets/models/kit_junction_box.glb"),
	"lamp": preload("res://assets/models/kit_lamp.glb"),
	"bench": preload("res://assets/models/kit_bench.glb"),
	"planter": preload("res://assets/models/kit_planter.glb"),
	"bollard": preload("res://assets/models/kit_bollard.glb"),
}
## Visibility range (m) per kit model. Cover stays visible across the whole
## map (you must see what you can hide behind); small dressing fades early.
const KIT_RANGE := {
	"hovercar": 400.0, "barrier": 400.0, "crate": 400.0, "kiosk": 400.0, "holo_pylon": 400.0,
	"charger": 400.0, "planter": 400.0, "railing": 250.0, "lamp": 250.0, "sign_blade": 500.0,
	"sign_banner": 600.0, "glyph_panel": 110.0, "pipe_run": 120.0, "duct": 120.0,
	"cable_bundle": 150.0, "vent_grille": 80.0, "fan": 90.0, "junction_box": 70.0,
	"bench": 90.0, "bollard": 70.0,
}
## Kit models that cast shadows (cover and big shapes); dressing doesn't.
const KIT_SHADOW := ["hovercar", "barrier", "crate", "kiosk", "holo_pylon", "charger", "planter", "lamp", "railing"]
## Neon accent palette for signs (ART_DIRECTION §2): magenta, cyan, amber, warm white.
const NEON := [Color(1.0, 0.23, 0.69), Color(0.23, 0.91, 1.0), Color(1.0, 0.7, 0.28), Color(1.0, 0.91, 0.78)]

var b: LevelBuilder
var root: Node3D
var _visual_mat: ShaderMaterial
var _instances: Dictionary = {}  ## PackedScene -> Array of [Transform3D, paint Color, glow Color]


func _init(builder: LevelBuilder) -> void:
	b = builder
	root = builder.root


## Low roof-edge wall. Vaultable at sprint (≤1.25 m), mantle-able otherwise.
func parapet(min_corner: Vector3, max_corner: Vector3, height: float = 0.6, thickness: float = 0.35) -> void:
	var y := min_corner.y
	var x0 := min_corner.x
	var x1 := max_corner.x
	var z0 := min_corner.z
	var z1 := max_corner.z
	b.block(Vector3(x0, y, z0), Vector3(x1, y + height, z0 + thickness), T.DARK)
	b.block(Vector3(x0, y, z1 - thickness), Vector3(x1, y + height, z1), T.DARK)
	b.block(Vector3(x0, y, z0 + thickness), Vector3(x0 + thickness, y + height, z1 - thickness), T.DARK)
	b.block(Vector3(x1 - thickness, y, z0 + thickness), Vector3(x1, y + height, z1 - thickness), T.DARK)


## Rooftop HVAC unit: solid box you can vault or use as cover.
func ac_unit(pos: Vector3, yaw_deg: float = 0.0, big: bool = false) -> void:
	var size := Vector3(3.2, 1.2, 2.0) if big else Vector3(2.0, 1.1, 1.4)
	b.collider(pos + Vector3.UP * size.y * 0.5, size, T.NEUTRAL, Vector3(0, yaw_deg, 0))
	_place(AC_BIG if big else AC_SMALL, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos))


## Tall ventilation stack (a thin climbable column). The model is 2.4 m tall.
func vent(pos: Vector3, height: float = 2.4) -> void:
	b.collider(pos + Vector3.UP * height * 0.5, Vector3(0.9, height, 0.9), T.DARK)
	_place(VENT, Transform3D(Basis.from_scale(Vector3(1.0, height / 2.4, 1.0)), pos))


## Stair bulkhead: the little building on a roof. Good wall-run/mantle block.
func bulkhead(pos: Vector3, size: Vector3, yaw_deg: float = 0.0) -> void:
	b.box(pos + Vector3.UP * size.y * 0.5, size, T.NEUTRAL, Vector3(0, yaw_deg, 0))
	var door := b.box(pos + Vector3(0, 1.05, size.z * 0.5 + 0.02), Vector3(1.1, 2.1, 0.06), T.DARK, Vector3(0, yaw_deg, 0))
	door.collision_layer = 0


## Water tower on legs with a grapple point on top.
func water_tower(pos: Vector3) -> void:
	var leg_h := 4.0
	for x: float in [-1.4, 1.4]:
		for z: float in [-1.4, 1.4]:
			b.collider(pos + Vector3(x, leg_h * 0.5, z), Vector3(0.25, leg_h, 0.25), T.DARK)
	b.collider(pos + Vector3(0, leg_h + 0.1, 0), Vector3(3.4, 0.2, 3.4), T.DARK)
	var tank := StaticBody3D.new()
	tank.collision_layer = 1
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.8
	cyl.height = 4.0
	cs.shape = cyl
	tank.add_child(cs)
	root.add_child(tank)
	_place(WATER_TOWER, Transform3D(Basis.IDENTITY, pos))
	tank.global_position = pos + Vector3(0, leg_h + 0.2 + 2.0, 0)
	b.grapple_point(pos + Vector3(0, leg_h + 0.2 + 4.0 + 1.6, 0))


## Radio antenna mast (visual only).
func antenna(pos: Vector3, height: float = 5.0) -> void:
	var mast := _visual_cylinder(0.06, height, Color(0.3, 0.32, 0.36))
	root.add_child(mast)
	mast.global_position = pos + Vector3.UP * height * 0.5
	var light := _visual_sphere(0.12, Color(1.0, 0.2, 0.15), 3.0)
	root.add_child(light)
	light.global_position = pos + Vector3.UP * height


## Satellite dish (visual only).
func dish(pos: Vector3, yaw_deg: float) -> void:
	var d := _visual_cone(0.7, 0.3, Color(0.85, 0.86, 0.88))
	root.add_child(d)
	d.global_position = pos + Vector3.UP * 1.1
	d.rotation = Vector3(deg_to_rad(-60.0), deg_to_rad(yaw_deg), 0.0)
	var pole := _visual_cylinder(0.05, 1.0, Color(0.3, 0.32, 0.36))
	root.add_child(pole)
	pole.global_position = pos + Vector3.UP * 0.5


## Street van: cover, and a step up (mantle) to reach low awnings.
func van(pos: Vector3, yaw_deg: float, color: Color) -> void:
	var body := b.box(pos + Vector3.UP * 1.1, Vector3(2.1, 2.2, 5.2), T.NEUTRAL, Vector3(0, yaw_deg, 0), color)
	for side: float in [-1.0, 1.0]:
		for end: float in [-1.6, 1.7]:
			var wheel := _visual_cylinder(0.42, 0.3, Color(0.08, 0.08, 0.09))
			body.add_child(wheel)
			wheel.position = Vector3(side * 1.02, -0.72, end)
			wheel.rotation.z = PI * 0.5


## Street lamp (visual only): the kit lamp, its arm reaching along local -Z.
func street_light(pos: Vector3, yaw_deg: float) -> void:
	_kit("lamp", pos, yaw_deg)


## Jersey barrier: 1.0 m vault/crouch cover. yaw 0 = runs along x.
func barrier(pos: Vector3, yaw_deg: float = 0.0, length: float = 3.2) -> void:
	b.collider(pos + Vector3.UP * 0.5, Vector3(length, 1.0, 0.6), T.DARK, Vector3(0, yaw_deg, 0))
	_kit("barrier", pos, yaw_deg, Vector3(length / 3.2, 1.0, 1.0))


## A stack of 1.2 m cargo crates (1 to 3 high, offset): vault the low ones,
## climb the stack. `stack` picks the shape.
func crates(pos: Vector3, yaw_deg: float = 0.0, stack: int = 2) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var rot := Vector3(0, yaw_deg, 0)
	var tints := [Color(0.35, 0.42, 0.5), Color(0.62, 0.6, 0.55), Color(0.3, 0.5, 0.45)]
	var spots := [Vector3(0, 0.6, 0), Vector3(1.25, 0.6, 0.1), Vector3(0.6, 1.8, 0.0)]
	for i in clampi(stack, 1, 3):
		var c: Vector3 = pos + basis * spots[i]
		b.collider(c, Vector3(1.2, 1.2, 1.2), T.NEUTRAL, rot)
		_kit("crate", c - Vector3.UP * 0.6, yaw_deg, Vector3.ONE, tints[i % tints.size()])


## Holo kiosk: 2.4 m sightline breaker with a glowing ad panel on both faces.
func kiosk(pos: Vector3, yaw_deg: float = 0.0, glow := Color(0.3, 0.85, 1.0)) -> void:
	b.collider(pos + Vector3.UP * 1.2, Vector3(2.0, 2.4, 1.2), T.METAL, Vector3(0, yaw_deg, 0))
	_kit("kiosk", pos, yaw_deg, Vector3.ONE, Color.WHITE, glow)


## Planter: 0.9 m box with a small tree (the tree is visual only).
func planter(pos: Vector3, size: Vector2 = Vector2(2.4, 1.4)) -> void:
	b.collider(pos + Vector3.UP * 0.45, Vector3(size.x, 0.9, size.y), T.NEUTRAL)
	# The model is 2.4 x 1.4; a narrow planter turns 90° rather than squashing.
	if size.x >= size.y:
		_kit("planter", pos, 0.0, Vector3(size.x / 2.4, 1.0, size.y / 1.4))
	else:
		_kit("planter", pos, 90.0, Vector3(size.y / 2.4, 1.0, size.x / 1.4))


# --------------------------------------------------------------------------- city kit

## Parked hover car (cover, 1.2 m: vault it). Nose toward local -Z.
func car(pos: Vector3, yaw_deg: float, paint: Color, collide: bool = true) -> void:
	if collide:
		b.collider(pos + Vector3.UP * 0.6, Vector3(2.2, 1.2, 4.6), T.NEUTRAL, Vector3(0, yaw_deg, 0))
	_kit("hovercar", pos, yaw_deg, Vector3.ONE, paint)


## Railing modules along a straight rail footprint (the min/max corners of
## the rail's collider). Visual only: the caller owns the collider.
func railing(min_corner: Vector3, max_corner: Vector3) -> void:
	var size := max_corner - min_corner
	var along_x := size.x >= size.z
	var length := size.x if along_x else size.z
	if length < 0.3:
		return
	var n := maxi(1, roundi(length / 2.0))
	var step := length / n
	var c := (min_corner + max_corner) * 0.5
	c.y = min_corner.y
	for i in n:
		var t := -length * 0.5 + step * (i + 0.5)
		var p := c + (Vector3(t, 0, 0) if along_x else Vector3(0, 0, t))
		_kit("railing", p, 0.0 if along_x else 90.0, Vector3(step / 2.0, size.y / 1.1, 1.0))


## Charging pod 1.4 x 1.2 x 1.4 (cover). Collision is the caller's.
func charger(pos: Vector3, yaw_deg: float = 0.0) -> void:
	_kit("charger", pos, yaw_deg)


## Holo pylon (model 2.4 x 2.6 x 0.6, scaled to `size`): a sightline breaker.
## Collision is the caller's.
func holo_pylon(pos: Vector3, yaw_deg: float, size: Vector3, glow: Color) -> void:
	_kit("holo_pylon", pos, yaw_deg, Vector3(size.x / 2.4, size.y / 2.6, size.z / 0.6), Color.WHITE, glow)


## Barrier model only (collision is the caller's), scaled to a footprint.
func barrier_model(pos: Vector3, yaw_deg: float, size: Vector3) -> void:
	_kit("barrier", pos, yaw_deg, Vector3(size.x / 3.2, size.y, size.z / 0.6))


## Blade sign sticking out of a wall: mounted at `pos`, the blade points
## along `out_yaw_deg` (0 = +X, 90 = -Z).
func sign_blade(pos: Vector3, out_yaw_deg: float, glow: Color, scale: float = 1.0) -> void:
	_kit("sign_blade", pos, out_yaw_deg, Vector3.ONE * scale, Color.WHITE, glow)


## Banner sign on a wall, facing local +Z (yaw 0 faces +Z, 180 faces -Z).
func sign_banner(pos: Vector3, yaw_deg: float, glow: Color, scale: float = 1.0) -> void:
	_kit("sign_banner", pos, yaw_deg, Vector3.ONE * scale, Color.WHITE, glow)


func glyph_panel(pos: Vector3, yaw_deg: float, glow: Color, scale: float = 1.0) -> void:
	_kit("glyph_panel", pos, yaw_deg, Vector3.ONE * scale, Color.WHITE, glow)


## Twin pipe run of `count` 2 m modules along local +X from `pos` (on the
## pipe axis; the wall is 0.35 m behind, along local -Z).
func pipe_run(pos: Vector3, yaw_deg: float, count: int) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	for i in count:
		_kit("pipe_run", pos + basis * Vector3(1.0 + i * 2.0, 0, 0), yaw_deg)


## Ceiling duct of `count` 2 m modules along local +X, hung from `pos` (the
## ceiling point above the start of the duct's centre line).
func duct(pos: Vector3, yaw_deg: float, count: int) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	for i in count:
		_kit("duct", pos + basis * Vector3(1.0 + i * 2.0, 0, 0), yaw_deg)


## Drooping cable bundle between two anchor points.
func cable(a: Vector3, b_point: Vector3) -> void:
	var d := b_point - a
	var flat := Vector3(d.x, 0, d.z)
	if flat.length() < 0.5:
		return
	var z := flat.normalized().cross(Vector3.UP)
	_place(KIT["cable_bundle"], Transform3D(Basis(d / 4.0, Vector3.UP, z), (a + b_point) * 0.5))  # model spans 4 m


## Wall machinery, mounted at `pos` facing local +Z (yaw 0 faces +Z).
func vent_grille(pos: Vector3, yaw_deg: float) -> void:
	_kit("vent_grille", pos, yaw_deg)


func fan(pos: Vector3, yaw_deg: float) -> void:
	_kit("fan", pos, yaw_deg)


func junction_box(pos: Vector3, yaw_deg: float) -> void:
	_kit("junction_box", pos, yaw_deg)


## Street furniture (visual only: benches and bollards sit below vault height).
func bench(pos: Vector3, yaw_deg: float) -> void:
	_kit("bench", pos, yaw_deg)


func bollard(pos: Vector3) -> void:
	_kit("bollard", pos, 0.0)


func _kit(model: String, pos: Vector3, yaw_deg: float, scale := Vector3.ONE, paint := Color.WHITE, glow := Color(0, 0, 0, 0)) -> void:
	var xform := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled_local(scale), pos)
	_place(KIT[model], xform, paint, glow)


## Non-colliding skyline boxes far outside the map, fading into haze.
func skyline(center: Vector3, inner: float, outer: float, count: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = count
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mm.mesh = mesh
	for i in count:
		var a := rng.randf() * TAU
		var r := rng.randf_range(inner, outer)
		var w := rng.randf_range(12.0, 34.0)
		var d := rng.randf_range(12.0, 34.0)
		var h := rng.randf_range(20.0, 110.0) * (0.6 + 0.4 * (1.0 - (r - inner) / (outer - inner)))
		var p := center + Vector3(cos(a) * r, h * 0.5 - 2.0, sin(a) * r)
		var xform := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(w, h, d)), p)
		mm.set_instance_transform(i, xform)
		var shade := rng.randf_range(0.72, 0.92)
		mm.set_instance_color(i, Color(shade, shade * 1.01, shade * 1.04, 0.0))  # alpha = glow
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = SurfaceMaterials.get_material(LevelBuilder.Kind.FACADE)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)


## Draws every placed model: one MultiMeshInstance3D per model (a draw call
## per material surface, however many copies). Call once after building.
func finalize() -> void:
	for scene: PackedScene in _instances:
		var items: Array = _instances[scene]
		var src := scene.instantiate()
		var mi := src if src is MeshInstance3D else src.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var local := (mi as Node3D).transform if mi != src else Transform3D.IDENTITY
		var model := scene.resource_path.get_file().get_basename()
		var kit_name := model.trim_prefix("kit_")
		var is_kit := model.begins_with("kit_")
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = is_kit
		mm.use_custom_data = is_kit
		mm.mesh = kit_mesh(mi.mesh) if is_kit else mi.mesh
		mm.instance_count = items.size()
		for i in items.size():
			var it: Array = items[i]
			mm.set_instance_transform(i, (it[0] as Transform3D) * local)
			if is_kit:
				mm.set_instance_color(i, it[1])
				mm.set_instance_custom_data(i, it[2])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Props_" + model
		mmi.multimesh = mm
		if KIT_RANGE.has(kit_name):
			mmi.visibility_range_end = KIT_RANGE[kit_name]
			mmi.visibility_range_end_margin = KIT_RANGE[kit_name] * 0.1
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			if not KIT_SHADOW.has(kit_name):
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
		src.free()
	_instances.clear()


static var _kit_meshes: Dictionary = {}  ## source Mesh -> Mesh with kit materials
static var _paint_mat: StandardMaterial3D
static var _sign_mat: ShaderMaterial


## The model's mesh with its kit materials swapped for instance-tinted ones:
## "KitPaint" multiplies the instance colour, "KitSign" glows in the custom
## colour. Cached per source mesh, so every level shares them.
static func kit_mesh(src: Mesh) -> Mesh:
	if _kit_meshes.has(src):
		return _kit_meshes[src]
	var mesh := src
	for i in src.get_surface_count():
		var m := src.surface_get_material(i)
		if m == null:
			continue
		var swap := kit_material(m)
		if swap != m:
			if mesh == src:
				mesh = src.duplicate()
			mesh.surface_set_material(i, swap)
	_kit_meshes[src] = mesh
	return mesh


static func kit_material(m: Material) -> Material:
	if m.resource_name.begins_with("KitPaint") and m is StandardMaterial3D:
		if _paint_mat == null:
			_paint_mat = (m as StandardMaterial3D).duplicate() as StandardMaterial3D
			_paint_mat.vertex_color_use_as_albedo = true
			_paint_mat.vertex_color_is_srgb = true
		return _paint_mat
	if m.resource_name.begins_with("KitSign"):
		if _sign_mat == null:
			_sign_mat = ShaderMaterial.new()
			_sign_mat.shader = preload("res://shaders/kit_sign.gdshader")
		return _sign_mat
	return m


## Paint for one kit model placed as a node (e.g. on a mover): overrides the
## KitPaint surfaces of every MeshInstance3D under `node`.
static func paint_node(node: Node, paint: Color) -> void:
	var mat: StandardMaterial3D = null
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m and m.resource_name.begins_with("KitPaint") and m is StandardMaterial3D:
				if mat == null:
					mat = (m as StandardMaterial3D).duplicate() as StandardMaterial3D
					mat.albedo_color = Color(paint.r * 0.9, paint.g * 0.9, paint.b * 0.9)
				mi.set_surface_override_material(i, mat)


func _place(scene: PackedScene, xform: Transform3D, paint := Color.WHITE, glow := Color(0, 0, 0, 0)) -> void:
	if not _instances.has(scene):
		_instances[scene] = []
	(_instances[scene] as Array).append([xform, paint, glow])


func _mat(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.7
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


func _visual_cylinder(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 16
	mi.mesh = m
	mi.material_override = _mat(color)
	return mi


func _visual_cone(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.02
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 16
	mi.mesh = m
	mi.material_override = _mat(color)
	return mi


func _visual_sphere(radius: float, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	mi.mesh = m
	mi.material_override = _mat(color, emission)
	return mi


func _visual_box(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = _mat(color)
	return mi
