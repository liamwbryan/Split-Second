class_name SurfaceMaterials
extends RefCounted
## One ShaderMaterial per surface kind, created once and shared by every level
## (materials are the unit of batching, so fewer = fewer draw calls).

const TEX := "res://assets/textures/%s/%s_%s_1k.jpg"

## Average albedo luminance, measured offline (see docs): gain = 1 / mean,
## capped so dark textures don't turn noisy.
const MEAN_LUM := {
	"white_plaster_02": 0.502, "concrete_wall_008": 0.496, "tarred_gravel": 0.213,
	"bitumen": 0.201, "metal_plate": 0.187, "concrete_tiles": 0.175,
}

## kind -> [side texture, top texture, side repeats/m, top repeats/m, detail]
const SETS := {
	LevelBuilder.Kind.PAINT: ["white_plaster_02", "white_plaster_02", 0.33, 0.33, 0.15],  # low detail: route colors stay vivid
	LevelBuilder.Kind.CONCRETE: ["concrete_wall_008", "concrete_tiles", 0.33, 0.5, 0.7],
	LevelBuilder.Kind.FACADE: ["white_plaster_02", "tarred_gravel", 0.33, 0.25, 0.6],
	LevelBuilder.Kind.ASPHALT: ["bitumen", "bitumen", 0.25, 0.25, 0.6],
	LevelBuilder.Kind.METAL: ["metal_plate", "metal_plate", 0.5, 0.5, 0.5],
}

static var _cache: Dictionary = {}


static func get_material(kind: int) -> ShaderMaterial:
	if _cache.has(kind):
		return _cache[kind]
	var set_: Array = SETS[kind]
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/surface.gdshader")
	m.set_shader_parameter(&"kind", kind)
	_bind(m, "side", set_[0])
	_bind(m, "top", set_[1])
	m.set_shader_parameter(&"side_scale", set_[2])
	m.set_shader_parameter(&"top_scale", set_[3])
	m.set_shader_parameter(&"detail_strength", set_[4])
	_cache[kind] = m
	return m


static func _bind(m: ShaderMaterial, prefix: String, id: String) -> void:
	m.set_shader_parameter(prefix + "_albedo", load(TEX % [id, id, "diff"]))
	m.set_shader_parameter(prefix + "_normal", load(TEX % [id, id, "nor_gl"]))
	m.set_shader_parameter(prefix + "_arm", load(TEX % [id, id, "arm"]))
	m.set_shader_parameter(prefix + "_gain", minf(1.0 / MEAN_LUM[id], 3.0))
