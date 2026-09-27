extends LevelBase
## Movement Gym (Milestone 1): one station per mechanic plus a rooftop combo
## route and a shooting range.


func _init() -> void:
	stations = [
		["Hub", Vector3(0, 0, 10), 0.0],
		["Slide & Vault", Vector3(0, 6, -14), 0.0],
		["Wall-run", Vector3(-18, 0, 0), PI * 0.5],
		["Climb & Mantle", Vector3(14, 0, 0), -PI * 0.5],
		["Grapple", Vector3(0, 0, 24), PI],
		["Rooftop Combo", Vector3(20, 6, -30), -PI * 0.5],
		["Range", Vector3(12, 0, 25), -PI * 0.5],
	]


func build_level() -> void:
	var b := _b
	b.block(Vector3(-160, -1, -160), Vector3(160, 0, 160))
	b.label(Vector3(0, 3.2, 4), "MOVEMENT GYM", 160)
	_build_slide_lane()
	_build_wallrun_lane()
	_build_climb_station()
	_build_grapple_field()
	_build_rooftops()
	_build_range()


func _build_slide_lane() -> void:
	var b := _b
	# Mantle stairs up to the deck: jump into each step to mantle.
	var tops := [1.2, 2.4, 3.6, 4.8]
	for i in tops.size():
		var z0 := -2.0 - i * 2.0
		b.block(Vector3(-5, 0, z0 - 2.0), Vector3(5, tops[i], z0), T.DARK if i % 2 else T.NEUTRAL)
	b.block(Vector3(-5, 0, -18), Vector3(5, 6, -10))
	b.label(Vector3(0, 8.5, -14), "SLIDE  (hold C / Ctrl, or tap B)", 80, 0)
	checkpoint(Vector3(0, 6, -14), Vector3(10, 2, 8), 0.0)
	# Long slide ramp, then flat ground for slide-hops.
	b.ramp(Vector3(0, 6, -18), Vector3(0, 0, -42), 10.0)
	b.label(Vector3(7, 2.5, -48), "SLIDE-HOP: jump as you land, keep crouch held", 56, 0)
	# Vault hurdles (sprint into them).
	for z in [-56.0, -64.0, -72.0]:
		b.block(Vector3(-5, 0, z - 0.4), Vector3(5, 1.0, z), T.DARK)
	b.label(Vector3(0, 2.6, -60), "VAULT", 72)
	# Slide-under bar.
	b.block(Vector3(-5.6, 0, -84), Vector3(-5, 3, -82))
	b.block(Vector3(5, 0, -84), Vector3(5.6, 3, -82))
	b.block(Vector3(-5, 1.15, -84), Vector3(5, 3, -82), T.DARK)
	b.label(Vector3(0, 3.8, -83), "SLIDE UNDER", 72)
	# Waist-high platform to vault onto, then a jump pad home.
	b.block(Vector3(-5, 0, -100), Vector3(5, 1.2, -94))
	pad(Vector3(0, 0, -108), Vector3(0, 17, 13))


func _build_wallrun_lane() -> void:
	var b := _b
	checkpoint(Vector3(-18, 0, 0), Vector3(6, 2, 10), PI * 0.5)
	b.label(Vector3(-20, 3.5, -7), "WALL-RUN: jump at a wall holding forward. Jump again to kick off.", 56, 90)
	b.block(Vector3(-122, 0, -7), Vector3(-32, 0.06, 7), T.HAZARD)
	hazard(Vector3(-77, 0.6, 0), Vector3(90, 1.0, 14))
	# [x_start, x_end, side]: two same-side segments with a gap, then alternating.
	var walls := [
		[-32.0, -44.0, -1], [-47.0, -59.0, -1], [-62.0, -74.0, 1],
		[-77.0, -89.0, -1], [-92.0, -104.0, 1], [-107.0, -119.0, -1],
	]
	for w in walls:
		var z0: float = 2.5 if w[2] > 0 else -3.1
		b.block(Vector3(w[1], 0, z0), Vector3(w[0], 7, z0 + 0.6), T.RUN)
	b.block(Vector3(-132, 0, -6), Vector3(-120, 3, 6))
	b.label(Vector3(-126, 5, 0), "NICE", 90, 90)


