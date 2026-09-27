class_name Course
extends Node3D
## A timed single-player course threaded through a map (DESIGN §8): a start
## zone, ordered checkpoint gates and a finish. Every map can carry one.
##  - The clock starts when you leave the start zone and counts physics time.
##  - Gates only count in order; each one becomes your respawn point.
##  - Restart (T) puts you back in the start zone with a fresh run.
##  - Teleporting (station cycling) mid-run cancels the run.
##  - Best time and best splits are saved per course in user://records.cfg.
## Works per player, so couch Race can reuse it later. Gate checks are a
## cylinder test against each player's next gate once per tick (no physics).

signal gate_passed(player: Player, index: int, split: float, delta_to_best: float)
signal finished(player: Player, time: float, new_best: bool)

enum RunState { IDLE, ARMED, RUNNING, FINISHED, VOID }

const RECORDS_PATH := "user://records.cfg"
const SILVER := 1.15  ## medal thresholds as multiples of par
const BRONZE := 1.35

class Gate:
	var name: String
	var position: Vector3   ## base center (on the walking surface)
	var radius: float
	var height: float
	var yaw: float          ## respawn facing (toward the next gate)
	var marker: MeshInstance3D
	var beam: MeshInstance3D

	func contains(p: Vector3) -> bool:
		var d := Vector2(p.x - position.x, p.z - position.z)
		return d.length() <= radius and p.y >= position.y - 0.6 and p.y <= position.y + height


class Run:
	var state: RunState = RunState.IDLE
	var time: float = 0.0
	var next_gate: int = 0          ## index into gates; gates.size() = heading for the finish
	var splits: PackedFloat32Array = []


var id: String
var title: String
var par_time: float
var start: Gate
var gates: Array[Gate] = []     ## checkpoints in order (the finish is separate)
var finish: Gate
var best_time: float = 0.0      ## 0 = no record yet
var best_splits: PackedFloat32Array = []
var save_records: bool = true   ## tests turn this off

var _runs: Dictionary = {}      ## Player -> Run
var _players: Array[Player] = []
var _mat_next: StandardMaterial3D
var _mat_later: StandardMaterial3D
var _mat_finish: StandardMaterial3D
var _shown_gate: int = -2       ## marker state last drawn (for player 0)


func setup(p_id: String, p_title: String, p_par: float) -> void:
	id = p_id
	title = p_title
	par_time = p_par
	name = "Course"
	_mat_next = _marker_mat(Color(1.0, 0.8, 0.15, 0.32))
	_mat_later = _marker_mat(Color(0.85, 0.93, 1.0, 0.12))
	_mat_finish = _marker_mat(Color(0.3, 1.0, 0.45, 0.32))
	_load_records()


## The start zone: where a run is armed, and where restarts put you.
func set_start(pos: Vector3, yaw: float, radius: float = 3.0) -> void:
	start = _gate("Start", pos, radius, 4.0)
	start.yaw = yaw


func add_gate(gate_name: String, pos: Vector3, radius: float = 3.0, height: float = 5.0) -> void:
	gates.append(_gate(gate_name, pos, radius, height))


func set_finish(pos: Vector3, radius: float = 4.0, height: float = 6.0) -> void:
	finish = _gate("Finish", pos, radius, height)


## Call once all gates are added: aims each respawn at the next gate and
## builds the markers.
func finalize() -> void:
	var chain: Array[Gate] = [start]
	chain.append_array(gates)
	chain.append(finish)
	for i in range(1, chain.size() - 1):
		var d := chain[i + 1].position - chain[i].position
		chain[i].yaw = atan2(-d.x, -d.z)
	for g in chain.slice(1):
		_build_marker(g)
	_refresh_markers()


func add_player(player: Player) -> void:
	_players.append(player)
	_runs[player] = Run.new()
	player.restart_handler = restart
	var hud := CourseHud.new()
	player.hud.get_parent().add_child(hud)
	hud.setup(self, player)


func run_of(player: Player) -> Run:
	return _runs.get(player)


## Back to the start zone with a fresh run.
func restart(player: Player) -> void:
	var run := run_of(player)
	run.state = RunState.IDLE
	run.time = 0.0
	run.next_gate = 0
	run.splits.clear()
	player.spawn(start.position, start.yaw)
	_update(player, run, 0.0)


## A teleport mid-run (station cycling) voids the run; out of the start zone
## it disarms it (it must not start the clock).
func on_teleport(player: Player) -> void:
	var run := run_of(player)
	if run == null:
		return
	if run.state == RunState.RUNNING:
		run.state = RunState.VOID
	elif run.state == RunState.ARMED:
		run.state = RunState.IDLE


func next_target(player: Player) -> Gate:
	var run := run_of(player)
	if run == null:
		return null
	match run.state:
		RunState.RUNNING:
			return gates[run.next_gate] if run.next_gate < gates.size() else finish
		RunState.ARMED:
			return gates[0] if not gates.is_empty() else finish
		_:
			return start


