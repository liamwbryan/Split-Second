class_name TuningPanel
extends PanelContainer
## F1 / Tab: live sliders for every exported number on the given resources.
## "Save as default" writes them to res://tuning/ so tuned values land in the
## repo (only when running from the project, not an exported build).

signal visibility_toggled(open: bool)

const SAVE_PATHS := {
	"Movement": "res://tuning/movement_default.tres",
	"Player": "res://tuning/player_settings_default.tres",
	"Rifle": "res://scripts/weapons/rifle.tres",
}

var ui_scale: float = 1.0
var _targets: Dictionary = {}  # section name -> Resource
var _tabs: TabContainer
var _status: Label


func setup(targets: Dictionary, p_ui_scale: float = 1.0) -> void:
	_targets = targets
	ui_scale = p_ui_scale
	visible = false
	var t := Theme.new()
	t.default_font_size = int(14 * ui_scale)
	theme = t
	set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	custom_minimum_size = Vector2(460 * ui_scale, 0)
	offset_right = 460 * ui_scale
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.11, 0.92)
	bg.content_margin_left = 12
	bg.content_margin_right = 12
	bg.content_margin_top = 10
	bg.content_margin_bottom = 10
	add_theme_stylebox_override(&"panel", bg)

	var col := VBoxContainer.new()
	add_child(col)
	var title := Label.new()
	title.text = "Tuning  ( ` or Esc to close )"
	title.add_theme_font_size_override(&"font_size", int(18 * ui_scale))
	col.add_child(title)

	var buttons := HBoxContainer.new()
	col.add_child(buttons)
	var save := Button.new()
	save.text = "Save as default"
	save.pressed.connect(_save)
	buttons.add_child(save)
	var reset := Button.new()
	reset.text = "Reset tab to code defaults"
	reset.pressed.connect(_reset_current)
	buttons.add_child(reset)
	var gfx := Button.new()
	gfx.text = "Graphics: %s" % Graphics.quality_name()
	gfx.pressed.connect(func() -> void:
		Graphics.cycle_quality()
		gfx.text = "Graphics: %s" % Graphics.quality_name())
	buttons.add_child(gfx)
	_status = Label.new()
	_status.add_theme_font_size_override(&"font_size", int(12 * ui_scale))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_tabs)
	for section: String in _targets:
		_build_tab(section, _targets[section])


# _input (not _unhandled_input): a focused slider would otherwise swallow Tab
# for focus navigation and the panel could never close.
func _input(event: InputEvent) -> void:
	var close_key: bool = visible and event.is_action_pressed(&"kb_menu")
	var pad_toggle: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START
	if event.is_action_pressed(&"debug_panel") or close_key or pad_toggle:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var first := _find_focusable(_tabs.get_current_tab_control())
		if first:
			first.grab_focus()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	visibility_toggled.emit(visible)


func _build_tab(section: String, res: Resource) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = section
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var pending_header := ""
	for prop in res.get_property_list():
		var usage: int = prop.usage
		if usage & PROPERTY_USAGE_CATEGORY:
			continue
		if usage & PROPERTY_USAGE_GROUP:
			pending_header = prop.name
			continue
		if not (usage & PROPERTY_USAGE_EDITOR) or not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		if prop.type not in [TYPE_FLOAT, TYPE_INT, TYPE_BOOL]:
			continue
		if pending_header != "":
			# Headers only appear above script variables (skips built-in groups like "Resource").
			var header := Label.new()
			header.text = pending_header
			header.add_theme_color_override(&"font_color", Color(1.0, 0.55, 0.25))
			header.add_theme_font_size_override(&"font_size", int(15 * ui_scale))
			list.add_child(header)
			pending_header = ""
		if prop.type == TYPE_BOOL:
			list.add_child(_toggle_row(res, prop))
		elif prop.hint == PROPERTY_HINT_ENUM:
			list.add_child(_enum_row(res, prop))
		else:
			list.add_child(_slider_row(res, prop))


