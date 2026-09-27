shader_type spatial;
// First-person gun and arms.
//  - Own field of view (fp_fov_deg): arms/gun keep one natural-looking
//    projection whatever the camera FOV (settings slider, speed FOV), and
//    near-camera arm parts leave the frame instead of ballooning at the edges.
//    Both the gun and the arms must use the same value or hands slide off grips.
//  - Depth squashed into the nearest slice of the depth buffer so the gun and
//    hands never clip into walls, while their own parts still sort correctly.
//    Godot 4 uses reverse-Z (1 = near).

uniform vec4 albedo : source_color = vec4(0.86, 0.87, 0.9, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.45;
uniform float metallic : hint_range(0.0, 1.0) = 0.15;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float fp_fov_deg = 68.0;     // vertical
uniform float fp_fov_weight = 1.0;   // 0 = camera FOV (e.g. the legs)
uniform float depth_squash = 0.92;

void vertex() {
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// abs(): the projection Y term is negative on Vulkan/Metal (flipped Y).
	float k = (1.0 / tan(radians(fp_fov_deg) * 0.5)) / abs(PROJECTION_MATRIX[1][1]);
	POSITION.xy *= mix(1.0, k, fp_fov_weight);
	POSITION.z = mix(POSITION.z, POSITION.w, depth_squash);
}

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission.rgb * emission_energy;
}
