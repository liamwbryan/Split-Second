extends LevelBase
## "PENDULUM HALL" (MAP_BRIEFS §5.2): a museum of the future filling an
## atrium halfway up a megatower. White composite, gold light strips, floating
## exhibits, and one whole wall of glass over a city 500 m below.
##
## Coordinates: x = east (hall length), z = south, y = up. The hall is
## 112 × 52 m (|x| ≤ 56, |z| ≤ 26), floor at y = 0, play space up to ~46 m,
## ceiling at 150 m. The south wall (z = 26) is glass: an invisible collider
## you can see the city through.
##
## The pendulum: pivot at (0, 100, 0), 90 m arm, swings along x (±30°, 10 s),
## so the bob passes 10 m above the floor at ~30 m/s (Liam: keep the full
## slingshot) and rises to 22 m at each end, where it meets the top end
## galleries. The rod is visual only; the mezzanine has a slot for it.

const W := 56.0          ## half length (x)
const D := 26.0          ## half width (z)
const LEVELS := [8.0, 16.0, 24.0]  ## gallery floors
const GALLERY := 6.0     ## gallery depth
const PIVOT := Vector3(0, 100, 0)
const ARM := 90.0
const CITY_Y := -500.0
const GOLD := Color(1.0, 0.78, 0.35)

var pendulum: Mover
var backdrop: Backdrop


func _init() -> void:
	stations = [
		["Course start (floor, west)", Vector3(-46, 0, 0), -PI * 0.5],
		["Pendulum floor", Vector3(-8, 0, 12), PI * 0.1],
		["North gallery 8 (wall-runs)", Vector3(-44, 8, -23), -PI * 0.5],
		["Mezzanine (drop onto the bob)", Vector3(0, 16, -8), PI],
		["East top gallery (bob meets it)", Vector3(52, 24, -6), PI * 0.5],
		["Skylight catwalk", Vector3(-20, 40, -10), -PI * 0.5],
		["Glass wall vista", Vector3(8, 24, 25.2), PI, deg_to_rad(-40.0)],
	]
	arena_spawns = [
		[Vector3(-50, 0, -20), -PI * 0.5], [Vector3(50, 0, 20), PI * 0.5],
		[Vector3(-30, 8, -23), -PI * 0.5], [Vector3(30, 8, 23), PI * 0.5],
		[Vector3(40, 16, -23), PI * 0.5], [Vector3(-40, 16, 23), -PI * 0.5],
		[Vector3(-52, 24, 10), PI], [Vector3(52, 24, -10), 0.0],
	]


func intro_hint() -> String:
	return "PENDULUM HALL   ·   ride the pendulum, jump off at the bottom   ·   Hold Q grapple   ·   T restart   ·   [ ] stations"


func build_level() -> void:
	_shell()
	_galleries()
	_mezzanine()
	_pendulum()
	_exhibits()
	_floor_cover()
	_catwalk()
	_backdrop()
	_course()


# --------------------------------------------------------------------------- course

## "Pendulum Run": floor → north 8 m gallery wall-runs → mezzanine → drop onto
## the bob → ride it east and step off onto the top gallery → grapple up to
## the skylight catwalk. Par is a guess until timed.
func _course() -> void:
	var c := make_course("pendulum_run", "Pendulum Run", 50.0)
	c.set_start(Vector3(-46, 0, 0), -PI * 0.5)
	c.add_gate("North gallery", Vector3(-10, 8, -23), 3.5)
	c.add_gate("Mezzanine", Vector3(0, 16, -8), 3.5)
	c.add_gate("Top gallery (east)", Vector3(52, 24, 0), 4.0)
	c.set_finish(Vector3(10, 40, -10), 3.0)
	c.finalize()


# --------------------------------------------------------------------------- shell

