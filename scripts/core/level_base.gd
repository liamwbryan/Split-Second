class_name LevelBase
extends Node3D
## Shared level runtime: loads tuning, builds the level (subclass hook),
## spawns players into split-screen views, and hosts the dev tools (tuning
## panel, debug readout, station cycling, screenshot tour, benchmark).
## Subclasses override build_level(), and optionally build_environment()
## and intro_hint().

const T := LevelBuilder.Tag
const MOVEMENT_DEFAULT := "res://tuning/movement_default.tres"
const SETTINGS_DEFAULT := "res://tuning/player_settings_default.tres"

## name, position, yaw[, pitch]. Station 0 is the default spawn. The optional
## pitch (radians) is for vista stations that should look down over a drop.
var stations: Array = [["Start", Vector3.ZERO, 0.0]]
## Couch FFA spawn points for M3: [position, yaw]. Put some on every layer and
## never facing each other. The level lint checks each one.
var arena_spawns: Array = []

var players: Array[Player] = []
var course: Course              ## optional timed course (build it in build_level via make_course)
var tuning: MovementTuning
var settings: PlayerSettings
var split: SplitScreen
var ui: CanvasLayer
var panel: TuningPanel
var overlay: DebugOverlay
var _b: LevelBuilder
var _overlay_was_visible: bool = true
var _station: int = 0


## Override: build geometry, set pieces, and fill `stations`.
func build_level() -> void:
	pass


## Override: sky, sun, and post-processing for this map.
func build_environment() -> void:
	_default_environment()


func intro_hint() -> String:
	return "Hold Q grapple   ·   [ ] change station   ·   ` tuning   ·   T restart"


func _ready() -> void:
	tuning = _load_or_new(MOVEMENT_DEFAULT, MovementTuning) as MovementTuning
	settings = _load_or_new(SETTINGS_DEFAULT, PlayerSettings) as PlayerSettings
	RenderingServer.global_shader_parameter_set(&"night", 0.0)  # night maps raise it in build_environment()
	build_environment()
	_apply_perf_flags()
	_b = LevelBuilder.new(self)
	build_level()
	_b.finalize()

	ui = CanvasLayer.new()
	add_child(ui)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scale="):
			Graphics.render_scale_override = float(arg.substr(8))
		elif arg.begins_with("--quality="):
			Graphics.quality = clampi(int(arg.substr(10)), 0, 3) as Graphics.Quality
	split = SplitScreen.new()
	ui.add_child(split)

	var router := InputRouter.new(settings)
	router.use_kbm = true
	router.accept_any_pad = true
	var player := spawn_player(router)

	var ui_scale := clampf(DisplayServer.window_get_size().y / 1080.0, 1.0, 3.0)
	overlay = DebugOverlay.new()
	ui.add_child(overlay)
	overlay.setup(player, ui_scale)
	panel = TuningPanel.new()
	ui.add_child(panel)
	var lo := player.loadout
	panel.setup({"Movement": tuning, "Player": settings, "Rifle": lo.weapons[0], "Rail": lo.weapons[1], "Blade": lo.weapons[2], "Knife": lo.knife}, ui_scale)
	panel.visibility_toggled.connect(_on_panel_toggled)
	player.hud.toast(intro_hint(), 6.0)
	_update_avatar_visibility()
	_apply_graphics()
	Graphics.changed.connect(_apply_graphics)

	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_screenshot_tour(arg.substr(8))
		elif arg == "--bench":
			_benchmark()
		elif arg.begins_with("--idle="):
			_idle_capture(arg.substr(7))


