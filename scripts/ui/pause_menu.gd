class_name PauseMenu
extends Control
## In-map pause menu: Esc or pad Start opens it (and pauses the game, course
## clock included); Esc, Start or pad B resumes. Keyboard, mouse and pad
## navigable. The level wires the actions through the signals.

signal resumed
signal restart_requested
signal tuning_requested
signal main_menu_requested
signal quit_requested

var _first: Button
var _gfx: Button


func setup(ui_scale: float) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # it has to work while the tree is paused
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var stripe := ColorRect.new()
	stripe.color = Color(0.95, 0.33, 0.16)
	stripe.size = Vector2(10 * ui_scale, 4000)
	add_child(stripe)

	var col := VBoxContainer.new()
	col.position = Vector2(110, 150) * ui_scale
	col.add_theme_constant_override(&"separation", int(12 * ui_scale))
	add_child(col)
	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override(&"font_size", int(56 * ui_scale))
	col.add_child(title)
	var sub := Label.new()
	sub.text = "Split Second"
	sub.add_theme_font_size_override(&"font_size", int(18 * ui_scale))
	sub.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.5))
	col.add_child(sub)
	col.add_child(Control.new())

	_first = _button(col, "Resume", ui_scale, func() -> void: close())
	_button(col, "Restart run", ui_scale, func() -> void:
		close()
		restart_requested.emit())
	_button(col, "Tuning panel", ui_scale, func() -> void:
		close()
		tuning_requested.emit())
	_gfx = _button(col, "", ui_scale, func() -> void:
		Graphics.cycle_quality()
		_refresh())
	_button(col, "Main menu", ui_scale, func() -> void:
		get_tree().paused = false
		main_menu_requested.emit())
	_button(col, "Quit to desktop", ui_scale, func() -> void: quit_requested.emit())
	var hint := Label.new()
	hint.text = "Esc / Start / B to resume"
	hint.add_theme_font_size_override(&"font_size", int(16 * ui_scale))
	hint.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.45))
	col.add_child(hint)
	_refresh()


func open() -> void:
	if visible:
		return
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	_first.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resumed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var start: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START
	if event.is_action_pressed(&"kb_menu") or event.is_action_pressed(&"ui_cancel") or start:
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if _gfx:
		_gfx.text = "  Graphics: %s" % Graphics.quality_name()


func _button(parent: Control, text: String, ui_scale: float, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = "  " + text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override(&"font_size", int(28 * ui_scale))
	b.custom_minimum_size = Vector2(520, 58) * ui_scale
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b
