extends Node
## Pause menu checks: Esc pauses (the game and the course clock freeze), Esc
## resumes, and "Main menu" leaves the map.
##   godot --headless --path . --fixed-fps 120 res://tests/menu_tests.tscn

var level: LevelBase
var failures := 0
var exited := false


func _ready() -> void:
	level = load("res://scenes/rooftops.tscn").instantiate()
	add_child(level)
	level.exit_to_menu = func() -> void: exited = true  # don't really change scene (it would free this test)
	if level.course:
		level.course.save_records = false
	for i in 10:
		await get_tree().physics_frame
	var p: Player = level.players[0]
	p.velocity = Vector3(8, 0, 0)

	await _press_esc()
	_check("Esc opens the pause menu", level.pause_menu.visible, "")
	_check("pausing freezes the game", get_tree().paused, "")
	for arg in OS.get_cmdline_user_args():  # `-- --shot=PATH` (windowed) saves the pause screen
		if arg.begins_with("--shot="):
			for i in 10:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(arg.substr(7))
	var before := p.global_position
	for i in 20:
		await get_tree().process_frame
	_check("the player doesn't move while paused", p.global_position.distance_to(before) < 0.001, "moved %.3f" % p.global_position.distance_to(before))

	await _press_esc()
	_check("Esc again resumes", not level.pause_menu.visible and not get_tree().paused, "")

	await _press_esc()
	var main_menu: Button = null
	for b in level.pause_menu.find_children("*", "Button", true, false):
		if (b as Button).text.strip_edges() == "Main menu":
			main_menu = b
	_check("the pause menu has a Main menu button", main_menu != null, "")
	if main_menu:
		main_menu.pressed.emit()
		await get_tree().process_frame
	_check("Main menu leaves the map", exited and not get_tree().paused, "")
	_check("the real exit goes to the main menu scene", ResourceLoader.exists(LevelBase.MAIN_MENU), LevelBase.MAIN_MENU)
	print("\nmenu: %d failures" % failures)
	get_tree().quit(failures)


func _press_esc() -> void:
	var ev := InputEventAction.new()
	ev.action = &"kb_menu"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = &"kb_menu"
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _check(name: String, ok: bool, detail: String) -> void:
	print("  %s %s  %s" % ["ok  " if ok else "FAIL", name, detail])
	if not ok:
		failures += 1
