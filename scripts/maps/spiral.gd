extends LevelBase
## "SPIRAL" (MAP_BRIEFS §5.1): a sky garage for flying cars bolted to the south
## flank of a 900 m arcology, at night, 300 m above a glowing megacity.
##
## Coordinates: x = east, z = south, y = up. The garage is a 76 × 76 m square
## (|x|,|z| ≤ 38) whose north side is the arcology face (z = -38). Seven decks
## 6 m apart (deck 1 at y = 0 … deck 7 at 36) plus the roof at 42. A 36 × 36 m
## square void runs through every deck above deck 1.
##
## The Express is a helical slide lane (r 13–18 m around the void's axis) from
## the roof's east edge down to deck 1: 12 m per quarter turn (≈26°, which
## holds the 18 m/s soft cap). Every quarter turn it touches a deck edge at
## that deck's height: roof (E), deck 6 (S), deck 4 (W), deck 2 (N), and it
## runs out onto deck 1 in the NE corner.
##
## Deck 1 sits at y = 0 so the player's fall reset (y < -60) and the hazard
## 40 m below stay valid; the city floor is drawn 300 m below that.

const H := 38.0          ## outer half-size
const Q := 18.0          ## void half-size (square hole in decks 2..roof)
const DECK := 6.0
const ROOF := 42.0
const R_IN := 13.0       ## Express inner / outer radius
const R_OUT := 18.0
const DROP_PER_90 := 12.0
const EXPRESS_SWEEP := 315.0
const CITY_Y := -300.0
const LIFT := Rect2(-34, -35, 6, 6)
const RING := Vector3(72, 46, -14)  ## traffic ring centre (radius 13)
const PIT_PAD_Z := -3.0
## Course gates: name, position, radius (start and finish are separate).
const GATES := [
	["Express drop-in", Vector3(-15.5, 18, 0), 3.5],
	["Express exit", Vector3(20, 0, -8), 3.5],
	["SW dock", Vector3(-33, 0, 33), 4.0],
	["Deck 4 corner", Vector3(-21, 18, 21), 4.0],
	["Deck 7 corner", Vector3(-21, 36, -21), 4.0],
]

var backdrop: Backdrop
var outer_car: Mover
var lift: Mover
var _holes: Dictionary = {}  ## level index (0 = deck 1 … 7 = roof) -> Array[Rect2]
var _car_bays: Array[Rect2] = []  ## areas kept clear of parked cars (per all decks)


func _init() -> void:
	stations = [
		["Course start (roof)", Vector3(-26, ROOF, 2), -PI * 0.5],
		["Express top", Vector3(24, ROOF, 6), PI * 0.5],
		["Void from deck 4", Vector3(0, 18, -26), PI],
		["Deck 1 pit", Vector3(-4, 0, -9), -PI * 0.5],
		["Hover dock (SE)", Vector3(33, 0, 33), PI],
		["Sky dock + launch pad", Vector3(17, 45.5, -33), -PI * 0.5],
		["Traffic ring", RING + Vector3(-13, 0, -4), PI * 0.5],
		["Vista (SE dock edge, 300 m drop)", Vector3(44, 0, 46.8), PI * 0.85, deg_to_rad(-38.0)],
	]
	# Couch FFA spawns (M3): two per level, facing outward or along a side,
	# never across the void.
	arena_spawns = [
		[Vector3(-30, 0, -8), PI * 0.5], [Vector3(30, 0, 22), -PI * 0.5],
		[Vector3(22, 6, 32), PI], [Vector3(-32, 6, -20), PI * 0.5],
		[Vector3(32, 12, -22), -PI * 0.5], [Vector3(-22, 12, 32), PI],
		[Vector3(-32, 18, 22), PI * 0.5], [Vector3(24, 18, -32), 0.0],
		[Vector3(32, 24, 22), -PI * 0.5], [Vector3(-24, 24, -32), 0.0],
		[Vector3(-32, 30, -4), PI * 0.5], [Vector3(20, 30, 32), PI],
		[Vector3(32, 36, -6), -PI * 0.5], [Vector3(-20, 36, 32), PI],
		[Vector3(-30, ROOF, 30), PI * 0.75], [Vector3(30, ROOF, -24), -PI * 0.5],
	]


func intro_hint() -> String:
	return "SPIRAL RUN   ·   slide the Express (hold crouch, steer with the camera)   ·   Hold Q grapple   ·   T restart   ·   [ ] stations"


func build_level() -> void:
	_plan_holes()
	_decks()
	_express()
	_void()
	_hover_cars()
	_roof()
	_arcology()
	_traffic_ring()
	hazard(Vector3(0, -45, 0), Vector3(1800, 10, 1800))
	_backdrop()
	_course()


# --------------------------------------------------------------------------- course

## "Spiral Run": roof → drop from the catwalk onto the Express at deck 4 →
## slide to deck 1 → ride the outside hover car (or run) to the SW dock →
## grapple up the void corners to deck 4 and deck 7 → climb to the roof →
## wall-run the arcology face → finish on the sky-dock launch pad.
## Par is a first guess until timed in play.
func _course() -> void:
	var c := make_course("spiral_run", "Spiral Run", 45.0)  # ≈38 s clean run (leg estimate) + 15%
	c.set_start(Vector3(-26, ROOF, 2), -PI * 0.5)
	for g: Array in GATES:
		c.add_gate(g[0], g[1], g[2], 6.0)
	c.set_finish(Vector3(24, 45.62, -34), 3.0)
	c.finalize()


