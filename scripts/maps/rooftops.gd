extends LevelBase
## Flagship map "Rooftops" (DESIGN §7.5). A near-future city block split by a
## crossroads into four blocks: NW office, NE construction site, SE billboard
## block, SW residential terraces. Doubles as a couch arena and a timed course.
##
## Coordinates: x = east, z = south (+z), y = up. Streets: N-S x∈[-6,6],
## E-W z∈[-6,6]; building faces start at |x|,|z| = 8 (16 m street gaps).

var props: Props
var crane: Mover
var billboard: Mover
var lift: Mover
var container: Mover


func _init() -> void:
	stations = [
		["Course start (SW street)", Vector3(-2, 0, 54), 0.0],
		["Residential terraces", Vector3(-26, 8, 18), PI],
		["Billboard block", Vector3(28, 20, 40), 0.0],
		["Construction tower", Vector3(20, 15, -14), 0.0],
		["Crane roof", Vector3(15, 35, -15), PI * 0.75],
		["Office tall wing", Vector3(-50, 28, -50), -PI * 0.75],
		["Crossroads", Vector3(0, 0, 0), 0.0],
	]


func intro_hint() -> String:
	return "ROOFTOPS RUN   ·   leave the start to begin   ·   Hold Q grapple   ·   T restart run   ·   [ ] stations"


func build_level() -> void:
	props = Props.new(_b)
	_streets()
	_nw_office()
	_ne_construction()
	_se_billboard_block()
	_sw_residential()
	_perimeter()
	props.skyline(Vector3.ZERO, 110.0, 420.0, 180, 7)
	props.finalize()
	_course()


# --------------------------------------------------------------------------- course

## "Rooftops Run" (DESIGN §7.5): fire escape → terraces → street-billboard
## wall-run → billboard roof → skybridge → up the construction tower → crane
## → office roof → drop to the crossroads. Par is a first guess until timed.
func _course() -> void:
	var c := make_course("rooftops_run", "Rooftops Run", 75.0)
	c.set_start(Vector3(-2, 0, 54), 0.0)
	c.add_gate("Fire escape", Vector3(-12, 8, 19))
	c.add_gate("Top terrace", Vector3(-13, 16, 48))
	c.add_gate("Billboard roof", Vector3(30, 20, 19))
	c.add_gate("Construction tower", Vector3(24, 15, -15), 2.5)
	c.add_gate("Crane roof", Vector3(15, 35, -15), 2.5)
	c.add_gate("Office roof", Vector3(-30, 16, -40))
	c.set_finish(Vector3(0, 0, 0))
	c.finalize()


# --------------------------------------------------------------------------- streets

func _streets() -> void:
	var b := _b
	# Asphalt everywhere (2 cm below the sidewalks so no surfaces are coplanar,
	# which would z-fight), then pale sidewalks around every block.
	b.block(Vector3(-70, -1, -70), Vector3(70, -0.02, 70), T.ASPHALT)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var x0 := 6.0 * sx
			var x1 := 68.0 * sx
			var z0 := 6.0 * sz
			var z1 := 68.0 * sz
			b.block(Vector3(minf(x0, x1), -0.02, minf(z0, z1)), Vector3(maxf(x0, x1), 0.0, maxf(z0, z1)))
	# Lane markings (thin, non-colliding) down both streets.
	for i in range(-6, 7):
		if absi(i) < 1:
			continue
		b.deco(Vector3(0, -0.012, i * 9.0), Vector3(0.25, 0.012, 4.0), T.BOOST)
		b.deco(Vector3(i * 9.0, -0.012, 0), Vector3(4.0, 0.012, 0.25), T.BOOST)
	# Parked vans (cover + a step up).
	props.van(Vector3(-4, 0, 30), 0.0, Color(0.9, 0.9, 0.92))
	props.van(Vector3(4, 0, -34), 180.0, Color(0.25, 0.45, 0.8))
	props.van(Vector3(28, 0, -4), 90.0, Color(0.85, 0.3, 0.25))
	props.van(Vector3(-36, 0, 4), -90.0, Color(0.9, 0.75, 0.2))
	for p in [Vector3(-7, 0, 20), Vector3(7, 0, -20), Vector3(20, 0, 7), Vector3(-20, 0, -7), Vector3(-7, 0, -48), Vector3(7, 0, 48)]:
		props.street_light(p, 90.0 if p.x < 0 else -90.0)


# --------------------------------------------------------------------------- NW office

