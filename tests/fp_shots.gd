extends "res://tests/movement_tests.gd"
## Dev tool: renders the first-person view at key traversal moments so arm and
## weapon animation can be checked without playing.
##   godot --path . res://tests/fp_shots.tscn -- --out=/some/dir [--only=name]

var out_dir := "/tmp/fp_shots"
var vp: SubViewport


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg.begins_with("--only="):
			only = arg.substr(7)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.7, 0.82)
	env.ambient_light_color = Color(0.7, 0.72, 0.75)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-30), 0)
	sun.shadow_enabled = true
	add_child(sun)
	b = LevelBuilder.new(self)
	_build_course()
	b.finalize()
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	# Show what's being captured (otherwise the window is an empty gray screen).
	var layer := CanvasLayer.new()
	add_child(layer)
	var view := TextureRect.new()
	view.texture = vp.get_texture()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.add_child(view)
	router = InputRouter.new(PlayerSettings.new())
	router.scripted = true
	router.use_kbm = false
	player = Player.new()
	add_child(player)
	player.setup(0, router, MovementTuning.new(), vp)
	player.motor.state_changed.connect(func(_f: int, to: int) -> void: states_seen.append(to))
	await _capture_all()
	get_tree().quit()


func shot(name: String) -> void:
	if only != "" and not name.begins_with(only):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	vp.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("SHOT ", name, " state=", player.motor.state_name())


func wait_state(state: int, extra: float, timeout: float = 3.0) -> bool:
	var t := 0.0
	while player.motor.state != state and t < timeout:
		await get_tree().physics_frame
		t += 1.0 / 120.0
	if player.motor.state != state:
		return false
	await seconds(extra)
	return true


func _capture_all() -> void:
	await reset(Vector3(0, 0, 20))
	await seconds(0.3)
	await shot("01_idle")
	player.pitch = deg_to_rad(-60)
	await seconds(0.2)
	await shot("02_look_down")
	player.pitch = 0.0

	await reset(Vector3(20, 0, 0))
	router.scripted_move = Vector2(0, 1)
	await seconds(0.7)
	await shot("03_sprint")
	hold(A.CROUCH)
	await seconds(0.25)
	await shot("04_slide")
	player.pitch = deg_to_rad(-35)
	await seconds(0.05)
	await shot("05_slide_look_down")
	player.pitch = 0.0
	hold(A.CROUCH, false)

	await reset(Vector3(400, 0, 0))
	router.scripted_move = Vector2(0, 1)
	if await wait_state(S.MANTLE, 0.08):
		await shot("06_vault")

	await reset(Vector3(300, 0, 0))
	router.scripted_move = Vector2(0, 1)
	await ticks(10)
	await tap(A.JUMP)
	if await wait_state(S.MANTLE, 0.08):
		await shot("07_mantle")

	await reset(Vector3(200, 0, 0))
	router.scripted_move = Vector2(0, 1)
	await seconds(0.12)
	await tap(A.JUMP)
	if await wait_state(S.WALLCLIMB, 0.2):
		await shot("08_climb")

	await reset(Vector3(1198.3, 0, -1))
	router.scripted_move = Vector2(-0.3, 1)
	await seconds(0.25)
	await tap(A.JUMP)
	router.scripted_move = Vector2(0, 1)
	if await wait_state(S.WALLRUN, 0.35):
		await shot("09_wallrun_left")

	await reset(Vector3(600, 0, 0))
	player.pitch = atan2(10.0 - player.tuning.eye_height, 20.0)
	hold(A.GRAPPLE)
	await seconds(0.3)
	await shot("10_grapple")
	hold(A.GRAPPLE, false)