# --------------------------------------------------------------------------- decks

func _level_y(i: int) -> float:
	return i * DECK


## Every hole in every slab, planned first so slabs split around them.
## Climb wells: a hole in level i+1 above a stepped climb block on level i.
func _plan_holes() -> void:
	for i in 8:
		_holes[i] = [] as Array[Rect2]
		if i >= 1:
			(_holes[i] as Array).append(Rect2(-Q, -Q, Q * 2.0, Q * 2.0))
		(_holes[i] as Array).append(LIFT)
	_car_bays.append(LIFT.grow(2.0))
	var wells := [
		[Vector2(30, 10), Vector2(1, 0)],     # deck 1 → 2 (east)
		[Vector2(-10, 30), Vector2(0, 1)],    # 2 → 3 (south)
		[Vector2(-30, -10), Vector2(-1, 0)],  # 3 → 4 (west)
		[Vector2(30, -10), Vector2(1, 0)],    # 4 → 5 (east)
		[Vector2(10, 30), Vector2(0, 1)],     # 5 → 6 (south)
		[Vector2(-30, 10), Vector2(-1, 0)],   # 6 → 7 (west)
		[Vector2(-8, -28), Vector2(0, -1)],   # 7 → roof (north)
	]
	for i in wells.size():
		var c: Vector2 = wells[i][0]
		var d: Vector2 = wells[i][1]
		var across := Vector2(-d.y, d.x)
		var hole := _rect_from(c - d * 2.5 - across * 2.0, c + d * 2.5 + across * 2.0)
		(_holes[i + 1] as Array).append(hole)
		_car_bays.append(hole.grow(1.5))
		_climb_well(_level_y(i), c, d)


func _rect_from(a: Vector2, b: Vector2) -> Rect2:
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


## A stepped climb block under a hole: mantle the 1.5 m step, climb the 4.5 m
## face, mantle out onto the next level (DESIGN §7.4: climb + mantle ≤ 6 m).
func _climb_well(y: float, c: Vector2, d: Vector2) -> void:
	var across := Vector2(-d.y, d.x)
	var block := _rect_from(c + d * 0.5 - across * 2.0, c + d * 2.5 + across * 2.0)
	var step := _rect_from(c - d * 0.5 - across * 2.0, c + d * 0.5 + across * 2.0)
	_b.block(Vector3(block.position.x, y, block.position.y), Vector3(block.end.x, y + DECK, block.end.y), T.RUN)
	_b.block(Vector3(step.position.x, y, step.position.y), Vector3(step.end.x, y + 1.5, step.end.y), T.DARK)


func _decks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_car_bays.append(Rect2(12, -38, 20, 10))  # the sky dock on the roof
	for i in 8:
		var y := _level_y(i)
		var thick := 1.0 if i == 0 else 0.4
		_slab(y, thick, _holes[i])
		_edges(i, y)
		_cover(i, y, rng)
		if i < 7:
			_columns(i, y)
			_ceiling_lights(y + DECK - 0.42)
			_parked_cars(i, y, rng)
		if i >= 1 and i < 7:
			_b.label(Vector3(-H + 1.2, y + 3.2, 0), "DECK %d" % (i + 1), 160, 90.0)
			_b.label(Vector3(H - 1.2, y + 3.2, 0), "DECK %d" % (i + 1), 160, -90.0)
	# Deck 1 underside: a stepped undercroft hanging off the arcology.
	_b.deco(Vector3(0, -4.5, -2), Vector3(70, 7, 72), T.DARK)
	_b.deco(Vector3(0, -12, -8), Vector3(52, 8, 60), T.METAL)
	_b.deco(Vector3(0, -22, -16), Vector3(30, 12, 44), T.DARK)
	for x: float in [-30.0, 30.0]:
		_b.deco(Vector3(x, -18, -24), Vector3(3, 3, 32), T.METAL, Vector3(-28, 0, 0))
	# Service lift through every level (NW, against the arcology): stops at
	# each deck and the roof. Its shaft is a hole in every slab.
	_b.block(Vector3(LIFT.position.x, -1.6, LIFT.position.y), Vector3(LIFT.end.x, -1.0, LIFT.end.y), T.DARK)
	var lc := LIFT.get_center()
	lift = _b.mover(Vector3(lc.x, 0, lc.y))
	var stops := PackedVector3Array()
	for i in 8:
		stops.append(Vector3(0, _level_y(i), 0))
	lift.points = stops
	lift.move_time = 1.4
	lift.pause_time = 1.4
	_b.attach_box(lift, Vector3(0, -0.2, 0), Vector3(LIFT.size.x - 0.4, 0.4, LIFT.size.y - 0.4), T.BOOST)
	_b.label(Vector3(lc.x, 3.2, lc.y + 3.6), "LIFT", 160)


