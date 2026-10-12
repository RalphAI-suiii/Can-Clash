shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.07, 0.05, 0.05, 1.0);
uniform float outline_width = 6.0;
uniform float smooth_px = 1.5;
uniform float saturation : hint_range(0.5, 2.0) = 1.3;
uniform float brightness : hint_range(0.5, 1.5) = 1.1;
uniform float steps : hint_range(2.0, 32.0) = 8.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // soften grain, ignoring transparent pixels
    vec2 o = TEXTURE_PIXEL_SIZE * smooth_px;
    vec4 c0 = tex;
    vec4 c1 = texture(TEXTURE, UV + vec2( o.x, 0.0));
    vec4 c2 = texture(TEXTURE, UV + vec2(-o.x, 0.0));
    vec4 c3 = texture(TEXTURE, UV + vec2(0.0,  o.y));
    vec4 c4 = texture(TEXTURE, UV + vec2(0.0, -o.y));

    vec4 acc = vec4(c0.rgb * c0.a, c0.a) * 4.0
             + vec4(c1.rgb * c1.a, c1.a)
             + vec4(c2.rgb * c2.a, c2.a)
             + vec4(c3.rgb * c3.a, c3.a)
             + vec4(c4.rgb * c4.a, c4.a);
    acc /= 8.0;
    vec3 base = acc.a > 0.001 ? acc.rgb / acc.a : tex.rgb;

    // saturate, brighten, flatten into bands
    float g = dot(base, vec3(0.299, 0.587, 0.114));
    vec3 col = mix(vec3(g), base, saturation) * brightness;
    col = floor(col * steps + 0.5) / steps;

    // outline
    vec2 px = TEXTURE_PIXEL_SIZE * outline_width;
    float a = 0.0;
    a = max(a, texture(TEXTURE, UV + vec2( px.x, 0.0)).a);
    a = max(a, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
    a = max(a, texture(TEXTURE, UV + vec2(0.0,  px.y)).a);
    a = max(a, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
    a = max(a, texture(TEXTURE, UV + vec2( px.x,  px.y)).a);
    a = max(a, texture(TEXTURE, UV + vec2(-px.x,  px.y)).a);
    a = max(a, texture(TEXTURE, UV + vec2( px.x, -px.y)).a);
    a = max(a, texture(TEXTURE, UV + vec2(-px.x, -px.y)).a);

    COLOR = mix(vec4(outline_color.rgb, a * outline_color.a), vec4(col, tex.a), tex.a);
}