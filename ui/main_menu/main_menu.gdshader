shader_type canvas_item;

uniform sampler2D wear_noise : repeat_enable, filter_linear;

uniform vec4 line_color : source_color = vec4(0.90, 0.88, 0.82, 1.0);   // off-white chalk
uniform vec4 grime_color : source_color = vec4(0.62, 0.60, 0.56, 1.0);  // dirty tone
uniform float grime_amount : hint_range(0.0, 1.0) = 0.45;
uniform float line_wear : hint_range(0.0, 0.6) = 0.12;
uniform float paint_wear : hint_range(0.0, 0.6) = 0.0;
uniform float paint_dull : hint_range(0.0, 1.0) = 0.25;
uniform vec2 patch_scale = vec2(2.5, 1.4);
uniform vec2 chip_scale = vec2(9.0, 5.0);
uniform float softness : hint_range(0.01, 0.3) = 0.06;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float patch = texture(wear_noise, UV * patch_scale).r;
    float chip = texture(wear_noise, UV * chip_scale + vec2(0.37, 0.61)).r;

    // white lines have a high minimum channel, red paint does not
    float is_line = step(0.8, min(min(tex.r, tex.g), tex.b));

    // wear: broad patches decide where paint thins, chips add a few nicks
    float n = mix(patch, chip, 0.35);
    float wear = mix(paint_wear, line_wear, is_line);
    float keep = smoothstep(wear, wear + softness, n);