## One slab at top height y, split into as few boxes as possible around holes.
func _slab(y: float, thick: float, holes: Array) -> void:
	var xs: Array[float] = [-H, H]
	var zs: Array[float] = [-H, H]
	for h: Rect2 in holes:
		for v: float in [h.position.x, h.end.x]:
			if v > -H and v < H and not xs.has(v):
				xs.append(v)
		for v: float in [h.position.y, h.end.y]:
			if v > -H and v < H and not zs.has(v):
				zs.append(v)
	xs.sort()
	zs.sort()
	# Row runs (merge along x), then stack identical runs along z.
	var open: Dictionary = {}  ## "x0|x1" -> z0 of the run being extended
	var rows: Array = []
	for j in zs.size() - 1:
		var z0 := zs[j]
		var z1 := zs[j + 1]
		var runs: Array = []
		var start := -1
		for k in xs.size() - 1:
			var cx := (xs[k] + xs[k + 1]) * 0.5
			var cz := (z0 + z1) * 0.5
			var filled := true
			for h: Rect2 in holes:
				if h.has_point(Vector2(cx, cz)):
					filled = false
					break
			if filled and start < 0:
				start = k
			if (not filled or k == xs.size() - 2) and start >= 0:
				var end := k + 1 if filled else k
				runs.append(Vector2(xs[start], xs[end]))
				start = -1
		rows.append([z0, z1, runs])
	var active: Dictionary = {}  ## Vector2 run -> z0
	for row: Array in rows:
		var runs: Array = row[2]
		for run: Vector2 in active.keys():
			if not runs.has(run):
				_b.block(Vector3(run.x, y - thick, active[run]), Vector3(run.y, y, row[0]), T.NEUTRAL)
				active.erase(run)
		for run: Vector2 in runs:
			if not active.has(run):
				active[run] = row[0]
	for run: Vector2 in active.keys():
		_b.block(Vector3(run.x, y - thick, active[run]), Vector3(run.y, y, H), T.NEUTRAL)


## Rails (1.1 m: vault them at speed) and light strips along slab edges.
func _edges(i: int, y: float) -> void:
	var cyan := Color(0.55, 0.9, 1.0)
	var warm := Color(1.0, 0.78, 0.5)
	# Outer edges (E, S, W; north is the arcology). The SE and SW corners stay
	# open on deck 1 for the hover-car docks; docked cars need gaps too.
	for side in 3:
		for seg: Vector2 in _outer_rail_segments(i, side):
			var a := seg.x
			var b := seg.y
			match side:
				0:  # east, along z
					_rail(Vector3(H - 0.2, y, a), Vector3(H, y + 1.1, b))
				1:  # south, along x
					_rail(Vector3(a, y, H - 0.2), Vector3(b, y + 1.1, H))
				2:  # west
					_rail(Vector3(-H, y, a), Vector3(-H + 0.2, y + 1.1, b))
	# Slab edge light strips (outside faces).
	_b.deco(Vector3(H + 0.03, y - 0.2, 0), Vector3(0.06, 0.12, H * 2.0), T.LIGHT, Vector3.ZERO, warm)
	_b.deco(Vector3(-H - 0.03, y - 0.2, 0), Vector3(0.06, 0.12, H * 2.0), T.LIGHT, Vector3.ZERO, warm)
	_b.deco(Vector3(0, y - 0.2, H + 0.03), Vector3(H * 2.0, 0.12, 0.06), T.LIGHT, Vector3.ZERO, warm)
	if i == 0:
		return
	# Void edges: rails in the middle of each side (the corners stay open for
	# drops and grapple mantles), with a gap where the Express touches this
	# level. A cyan strip traces the whole void edge.
	var touch := _express_touch_side(i)
	for side in 4:
		var n := [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)][side] as Vector2
		var along := Vector2(-n.y, n.x)
		var spans: Array[Vector2] = [Vector2(-10, -4), Vector2(4, 10)]
		if side != touch:
			spans = [Vector2(-10, 10)]
		if i == 2 and (side == 0 or side == 2):  # deck 3: open where the pit pads land you
			var t := PIT_PAD_Z * along.y
			spans = [Vector2(-10, t - 3.0), Vector2(t + 3.0, 10)]
		for sp in spans:
			var p0 := n * Q + along * sp.x
			var p1 := n * (Q + 0.2) + along * sp.y
			_rail(Vector3(minf(p0.x, p1.x), y, minf(p0.y, p1.y)), Vector3(maxf(p0.x, p1.x), y + 1.1, maxf(p0.y, p1.y)))
		var mid := n * (Q - 0.03)
		var size := Vector3(0.06, 0.12, Q * 2.0) if absf(n.x) > 0.5 else Vector3(Q * 2.0, 0.12, 0.06)
		_b.deco(Vector3(mid.x, y - 0.2, mid.y), size, T.LIGHT, Vector3.ZERO, cyan)


func _rail(a: Vector3, b: Vector3) -> void:
	if (b - a).x < 0.05 or (b - a).z < 0.05:
		return
	_b.block(a, b, T.DARK)
	var top := Vector3((a.x + b.x) * 0.5, b.y + 0.02, (a.z + b.z) * 0.5)
	_b.deco(top, Vector3(b.x - a.x, 0.03, b.z - a.z), T.LIGHT, Vector3.ZERO, Color(0.35, 0.4, 0.45))


