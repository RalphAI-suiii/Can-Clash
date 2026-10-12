shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.16, 0.10, 0.12, 1.0);
uniform float outline_width : hint_range(0.0, 16.0) = 3.0;
uniform float shadow_cutoff : hint_range(0.0, 1.0) = 0.8;
uniform float dark_threshold : hint_range(0.0, 0.5) = 0.15;

float clean_alpha(float a) {
    // drops the faint baked-in shadow, keeps the solid crate
    return smoothstep(shadow_cutoff - 0.1, shadow_cutoff, a);
}

void vertex() {
    // grows the sprite's quad so the outline never gets clipped
    VERTEX += (UV * 2.0 - 1.0) * outline_width;
}

void fragment() {
    vec2 pad = TEXTURE_PIXEL_SIZE * outline_width;
    vec2 uv = UV * (1.0 + 2.0 * pad) - pad;   // keeps the crate at its original size

    vec4 tex = texture(TEXTURE, uv);
    tex.a = clean_alpha(tex.a);

    // recolor the crate's baked-in black border to the bench's outline color
    float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    if (lum < dark_threshold) {
        tex.rgb = outline_color.rgb;
    }

    float a = 0.0;
    for (int i = 0; i < 16; i++) {
        float ang = float(i) * TAU / 16.0;
        vec2 off = vec2(cos(ang), sin(ang)) * TEXTURE_PIXEL_SIZE * outline_width;
        a = max(a, clean_alpha(texture(TEXTURE, uv + off).a));
    }

    COLOR = mix(vec4(outline_color.rgb, a), tex, tex.a);
}