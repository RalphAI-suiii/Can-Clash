shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.16, 0.10, 0.12, 1.0);
uniform float outline_width : hint_range(0.0, 16.0) = 3.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    vec2 px = TEXTURE_PIXEL_SIZE * outline_width;
    float a = 0.0;
    for (int i = 0; i < 16; i++) {
        float ang = float(i) * TAU / 16.0;
        a = max(a, texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * px).a);
    }
    COLOR = mix(vec4(outline_color.rgb, a), tex, tex.a);
}