func _shell() -> void:
	var b := _b
	b.block(Vector3(-W - 1, -1, -D - 1), Vector3(W + 1, 0, D + 1), T.NEUTRAL)
	# Floor inlay: gold strips along the pendulum's path.
	for z: float in [-4.2, 4.2]:
		b.deco(Vector3(0, 0.01, z), Vector3(W * 2.0 - 8.0, 0.02, 0.18), T.LIGHT, Vector3.ZERO, GOLD)
	# North wall (solid, white) and end walls, collision to 60 m, visual to the ceiling.
	b.block(Vector3(-W - 1, 0, -D - 1), Vector3(W + 1, 60, -D), T.NEUTRAL)
	b.deco(Vector3(0, 105, -D - 0.5), Vector3(W * 2.0 + 2.0, 90, 1), T.NEUTRAL)
	for sx: float in [-1.0, 1.0]:
		b.block(Vector3(minf(sx * W, sx * (W + 1)), 0, -D), Vector3(maxf(sx * W, sx * (W + 1)), 60, D), T.NEUTRAL)
		b.deco(Vector3(sx * (W + 0.5), 105, 0), Vector3(1, 90, D * 2.0), T.NEUTRAL)
	# The glass wall: invisible collider, slim mullions and transoms.
	var glass := StaticBody3D.new()
	glass.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(W * 2.0, 60, 1)
	cs.shape = box
	glass.add_child(cs)
	add_child(glass)
	glass.position = Vector3(0, 30, D + 0.5)
	var x := -W
	while x <= W + 0.1:
		b.deco(Vector3(x, 75, D + 0.3), Vector3(0.25, 150, 0.3), T.METAL)
		x += 8.0
	for y: float in [0.3, 32.0, 64.0, 96.0, 128.0]:
		b.deco(Vector3(0, y, D + 0.3), Vector3(W * 2.0, 0.3, 0.35), T.METAL)
	# Ceiling at 150 with a skylight over the pendulum (the tower continues
	# above it), and the pivot housing: a gold ring around the pivot.
	b.deco(Vector3(-36, 151, 0), Vector3(40, 2, D * 2.0 + 2.0), T.NEUTRAL)
	b.deco(Vector3(36, 151, 0), Vector3(40, 2, D * 2.0 + 2.0), T.NEUTRAL)
	b.deco(Vector3(0, 151, -20), Vector3(32, 2, 14), T.NEUTRAL)
	b.deco(Vector3(0, 151, 20), Vector3(32, 2, 14), T.NEUTRAL)
	b.deco(PIVOT + Vector3(0, 1.5, 0), Vector3(8, 3, 8), T.METAL)
	b.helix_ramp(PIVOT, 5.0, 6.0, 0.5, 0.0, 360.0, 0.0, T.LIGHT, 1.0, 6.0, GOLD, false)
	# Gold light bands along the long walls every 8 m of height.
	for y in range(34, 150, 12):
		b.deco(Vector3(0, y, -D + 0.05), Vector3(W * 2.0, 0.25, 0.1), T.LIGHT, Vector3.ZERO, GOLD)


# --------------------------------------------------------------------------- galleries

## Galleries on three levels along the north wall and the glass wall, joined
## by end galleries. The north wall behind each gallery is RUN panels split by
## pillars: chained wall-runs, each touch refreshing the double jump.
func _galleries() -> void:
	var b := _b
	for y: float in LEVELS:
		# North gallery (z -26..-20) and south gallery on the glass (20..26).
		for side: float in [-1.0, 1.0]:
			var z_in := side * (D - GALLERY)
			var z_out := side * D
			b.block(Vector3(-W, y - 0.5, minf(z_in, z_out)), Vector3(W, y, maxf(z_in, z_out)), T.NEUTRAL)
			b.deco(Vector3(0, y - 0.3, z_in - side * 0.03), Vector3(W * 2.0, 0.12, 0.06), T.LIGHT, Vector3.ZERO, GOLD)
			# Front rail with gaps (drop points) every 20 m.
			var xr := -W + 6.0
			while xr < W - 6.0:
				var z0 := z_in - side * 0.1
				b.block(Vector3(xr, y, minf(z0, z_in + side * 0.1)), Vector3(xr + 12.0, y + 1.1, maxf(z0, z_in + side * 0.1)), T.DARK)
				xr += 20.0
		# End galleries (x 50..56) joining the long ones. The pendulum's disc
		# reaches x ≈ 48 at the ends of its swing, level with the top one.
		for sx: float in [-1.0, 1.0]:
			b.block(Vector3(minf(sx * (W - GALLERY), sx * W), y - 0.5, -D + GALLERY), Vector3(maxf(sx * (W - GALLERY), sx * W), y, D - GALLERY), T.NEUTRAL)
	# RUN panels on the north wall, 16 m long between 1.5 m pillars.
	for y: float in [0.0] + LEVELS:
		var x := -W + 4.0
		while x + 16.0 <= W - 4.0:
			b.block(Vector3(x, y + 1.0, -D), Vector3(x + 16.0, y + 6.5, -D + 0.3), T.RUN)
			b.block(Vector3(x + 16.0, y, -D), Vector3(x + 17.5, y + 7.5, -D + 1.0), T.NEUTRAL)  # pillar
			x += 17.5
	# Gallery pillars (front edge) from the floor to the top gallery.
	for side: float in [-1.0, 1.0]:
		for xp: float in [-40.0, -20.0, 20.0, 40.0]:
			var z := side * (D - GALLERY + 0.7)
			b.block(Vector3(xp - 0.7, 0, z - 0.7), Vector3(xp + 0.7, LEVELS[2] - 0.5, z + 0.7), T.NEUTRAL)
			b.deco(Vector3(xp, 4.0, z), Vector3(1.46, 0.3, 1.46), T.LIGHT, Vector3.ZERO, GOLD)
	# Antigrav pads from the floor up to the 8 m galleries (rail gaps above them).
	pad(Vector3(-14, 0, -14), Vector3(0, 21.0, -8.0))
	pad(Vector3(26, 0, 14), Vector3(0, 21.0, 8.0))


