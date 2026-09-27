class_name SplitScreen
extends Control
## One SubViewport per local player, laid out for 1-4 players. All viewports
## share the level's World3D; each holds its player's camera and HUD.

var _containers: Array[SubViewportContainer] = []
var _viewports: Array[SubViewport] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)


func add_view() -> SubViewport:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var vp := SubViewport.new()
	vp.use_debanding = true
	vp.audio_listener_enable_3d = _viewports.is_empty()
	container.add_child(vp)
	_containers.append(container)
	_viewports.append(vp)
	for v in _viewports:
		Graphics.apply_to_viewport(v, _viewports.size())
	_layout()
	return vp


func viewports() -> Array[SubViewport]:
	return _viewports


func view_count() -> int:
	return _viewports.size()


func _layout() -> void:
	var n := _containers.size()
	var s := size
	var rects: Array[Rect2] = []
	match n:
		1:
			rects = [Rect2(Vector2.ZERO, s)]
		2:
			# Top/bottom keeps the full horizontal field of view for both players.
			rects = [Rect2(0, 0, s.x, s.y / 2), Rect2(0, s.y / 2, s.x, s.y / 2)]
		3:
			rects = [Rect2(0, 0, s.x, s.y / 2), Rect2(0, s.y / 2, s.x / 2, s.y / 2), Rect2(s.x / 2, s.y / 2, s.x / 2, s.y / 2)]
		_:
			for i in n:
				rects.append(Rect2((i % 2) * s.x / 2, (i / 2) * s.y / 2, s.x / 2, s.y / 2))
	for i in n:
		_containers[i].position = rects[i].position
		_containers[i].size = rects[i].size
