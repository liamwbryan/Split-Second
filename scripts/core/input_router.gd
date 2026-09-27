class_name InputRouter
extends RefCounted
## Per-player input. Gameplay reads input only through a router, never the
## global Input singleton, so 1-4 local players stay independent.
##
## Buttons are latched from events (so taps shorter than a physics tick are
## never lost) and also polled (for triggers, which have no button events).
## Call tick() once at the start of each physics step.

## SWAP = next weapon, SWAP_PREV = previous, SLOT1-3 = pick a slot directly.
enum Action { JUMP, CROUCH, SPRINT, GRAPPLE, FIRE, ADS, RELOAD, MELEE, SWAP, RESET, MENU, SLOT1, SLOT2, SLOT3, SWAP_PREV }
const ACTION_COUNT := 15

## Keyboard/mouse action names defined by InputHub, indexed by Action.
const KB_ACTIONS: Array = [
	[&"kb_jump"], [&"kb_crouch"], [&"kb_sprint"], [&"kb_grapple"],
	[&"kb_fire"], [&"kb_ads"], [&"kb_reload"], [&"kb_melee"], [&"kb_swap"],
	[&"kb_reset"], [&"kb_menu"], [&"kb_slot1"], [&"kb_slot2"], [&"kb_slot3"], [&"kb_swap_prev"],
]

## Xbox layout (Titanfall-style). -1 = not a face/shoulder button.
const PAD_BUTTONS: Array[int] = [
	JOY_BUTTON_A,              # JUMP
	JOY_BUTTON_B,              # CROUCH / slide
	JOY_BUTTON_LEFT_STICK,     # SPRINT
	JOY_BUTTON_LEFT_SHOULDER,  # GRAPPLE
	-1,                        # FIRE  (right trigger)
	-1,                        # ADS   (left trigger)
	JOY_BUTTON_X,              # RELOAD
	JOY_BUTTON_RIGHT_STICK,    # MELEE (quick melee)
	JOY_BUTTON_Y,              # SWAP (next weapon: primary → secondary → blade)
	JOY_BUTTON_BACK,           # RESET (View)
	JOY_BUTTON_START,          # MENU
	-1,                        # SLOT1 (keyboard only)
	-1,                        # SLOT2
	-1,                        # SLOT3
	-1,                        # SWAP_PREV (mouse wheel up)
]

const TRIGGER_PRESS := 0.45
const TRIGGER_RELEASE := 0.3

var use_kbm: bool = true
## Pads owned by this player. With accept_any_pad, every connected pad drives it.
var pads: Array[int] = []
var accept_any_pad: bool = false
var settings: PlayerSettings

## Scripted input for automated tests: when true, devices are ignored.
var scripted: bool = false
var scripted_move: Vector2 = Vector2.ZERO
var scripted_held: Array[bool] = []
var scripted_look: Vector2 = Vector2.ZERO   ## raw right stick, -1..1
var scripted_mouse: Vector2 = Vector2.ZERO  ## mouse pixels per consume_look()

## The stick's share of the last consume_look() (radians, after invert) and
## its curved deflection 0..1. Aim assist reads and scales only this part, so
## mouse aim is never assisted.
var last_stick_look: Vector2 = Vector2.ZERO
var last_stick_mag: float = 0.0

var last_device_was_pad: bool = false

var _held: Array[bool] = []
var _prev_held: Array[bool] = []
var _latched: Array[bool] = []
var _pressed: Array[bool] = []
var _released: Array[bool] = []
var _press_time: Array[float] = []  # seconds, from _clock
var _clock: float = 0.0
var _mouse_delta: Vector2 = Vector2.ZERO
var _edge_hold_time: float = 0.0
var _trigger_state: Array[bool] = [false, false]  # RT, LT hysteresis


func _init(p_settings: PlayerSettings = null) -> void:
	settings = p_settings if p_settings else PlayerSettings.new()
	for i in ACTION_COUNT:
		_held.append(false)
		_prev_held.append(false)
		_latched.append(false)
		_pressed.append(false)
		_released.append(false)
		_press_time.append(-INF)
		scripted_held.append(false)


func owns_pad(device: int) -> bool:
	return accept_any_pad or pads.has(device)


## Called by InputHub for every input event.
func handle_event(event: InputEvent) -> void:
	if scripted:
		return
	if event is InputEventJoypadButton:
		if not owns_pad(event.device):
			return
		last_device_was_pad = true
		if event.pressed:
			var idx := PAD_BUTTONS.find(event.button_index)
			if idx >= 0:
				_latched[idx] = true
		return
	if event is InputEventJoypadMotion:
		if owns_pad(event.device) and absf(event.axis_value) > 0.5:
			last_device_was_pad = true
		return
	if not use_kbm:
		return
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_mouse_delta += event.screen_relative
			last_device_was_pad = false
		return
	if event is InputEventKey or event is InputEventMouseButton:
		if not event.is_pressed() or event.is_echo():
			return
		last_device_was_pad = false
		for i in ACTION_COUNT:
			for action: StringName in KB_ACTIONS[i]:
				if event.is_action(action):
					_latched[i] = true