func _nw_office() -> void:
	var b := _b
	# Main office roof 16, with a stair bulkhead and HVAC field.
	b.block(Vector3(-40, 0, -44), Vector3(-8, 16, -8), T.FACADE)
	props.parapet(Vector3(-40, 16, -44), Vector3(-8, 16, -8), 0.55)
	props.bulkhead(Vector3(-30, 16, -30), Vector3(5, 3.4, 4))
	props.ac_unit(Vector3(-18, 16, -34), 0.0, true)
	props.ac_unit(Vector3(-22, 16, -20), 90.0)
	props.ac_unit(Vector3(-34, 16, -16), 0.0)
	props.vent(Vector3(-14, 16, -14), 2.6)
	props.dish(Vector3(-37, 16, -41), 135.0)
	# Skylight ramp: slide down it for speed toward the street edge.
	b.ramp(Vector3(-26, 18.2, -22), Vector3(-13, 16.0, -22), 5.0, T.NEUTRAL, 0.4)
	b.block(Vector3(-28.5, 16, -24.5), Vector3(-26, 18.2, -19.5), T.DARK)

	# Tall wing roof 28, with a water tower. Balconies step up its east face.
	b.block(Vector3(-60, 0, -60), Vector3(-40, 28, -40), T.FACADE)
	props.parapet(Vector3(-60, 28, -60), Vector3(-40, 28, -40), 0.55)
	props.water_tower(Vector3(-54, 28, -54))
	props.antenna(Vector3(-44, 28, -57), 7.0)
	b.block(Vector3(-40, 19.1, -44), Vector3(-37, 19.5, -42), T.RUN)
	b.block(Vector3(-40, 22.6, -42), Vector3(-37, 23.0, -40), T.RUN)
	# Tall wing's east face above the office roof is a climb wall.
	b.block(Vector3(-40, 16, -44), Vector3(-39.8, 28, -40), T.RUN)

	# Window-washer lift on the tall wing's south face: street → 28 m.
	lift = b.mover(Vector3(-50, 0, -38.6))
	lift.points = PackedVector3Array([Vector3.ZERO, Vector3(0, 28.0, 0)])
	lift.move_time = 6.0
	lift.pause_time = 2.0
	b.attach_box(lift, Vector3(0, 0.2, 0), Vector3(4, 0.4, 2.6), T.BOOST)
	b.attach_box(lift, Vector3(0, 0.75, 1.2), Vector3(4, 0.7, 0.12), T.DARK)  # front rail
	b.label(Vector3(-50, 3.2, -36.8), "LIFT", 48)

	target(Vector3(-24, 16, -38), Vector3(5, 0, 0))
	target(Vector3(-50, 28, -46), Vector3.ZERO)


# --------------------------------------------------------------------------- NE construction

