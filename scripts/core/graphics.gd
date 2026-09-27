extends Node
## Autoload. Quality presets and frame pacing, applied on top of each map's
## authored look so the game scales from integrated GPUs to high-end PCs.
## Persists to user://graphics.cfg. Maps describe their ideal look; this
## decides how much of it the machine pays for.

signal changed

enum Quality { LOW, MEDIUM, HIGH, ULTRA }
const QUALITY_NAMES: Array[String] = ["Low", "Medium", "High", "Ultra"]
const SAVE_PATH := "user://graphics.cfg"
const UNFOCUSED_FPS := 30

var quality: Quality = Quality.MEDIUM
var vsync: bool = true
var max_fps: int = 0  ## 0 = uncapped (vsync still applies)
var render_scale_override: float = 0.0  ## 0 = automatic

var _focused: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	apply_frame_pacing()


func _notification(what: int) -> void:
	# Don't burn CPU/GPU (or a laptop's battery) while alt-tabbed.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		apply_frame_pacing()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true
		apply_frame_pacing()


func set_quality(q: Quality) -> void:
	quality = q
	_save()
	changed.emit()


func cycle_quality() -> void:
	set_quality(((quality + 1) % QUALITY_NAMES.size()) as Quality)


func quality_name() -> String:
	return QUALITY_NAMES[quality]


## Applies the preset to a level's environment, sun and player viewports.
func apply_to_level(env: Environment, sun: DirectionalLight3D, viewports: Array[SubViewport]) -> void:
	RenderingServer.global_shader_parameter_set(&"surface_detail", 0.0 if quality == Quality.LOW else 1.0)
	if env:
		# Remember what the map asked for, so presets can go down *and* back up.
		if not env.has_meta(&"authored"):
			env.set_meta(&"authored", {
				"ssil": env.ssil_enabled, "ssao": env.ssao_enabled,
				"vfog": env.volumetric_fog_enabled, "glow": env.glow_enabled,
			})
		var a: Dictionary = env.get_meta(&"authored")
		env.ssil_enabled = a.ssil and quality >= Quality.ULTRA
		env.ssao_enabled = a.ssao and quality >= Quality.MEDIUM
		env.sdfgi_enabled = false
		env.volumetric_fog_enabled = a.vfog and quality >= Quality.HIGH
		env.glow_enabled = a.glow and quality >= Quality.MEDIUM
	RenderingServer.environment_set_ssao_quality(
		RenderingServer.ENV_SSAO_QUALITY_MEDIUM if quality >= Quality.HIGH else RenderingServer.ENV_SSAO_QUALITY_LOW,
		quality < Quality.HIGH, 0.5, 2, 50.0, 300.0)
	if sun:
		# Shadow texels are spent near the player (short distance, first split
		# small) so edges stay crisp and don't crawl as you move.
		sun.directional_shadow_blend_splits = quality >= Quality.MEDIUM
		match quality:
			Quality.LOW:
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
				sun.directional_shadow_max_distance = 50.0
			Quality.MEDIUM:
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
				sun.directional_shadow_max_distance = 80.0
				sun.directional_shadow_split_1 = 0.25
			_:
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
				sun.directional_shadow_max_distance = 160.0
				sun.directional_shadow_split_1 = 0.08
				sun.directional_shadow_split_2 = 0.25
				sun.directional_shadow_split_3 = 0.55
	var atlas := 2048 if quality == Quality.LOW else 4096
	RenderingServer.directional_shadow_atlas_set_size(atlas, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW if quality == Quality.LOW else
		(RenderingServer.SHADOW_QUALITY_SOFT_LOW if quality == Quality.MEDIUM else RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM))
	for vp in viewports:
		apply_to_viewport(vp, viewports.size())


func apply_to_viewport(vp: SubViewport, view_count: int) -> void:
	vp.msaa_3d = Viewport.MSAA_DISABLED if quality == Quality.LOW else Viewport.MSAA_2X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if quality == Quality.LOW else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	vp.scaling_3d_scale = render_scale(view_count)
	vp.fsr_sharpness = 0.3
	vp.positional_shadow_atlas_size = 1024 if quality <= Quality.MEDIUM else 2048


## 3D resolution per view. Automatic mode targets a pixel budget per quality
## (split-screen shares it), so 4K/Retina displays upscale with FSR.
func render_scale(view_count: int = 1) -> float:
	if render_scale_override > 0.0:
		return render_scale_override
	var budget: float = [1280.0 * 720.0, 1920.0 * 1080.0, 2560.0 * 1440.0, 3840.0 * 2160.0][quality]
	var px := DisplayServer.window_get_size()
	var pixels := float(px.x * px.y)
	return clampf(sqrt(budget / maxf(pixels, 1.0)), 0.5, 1.0)


func apply_frame_pacing() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = UNFOCUSED_FPS if not _focused else max_fps


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	quality = clampi(cfg.get_value("graphics", "quality", quality), 0, 3) as Quality
	vsync = cfg.get_value("graphics", "vsync", vsync)
	max_fps = cfg.get_value("graphics", "max_fps", max_fps)
	render_scale_override = cfg.get_value("graphics", "render_scale", render_scale_override)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "quality", quality)
	cfg.set_value("graphics", "vsync", vsync)
	cfg.set_value("graphics", "max_fps", max_fps)
	cfg.set_value("graphics", "render_scale", render_scale_override)
	cfg.save(SAVE_PATH)
