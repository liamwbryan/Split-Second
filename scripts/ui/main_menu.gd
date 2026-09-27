extends Control
## Title screen / level select. Keyboard, mouse and gamepad navigable.

const LEVELS := [
	["Spiral", "res://scenes/spiral.tscn", "Spiral Run: a sky garage 300 m up an arcology. Slide the Express."],
	["Pendulum Hall", "res://scenes/pendulum_hall.tscn", "Pendulum Run: a sky museum with a 90 m pendulum slingshot. (First pass)"],
	["Rooftops", "res://scenes/rooftops.tscn", "Rooftops Run time trial: city rooftops, crane, billboard, lift."],
	["Movement Gym", "res://scenes/gym.tscn", "One station per move, plus a shooting range."],
]

var _first: Button


func _ready() -> void:
	# `-- --level=rooftops` skips the menu (exported builds can't take a scene
	# path; used to time level loads and for quick tests).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			var want := arg.substr(8).to_lower()
			for level in LEVELS:
				if String(level[0]).to_lower().begins_with(want):
					get_tree().change_scene_to_file.call_deferred(level[1])
					return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	OS.low_processor_usage_mode = true  # static menu: only redraw when something changes
	tree_exiting.connect(func() -> void: OS.low_processor_usage_mode = false)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ui := clampf(DisplayServer.window_get_size().y / 1080.0, 1.0, 3.0)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var stripe := ColorRect.new()
	stripe.color = Color(0.95, 0.33, 0.16)
	stripe.position = Vector2(0, 0)
	stripe.size = Vector2(12 * ui, 4000)
	add_child(stripe)

	var col := VBoxContainer.new()
	col.position = Vector2(120, 140) * ui
	col.add_theme_constant_override(&"separation", int(14 * ui))
	add_child(col)
	var title := Label.new()
	title.text = "SPLIT SECOND"
	title.add_theme_font_size_override(&"font_size", int(72 * ui))
	col.add_child(title)
	var sub := Label.new()
	sub.text = "a parkour shooter  ·  milestone build"
	sub.add_theme_font_size_override(&"font_size", int(20 * ui))
	sub.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.5))
	col.add_child(sub)
	col.add_child(Control.new())

	for level in LEVELS:
		var btn := Button.new()
		btn.text = "  %s  —  %s" % [level[0], level[2]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override(&"font_size", int(28 * ui))
		btn.custom_minimum_size = Vector2(900, 64) * ui
		btn.pressed.connect(func() -> void: get_tree().change_scene_to_file(level[1]))
		col.add_child(btn)
		if _first == null:
			_first = btn
	var quit := Button.new()
	quit.text = "  Quit"
	quit.alignment = HORIZONTAL_ALIGNMENT_LEFT
	quit.add_theme_font_size_override(&"font_size", int(28 * ui))
	quit.custom_minimum_size = Vector2(900, 64) * ui
	quit.pressed.connect(func() -> void: get_tree().quit())
	col.add_child(quit)
	_first.grab_focus()
