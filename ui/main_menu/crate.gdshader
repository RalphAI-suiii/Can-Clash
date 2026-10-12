shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.06, 0.04, 0.04, 1.0);
uniform float outline_width = 3.0;

void fragment() {
    vec2 px = TEXTURE_PIXEL_SIZE * outline_width;
    vec4 tex = texture(TEXTURE, UV);

    float a = 0.0;
    a = max(a, texture(TEXTURE, UV + vec2( px.x, 0.0)).a);
    a = max(a, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
    a = max(a, texture(TEXTURE, UV + vec2(0.0,  px.y)).a);
    a = max(a, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
    a = max(a, texture(TEXTURE, UV + vec2( px.x,  px.y)).a);
    a = max(a, texture(TEXTURE, UV + vec2(-px.x,  px.y)).a);
    a = max(a, texture(TEXTURE, UV + vec2( px.x, -px.y)).a);
    a = max(a, texture(TEXTURE, UV + vec2(-px.x, -px.y)).a);

    COLOR = mix(vec4(outline_color.rgb, a * outline_color.a), tex, tex.a);
}
