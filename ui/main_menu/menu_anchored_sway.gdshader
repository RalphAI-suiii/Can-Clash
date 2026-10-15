shader_type canvas_item;

uniform float phase = 0.0;

void fragment() {
	vec2 within_frame = (UV - REGION_RECT.xy) / REGION_RECT.zw;
	float upper_body = 1.0 - smoothstep(0.28, 0.70, within_frame.y);
	float sway = sin(TIME * 0.8 + phase) * 6.0 * upper_body;
	vec2 source_uv = UV - vec2(sway * TEXTURE_PIXEL_SIZE.x, 0.0);
	vec2 region_min = REGION_RECT.xy + TEXTURE_PIXEL_SIZE * 0.5;
	vec2 region_max = REGION_RECT.xy + REGION_RECT.zw - TEXTURE_PIXEL_SIZE * 0.5;
	COLOR = texture(TEXTURE, clamp(source_uv, region_min, region_max));
}