func _ne_construction() -> void:
	var b := _b
	# Open-frame tower 16x16, floors every 5 m to 35 m, with a central core.
	var x0 := 12.0
	var x1 := 28.0
	var z0 := -28.0
	var z1 := -12.0
	for c in [Vector3(x0, 0, z0), Vector3(x1 - 1, 0, z0), Vector3(x0, 0, z1 - 1), Vector3(x1 - 1, 0, z1 - 1)]:
		b.block(c, c + Vector3(1, 35, 1), T.METAL)
	# Core: 4x4 climb column the full height (orange: climb its faces).
	b.block(Vector3(18, 0, -22), Vector3(22, 35, -18), T.RUN)
	# Floors with a 5x5 hole beside the core that rotates around it each level.
	var holes := [
		Rect2(22, -22, 5, 4),   # east of core
		Rect2(18, -27, 4, 5),   # north
		Rect2(13, -22, 5, 4),   # west
		Rect2(18, -18, 4, 5),   # south
	]
	# A 2 m climb block fills the core side of each hole, its top flush with
	# the floor above: climb its face head-on, mantle out onto the next floor.
	var climb_blocks := [
		Rect2(22, -22, 2, 4),   # east hole
		Rect2(18, -24, 4, 2),   # north hole
		Rect2(16, -22, 2, 4),   # west hole
		Rect2(18, -18, 4, 2),   # south hole
	]
	var level := 0
	for y in [5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 35.0]:
		var i := level % holes.size()
		_slab_with_hole(Rect2(x0, z0, x1 - x0, z1 - z0), y, holes[i])
		var cb: Rect2 = climb_blocks[i]
		b.block(Vector3(cb.position.x, y - 5.0, cb.position.y), Vector3(cb.end.x, y, cb.end.y), T.RUN)
		level += 1
	props.parapet(Vector3(x0, 35, z0), Vector3(x1, 35, z1), 0.5)
	# Scaffold stairs up the south side to floor 5 (street access).
	for i in 4:
		b.block(Vector3(14 + i * 3.0, 0, -10.5), Vector3(17 + i * 3.0, 1.25 * (i + 1), -8), T.DARK)

	# Tower crane: mast from the roof, swinging jib at 41 m. The jib is a
	# moving bridge (1.4 m wide) with a grapple point at the tip. The lattice
	# models (art/blender/crane_billboard.py) are visuals only: collision is
	# the same simple boxes, and the walkable decks stay BOOST-painted plates.
	const CRANE_MAST := preload("res://assets/models/prop_crane_mast.glb")
	const CRANE_JIB := preload("res://assets/models/prop_crane_jib.glb")
	b.collider(Vector3(20, 38, -20), Vector3(2, 6, 2), T.METAL)
	b.model(self, CRANE_MAST, Transform3D(Basis.IDENTITY, Vector3(20, 35, -20)))
	crane = b.mover(Vector3(20, 41, -20), Mover.Mode.SWING)
	crane.axis = Vector3.UP
	crane.swing_amplitude_deg = 55.0
	crane.period = 20.0
	crane.rotation.y = deg_to_rad(45.0)  # rest: jib points north-west over the office roof
	b.attach_box(crane, Vector3(0, 0.6, -19.0), Vector3(1.4, 1.2, 36.0), T.BOOST, Vector3.ZERO, false)  # jib (runs along local -z)
	b.attach_box(crane, Vector3(0, 0.6, 6.0), Vector3(1.4, 1.2, 10.0), T.BOOST, Vector3.ZERO, false)    # counter-jib
	b.attach_box(crane, Vector3(0, 2.2, 9.5), Vector3(3.0, 2.6, 3.0), T.DARK, Vector3.ZERO, false)      # counterweight
	b.attach_box(crane, Vector3(0, 1.8, 0.0), Vector3(2.6, 2.4, 2.6), T.NEUTRAL, Vector3.ZERO, false)   # cab
	b.model(crane, CRANE_JIB)
	b.attach_deco(crane, Vector3(0, 1.14, -19.0), Vector3(1.4, 0.12, 36.0), T.BOOST)  # jib deck plate
	b.attach_deco(crane, Vector3(0, 1.14, 6.0), Vector3(1.4, 0.12, 10.0), T.BOOST)    # counter-jib deck plate
	b.attach_grapple_point(crane, Vector3(0, 2.2, -36.0))
	b.attach_grapple_point(crane, Vector3(0, 2.2, -18.0))

	# Gantry with a sliding container over the E-W street (a moving bridge
	# between the site scaffold at 12 m and the SE lower wing at 12 m).
	b.block(Vector3(42.5, 0, -16), Vector3(43.5, 19.5, -15), T.METAL)
	b.block(Vector3(42.5, 0, 15), Vector3(43.5, 19.5, 16), T.METAL)
	b.block(Vector3(38.5, 18.5, -16), Vector3(43.5, 19.5, 16), T.METAL)  # beam well above riders' heads
	b.block(Vector3(38, 0, -24), Vector3(46, 12, -12), T.FACADE)  # site office block (roof 12)
	# Stepped crate tiers up to the scaffold roof: 2.8 → 6.0 → 9.4 → 12.
	var tiers := [2.8, 6.0, 9.4]
	for i in tiers.size():
		b.block(Vector3(32 + i * 2.0, 0, -22), Vector3(34 + i * 2.0, tiers[i], -16), T.DARK if i % 2 else T.NEUTRAL)
	container = b.mover(Vector3(40.5, 12, -9))
	container.points = PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 18)])
	container.move_time = 4.0
	container.pause_time = 2.0
	b.attach_box(container, Vector3(0, 1.3, 0), Vector3(2.5, 2.6, 6.0), T.RUN)
	# Stacked containers on the ground: cover.
	b.box(Vector3(44, 1.3, -40), Vector3(2.5, 2.6, 6.0), T.RUN)
	b.box(Vector3(47, 1.3, -40), Vector3(2.5, 2.6, 6.0), T.GRAPPLE)
	b.box(Vector3(45.5, 3.9, -40), Vector3(2.5, 2.6, 6.0), T.DARK)

	target(Vector3(24, 15, -14), Vector3.ZERO)
	target(Vector3(14, 30, -26), Vector3.ZERO)
	target(Vector3(42, 12, -18), Vector3(0, 0, 3))


