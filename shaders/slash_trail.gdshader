shader_type spatial;
// Blade slash trail: additive, unshaded, drawn with the first-person FOV and
// squashed depth like the viewmodel (shaders/viewmodel.gdshader), so it lines
// up with the blade and never clips into walls. Vertex alpha fades it out;
// UV.y runs base (0) to tip (1), brighter toward the tip.
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec4 color : source_color = vec4(1.0, 0.45, 0.15, 1.0);
uniform float fp_fov_deg = 68.0;
uniform float depth_squash = 0.92;

void vertex() {
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float k = (1.0 / tan(radians(fp_fov_deg) * 0.5)) / abs(PROJECTION_MATRIX[1][1]);
	POSITION.xy *= k;
	POSITION.z = mix(POSITION.z, POSITION.w, depth_squash);
}

void fragment() {
	float a = COLOR.a * mix(0.25, 1.0, UV.y);
	ALBEDO = color.rgb * 2.2 * a;
	ALPHA = a;
}