## Rail spans along an outer side (as [from, to] along the side's axis).
func _outer_rail_segments(i: int, side: int) -> Array[Vector2]:
	var gaps: Array[Vector2] = []
	if i == 0 and side == 1:
		gaps = [Vector2(-H, -H + 9), Vector2(H - 9, H)]  # outside car docks (SW, SE)
	for d: Array in _dock_defs():
		if d[0] == i and d[1] == side:
			gaps.append(Vector2(d[2] - 1.8, d[2] + 1.8))
	var segs: Array[Vector2] = []
	var s := -H  # every side spans -H..H (the north ends meet the arcology)
	gaps.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	for g in gaps:
		if g.x > s:
			segs.append(Vector2(s, g.x))
		s = maxf(s, g.y)
	if s < H:
		segs.append(Vector2(s, H))
	return segs


## Which void side the Express touches on level i (0 E, 1 S, 2 W, 3 N), or -1.
func _express_touch_side(i: int) -> int:
	match i:
		7: return 0
		5: return 1
		3: return 2
		1: return 3
	return -1


func _columns(i: int, y: float) -> void:
	var m := 28.0
	for side in 4:
		for t: float in [-28.0, -14.0, 0.0, 14.0]:
			var p: Vector2 = [Vector2(m, t), Vector2(-t, m), Vector2(-m, -t), Vector2(t, -m)][side]
			var r := Rect2(p - Vector2(0.6, 0.6), Vector2(1.2, 1.2))
			if _blocked(r.grow(0.8), i) or _blocked(r.grow(0.8), i + 1):
				continue
			_b.block(Vector3(r.position.x, y, r.position.y), Vector3(r.end.x, y + DECK - 0.4, r.end.y), T.NEUTRAL)
			_b.deco(Vector3(p.x, y + 2.6, p.y), Vector3(1.26, 0.3, 1.26), T.LIGHT, Vector3.ZERO, Color(1.0, 0.78, 0.5))


func _blocked(r: Rect2, level: int) -> bool:
	if not _holes.has(level):
		return false
	for h: Rect2 in _holes[level]:
		if h.intersects(r):
			return true
	return false


func _ceiling_lights(y: float) -> void:
	for side in 4:
		for t: float in [-22.0, 0.0, 22.0]:
			var p: Vector2 = [Vector2(27, t), Vector2(-t, 27), Vector2(-27, -t), Vector2(t, -27)][side]
			var size := Vector3(0.35, 0.05, 12.0) if side % 2 == 0 else Vector3(12.0, 0.05, 0.35)
			_b.deco(Vector3(p.x, y, p.y), size, T.LIGHT)


## Parked hover cars in the outer bays: 1.2 m, so they're vault cover with
## slide lanes between them.
func _parked_cars(i: int, y: float, rng: RandomNumberGenerator) -> void:
	var paints := [Color(0.92, 0.93, 0.95), Color(0.12, 0.13, 0.15), Color(0.75, 0.2, 0.2), Color(0.2, 0.35, 0.75), Color(0.85, 0.7, 0.2), Color(0.55, 0.57, 0.6)]
	for side in 4:
		var t := -30.0
		while t <= 30.0:
			var p: Vector2 = [Vector2(34, t), Vector2(-t, 34), Vector2(-34, -t), Vector2(t, -34)][side]
			var along_x := side % 2 == 0  # E/W bays: cars point east-west
			var r := Rect2(p - (Vector2(2.4, 1.1) if along_x else Vector2(1.1, 2.4)), Vector2(4.8, 2.2) if along_x else Vector2(2.2, 4.8))
			var free := rng.randf() < 0.55
			for bay in _car_bays:
				if bay.intersects(r):
					free = false
			if _blocked(r.grow(0.5), i) or _blocked(r.grow(0.5), i + 1):
				free = false
			for d: Array in _dock_defs():
				if d[0] == i and d[1] == side and absf(d[2] - (p.y if along_x else p.x)) < 3.0:
					free = false
			for k: Vector3 in _keep_clear():
				if absf(k.y - y) < 1.0 and r.grow(1.5).has_point(Vector2(k.x, k.z)):
					free = false
			if free:
				_car_static(Vector3(p.x, y, p.y), 90.0 if along_x else 0.0, paints[rng.randi_range(0, paints.size() - 1)])
			t += 3.2


## Points parked cars must leave room around: stations, spawns, gates.
func _keep_clear() -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for st: Array in stations:
		pts.append(st[1])
	for sp: Array in arena_spawns:
		pts.append(sp[0])
	for g: Array in GATES:
		pts.append(g[1])
	return pts


