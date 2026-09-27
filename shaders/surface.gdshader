shader_type spatial;
// Level surface, built for low cost on mid-range GPUs:
//  - world-space projection on the dominant axis: ONE set of texture reads
//    (albedo, normal, ARM) per pixel, no triplanar blending
//  - per-block color / glow / pattern come from vertex data, so static level
//    geometry merges into a few large meshes (few draw calls)
//  - facade windows are simple arithmetic (step/fract), no noise
//
// Vertex data: COLOR.rgb = tint, COLOR.a = glow (0..1 -> 0..2 energy)
//              UV2.x = stripes (hazard), UV2.y = per-block seed
// Material uniform `kind`: 0 paint, 1 concrete, 2 facade, 3 asphalt, 4 metal

uniform int kind = 1;
uniform sampler2D side_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D side_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D side_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D top_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D top_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D top_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float side_scale = 0.4;  // texture repeats per meter
uniform float top_scale = 0.35;
uniform float detail_strength = 0.8;  // how much texture brightness variation shows through the tint
uniform float side_gain = 2.0;  // 1 / average luminance of the side albedo (set by LevelBuilder)
uniform float top_gain = 2.0;
uniform float normal_strength = 1.0;

uniform float floor_height = 3.6;
uniform float bay_width = 2.8;
uniform vec3 glass_color : source_color = vec3(0.14, 0.2, 0.28);
uniform float grid_strength = 0.06;
uniform float edge_wear = 0.45;      // chamfer highlight (LevelBuilder bevels every block edge)
uniform float seam_strength = 0.35;  // panel seams on concrete and metal
// 0 = day, 1 = night: more windows lit and brighter, darker glass. Set per
// map by LevelBase (RenderingServer.global_shader_parameter_set).
global uniform float night;
// 0 on the Low preset (Graphics): skip chamfer highlights and panel seams.
global uniform float surface_detail;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 tint_linear;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// Tints are authored in sRGB (like every color picker); lighting needs linear.
	// Converting per vertex is free compared to per pixel.
	vec3 c = COLOR.rgb;
	tint_linear = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float line_aa(float coord, float cell, float width) {
	float g = abs(fract(coord / cell - 0.5) - 0.5) * cell;
	float fw = fwidth(coord) * 1.2;
	return 1.0 - smoothstep(width - fw, width + fw, g);
}

