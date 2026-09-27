shader_type spatial;
// Backdrop towers (Backdrop MultiMeshes, 150 m+ away): the surface shader's
// curtain-wall windows with no texture reads and no normal mapping; at that
// distance the textures are sub-pixel anyway. COLOR.rgb = tint (sRGB).
render_mode shadows_disabled;

uniform float floor_height = 3.6;
uniform float bay_width = 2.8;
uniform vec3 glass_color : source_color = vec3(0.14, 0.2, 0.28);
global uniform float night;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 tint_linear;
varying float seed;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 c = COLOR.rgb;
	tint_linear = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
	seed = float(INSTANCE_ID) * 0.37;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec3 an = abs(world_normal);
	vec3 col = tint_linear * 0.8;
	float rough = 0.8;
	float metal = 0.0;
	vec3 emit = vec3(0.0);
	if (an.y < 0.6) {
		float u = an.x > an.z ? world_pos.z : world_pos.x;
		float fl = fract(world_pos.y / floor_height);
		float bx = u / bay_width;
		float bl = fract(bx);
		float glazed = step(0.28, fl) * step(fl, 0.93) * step(0.05, bl) * step(bl, 0.95);
		float r = hash12(vec2(floor(bx), floor(world_pos.y / floor_height)) + seed * 13.0);
		float lit = step(1.0 - mix(0.1, 0.24, night), r);
		vec3 glass = glass_color * (0.75 + 0.5 * r) * mix(1.0, 0.25, night);
		vec3 lamp = mix(vec3(0.95, 0.85, 0.65), vec3(0.75, 0.88, 1.0), step(0.5, fract(r * 7.0)) * night);
		glass = lit > 0.5 ? mix(glass, lamp, 0.6) : glass;
		col = mix(col, glass, glazed);
		rough = mix(rough, 0.1, glazed);
		metal = mix(metal, 0.8, glazed);
		emit = mix(vec3(0.9, 0.7, 0.45), lamp, night) * lit * glazed * mix(0.25, 0.8, night);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emit;
}