func _build_climb_station() -> void:
	var b := _b
	checkpoint(Vector3(14, 0, 0), Vector3(6, 2, 8), -PI * 0.5)
	# Mantle row: heights you can reach from standing, jumping, and double-jumping.
	var heights := [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0]
	for i in heights.size():
		var x := 20.0 + i * 6.0
		b.block(Vector3(x - 1.5, 0, -14), Vector3(x + 1.5, heights[i], -11), T.NEUTRAL if i % 2 else T.DARK)
		b.label(Vector3(x, heights[i] + 0.8, -10.5), "%.1fm" % heights[i], 64, 0)
	b.label(Vector3(38, 6, -12.5), "MANTLE: jump into a ledge holding forward", 56, 0)
	# Chimney: climb one wall, kick back (auto 180), climb the other.
	b.block(Vector3(28, 0, 4.5), Vector3(34, 10, 6.25), T.RUN)
	b.block(Vector3(28, 0, 9.75), Vector3(34, 12, 11.5), T.RUN)
	b.label(Vector3(26, 4, 8), "CHIMNEY: run at a wall head-on, jump to kick back", 52, -90)
	# Climb + mantle wall.
	b.block(Vector3(44, 0, 2), Vector3(48, 4.5, 10), T.RUN)
	b.label(Vector3(42, 6, 6), "CLIMB 4.5m", 64, -90)
	b.block(Vector3(52, 0, 2), Vector3(56, 6.5, 10), T.RUN)
	b.label(Vector3(50, 8, 6), "6.5m: climb, kick, double jump", 56, -90)


func _build_grapple_field() -> void:
	var b := _b
	checkpoint(Vector3(0, 0, 24), Vector3(8, 2, 6), PI)
	b.label(Vector3(0, 4, 28), "GRAPPLE (Q / LB): cyan points pull your aim", 64, 180)
	var towers := [
		[Vector3(-8, 0, 40), Vector3(-4, 14, 44)],
		[Vector3(4, 0, 52), Vector3(8, 20, 56)],
		[Vector3(-6, 0, 66), Vector3(-2, 26, 70)],
		[Vector3(-5, 0, 86), Vector3(5, 32, 96)],
	]
	for t in towers:
		b.block(t[0], t[1], T.DARK)
		var top: Vector3 = (t[0] + t[1]) * 0.5
		top.y = t[1].y + 2.0
		b.grapple_point(top)
	# Floating platforms between towers.
	b.block(Vector3(14, 11.4, 44), Vector3(20, 12, 50), T.GRAPPLE)
	b.grapple_point(Vector3(17, 15, 47))
	b.block(Vector3(-20, 17.4, 58), Vector3(-14, 18, 64), T.GRAPPLE)
	b.grapple_point(Vector3(-17, 21, 61))
	target(Vector3(2.5, 32, 93.5), Vector3.ZERO)
	target(Vector3(17, 12, 46), Vector3.ZERO)


func _build_rooftops() -> void:
	var b := _b
	b.ramp(Vector3(20, 0, -10), Vector3(20, 6, -24), 4.0, T.DARK)
	b.block(Vector3(14, 0, -36), Vector3(26, 6, -24))
	b.label(Vector3(20, 9, -30), "ROOFTOP COMBO →", 72, -90)
	b.block(Vector3(33, 0, -36), Vector3(47, 8, -24), T.DARK)
	b.block(Vector3(38, 8, -31), Vector3(39, 9, -29))  # low cover to vault
	# Floating wall-run panel across the gap.
	b.block(Vector3(49, 4, -38.5), Vector3(63, 12, -37.5), T.RUN)
	b.block(Vector3(65, 0, -36), Vector3(79, 8, -24))
	# Slide-under bar on roof 3.
	b.block(Vector3(70, 9.15, -36), Vector3(71, 11, -24), T.DARK)
	# Grapple across the big gap.
	b.grapple_point(Vector3(91, 18, -30))
	b.block(Vector3(103, 0, -36), Vector3(117, 12, -24), T.DARK)
	b.label(Vector3(110, 15, -30), "FINISH", 90, -90)
	target(Vector3(44, 8, -26), Vector3.ZERO)
	target(Vector3(75, 8, -33), Vector3(0, 0, 3))
	target(Vector3(112, 12, -30), Vector3.ZERO)
	target(Vector3(90, 0, -20), Vector3(4, 0, 0))


func _build_range() -> void:
	var b := _b
	checkpoint(Vector3(12, 0, 25), Vector3(4, 2, 6), -PI * 0.5)
	b.label(Vector3(12, 3.5, 19), "RANGE", 80, -90)
	b.block(Vector3(18, 0, 15), Vector3(19, 1.0, 35), T.DARK)
	for pos in [Vector3(24, 0, 20), Vector3(32, 0, 29), Vector3(44, 0, 18), Vector3(62, 0, 31), Vector3(85, 0, 24)]:
		target(pos, Vector3.ZERO)
	target(Vector3(38, 0, 25), Vector3(0, 0, 4))
	target(Vector3(55, 0, 22), Vector3(0, 0, 6))
	b.block(Vector3(70, 0, 16), Vector3(74, 4, 20), T.DARK)
	target(Vector3(72, 4, 18), Vector3.ZERO)