## Fill the deck ring with fighting cover (MAP_BRIEFS §0.4, "big but full"):
## two bands of pieces either side of a clear 3 m slide lane (r 23.5–26.5
## from the void axis): low vaultable barriers, charging pods, and tall holo
## pylons that break sightlines across the deck.
func _cover(i: int, y: float, rng: RandomNumberGenerator) -> void:
	var holo := [Color(0.3, 0.9, 1.0), Color(1.0, 0.3, 0.75), Color(1.0, 0.75, 0.3)]
	for side in 4:
		var n := [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)][side] as Vector2
		var along := Vector2(-n.y, n.x)
		for band: Array in [[21.0, [-13.0, -5.0, 5.0, 13.0]], [29.8, [-21.0, -7.0, 7.0, 21.0]]]:
			var r: float = band[0]
			for t: float in band[1]:
				t += rng.randf_range(-1.5, 1.5)
				var roll := rng.randf()
				if roll < 0.2:
					continue
				var c := n * r + along * t
				var kind := 0 if roll < 0.55 else (1 if roll < 0.8 else 2)
				# Footprint in (along, across) then to world axes.
				var fa: float = [3.6, 1.4, 2.4][kind]
				var fn: float = [0.5, 1.4, 0.6][kind]
				var half := (along * fa + n * fn).abs() * 0.5
				var rect := Rect2(c - half, half * 2.0)
				if _blocked(rect.grow(1.0), i) or _blocked(rect.grow(1.0), i + 1):
					continue
				var clear := true
				for k: Vector3 in _keep_clear():
					if absf(k.y - y) < 1.0 and rect.grow(2.0).has_point(Vector2(k.x, k.z)):
						clear = false
				for bay in _car_bays:
					if bay.intersects(rect):
						clear = false
				if not clear:
					continue
				var size3 := Vector3(half.x * 2.0, 0, half.y * 2.0)
				match kind:
					0:  # low barrier: vault it at speed, crouch behind it
						_b.block(Vector3(rect.position.x, y, rect.position.y), Vector3(rect.end.x, y + 1.05, rect.end.y), T.DARK)
						_b.deco(Vector3(c.x, y + 1.08, c.y), size3 + Vector3(0, 0.05, 0), T.LIGHT, Vector3.ZERO, Color(1.0, 0.78, 0.5))
					1:  # charging pod
						_b.block(Vector3(rect.position.x, y, rect.position.y), Vector3(rect.end.x, y + 1.2, rect.end.y), T.NEUTRAL)
						_b.deco(Vector3(c.x, y + 0.7, c.y), size3 + Vector3(0.04, 0.12, 0.04), T.LIGHT, Vector3.ZERO, Color(0.4, 0.9, 1.0))
					2:  # holo pylon: breaks sightlines, glows
						_b.block(Vector3(rect.position.x, y, rect.position.y), Vector3(rect.end.x, y + 2.6, rect.end.y), T.METAL)
						var face := n * (fn * 0.5 + 0.03)
						var panel := Vector3(fa - 0.3, 1.4, 0.04) if absf(along.x) > 0.5 else Vector3(0.04, 1.4, fa - 0.3)
						for sgn: float in [1.0, -1.0]:
							_b.deco(Vector3(c.x + face.x * sgn, y + 1.6, c.y + face.y * sgn), panel, T.LIGHT, Vector3.ZERO, holo[rng.randi_range(0, 2)])


func _car_static(pos: Vector3, yaw_deg: float, paint: Color) -> void:
	var rot := Vector3(0, yaw_deg, 0)
	_b.collider(pos + Vector3.UP * 0.6, Vector3(2.2, 1.2, 4.6), T.NEUTRAL, rot)
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	_b.deco(pos + Vector3.UP * 0.62, Vector3(2.2, 0.76, 4.6), T.NEUTRAL, rot, paint)
	_b.deco(pos + basis * Vector3(0, 1.1, 0.3), Vector3(1.8, 0.2, 2.4), T.DARK, rot, Color(0.08, 0.1, 0.14))
	_b.deco(pos + Vector3.UP * 0.12, Vector3(1.6, 0.04, 3.8), T.LIGHT, rot, Color(0.4, 0.85, 1.0))


# --------------------------------------------------------------------------- the Express

func _express_y(angle_deg: float) -> float:
	return ROOF - angle_deg * DROP_PER_90 / 90.0


func _express() -> void:
	var drop := EXPRESS_SWEEP * DROP_PER_90 / 90.0 - 0.02  # ends 2 cm above deck 1 (no z-fight)
	_b.helix_ramp(Vector3.ZERO, R_IN, R_OUT, ROOF, 0.0, EXPRESS_SWEEP, drop, T.ASPHALT, 0.6)
	# Edge light strips (visual only), and the outer rail with gaps at the
	# deck touch points so you can join or leave the lane there.
	_b.helix_ramp(Vector3.ZERO, R_IN, R_IN + 0.25, ROOF + 0.03, 0.0, EXPRESS_SWEEP, drop, T.LIGHT, 0.05, 2.0, Color(0.5, 0.9, 1.0), false)
	_b.helix_ramp(Vector3.ZERO, R_OUT - 0.5, R_OUT - 0.3, ROOF + 0.03, 0.0, EXPRESS_SWEEP, drop, T.LIGHT, 0.05, 2.0, Color(1.0, 0.8, 0.3), false)
	for span: Vector2 in [Vector2(10, 80), Vector2(100, 170), Vector2(190, 260), Vector2(280, 300)]:
		var a := span.x
		var sweep := span.y - span.x
		_b.helix_ramp(Vector3.ZERO, R_OUT - 0.25, R_OUT, _express_y(a) + 1.1, a, sweep, sweep * DROP_PER_90 / 90.0, T.DARK, 1.1, 2.0, Color(0.16, 0.2, 0.26))
		_b.helix_ramp(Vector3.ZERO, R_OUT - 0.25, R_OUT, _express_y(a) + 1.14, a, sweep, sweep * DROP_PER_90 / 90.0, T.LIGHT, 0.04, 2.0, Color(1.0, 0.8, 0.3), false)
	_b.label(Vector3(16, ROOF + 3.5, -2.5), "EXPRESS", 220, -90.0)
	# ENEMY: sniper on deck 6 south watching the Express and the void.
	target(Vector3(0, 30, 26), Vector3(4, 0, 0))
	# ENEMY: grunt pair on deck 4 west by the drop-in.
	target(Vector3(-24, 18, -6), Vector3(0, 0, 3))


