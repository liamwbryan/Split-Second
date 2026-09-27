shader_type spatial;
// Flying traffic lane: every car is one MultiMesh instance, scrolled along the
// lane's local x axis on the GPU (no per-frame CPU work, no per-car nodes).
// INSTANCE_CUSTOM.x = phase 0..1 along the lane, .y = direction (+1 / -1),
// .z = speed multiplier. Instances keep an identity basis.
render_mode unshaded, shadows_disabled;

uniform float lane_length = 800.0;
uniform float speed = 45.0;
uniform float energy = 3.0;

void vertex() {
	float s = speed * INSTANCE_CUSTOM.z * INSTANCE_CUSTOM.y;
	float x = mod(INSTANCE_CUSTOM.x * lane_length + TIME * s, lane_length) - lane_length * 0.5;
	VERTEX.x = VERTEX.x * INSTANCE_CUSTOM.y + x;  // cars face their direction of travel
}

void fragment() {
	// Front of the car (local +x end) is the headlight; the rest is the body glow.
	ALBEDO = COLOR.rgb * energy;
}
