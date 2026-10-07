shader_type canvas_item;
render_mode blend_mul, unshaded;

uniform float paper_cutoff : hint_range(0.0, 0.3) = 0.08;
uniform float edge_softness : hint_range(0.01, 0.3) = 0.12;
uniform float ink_opacity : hint_range(0.0, 1.0) = 0.95;
uniform float absorption_progress : hint_range(0.0, 1.0) = 0.0;
uniform float absorption_spread_pixels : hint_range(0.0, 4.0) = 1.25;
uniform float absorption_grain : hint_range(0.0, 1.0) = 0.35;

varying float item_alpha;

void vertex() {
	item_alpha = COLOR.a;
}

vec4 red_ink(vec4 source) {
	// The supplied PNG has a cream paper background. Keep only the red ink;
	// carry its colour with the mask so diffusion cannot spread the backing.
	float redness = max(source.r - max(source.g, source.b), 0.0);
	float mask = smoothstep(paper_cutoff, paper_cutoff + edge_softness, redness) * source.a;
	return vec4(source.rgb * mask, mask);
}

void fragment() {
	float progress = clamp(absorption_progress, 0.0, 1.0);
	vec4 ink = red_ink(texture(TEXTURE, UV));
	float diffusion = sin(progress * PI);
	vec2 offset = TEXTURE_PIXEL_SIZE * absorption_spread_pixels * diffusion;
	vec4 dispersed = (ink + red_ink(texture(TEXTURE, UV + vec2(offset.x, 0.0)))
		+ red_ink(texture(TEXTURE, UV - vec2(offset.x, 0.0)))
		+ red_ink(texture(TEXTURE, UV + vec2(0.0, offset.y)))
		+ red_ink(texture(TEXTURE, UV - vec2(0.0, offset.y)))) * 0.2;
	ink = mix(ink, dispersed, diffusion * 0.45);
	// Stable paper pores: only progress changes, including across a pause.
	vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE);
	float grain = fract(sin(dot(pixel, vec2(12.9898, 78.233))) * 43758.5453);
	float absorbed = smoothstep(grain * 0.55, grain * 0.55 + 0.45, progress);
	float remaining = (1.0 - progress) * mix(1.0, 1.0 - absorbed, absorption_grain);
	vec3 ink_color = ink.rgb / max(ink.a, 0.0001);
	// White is neutral for Multiply; fully absorbed ink leaves the paper intact.
	vec3 tone = mix(vec3(1.0), ink_color, ink.a * ink_opacity * item_alpha * remaining);
	COLOR = vec4(tone, 1.0);
}