# --------------------------------------------------------------------------- the void

func _void() -> void:
	# The chimney: two RUN panels 3.9 m apart beside the roof catwalk; drop in
	# and kick wall to wall (each touch refreshes the double jump).
	_b.block(Vector3(-5, 3, 1.2), Vector3(5, 40, 1.8), T.RUN)
	_b.block(Vector3(-5, 3, 5.7), Vector3(5, 40, 6.3), T.RUN)
	# Corner pillars (RUN, full height): wall touches while dropping.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var c := Vector3(15 * sx, 0, 15 * sz)
			_b.block(c + Vector3(-1.25, 0, -1.25), c + Vector3(1.25, ROOF + 3.0, 1.25), T.RUN)
	# Corner grapple beacons, each 2.5 m above a deck: zip up the corner gap
	# from any deck below, then step out onto that deck.
	_b.grapple_point(Vector3(17.3, 14.5, 17.3))    # SE → deck 3
	_b.grapple_point(Vector3(-17.3, 20.5, 17.3))   # SW → deck 4
	_b.grapple_point(Vector3(17.3, 32.5, -17.3))   # NE → deck 6
	_b.grapple_point(Vector3(-17.3, 38.5, -17.3))  # NW → deck 7
	_b.grapple_point(Vector3(0, ROOF + 6.0, 9.0))  # over the void, south of the catwalk
	# Deck 1 pit: a ring of light on the floor and two antigrav pads that
	# launch you up and out onto deck 3 (east and west).
	_b.helix_ramp(Vector3.ZERO, 11.8, 12.1, 0.02, 0.0, 360.0, 0.0, T.LIGHT, 0.02, 4.0, Color(0.5, 0.9, 1.0), false)
	pad(Vector3(10.5, 0, PIT_PAD_Z), Vector3(9.5, 26.0, 0.0))
	pad(Vector3(-10.5, 0, PIT_PAD_Z), Vector3(-9.5, 26.0, 0.0))
	# ENEMY: rusher in the pit.
	target(Vector3(-4, 0, -9), Vector3(3, 0, 0))


# --------------------------------------------------------------------------- hover cars

## Docked hover cars that pull out over the edge and drift along it:
## [level, side (0 E / 1 S / 2 W), position along the side].
func _dock_defs() -> Array:
	return [[2, 0, 12.0], [4, 2, -12.0], [6, 1, -8.0]]


func _hover_cars() -> void:
	for d: Array in _dock_defs():
		var i: int = d[0]
		var side: int = d[1]
		var t: float = d[2]
		var y := _level_y(i)
		var n := [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][side] as Vector2
		var along := Vector2(absf(n.y), absf(n.x))  # the side's axis (+z for E/W, +x for S)
		var bay := n * 34.0 + along * t
		var car := _b.mover(Vector3(bay.x, y, bay.y))
		var out := n * 12.0
		var slide := along * (18.0 if t < 0.0 else -18.0)
		car.points = PackedVector3Array([Vector3.ZERO, Vector3(out.x, 0, out.y), Vector3(out.x + slide.x, 0, out.y + slide.y)])
		car.move_time = 2.4
		car.pause_time = 1.6
		car.phase = 0.25 * i
		_car_on_mover(car, absf(n.x) > 0.5, Color(0.95, 0.95, 0.97))
		_b.deco(Vector3(bay.x, y + 0.02, bay.y), Vector3(5.4, 0.02, 3.2) if absf(n.x) > 0.5 else Vector3(3.2, 0.02, 5.4), T.BOOST)

	# The outside express car: from the SE dock along the south face to the
	# SW dock, over the drop. Jump off mid-leg for ~25 m/s of free speed.
	for x: float in [-43.0, 43.0]:
		_b.block(Vector3(x - 5, -1, 38), Vector3(x + 5, 0, 48), T.DARK)
		_b.deco(Vector3(x, 0.02, 43), Vector3(6, 0.02, 6), T.BOOST)
		_b.label(Vector3(x, 3.5, 47.5), "DOCK", 160, 180.0)
	outer_car = _b.mover(Vector3(43, 0, 43))
	outer_car.points = PackedVector3Array([Vector3.ZERO, Vector3(-86, 0, 0)])
	outer_car.move_time = 5.0
	outer_car.pause_time = 2.0
	_car_on_mover(outer_car, true, Color(1.0, 0.55, 0.15))
	# ENEMY: drone patrolling the south face at car height.


