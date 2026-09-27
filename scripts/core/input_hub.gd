extends Node
## Autoload. Defines keyboard/mouse bindings, forwards raw events to every
## registered InputRouter, and tracks gamepad connections.

signal pads_changed

var _routers: Array[InputRouter] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_define_keyboard_actions()
	Input.joy_connection_changed.connect(func(_d: int, _c: bool) -> void: pads_changed.emit())


func register(router: InputRouter) -> void:
	if not _routers.has(router):
		_routers.append(router)


func unregister(router: InputRouter) -> void:
	_routers.erase(router)


func _input(event: InputEvent) -> void:
	for router in _routers:
		router.handle_event(event)


func pad_summary() -> String:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return "no pads"
	var parts: PackedStringArray = []
	for d in pads:
		parts.append("%d:%s" % [d, Input.get_joy_name(d)])
	return ", ".join(parts)


func _define_keyboard_actions() -> void:
	# Physical keycodes so bindings follow key position on any layout (AZERTY etc.).
	# Titanfall 2 / Apex PC conventions.
	var keys := {
		&"kb_forward": [KEY_W],
		&"kb_back": [KEY_S],
		&"kb_left": [KEY_A],
		&"kb_right": [KEY_D],
		&"kb_jump": [KEY_SPACE],
		&"kb_crouch": [KEY_CTRL, KEY_C],   # hold to slide/crouch, release to stand
		&"kb_sprint": [KEY_SHIFT],
		&"kb_grapple": [KEY_Q],            # tactical ability
		&"kb_reload": [KEY_R],
		&"kb_melee": [KEY_V],
		&"kb_swap": [KEY_1, KEY_2],
		&"kb_reset": [KEY_T],
		&"kb_menu": [KEY_ESCAPE],
		&"debug_panel": [KEY_QUOTELEFT],   # ` like the Source dev console
		&"debug_overlay": [KEY_O],
		&"debug_third_person": [KEY_P],
		&"station_prev": [KEY_BRACKETLEFT],
		&"station_next": [KEY_BRACKETRIGHT],
	}
	for action: StringName in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for code: Key in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)
	var mouse := {
		&"kb_fire": MOUSE_BUTTON_LEFT,
		&"kb_ads": MOUSE_BUTTON_RIGHT,
		&"kb_swap": MOUSE_BUTTON_WHEEL_UP,
	}
	for action: StringName in mouse:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		var mev := InputEventMouseButton.new()
		mev.button_index = mouse[action]
		InputMap.action_add_event(action, mev)
	var extra := {
		&"kb_grapple": [MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2],
		&"kb_swap": [MOUSE_BUTTON_WHEEL_DOWN],
	}
	for action: StringName in extra:
		for button: MouseButton in extra[action]:
			var ev := InputEventMouseButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)