func _slab_with_hole(r: Rect2, y: float, hole: Rect2) -> void:
	# Split the slab into up to four blocks around the hole.
	var t := 0.4
	var hx0 := hole.position.x
	var hx1 := hole.end.x
	var hz0 := hole.position.y
	var hz1 := hole.end.y
	var sx0 := r.position.x
	var sx1 := r.end.x
	var sz0 := r.position.y
	var sz1 := r.end.y
	if hz0 > sz0:
		_b.block(Vector3(sx0, y - t, sz0), Vector3(sx1, y, hz0))
	if hz1 < sz1:
		_b.block(Vector3(sx0, y - t, hz1), Vector3(sx1, y, sz1))
	if hx0 > sx0:
		_b.block(Vector3(sx0, y - t, hz0), Vector3(hx0, y, hz1))
	if hx1 < sx1:
		_b.block(Vector3(hx1, y - t, hz0), Vector3(sx1, y, hz1))


# --------------------------------------------------------------------------- SE billboard block

func _se_billboard_block() -> void:
	var b := _b
	# Main building D roof 20; lower wing D2 roof 12 (container bridge lands here).
	b.block(Vector3(22, 0, 14), Vector3(46, 20, 44), T.FACADE)
	props.parapet(Vector3(22, 20, 14), Vector3(46, 20, 44), 0.55)
	b.block(Vector3(36, 0, 8), Vector3(46, 12, 14), T.FACADE)  # no parapet: the container docks here
	props.ac_unit(Vector3(44.5, 12, 12), 90.0)
	# West lower building F roof 14 (lands the street-billboard wall-run).
	b.block(Vector3(8, 0, 36), Vector3(22, 14, 56), T.FACADE)
	props.parapet(Vector3(8, 14, 36), Vector3(22, 14, 56), 0.5)
	# F → D: step vent then climb the D face (orange).
	b.block(Vector3(20, 14, 38), Vector3(22, 16.8, 42), T.DARK)
	b.block(Vector3(21.8, 14, 36), Vector3(22, 20, 44), T.RUN)

	# Rotating billboard on D's roof: a 14 x 6 m panel on a pole, 10 s per turn.
	# The frame model's pivot collar turns with it and hides the stub pole.
	const BILLBOARD_FRAME := preload("res://assets/models/prop_billboard_frame.glb")
	b.collider(Vector3(34, 20.5, 30), Vector3(0.8, 1.0, 0.8), T.METAL)
	billboard = b.mover(Vector3(34, 20.9, 30), Mover.Mode.ROTATE)
	billboard.axis = Vector3.UP
	billboard.rotate_speed_deg = 36.0
	b.attach_box(billboard, Vector3(0, 3.0, 0), Vector3(14, 6, 0.5), T.RUN)
	b.model(billboard, BILLBOARD_FRAME)
	props.ac_unit(Vector3(26, 20, 40), 90.0, true)
	props.ac_unit(Vector3(42, 20, 18), 0.0)
	props.antenna(Vector3(44, 20, 42), 6.0)

	# Balcony on D's north face at 15 and a skybridge across the E-W street
	# into the construction tower's floor 15.
	b.block(Vector3(22, 14.6, 11), Vector3(30, 15, 14), T.NEUTRAL)
	b.block(Vector3(22, 14.6, -12), Vector3(26, 15, 11), T.NEUTRAL)            # bridge deck
	b.block(Vector3(21.6, 15, -10), Vector3(22, 18.5, 9), T.RUN)                # west glass wall
	b.block(Vector3(26, 15, -10), Vector3(26.4, 18.5, 9), T.RUN)                # east glass wall
	b.block(Vector3(21.6, 18.5, -10), Vector3(26.4, 18.8, 9), T.DARK)           # roof (walkable)

	target(Vector3(28, 20, 24), Vector3(0, 0, 4))
	target(Vector3(16, 14, 50), Vector3.ZERO)
	target(Vector3(40, 12, 12), Vector3.ZERO)


# --------------------------------------------------------------------------- SW residential