# --------------------------------------------------------------------------- mezzanine

## A bridge across the hall at 16 m, over the pendulum's lowest point. A 2.4 m
## slot lets the rod through; drop through it onto the bob as it passes.
func _mezzanine() -> void:
	var b := _b
	var y := LEVELS[1]
	b.block(Vector3(-2.5, y - 0.5, -D + GALLERY), Vector3(2.5, y, -1.2), T.NEUTRAL)
	b.block(Vector3(-2.5, y - 0.5, 1.2), Vector3(2.5, y, D - GALLERY), T.NEUTRAL)
	for sx: float in [-1.0, 1.0]:
		b.block(Vector3(sx * 2.5 - 0.1, y, -D + GALLERY), Vector3(sx * 2.5 + 0.1, y + 1.1, -1.2), T.DARK)
		b.block(Vector3(sx * 2.5 - 0.1, y, 1.2), Vector3(sx * 2.5 + 0.1, y + 1.1, D - GALLERY), T.DARK)
	b.deco(Vector3(0, y - 0.3, -1.25), Vector3(5, 0.1, 0.1), T.LIGHT, Vector3.ZERO, GOLD)
	b.deco(Vector3(0, y - 0.3, 1.25), Vector3(5, 0.1, 0.1), T.LIGHT, Vector3.ZERO, GOLD)
	# ENEMY: grunt pair holding the mezzanine.
	target(Vector3(0, y, -12), Vector3(0, 0, 2))


# --------------------------------------------------------------------------- pendulum

func _pendulum() -> void:
	var b := _b
	pendulum = b.mover(PIVOT, Mover.Mode.SWING)
	pendulum.axis = Vector3.BACK  # swings in the x-y plane
	pendulum.swing_amplitude_deg = 30.0
	pendulum.period = 10.0
	b.attach_box(pendulum, Vector3(0, -ARM, 0), Vector3(7, 0.6, 7), T.BOOST)
	b.attach_deco(pendulum, Vector3(0, -ARM - 0.6, 0), Vector3(5, 0.6, 5), T.METAL)
	b.attach_deco(pendulum, Vector3(0, -ARM * 0.5 + 1.0, 0), Vector3(0.5, ARM - 2.5, 0.5), T.METAL)  # rod (no collision)
	b.attach_grapple_point(pendulum, Vector3(0, -ARM + 6.0, 0))
	b.label(Vector3(0, 3.0, -12), "PENDULUM", 200)


# --------------------------------------------------------------------------- exhibits