func _slider_row(res: Resource, prop: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = String(prop.name).replace("_", " ")
	name_label.custom_minimum_size.x = 200 * ui_scale
	name_label.add_theme_font_size_override(&"font_size", int(13 * ui_scale))
	name_label.clip_text = true
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 150 * ui_scale
	var range_parts := String(prop.hint_string).split(",")
	if prop.hint == PROPERTY_HINT_RANGE and range_parts.size() >= 2:
		slider.min_value = float(range_parts[0])
		slider.max_value = float(range_parts[1])
		slider.step = float(range_parts[2]) if range_parts.size() >= 3 else 0.01
	else:
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0 if prop.type == TYPE_INT else 0.01
	slider.value = res.get(prop.name)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 56 * ui_scale
	value_label.add_theme_font_size_override(&"font_size", int(13 * ui_scale))
	value_label.text = _fmt(slider.value, prop.type)
	slider.value_changed.connect(func(v: float) -> void:
		res.set(prop.name, int(v) if prop.type == TYPE_INT else v)
		value_label.text = _fmt(v, prop.type))
	row.add_child(slider)
	row.add_child(value_label)
	return row


## Dropdown for enum settings (hint_string "Name:0,Other:1,...").
func _enum_row(res: Resource, prop: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = String(prop.name).replace("_", " ")
	name_label.custom_minimum_size.x = 200 * ui_scale
	name_label.add_theme_font_size_override(&"font_size", int(13 * ui_scale))
	row.add_child(name_label)
	var pick := OptionButton.new()
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.add_theme_font_size_override(&"font_size", int(13 * ui_scale))
	var next_value := 0
	for entry in String(prop.hint_string).split(","):
		var parts := entry.split(":")
		var value := int(parts[1]) if parts.size() > 1 else next_value
		pick.add_item(parts[0].capitalize(), value)
		next_value = value + 1
	pick.select(pick.get_item_index(res.get(prop.name)))
	pick.item_selected.connect(func(i: int) -> void: res.set(prop.name, pick.get_item_id(i)))
	row.add_child(pick)
	return row


func _toggle_row(res: Resource, prop: Dictionary) -> Control:
	var check := CheckBox.new()
	check.text = String(prop.name).replace("_", " ")
	check.button_pressed = res.get(prop.name)
	check.toggled.connect(func(on: bool) -> void: res.set(prop.name, on))
	return check


func _fmt(v: float, type: int) -> String:
	return str(int(v)) if type == TYPE_INT else ("%.4f" % v if absf(v) < 0.01 and v != 0.0 else "%.2f" % v)


func _save() -> void:
	if OS.has_feature("template"):
		_status.text = "Saving defaults only works when running from the project."
		return
	var saved: PackedStringArray = []
	for section: String in _targets:
		var path: String = SAVE_PATHS.get(section, "")
		if path.is_empty():
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var err := ResourceSaver.save(_targets[section], path)
		saved.append("%s %s" % [section, "ok" if err == OK else "FAILED (%d)" % err])
	_status.text = "Saved: " + ", ".join(saved)


func _reset_current() -> void:
	var section := _tabs.get_current_tab_control().name
	var res: Resource = _targets[section]
	var fresh: Resource = res.get_script().new()
	for prop in fresh.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			res.set(prop.name, fresh.get(prop.name))
	var idx := _tabs.current_tab
	var old := _tabs.get_current_tab_control()
	_tabs.remove_child(old)
	old.queue_free()
	_build_tab(section, res)
	_tabs.move_child(_tabs.get_child(_tabs.get_child_count() - 1), idx)
	_tabs.current_tab = idx
	_status.text = "%s reset to code defaults (not saved)." % section


func _find_focusable(node: Node) -> Control:
	if node == null:
		return null
	for child in node.get_children():
		if child is Control and (child as Control).focus_mode != Control.FOCUS_NONE and (child is Range or child is BaseButton):
			return child
		var found := _find_focusable(child)
		if found:
			return found
	return null
