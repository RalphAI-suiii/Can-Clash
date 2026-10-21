shader_type canvas_item;

// 1. Thin the outline: erases outline pixels within this many px of the sprite's edge
uniform int thin_px : hint_range(0, 8) = 2;
// What counts as "outline" (near-black pixels)
uniform float dark_threshold : hint_range(0.0, 0.5) = 0.18;
// 2. Outline becomes a darker version of the nearest neighbor color
uniform float outline_darken : hint_range(0.2, 1.0) = 0.55;
uniform int search_px : hint_range(1, 10) = 6;
// 3. Erase outline below this height (0 = top, 1 = bottom of the sprite)
uniform float base_cut : hint_range(0.0, 1.0) = 0.92;
// 4. Shift the tree's colors toward your grass
uniform float hue_shift : hint_range(-0.5, 0.5) = 0.0;
uniform float sat_mult : hint_range(0.0, 2.0) = 1.15;
uniform float val_mult : hint_range(0.5, 1.5) = 1.0;

const vec2 DIRS[8] = vec2[](
    vec2(1, 0), vec2(-1, 0), vec2(0, 1), vec2(0, -1),
    vec2(1, 1), vec2(-1, 1), vec2(1, -1), vec2(-1, -1)
);

bool is_dark(vec4 c) {
    return c.a > 0.5 && dot(c.rgb, vec3(0.299, 0.587, 0.114)) < dark_threshold;
}

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec4 process(sampler2D tex, vec2 uv, vec2 px) {
    vec4 c = texture(tex, uv);
    if (c.a < 0.01) {
        return c;
    }

    if (is_dark(c)) {
        // 3. remove the heavy blob at the base
        if (uv.y > base_cut) {
            return vec4(0.0);
        }

        // 1. thin the outline from the outside
        for (int x = -thin_px; x <= thin_px; x++) {
            for (int y = -thin_px; y <= thin_px; y++) {
                if (texture(tex, uv + vec2(float(x), float(y)) * px).a < 0.5) {
                    return vec4(0.0);
                }
            }
        }

        // 2. recolor using the nearest non-dark neighbor
        vec3 sum = vec3(0.0);
        float n = 0.0;
        for (int r = 1; r <= search_px; r++) {
            for (int i = 0; i < 8; i++) {
                vec4 s = texture(tex, uv + DIRS[i] * float(r) * px);
                if (s.a > 0.5 && !is_dark(s)) {
                    sum += s.rgb;
                    n += 1.0;
                }
            }
            if (n > 0.0) {
                break;
            }
        }
        if (n > 0.0) {
            c.rgb = (sum / n) * outline_darken;
        }
        return c;
    }

    // 4. shift fill colors toward the grass
    vec3 hsv = rgb2hsv(c.rgb);
    hsv.x = fract(hsv.x + hue_shift);
    hsv.y = clamp(hsv.y * sat_mult, 0.0, 1.0);
    hsv.z = clamp(hsv.z * val_mult, 0.0, 1.0);
    c.rgb = hsv2rgb(hsv);
    return c;
}

void fragment() {
    COLOR = process(TEXTURE, UV, TEXTURE_PIXEL_SIZE);
}