## Floating exhibits (static, antigrav-looking) with grapple beacons: stepping
## stones at mid-height either side of the pendulum's path.
func _exhibits() -> void:
	var b := _b
	for p: Vector3 in [Vector3(-26, 12, -11), Vector3(26, 12, 11), Vector3(-34, 20, 10), Vector3(34, 20, -10)]:
		b.box(p + Vector3(0, -0.3, 0), Vector3(6, 0.6, 6), T.NEUTRAL)
		b.deco(p + Vector3(0, -0.65, 0), Vector3(4.5, 0.1, 4.5), T.LIGHT, Vector3.ZERO, Color(0.5, 0.85, 1.0))
		b.box(p + Vector3(1.2, 0.6, 1.2), Vector3(1.4, 1.2, 1.4), T.DARK)  # the exhibit case: cover
		b.grapple_point(p + Vector3(0, 7.0, 0))
	# The fossil: a skeleton hanging on tethers above the west half, with a
	# grapple beacon at its skull. Visual only (it's up in the air).
	var spine := Vector3(-18, 36, 12)
	for i in 9:
		b.deco(spine + Vector3(i * 2.2, sin(i * 0.6) * 0.8, 0), Vector3(1.6, 1.0, 1.0), T.NEUTRAL, Vector3(0, 0, i * 4.0), Color(0.9, 0.86, 0.76))
		b.deco(spine + Vector3(i * 2.2, -1.6, 0), Vector3(0.3, 2.4, 3.6 - absf(i - 4.0) * 0.5), T.NEUTRAL, Vector3.ZERO, Color(0.9, 0.86, 0.76))
	b.grapple_point(spine + Vector3(20.5, 1.0, 0))
	# The planet: a big hologram sphere over the east half.
	var planet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 7.0
	sphere.height = 14.0
	sphere.radial_segments = 32
	sphere.rings = 16
	planet.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.4, 0.8, 1.0, 0.35)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	planet.material_override = mat
	planet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(planet)
	planet.position = Vector3(26, 38, -12)
	b.grapple_point(Vector3(26, 38, -12))


# --------------------------------------------------------------------------- floor

## "Big but full": plinths, display cases and holo pylons across the floor,
## kept out of the pendulum's sweep (|z| < 5) so the bob never hits them.
func _floor_cover() -> void:
	var b := _b
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for x in range(-44, 45, 11):
		for z: float in [-13.0, 13.0]:
			var p := Vector3(x + rng.randf_range(-2.0, 2.0), 0, z + rng.randf_range(-2.5, 2.5))
			if absf(p.x - (-14.0)) < 5.0 and absf(p.z - (-14.0)) < 5.0:
				continue  # west pad
			if absf(p.x - 26.0) < 5.0 and absf(p.z - 14.0) < 5.0:
				continue  # east pad
			if p.distance_to(Vector3(-8, 0, 12)) < 4.0 or p.distance_to(Vector3(-46, 0, 0)) < 5.0:
				continue  # stations
			match rng.randi_range(0, 2):
				0:  # plinth with a sculpture
					b.block(p + Vector3(-1, 0, -1), p + Vector3(1, 1.1, 1), T.NEUTRAL)
					b.deco(p + Vector3(0, 1.9, 0), Vector3(0.9, 1.6, 0.9), T.METAL, Vector3(0, rng.randf() * 90.0, 20.0))
				1:  # long display case (vault it)
					b.block(p + Vector3(-2.5, 0, -0.6), p + Vector3(2.5, 1.05, 0.6), T.DARK)
					b.deco(p + Vector3(0, 1.08, 0), Vector3(5, 0.05, 1.2), T.LIGHT, Vector3.ZERO, GOLD)
				2:  # holo pylon (sightline breaker)
					b.block(p + Vector3(-1, 0, -0.35), p + Vector3(1, 2.6, 0.35), T.METAL)
					for s: float in [-1.0, 1.0]:
						b.deco(p + Vector3(0, 1.5, s * 0.37), Vector3(1.7, 1.4, 0.04), T.LIGHT, Vector3.ZERO, Color(0.4, 0.85, 1.0))
	# Gallery dressing: benches and cases along the galleries.
	for y: float in LEVELS:
		for side: float in [-1.0, 1.0]:
			for x: float in [-22.0, 4.0, 46.0]:
				var z := side * (D - 3.5)
				b.block(Vector3(x - 2, y, z - 0.5), Vector3(x + 2, y + 1.0, z + 0.5), T.DARK)
	target(Vector3(-10, 0, -12), Vector3(3, 0, 0))
	target(Vector3(18, 8, 23), Vector3(3, 0, 0))
	target(Vector3(-40, 24, -23), Vector3(0, 0, 0))
	# ENEMY: sniper on the east top gallery; rusher on the floor; drone circling the planet.


