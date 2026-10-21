shader_type canvas_item;

group_uniforms ground_color;
uniform vec4 ground_tint : source_color = vec4(0.647, 0.541, 0.478, 1.0);   // #A58A7A
uniform float ground_tint_strength : hint_range(0.0, 1.0) = 1.0;
uniform float ground_base_lum = 0.30;
group_uniforms;

group_uniforms zones;
uniform vec4 zone_dark : source_color = vec4(0.27, 0.27, 0.29, 1.0);
uniform vec4 zone_light : source_color = vec4(0.50, 0.47, 0.43, 1.0);
uniform float zone_strength : hint_range(0.0, 1.0) = 0.10;
uniform float zone_scale = 800.0;
uniform float zone_bands = 3.0;

group_uniforms patches;
uniform vec4 patch_dark : source_color = vec4(0.20, 0.20, 0.22, 1.0);
uniform vec4 patch_light : source_color = vec4(0.46, 0.44, 0.41, 1.0);
uniform vec4 patch_outline : source_color = vec4(0.08, 0.08, 0.09, 1.0);
uniform float patch_cell = 560.0;
uniform float patch_density : hint_range(0.0, 1.0) = 0.12;
uniform float patch_strength : hint_range(0.0, 1.0) = 0.10;

group_uniforms stains;
uniform vec4 stain_color : source_color = vec4(0.10, 0.09, 0.10, 1.0);
uniform float stain_scale = 250.0;
uniform float stain_t1 : hint_range(0.0, 1.0) = 0.70;
uniform float stain_t2 : hint_range(0.0, 1.0) = 0.80;
uniform float stain_strength : hint_range(0.0, 1.0) = 0.14;

group_uniforms grit;
uniform float grit_size = 11.0;
uniform float grit_density : hint_range(0.0, 1.0) = 0.06;

group_uniforms cracks;
uniform vec4 crack_color : source_color = vec4(0.09, 0.08, 0.08, 1.0);
uniform float crack_opacity : hint_range(0.0, 1.0) = 0.30;
uniform float cell_size = 350.0;
uniform float crack_width = 2.0;
uniform float density : hint_range(0.0, 1.0) = 0.25;
uniform float wobble = 28.0;
uniform float wobble_scale = 90.0;
uniform float fade_scale = 160.0;

group_uniforms;

varying vec2 world_pos;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash1(i);
	float b = hash1(i + vec2(1.0, 0.0));
	float c = hash1(i + vec2(0.0, 1.0));
	float d = hash1(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v / 0.875;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec3 col = COLOR.rgb;

	// bent position, shared by patches and cracks so their edges are not straight
	vec2 wn = vec2(vnoise(world_pos / wobble_scale), vnoise(world_pos / wobble_scale + 17.3));
	vec2 p = world_pos + (wn - 0.5) * 2.0 * wobble;

	// 1) faded and dirty zones, in flat bands
	float zn = fbm(world_pos / zone_scale);
	float band = clamp(floor(zn * zone_bands) / (zone_bands - 1.0), 0.0, 1.0);
	vec3 tone = mix(zone_dark.rgb, zone_light.rgb, band);
	col = mix(col, tone, zone_strength);

	// 2) repair patches: rounded blobs picked from a random cell grid
	vec2 pu = p / patch_cell;
	vec2 pg = floor(pu);
	vec2 pf = fract(pu);
	float pmd = 8.0;
	vec2 pid = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 r = o + hash2(pg + o) - pf;
			float d = dot(r, r);
			if (d < pmd) {
				pmd = d;
				pid = pg + o;
			}
		}
	}
	float pdist = sqrt(pmd);
	float prad = 0.22 + 0.18 * hash1(pid + 7.1);
	float is_patch = step(1.0 - patch_density, hash1(pid));
	float inside = step(pdist, prad) * is_patch;
	float ring = step(abs(pdist - prad), 0.012) * is_patch;
	vec3 pcol = mix(patch_dark.rgb, patch_light.rgb, step(0.5, hash1(pid + 3.3)));
	col = mix(col, pcol, inside * patch_strength);
	col = mix(col, patch_outline.rgb, ring * 0.5);

	// 3) stains with two flat levels
	float sn = fbm(world_pos / stain_scale + 31.7);
	col = mix(col, stain_color.rgb, step(stain_t1, sn) * stain_strength);
	col = mix(col, stain_color.rgb * 0.6, step(stain_t2, sn) * stain_strength);

	// 4) grit: jittered specks of random size
	vec2 gp = world_pos / grit_size;
	vec2 gi = floor(gp);
	vec2 gf = fract(gp);
	vec2 centre = 0.2 + 0.6 * hash2(gi + 11.0);
	float gsize = 0.10 + 0.16 * hash1(gi + 2.2);
	float has = step(1.0 - grit_density, hash1(gi + 11.0));
	float speck = step(length(gf - centre), gsize) * has;
	float shade = mix(-0.11, 0.13, step(0.5, hash1(gi + 5.5)));
	col += speck * shade * 0.6;

	// 5) cracks
	vec2 uv = p / cell_size;
	vec2 g = floor(uv);
	vec2 f = fract(uv);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 r = o + hash2(g + o) - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mr = r;
				mg = o;
			}
		}
	}
	float edge = 8.0;
	vec2 other = vec2(0.0);
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 o = mg + vec2(float(x), float(y));
			vec2 r = o + hash2(g + o) - f;
			vec2 diff = r - mr;
			float l2 = dot(diff, diff);
			if (l2 > 0.00001) {
				float d = dot(0.5 * (mr + r), diff / sqrt(l2));
				if (d < edge) {
					edge = d;
					other = o;
				}
			}
		}
	}
	float edge_px = edge * cell_size;
	vec2 ca = g + mg;
	vec2 cb = g + other;
	float keep = step(1.0 - density, hash1(ca + cb + ca * cb));
	float taper = smoothstep(0.35, 0.65, vnoise(p / fade_scale));
	float line = (1.0 - smoothstep(crack_width, crack_width + 1.2, edge_px)) * keep * taper;
	col = mix(col, crack_color.rgb, line * crack_opacity);

	// recolor the whole ground, keeping the texture detail and every layer
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 tinted = ground_tint.rgb * (lum / ground_base_lum);
	col = mix(col, tinted, ground_tint_strength);

	COLOR.rgb = clamp(col, 0.0, 1.0);
}