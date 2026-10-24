shader_type canvas_item;

uniform float saturation : hint_range(0.0, 1.5) = 0.8;
uniform float brightness : hint_range(0.5, 1.5) = 0.92;

void fragment() {
    vec4 c = texture(TEXTURE, UV);
    float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
    c.rgb = mix(vec3(g), c.rgb, saturation) * brightness;
    COLOR = c;
}