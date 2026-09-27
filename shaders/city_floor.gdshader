shader_type spatial;
// The megacity floor far below a map: dark blocks cut by glowing street grids.
// Pure arithmetic on world position (no textures, no noise), unshaded; the
// map's height fog does the rest.
render_mode unshaded, shadows_disabled;

uniform vec3 base_color : source_color = vec3(0.02, 0.025, 0.04);
uniform vec3 street_color : source_color = vec3(1.0, 0.55, 0.22);
uniform vec3 avenue_color : source_color = vec3(0.35, 0.75, 1.0);
uniform float block = 70.0;
uniform float avenue = 350.0;
uniform float energy = 2.2;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid(vec2 p, float cell, float width) {
	vec2 g = abs(fract(p / cell - 0.5) - 0.5) * cell;
	vec2 fw = fwidth(p) * 1.5;
	vec2 l = 1.0 - smoothstep(vec2(width) - fw, vec2(width) + fw, g);
	return max(l.x, l.y);
}

void fragment() {
	vec2 p = wpos.xz;
	float streets = grid(p, block, 2.5);
	float avenues = grid(p + vec2(block * 0.5), avenue, 6.0);
	// Blocks vary a little in brightness (hash of the block index, no noise).
	vec2 cell = floor(p / block);
	float h = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 col = base_color * (0.6 + 0.8 * h);
	col = mix(col, street_color * energy * 0.6, streets);
	col = mix(col, avenue_color * energy, avenues);
	ALBEDO = col;
}