static func medal(time: float, par: float) -> String:
	if time <= par:
		return "GOLD"
	if time <= par * SILVER:
		return "SILVER"
	if time <= par * BRONZE:
		return "BRONZE"
	return ""


static func format_time(t: float) -> String:
	var cs := roundi(t * 100.0)
	return "%d:%02d.%02d" % [cs / 6000, (cs / 100) % 60, cs % 100]


func _physics_process(delta: float) -> void:
	for p in _players:
		_update(p, _runs[p], delta)
	var lead := run_of(_players[0]) if not _players.is_empty() else null
	var shown := -1
	if lead and lead.state == RunState.RUNNING:
		shown = lead.next_gate
	elif lead and lead.state == RunState.ARMED:
		shown = 0
	if shown != _shown_gate:
		_shown_gate = shown
		_refresh_markers()


func _update(player: Player, run: Run, delta: float) -> void:
	var p := player.global_position
	if run.state != RunState.RUNNING:
		if start.contains(p):
			if run.state != RunState.ARMED:
				run.state = RunState.ARMED
				run.time = 0.0
				run.next_gate = 0
				run.splits.clear()
				player.spawn_position = start.position
				player.spawn_yaw = start.yaw
		elif run.state == RunState.ARMED:
			run.state = RunState.RUNNING  # the clock starts as you leave the zone
		return
	run.time += delta
	if run.next_gate < gates.size():
		var g := gates[run.next_gate]
		if g.contains(p):
			var i := run.next_gate
			run.splits.append(run.time)
			run.next_gate += 1
			player.spawn_position = g.position
			player.spawn_yaw = g.yaw
			var delta_best := run.time - best_splits[i] if i < best_splits.size() else NAN
			Sfx.play(&"double_jump", -4.0, 0.0, 1.3)
			gate_passed.emit(player, i, run.time, delta_best)
	elif finish.contains(p):
		run.state = RunState.FINISHED
		var new_best := best_time <= 0.0 or run.time < best_time
		if new_best:
			best_time = run.time
			best_splits = run.splits.duplicate()
			_save_records()
		Sfx.play(&"double_jump", -2.0, 0.0, 0.7)
		finished.emit(player, run.time, new_best)


# --------------------------------------------------------------------------- markers

func _gate(gate_name: String, pos: Vector3, radius: float, height: float) -> Gate:
	var g := Gate.new()
	g.name = gate_name
	g.position = pos
	g.radius = radius
	g.height = height
	return g


## A translucent open cylinder at the gate, plus a tall thin beam that only
## the next gate shows (so it can be found from across the map). Unshaded
## alpha blend (additive vanishes on pale concrete): no lighting, no shadows.
func _build_marker(g: Gate) -> void:
	var ring := CylinderMesh.new()
	ring.top_radius = g.radius
	ring.bottom_radius = g.radius
	ring.height = g.height
	ring.cap_top = false
	ring.cap_bottom = false
	ring.radial_segments = 32
	ring.rings = 1
	g.marker = MeshInstance3D.new()
	g.marker.mesh = ring
	g.marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g.marker)
	g.marker.global_position = g.position + Vector3.UP * g.height * 0.5
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.18
	beam_mesh.bottom_radius = 0.18
	beam_mesh.height = 60.0
	beam_mesh.cap_top = false
	beam_mesh.cap_bottom = false
	beam_mesh.radial_segments = 8
	beam_mesh.rings = 1
	g.beam = MeshInstance3D.new()
	g.beam.mesh = beam_mesh
	g.beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g.beam)
	g.beam.global_position = g.position + Vector3.UP * 30.0


func _refresh_markers() -> void:
	for i in gates.size():
		var g := gates[i]
		var is_next := i == _shown_gate
		g.marker.visible = _shown_gate < 0 or i >= _shown_gate
		g.marker.material_override = _mat_next if is_next else _mat_later
		g.beam.visible = is_next
		g.beam.material_override = _mat_next
	var finish_next := _shown_gate == gates.size()
	finish.marker.material_override = _mat_finish if finish_next else _mat_later
	finish.beam.visible = finish_next
	finish.beam.material_override = _mat_finish


static func _marker_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	m.disable_receive_shadows = true
	return m


# --------------------------------------------------------------------------- records

func _load_records() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RECORDS_PATH) != OK:
		return
	best_time = cfg.get_value(id, "best_time", 0.0)
	best_splits = cfg.get_value(id, "best_splits", PackedFloat32Array())


func _save_records() -> void:
	if not save_records:
		return
	var cfg := ConfigFile.new()
	cfg.load(RECORDS_PATH)  # keep other courses' records
	cfg.set_value(id, "best_time", best_time)
	cfg.set_value(id, "best_splits", best_splits)
	cfg.save(RECORDS_PATH)