## A hover car on a mover: one collision box (hovering 0.25 m above its base),
## plus a canopy and an underglow strip.
func _car_on_mover(m: Mover, along_x: bool, paint: Color) -> void:
	var size := Vector3(5.0, 1.0, 2.6) if along_x else Vector3(2.6, 1.0, 5.0)
	m.set_meta(&"car", true)
	_b.attach_box(m, Vector3(0, 0.75, 0), size, T.NEUTRAL)
	for c in m.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = _paint_mat(paint)
	_b.attach_deco(m, Vector3(0, 1.32, 0), Vector3(size.x * 0.55, 0.14, size.z * 0.55), T.DARK)
	_b.attach_deco(m, Vector3(0, 0.2, 0), Vector3(size.x * 0.8, 0.05, size.z * 0.8), T.GRAPPLE)


var _paint_mats: Dictionary = {}


func _paint_mat(c: Color) -> StandardMaterial3D:
	if not _paint_mats.has(c):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = 0.6
		m.roughness = 0.25
		_paint_mats[c] = m
	return _paint_mats[c]


# --------------------------------------------------------------------------- roof

func _roof() -> void:
	# Catwalk across the void from the west roof to the top of the Express.
	_b.block(Vector3(-Q, ROOF - 0.4, -1), Vector3(R_IN + 0.3, ROOF, 1), T.METAL)
	_b.deco(Vector3(-2.5, ROOF + 0.02, -0.95), Vector3(Q + R_IN - 0.5, 0.03, 0.08), T.LIGHT, Vector3.ZERO, Color(0.5, 0.9, 1.0))
	_b.deco(Vector3(-2.5, ROOF + 0.02, 0.95), Vector3(Q + R_IN - 0.5, 0.03, 0.08), T.LIGHT, Vector3.ZERO, Color(0.5, 0.9, 1.0))
	# Roof dressing: a few parked cars and vents as cover.
	_car_static(Vector3(-30, ROOF, -14), 90.0, Color(0.9, 0.9, 0.92))
	_car_static(Vector3(-30, ROOF, 20), 90.0, Color(0.12, 0.13, 0.15))
	_car_static(Vector3(26, ROOF, 28), 0.0, Color(0.75, 0.2, 0.2))
	_b.block(Vector3(24, ROOF, 12), Vector3(28, ROOF + 2.4, 16), T.NEUTRAL)
	_b.block(Vector3(-26, ROOF, -30), Vector3(-22, ROOF + 1.2, -26), T.DARK)
	# ENEMY: heavy on the roof by the catwalk.
	target(Vector3(-24, ROOF, 12), Vector3(0, 0, 3))


# --------------------------------------------------------------------------- arcology

func _arcology() -> void:
	# The megastructure the garage hangs on: 520 m wide, from the city floor to
	# 900 m. Visual only, except a collision face around the play space.
	_b.deco(Vector3(0, (CITY_Y + 640.0) * 0.5, -199), Vector3(520, 640.0 - CITY_Y, 322), T.FACADE)
	_b.deco(Vector3(0, 770, -200), Vector3(360, 260, 240), T.FACADE)
	_b.deco(Vector3(0, 960, -200), Vector3(60, 120, 60), T.FACADE)
	_b.collider(Vector3(0, 45, -41.5), Vector3(220, 170, 7), T.FACADE)
	# Light bands up the face every ~30 m, and vertical accent strips.
	for k in 22:
		var y := -120.0 + k * 30.0
		_b.deco(Vector3(0, y, -37.9), Vector3(520, 0.5, 0.2), T.LIGHT, Vector3.ZERO, Color(0.5, 0.85, 1.0))
	for x: float in [-120.0, -60.0, 60.0, 120.0]:
		_b.deco(Vector3(x, 250, -37.9), Vector3(0.6, 800, 0.2), T.LIGHT, Vector3.ZERO, Color(1.0, 0.75, 0.45))

	# Above the roof: a RUN panel along the face (wall-run it east) that ends
	# at the sky dock, a block bolted to the face with the launch pad on top.
	_b.block(Vector3(-24, ROOF + 1.0, -38), Vector3(14, ROOF + 8.0, -37.7), T.RUN)
	_b.block(Vector3(14, ROOF, -38), Vector3(30, 45.5, -30), T.NEUTRAL)
	_b.block(Vector3(14, ROOF, -30), Vector3(30, 45.5, -29.8), T.RUN)  # climb face
	_b.label(Vector3(22, 49, -37.5), "SKY DOCK", 200)
	# Launch pad: across the traffic lane to the ring platform (the power spot).
	pad(Vector3(24, 45.5, -34), Vector3(20.5, 26.0, 12.4))
	_b.grapple_point(Vector3(22, 51, -31))
	# ENEMY: sniper on the sky dock.
	target(Vector3(17, 45.5, -36), Vector3(0, 0, 0))


# --------------------------------------------------------------------------- traffic ring

