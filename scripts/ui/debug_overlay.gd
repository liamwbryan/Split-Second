class_name DebugOverlay
extends Label
## F2: movement readout for playtesting (state, speeds, flags, pads, fps).

var player: Player


func setup(p_player: Player, ui_scale: float = 1.0) -> void:
	player = p_player
	position = Vector2(16, 12) * ui_scale
	add_theme_font_size_override(&"font_size", int(15 * ui_scale))
	add_theme_color_override(&"font_color", Color(1, 1, 1, 0.95))
	add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.7))
	add_theme_constant_override(&"shadow_offset_x", 1)
	add_theme_constant_override(&"shadow_offset_y", 1)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay"):
		visible = not visible


func _process(_delta: float) -> void:
	if not visible or player == null:
		return
	var m := player.motor
	var v := player.velocity
	text = "\n".join([
		"%d fps  |  %.2f ms" % [Engine.get_frames_per_second(), 1000.0 / maxf(Engine.get_frames_per_second(), 1.0)],
		"state   %s  (%.2fs)" % [m.state_name(), m.state_time],
		"speed   %.1f m/s  (%d km/h)   vy %.1f" % [player.horizontal_speed(), roundi(player.horizontal_speed() * 3.6), v.y],
		"dbl jump %s   grapple %s   crouch %s" % [
			"ready" if m.double_jump_ready else "-",
			"ready" if m.grapple_cooldown_left <= 0.0 else "%.1fs" % m.grapple_cooldown_left,
			"yes" if m.crouched else "no"],
		("flow    %.2f   soft cap %.1f m/s" % [m.flow, m.soft_speed_cap()]) if player.tuning.momentum_enabled else "flow    off (Movement tab: momentum_enabled)",
		"pads    %s" % InputHub.pad_summary(),
		"Esc  menu   `  tuning   O  this readout   T  restart   [ ]  stations   (pad: Start menu, View restart, D-pad stations)",
	])