# --------------------------------------------------------------------------- catwalk

## Skylight catwalk at 40 m (parallel to the pendulum, out of the rod's
## sweep), reached by grappling the beacons above its ends from the top
## galleries. The course finishes here.
func _catwalk() -> void:
	var b := _b
	b.block(Vector3(-30, 39.6, -12), Vector3(30, 40, -8), T.METAL)
	for z: float in [-12.0, -8.0]:
		b.deco(Vector3(0, 40.02, z + (0.06 if z < -10 else -0.06)), Vector3(60, 0.03, 0.1), T.LIGHT, Vector3.ZERO, GOLD)
	for x: float in [-30.0, 30.0]:
		b.deco(Vector3(x, 95, -10), Vector3(0.3, 110, 0.3), T.METAL)  # hangers to the ceiling
	b.grapple_point(Vector3(-24, 46, -10))
	b.grapple_point(Vector3(24, 46, -10))
	target(Vector3(-6, 40, -10), Vector3(4, 0, 0))


# --------------------------------------------------------------------------- backdrop

func _backdrop() -> void:
	backdrop = Backdrop.new()
	add_child(backdrop)
	# Our tower (only its outside beyond the glass shows): keep towers out of
	# it and out of the view corridor right in front of the glass.
	var tower := AABB(Vector3(-160, CITY_Y, -200), Vector3(320, 1400, 230))
	var near := AABB(Vector3(-200, CITY_Y, 30), Vector3(400, 1400, 120))
	backdrop.city_floor(CITY_Y)
	backdrop.city(Vector3.ZERO, CITY_Y, 0.0, 1300.0, 800, 25.0, 170.0, 31, [tower])
	backdrop.megatowers(Vector3.ZERO, CITY_Y, 180.0, 750.0, 40, 350.0, 1200.0, 32, [tower, near])
	backdrop.silhouettes(Vector3.ZERO, CITY_Y, 800.0, 1400.0, 80, 300.0, 1300.0, Color(0.62, 0.7, 0.8), 33)
	# Hero landmark: the orbital elevator tether, south-west beyond the glass.
	backdrop.spire(Vector3(-420, CITY_Y, 700), 900.0, 90.0, 700.0, 110.0, Color(1.0, 0.8, 0.4))
	var tether := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 3.0
	cyl.bottom_radius = 3.0
	cyl.height = 2400.0
	cyl.radial_segments = 8
	tether.mesh = cyl
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.albedo_color = Color(1.0, 0.85, 0.55) * 1.6
	tether.material_override = tm
	tether.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.add_child(tether)
	tether.position = Vector3(-420, CITY_Y + 1200.0, 700)
	backdrop.traffic_lane(Vector3(-900, 30, 90), Vector3(900, 30, 90), 40, 50.0, 41)
	backdrop.traffic_lane(Vector3(-900, -60, 220), Vector3(900, -60, 220), 50, 42.0, 42)
	backdrop.traffic_lane(Vector3(-600, 140, 400), Vector3(700, 90, 60), 40, 45.0, 43, Vector2(8, 3))
	backdrop.finalize()


# --------------------------------------------------------------------------- look

func build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.55, 0.9)
	sky_mat.sky_horizon_color = Color(0.85, 0.88, 0.92)
	sky_mat.ground_horizon_color = Color(0.85, 0.88, 0.92)
	sky_mat.ground_bottom_color = Color(0.5, 0.55, 0.62)
	sky_mat.sun_angle_max = 12.0
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.87, 0.9)
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 1.8
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.86, 0.94)
	env.fog_density = 0.0009
	env.fog_aerial_perspective = 0.5
	env.fog_height = -150.0
	env.fog_height_density = 0.004
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Low afternoon sun from the south, pouring through the glass wall.
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-30.0), deg_to_rad(-15.0), 0.0)  # shines north (-z), through the glass
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)