void fragment() {
	vec3 an = abs(world_normal);
	bool top = an.y > 0.6;
	// Dominant-axis projection. t/b are the world axes the UV runs along,
	// used to put the tangent-space normal map into world space.
	vec2 uv;
	vec3 t_axis;
	vec3 b_axis;
	if (top) {
		uv = world_pos.xz;
		t_axis = vec3(1, 0, 0);
		b_axis = vec3(0, 0, 1);
	} else if (an.x > an.z) {
		uv = vec2(world_pos.z * sign(world_normal.x), -world_pos.y);
		t_axis = vec3(0, 0, sign(world_normal.x));
		b_axis = vec3(0, -1, 0);
	} else {
		uv = vec2(-world_pos.x * sign(world_normal.z), -world_pos.y);
		t_axis = vec3(-sign(world_normal.z), 0, 0);
		b_axis = vec3(0, -1, 0);
	}

	vec3 tex;
	vec3 nrm;
	vec3 arm;
	if (top) {
		vec2 tuv = uv * top_scale;
		tex = texture(top_albedo, tuv).rgb;
		nrm = texture(top_normal, tuv).rgb;
		arm = texture(top_arm, tuv).rgb;
	} else {
		vec2 suv = uv * side_scale;
		tex = texture(side_albedo, suv).rgb;
		nrm = texture(side_normal, suv).rgb;
		arm = texture(side_arm, suv).rgb;
	}

	vec3 tint = tint_linear;
	float glow = COLOR.a * 2.0;
	// Texture luminance (normalized by the texture's measured average) modulates
	// the tint, so route colors stay saturated and on-palette.
	float lum = dot(tex, vec3(0.299, 0.587, 0.114)) * (top ? top_gain : side_gain);
	vec3 col = tint * mix(1.0, lum, detail_strength);
	if (kind == 0) {
		col = tint;  // paint keeps its exact color; texture only adds normal/roughness detail
	}
	float rough = arm.g;
	float metal = arm.b;
	float ao = arm.r;
	vec3 emit = tint * glow;

	if (kind == 0) {
		// Paint: faint 1 m grid helps judge distances at speed.
		col *= 1.0 - grid_strength * max(line_aa(uv.x, 1.0, 0.01), line_aa(uv.y, 1.0, 0.01));
		rough = mix(rough, 0.55, 0.6);
		metal = 0.0;
	} else if (kind == 2 && !top) {
		// Curtain wall: plaster floor bands, glazed bays with mullions.
		float fl = fract(world_pos.y / floor_height);
		float bx = uv.x / bay_width;
		float bl = fract(bx);
		float glazed = step(0.28, fl) * step(fl, 0.93) * step(0.05, bl) * step(bl, 0.95);
		float r = hash12(vec2(floor(bx), floor(world_pos.y / floor_height)) + UV2.y * 13.0);
		float lit = step(1.0 - mix(0.1, 0.24, night), r);
		vec3 glass = glass_color * (0.75 + 0.5 * r) * mix(1.0, 0.25, night);
		vec3 lamp = mix(vec3(0.95, 0.85, 0.65), vec3(0.75, 0.88, 1.0), step(0.5, fract(r * 7.0)) * night);
		glass = lit > 0.5 ? mix(glass, lamp, 0.6) : glass;
		glass = r < 0.12 ? mix(glass, vec3(0.7, 0.72, 0.74), 0.55 * (1.0 - night)) : glass;
		col = mix(col, glass, glazed);
		rough = mix(rough, 0.06, glazed);
		metal = mix(metal, 0.85, glazed);
		nrm = mix(nrm, vec3(0.5, 0.5, 1.0), glazed);
		emit += mix(vec3(0.9, 0.7, 0.45), lamp, night) * lit * glazed * mix(0.25, 0.8, night);  // day: unchanged
	}

	// Chamfers (normals between two axes) catch a worn-paint highlight, so
	// block edges read crisp. Faces are flat-shaded, so this is exact.
	if (surface_detail > 0.5) {
	float axis_max = max(an.x, max(an.y, an.z));
	float edge = 1.0 - smoothstep(0.8, 0.95, axis_max);
	col = mix(col, min(col * 1.35 + 0.035, vec3(1.0)), edge * edge_wear * (kind == 0 ? 0.5 : 1.0));

	// Panel seams: a staggered cladding pattern on walls, a grid on floors.
	if (kind == 1 || kind == 4) {
		float cell = kind == 4 ? 1.2 : 3.0;
		float seam;
		if (top) {
			seam = max(line_aa(uv.x, cell, 0.012), line_aa(uv.y, cell, 0.012));
		} else {
			float row = floor(uv.y / (cell * 0.5));
			seam = max(line_aa(uv.y, cell * 0.5, 0.012), line_aa(uv.x + mod(row, 2.0) * cell * 0.5, cell, 0.012));
		}
		col *= 1.0 - seam_strength * seam * (1.0 - edge);
		rough = mix(rough, 0.9, seam * 0.5);
	}
	}

	if (UV2.x > 0.5) {
		float s = step(0.5, fract((uv.x + uv.y) * 0.5));
		col = mix(col, vec3(0.08, 0.08, 0.1), s * 0.85);
	}

	// Tangent-space normal -> world -> view.
	vec3 tn = nrm * 2.0 - 1.0;
	tn.xy *= normal_strength;
	vec3 wn = normalize(t_axis * tn.x + b_axis * tn.y + world_normal * tn.z);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	AO = ao;
	AO_LIGHT_AFFECT = 0.3;
	EMISSION = emit;
}
