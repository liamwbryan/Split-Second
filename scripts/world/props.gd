class_name Props
extends RefCounted
## Rooftop/street props. Modeled props (art/blender/rooftop_props.py) are
## drawn with one MultiMesh per model, built in finalize(), and keep simple box
## collision; the rest are primitives. Props that matter for movement get
## collision; small dressing (antennas, dishes) is visual only.

const T := LevelBuilder.Tag
const AC_SMALL := preload("res://assets/models/prop_ac_small.glb")
const AC_BIG := preload("res://assets/models/prop_ac_big.glb")
const VENT := preload("res://assets/models/prop_vent.glb")
const WATER_TOWER := preload("res://assets/models/prop_water_tower.glb")

var b: LevelBuilder
var root: Node3D
var _visual_mat: ShaderMaterial
var _instances: Dictionary = {}  ## PackedScene -> Array[Transform3D]


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


## Street light (visual only, thin).
func street_light(pos: Vector3, yaw_deg: float) -> void:
	var pole := _visual_cylinder(0.09, 7.0, Color(0.22, 0.24, 0.27))
	root.add_child(pole)
	pole.global_position = pos + Vector3.UP * 3.5
	var arm := _visual_box(Vector3(0.12, 0.12, 2.0), Color(0.22, 0.24, 0.27))
	root.add_child(arm)
	arm.global_position = pos + Vector3.UP * 7.0 + Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3(0, 0, -0.9)
	arm.rotation.y = deg_to_rad(yaw_deg)


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
		var xforms: Array = _instances[scene]
		var src := scene.instantiate()
		var mi := src if src is MeshInstance3D else src.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var local := (mi as Node3D).transform if mi != src else Transform3D.IDENTITY
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mi.mesh
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, (xforms[i] as Transform3D) * local)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Props_" + scene.resource_path.get_file().get_basename()
		mmi.multimesh = mm
		root.add_child(mmi)
		src.free()
	_instances.clear()


func _place(scene: PackedScene, xform: Transform3D) -> void:
	if not _instances.has(scene):
		_instances[scene] = []
	(_instances[scene] as Array).append(xform)


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
