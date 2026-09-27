shader_type spatial;
// Glowing sign faces / screens on city-kit models (material "KitSign").
// Colour per instance from the MultiMesh custom data (INSTANCE_CUSTOM, sRGB,
// alpha > 0 = set); falls back to `default_color`. Unshaded: no lights, the
// glow pass does the bloom. A soft vertical falloff and faint scan bands keep
// big faces from reading as flat colour (arithmetic only, no textures).
render_mode unshaded, shadows_disabled;

uniform vec4 default_color : source_color = vec4(0.3, 0.85, 1.0, 1.0);
uniform float energy = 2.6;

varying vec3 tint;
varying float band_coord;

void vertex() {
	// Custom data arrives raw (authored in sRGB); source_color is already linear.
	tint = INSTANCE_CUSTOM.a > 0.0 ? pow(INSTANCE_CUSTOM.rgb, vec3(2.2)) : default_color.rgb;
	band_coord = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float bands = 0.88 + 0.12 * step(0.5, fract(band_coord * 9.0));
	ALBEDO = tint * energy * bands;
}