func _sw_residential() -> void:
	var b := _b
	# Terraces rising south: 8 → 12 → 16.
	b.block(Vector3(-44, 0, 8), Vector3(-8, 8, 24), T.FACADE)
	b.block(Vector3(-44, 0, 24), Vector3(-8, 12, 38), T.FACADE)
	b.block(Vector3(-44, 0, 38), Vector3(-8, 16, 56), T.FACADE)
	# The terrace step faces (north-facing walls) are climb walls.
	b.block(Vector3(-30, 8, 23.8), Vector3(-18, 12, 24), T.RUN)
	b.block(Vector3(-30, 12, 37.8), Vector3(-18, 16, 38), T.RUN)
	# Fire escape up E1's street face from the sidewalk: 2.5 → 5.0 → roof 8.
	b.block(Vector3(-8.0, 2.1, 18.0), Vector3(-5.6, 2.5, 21.5), T.RUN)
	b.block(Vector3(-8.0, 4.6, 12.0), Vector3(-5.6, 5.0, 15.5), T.RUN)
	# E2's street face is a wall-run strip along the sidewalk.
	b.block(Vector3(-8.0, 2.0, 24.0), Vector3(-7.8, 12.0, 38.0), T.RUN)
	# Rooftop dressing.
	props.ac_unit(Vector3(-36, 8, 16), 0.0)
	props.ac_unit(Vector3(-16, 8, 14), 90.0)
	props.ac_unit(Vector3(-38, 12, 30), 0.0, true)
	props.bulkhead(Vector3(-24, 16, 48), Vector3(4, 3, 4))
	props.dish(Vector3(-40, 16, 52), 45.0)
	props.antenna(Vector3(-12, 16, 54), 5.0)
	# West strip building roof 10: an alternate route along the map edge.
	b.block(Vector3(-60, 0, 10), Vector3(-48, 10, 58), T.FACADE)
	props.parapet(Vector3(-60, 10, 10), Vector3(-48, 10, 58), 0.5)

	# Street billboard: a wall-run panel across the N-S street from the
	# residential top terrace (16) to the SE lower building F (14).
	b.block(Vector3(-8, 13.0, 43.4), Vector3(10, 19.0, 44.0), T.RUN)
	b.block(Vector3(-8.6, 0, 43.4), Vector3(-8, 19.0, 44.0), T.METAL)  # support post (west)
	b.block(Vector3(10, 0, 43.4), Vector3(10.6, 19.0, 44.0), T.METAL)  # support post (east)

	target(Vector3(-20, 8, 20), Vector3(0, 0, 2))
	target(Vector3(-34, 12, 34), Vector3.ZERO)
	target(Vector3(-4, 0, 40), Vector3(0, 0, 4))


# --------------------------------------------------------------------------- perimeter

func _perimeter() -> void:
	var b := _b
	# A ring of boundary buildings of varied height (their faces are the play
	# boundary and are wall-runnable) plus invisible walls above their roofs.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var edge := 62.0
	var depth := 14.0
	var x := -edge - depth
	while x < edge + depth:
		var w := rng.randf_range(12.0, 22.0)
		var h1 := rng.randf_range(18.0, 46.0)
		var h2 := rng.randf_range(18.0, 46.0)
		b.block(Vector3(x, 0, -edge - depth), Vector3(x + w, h1, -edge), T.FACADE)
		b.block(Vector3(x, 0, edge), Vector3(x + w, h2, edge + depth), T.FACADE)
		x += w
	var z := -edge
	while z < edge:
		var w := minf(rng.randf_range(12.0, 22.0), edge - z)
		b.block(Vector3(-edge - depth, 0, z), Vector3(-edge, rng.randf_range(18.0, 46.0), z + w), T.FACADE)
		b.block(Vector3(edge, 0, z), Vector3(edge + depth, rng.randf_range(18.0, 46.0), z + w), T.FACADE)
		z += w
	for wall in [
		[Vector3(-edge, 0, -edge - 1), Vector3(edge, 90, -edge)],
		[Vector3(-edge, 0, edge), Vector3(edge, 90, edge + 1)],
		[Vector3(-edge - 1, 0, -edge), Vector3(-edge, 90, edge)],
		[Vector3(edge, 0, -edge), Vector3(edge + 1, 90, edge)],
	]:
		_invisible_wall(wall[0], wall[1])


func _invisible_wall(min_corner: Vector3, max_corner: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = max_corner - min_corner
	cs.shape = box
	body.add_child(cs)
	add_child(body)
	body.global_position = (min_corner + max_corner) * 0.5


# --------------------------------------------------------------------------- look

func build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.52, 0.86)
	sky_mat.sky_horizon_color = Color(0.86, 0.88, 0.9)
	sky_mat.ground_horizon_color = Color(0.86, 0.88, 0.9)
	sky_mat.ground_bottom_color = Color(0.42, 0.44, 0.47)
	sky_mat.sun_angle_max = 14.0
	sky_mat.sun_curve = 0.08
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.ambient_light_sky_contribution = 0.55  # rest is neutral, so shade isn't navy
	env.ambient_light_color = Color(0.78, 0.77, 0.75)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 2.2
	env.ssil_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.04
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.85, 0.92)
	env.fog_density = 0.0016
	env.fog_aerial_perspective = 0.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Mid-afternoon sun from the south-west: long shadows across the streets.
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(-140.0), 0.0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 220.0
	sun.shadow_blur = 1.2
	add_child(sun)