## Advance one physics step. Computes held/pressed/released edges.
func tick(delta: float) -> void:
	_clock += delta
	for i in ACTION_COUNT:
		_prev_held[i] = _held[i]
		_held[i] = _poll_held(i)
		var pressed := _latched[i] or (_held[i] and not _prev_held[i])
		_pressed[i] = pressed
		_released[i] = _prev_held[i] and not _held[i]
		_latched[i] = false
		if pressed:
			_press_time[i] = _clock


func is_held(action: int) -> bool:
	return _held[action]


func just_pressed(action: int) -> bool:
	return _pressed[action]


func just_released(action: int) -> bool:
	return _released[action]


## True if the action was pressed within `window` seconds and not consumed.
## This is the input buffer: presses slightly early still count.
func buffered(action: int, window: float) -> bool:
	return _clock - _press_time[action] <= window


func consume(action: int) -> void:
	_press_time[action] = -INF
	_pressed[action] = false


func time_held(action: int) -> float:
	return _clock - _press_time[action] if _held[action] else 0.0


## x = strafe right, y = forward. Length <= 1.
func move_vector() -> Vector2:
	if scripted:
		return scripted_move.limit_length(1.0)
	var v := Vector2.ZERO
	if use_kbm:
		v.x = Input.get_action_strength(&"kb_right") - Input.get_action_strength(&"kb_left")
		v.y = Input.get_action_strength(&"kb_forward") - Input.get_action_strength(&"kb_back")
		v = v.limit_length(1.0)
	for device in _active_pads():
		var stick := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), -Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		stick = _radial_deadzone(stick, settings.pad_move_deadzone, settings.pad_outer_deadzone)
		if stick.length() > v.length():
			v = stick
	return v


## Look delta in radians (x = yaw right, y = pitch down) for this render frame.
## Mouse is raw (no smoothing); stick uses a response curve and edge boost.
## The stick's share is also left in last_stick_look / last_stick_mag, the only
## part aim assist may touch.
func consume_look(delta: float) -> Vector2:
	var mouse := scripted_mouse
	var stick := scripted_look
	if not scripted:
		mouse = _mouse_delta
		_mouse_delta = Vector2.ZERO
		stick = Vector2.ZERO
		for device in _active_pads():
			var s := Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
			if s.length() > stick.length():
				stick = s
	var look := mouse * settings.mouse_sensitivity
	var stick_look := Vector2.ZERO
	stick = _radial_deadzone(stick, settings.pad_inner_deadzone, settings.pad_outer_deadzone)
	var mag := stick.length()
	last_stick_mag = 0.0
	if mag > 0.0:
		var curved := pow(mag, settings.pad_response_curve)
		last_stick_mag = curved
		stick = stick / mag * curved
		# Holding the stick at the edge ramps up yaw so fast turns are possible
		# without making fine aim twitchy.
		if absf(stick.x) > 0.97:
			_edge_hold_time += delta
		else:
			_edge_hold_time = 0.0
		var ramp := clampf((_edge_hold_time - settings.pad_edge_boost_delay) / maxf(settings.pad_edge_boost_ramp, 0.001), 0.0, 1.0)
		var yaw_mult := lerpf(1.0, settings.pad_edge_yaw_boost, ramp)
		stick_look.x = stick.x * deg_to_rad(settings.pad_yaw_speed) * yaw_mult * delta
		stick_look.y = stick.y * deg_to_rad(settings.pad_pitch_speed) * delta
	else:
		_edge_hold_time = 0.0
	if settings.invert_y:
		look.y = -look.y
		stick_look.y = -stick_look.y
	last_stick_look = stick_look
	return look + stick_look


func _poll_held(action: int) -> bool:
	if scripted:
		return scripted_held[action]
	if use_kbm:
		for kb_action: StringName in KB_ACTIONS[action]:
			if Input.is_action_pressed(kb_action):
				return true
	var button := PAD_BUTTONS[action]
	for device in _active_pads():
		if button >= 0:
			if Input.is_joy_button_pressed(device, button):
				return true
		elif action == Action.FIRE or action == Action.ADS:
			var axis := JOY_AXIS_TRIGGER_RIGHT if action == Action.FIRE else JOY_AXIS_TRIGGER_LEFT
			var t := 0 if action == Action.FIRE else 1
			var value := Input.get_joy_axis(device, axis)
			var threshold := TRIGGER_RELEASE if _trigger_state[t] else TRIGGER_PRESS
			_trigger_state[t] = value > threshold
			if _trigger_state[t]:
				return true
	return false


func _active_pads() -> Array[int]:
	if accept_any_pad:
		return Input.get_connected_joypads()
	return pads


static func _radial_deadzone(v: Vector2, inner: float, outer: float) -> Vector2:
	var mag := v.length()
	if mag <= inner:
		return Vector2.ZERO
	var scaled := clampf((mag - inner) / maxf(outer - inner, 0.001), 0.0, 1.0)
	return v / mag * scaled