## Dev tool: `godot --path . -- --shots=/some/dir` saves one screenshot per
## station and quits. Lets changes be checked visually without playing.
## Dev tool: `-- --bench` flies through every station with vsync off and
## prints average and worst frame times.
func _benchmark() -> void:
	Graphics.vsync = false  # through Graphics, so focus changes don't turn it back on
	Graphics.apply_frame_pacing()
	for f in 120:
		await get_tree().process_frame
	var worst := 0.0
	var total := 0.0
	var frames := 0
	var phys_total := 0.0
	var phys_worst := 0.0
	for i in stations.size():
		teleport(players[0], i)
		for f in 200:
			await get_tree().process_frame
			players[0].yaw += 0.01
			var dt := get_process_delta_time()
			if f > 20:
				worst = maxf(worst, dt)
				total += dt
				frames += 1
				var ph := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
				phys_total += ph
				phys_worst = maxf(phys_worst, ph)
	print("BENCH avg %.2f ms (%.0f fps)  worst %.2f ms  over %d frames at %s" % [
		total / frames * 1000.0, frames / total, worst * 1000.0, frames, get_viewport().get_visible_rect().size])
	print("BENCH draw calls %d  objects %d  primitives %dk  process %.2f ms  physics %.2f ms" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	print("BENCH physics avg %.2f ms  worst %.2f ms" % [phys_total / frames, phys_worst])
	get_tree().quit()


## Dev tool: `-- --idle=/dir` stands still at the first station and saves a
## frame every 3 s for 36 s (catches problems that only appear over time).
func _idle_capture(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for i in 13:
		await get_tree().create_timer(3.0).timeout
		get_viewport().get_texture().get_image().save_png("%s/idle_%02d.png" % [dir, i])
		var p := players[0]
		print("IDLE %02d pos=%s vel=%s state=%s pitch=%.4f yaw=%.4f" % [i, p.global_position, p.velocity, p.motor.state_name(), p.pitch, p.yaw])
	get_tree().quit()


func _screenshot_tour(dir: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DirAccess.make_dir_recursive_absolute(dir)
	if OS.get_cmdline_user_args().has("--panel"):
		panel.toggle()
	if OS.get_cmdline_user_args().has("--third"):
		players[0].camera_rig.third_person = true
		_update_avatar_visibility()
	for i in stations.size():
		teleport(players[0], i)
		if (stations[i] as Array).size() < 4:
			players[0].pitch = deg_to_rad(8.0)
		for f in 45:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/station_%d.png" % [dir, i])
	get_tree().quit()


func _on_panel_toggled(open: bool) -> void:
	if open:
		_overlay_was_visible = overlay.visible
		overlay.visible = false
	else:
		overlay.visible = _overlay_was_visible


func spawn_player(router: InputRouter) -> Player:
	var view := split.add_view()
	var player := Player.new()
	add_child(player)
	player.setup(players.size(), router, tuning, view)
	var s: Array = stations[0]
	player.spawn(s[1], s[2])
	players.append(player)
	if course:
		course.add_player(player)
	return player


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"kb_menu") and not panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed(&"debug_third_person"):
		var rig := players[0].camera_rig
		rig.third_person = not rig.third_person
		_update_avatar_visibility()
	elif not panel.visible and (event.is_action_pressed(&"station_next") or _is_dpad(event, JOY_BUTTON_DPAD_RIGHT)):
		_cycle_station(1)
	elif not panel.visible and (event.is_action_pressed(&"station_prev") or _is_dpad(event, JOY_BUTTON_DPAD_LEFT)):
		_cycle_station(-1)


func _is_dpad(event: InputEvent, button: JoyButton) -> bool:
	return event is InputEventJoypadButton and event.pressed and event.button_index == button


func _cycle_station(step: int) -> void:
	_station = wrapi(_station + step, 0, stations.size())
	teleport(players[0], _station)
	players[0].hud.toast("%s   ([ / ] to change)" % stations[_station][0])


func teleport(player: Player, station: int) -> void:
	var s: Array = stations[station]
	if course:
		course.on_teleport(player)
	player.spawn(s[1], s[2])
	if s.size() > 3:
		player.pitch = s[3]


# --------------------------------------------------------------------------- level

# --------------------------------------------------------------------------- features

## Creates this level's course; add gates to it, then call course.finalize().
func make_course(id: String, title: String, par: float) -> Course:
	course = Course.new()
	add_child(course)
	course.setup(id, title, par)
	return course


func checkpoint(pos: Vector3, size: Vector3, yaw: float) -> void:
	var z := TriggerZone.create(self, TriggerZone.Kind.CHECKPOINT, pos + Vector3.UP * size.y * 0.5, size)
	z.spawn_position = pos
	z.spawn_yaw = yaw


func hazard(center: Vector3, size: Vector3) -> void:
	TriggerZone.create(self, TriggerZone.Kind.HAZARD, center, size)


func pad(pos: Vector3, launch: Vector3) -> void:
	_b.block(pos + Vector3(-2, 0, -2), pos + Vector3(2, 0.12, 2), T.BOOST)
	var z := TriggerZone.create(self, TriggerZone.Kind.JUMP_PAD, pos + Vector3.UP * 0.5, Vector3(4, 0.8, 4))
	z.launch_velocity = launch


func target(pos: Vector3, move: Vector3) -> void:
	var d := TargetDummy.new()
	d.move_axis = move
	d.position = pos  # before add_child: the dummy reads its home position on entering the tree
	add_child(d)


func _default_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.38, 0.6, 0.9)
	sky_mat.sky_horizon_color = Color(0.82, 0.88, 0.95)
	sky_mat.ground_horizon_color = Color(0.82, 0.88, 0.95)
	sky_mat.ground_bottom_color = Color(0.5, 0.55, 0.6)
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.85, 0.94)
	env.fog_density = 0.0025
	env.fog_aerial_perspective = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(-35.0), 0.0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 180.0
	add_child(sun)


## Dev tool: `-- --off=ssil,ssao,shadows,glow,fog,sdfgi` disables features to
## measure their cost with --bench.
func _apply_perf_flags() -> void:
	var off: PackedStringArray = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--off="):
			off = arg.substr(6).split(",")
	if off.is_empty():
		return
	for node in get_children():
		if node is WorldEnvironment:
			var env: Environment = node.environment
			env.ssil_enabled = env.ssil_enabled and not off.has("ssil")
			env.ssao_enabled = env.ssao_enabled and not off.has("ssao")
			env.glow_enabled = env.glow_enabled and not off.has("glow")
			env.fog_enabled = env.fog_enabled and not off.has("fog")
		elif node is DirectionalLight3D and off.has("shadows"):
			node.shadow_enabled = false


## Third-person bodies always animate: even when no camera sees them they cast
## their owner's shadow (the first-person body doesn't cast shadows).
func _update_avatar_visibility() -> void:
	for p in players:
		p.avatar.needed = true


func _apply_graphics() -> void:
	var env: Environment = null
	var sun: DirectionalLight3D = null
	for node in get_children():
		if node is WorldEnvironment:
			env = node.environment
		elif node is DirectionalLight3D and sun == null:
			sun = node
	Graphics.apply_to_level(env, sun, split.viewports())


func _load_or_new(path: String, type: GDScript) -> Resource:
	if ResourceLoader.exists(path):
		var res := load(path)
		if res and res.get_script() == type:
			return res
	return type.new()
