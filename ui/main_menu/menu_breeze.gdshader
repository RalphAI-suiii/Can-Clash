shader_type canvas_item;
render_mode unshaded;

float canopy(vec2 uv, vec2 center, vec2 radius, float grounded_at) {
	float shape = 1.0 - smoothstep(0.78, 1.18, length((uv - center) / radius));
	return shape * (1.0 - smoothstep(grounded_at - 0.10, grounded_at, uv.y));
}

void fragment() {
	float left_tree = canopy(UV, vec2(0.065, 0.280), vec2(0.115, 0.210), 0.47);
	float middle_tree = canopy(UV, vec2(0.293, 0.204), vec2(0.105, 0.145), 0.36);
	float right_tree = canopy(UV, vec2(0.940, 0.290), vec2(0.115, 0.210), 0.49)
		* smoothstep(0.18, 0.23, UV.y);
	float trees = left_tree * sin(TIME * 0.75 + UV.y * 5.0)
		+ middle_tree * sin(TIME * 0.67 + 1.3 + UV.y * 5.0)
		+ right_tree * sin(TIME * 0.71 + 2.5 + UV.y * 5.0);

	vec2 sample_uv = UV + vec2(trees * 0.0038, 0.0);
	COLOR = texture(TEXTURE, clamp(sample_uv, vec2(0.0), vec2(1.0)));
}