## A floating traffic-control ring east of the garage, over the drop: the
## exposed power position. Reach it from the sky-dock pad or by grappling
## the beacon on its west edge from the roof; a pad sends you back.
func _traffic_ring() -> void:
	var c := RING
	var r := 13.0
	for k in 8:
		var a := k * TAU / 8.0
		var p := c + Vector3(cos(a) * r, -0.3, sin(a) * r)
		_b.box(p, Vector3(4.5, 0.6, 11.2), T.NEUTRAL, Vector3(0, -rad_to_deg(a), 0))
		_b.deco(p + Vector3(cos(a) * 2.2, 0.35, sin(a) * 2.2), Vector3(0.12, 0.1, 11.2), T.LIGHT, Vector3(0, -rad_to_deg(a), 0), Color(0.5, 0.9, 1.0))
	_b.block(c + Vector3(-1.5, -24, -1.5), c + Vector3(1.5, 22, 1.5), T.RUN)  # pylon
	_b.grapple_point(c + Vector3(0, 23.5, 0))
	_b.grapple_point(c + Vector3(-r - 1.0, 4.0, 0))
	pad(c + Vector3(-r, 0, 3.5), Vector3(-24.0, 16.0, 0.0))
	# Cover on alternate ring segments: vault them while circling the pylon.
	for k: int in [1, 3, 5, 7]:
		var a := k * TAU / 8.0
		var p := c + Vector3(cos(a) * (r + 0.8), 0.52, sin(a) * (r + 0.8))
		_b.box(p, Vector3(0.5, 1.05, 3.2), T.DARK, Vector3(0, -rad_to_deg(a), 0))
	# ENEMY: shield heavy holding the ring.
	target(c + Vector3(0, 0, r), Vector3(3, 0, 0))


# --------------------------------------------------------------------------- backdrop

func _backdrop() -> void:
	backdrop = Backdrop.new()
	add_child(backdrop)
	var arcology := AABB(Vector3(-290, CITY_Y, -380), Vector3(580, 1400, 360))
	var play := AABB(Vector3(-160, CITY_Y, -60), Vector3(320, 600, 220))
	var spire_base := Vector3(380, CITY_Y, 260)
	var spire_box := AABB(spire_base - Vector3(90, 0, 90), Vector3(180, 1400, 180))
	backdrop.city_floor(CITY_Y)
	backdrop.city(Vector3.ZERO, CITY_Y, 0.0, 1300.0, 900, 25.0, 150.0, 11, [arcology, spire_box])
	backdrop.megatowers(Vector3.ZERO, CITY_Y, 200.0, 700.0, 42, 380.0, 1150.0, 5, [arcology, play, spire_box])
	backdrop.silhouettes(Vector3.ZERO, CITY_Y, 750.0, 1400.0, 90, 350.0, 1400.0, Color(0.05, 0.06, 0.11), 3)
	backdrop.spire(spire_base, 1350.0, 110.0, 980.0, 170.0, Color(0.4, 0.85, 1.0))
	# Flying traffic: one lane right past the south rail at deck height, more
	# above and below so the drop reads as depth.
	backdrop.traffic_lane(Vector3(-800, 18, 95), Vector3(800, 18, 95), 44, 48.0, 1)
	backdrop.traffic_lane(Vector3(-900, -70, 230), Vector3(900, -70, 230), 60, 40.0, 2)
	backdrop.traffic_lane(Vector3(-900, 120, 180), Vector3(900, 120, 180), 40, 55.0, 3)
	backdrop.traffic_lane(Vector3(130, -25, -36), Vector3(130, -25, 900), 40, 45.0, 4)
	backdrop.traffic_lane(Vector3(-140, 60, -36), Vector3(-140, 60, 900), 36, 42.0, 5)
	backdrop.traffic_lane(Vector3(-1000, -180, 520), Vector3(900, -150, -40), 70, 38.0, 6, Vector2(10, 4))
	backdrop.finalize()


# --------------------------------------------------------------------------- look

func build_environment() -> void:
	RenderingServer.global_shader_parameter_set(&"night", 1.0)
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.02, 0.03, 0.08)
	sky_mat.sky_horizon_color = Color(0.32, 0.16, 0.3)
	sky_mat.ground_horizon_color = Color(0.4, 0.2, 0.22)
	sky_mat.ground_bottom_color = Color(0.18, 0.08, 0.06)
	sky_mat.sky_curve = 0.12
	sky_mat.sun_angle_max = 3.0
	sky_mat.sun_curve = 0.02
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.44, 0.62)
	env.ambient_light_energy = 1.05
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 2.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.3, 0.2, 0.34)
	env.fog_density = 0.0011
	env.fog_aerial_perspective = 0.2
	env.fog_sky_affect = 0.4
	env.fog_height = -60.0
	env.fog_height_density = 0.006
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Moonlight from the south-east (the arcology is north, so the open decks
	# catch it), cool and fairly strong so the play space reads clearly.
	var moon := DirectionalLight3D.new()
	moon.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(150.0), 0.0)
	moon.light_energy = 0.75
	moon.light_color = Color(0.7, 0.78, 1.0)
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	moon.directional_shadow_max_distance = 160.0
	moon.shadow_blur = 1.2
	add_child(moon)
