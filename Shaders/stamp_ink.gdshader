shader_type canvas_item;
render_mode blend_mul, unshaded;

uniform float paper_cutoff : hint_range(0.0, 0.3) = 0.08;
uniform float edge_softness : hint_range(0.01, 0.3) = 0.12;
uniform float ink_opacity : hint_range(0.0, 1.0) = 0.95;
uniform float absorption_progress : hint_range(0.0, 1.0) = 0.0;
uniform float absorption_spread_pixels : hint_range(0.0, 4.0) = 1.25;
uniform float absorption_grain : hint_range(0.0, 1.0) = 0.35;
uniform float blotch_scale : hint_range(1.0, 16.0) = 4.5;
uniform float blotch_softness : hint_range(0.01, 0.3) = 0.09;
uniform float blotch_motion : hint_range(0.0, 2.0) = 0.45;
uniform float ink_time = 0.0;

varying float item_alpha;

void vertex() {
	item_alpha = COLOR.a;
}

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 part = fract(point);
	part = part * part * (3.0 - 2.0 * part);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), part.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), part.x), part.y);
}

float blotches(vec2 point) {
	float time = ink_time * blotch_motion;
	vec2 flow = vec2(noise(point * 0.7 + vec2(time * 0.3, -time * 0.2)),
		noise(point * 0.7 + vec2(8.1, 3.7) - time * 0.25));
	vec2 warped = point + flow * 1.6;
	float broad = noise(warped + vec2(time * 0.18, -time * 0.14));
	float detail = noise(warped * 2.4 + vec2(-time * 0.22, time * 0.17));
	return clamp(mix(broad, broad * 0.65 + detail * 0.35, absorption_grain), 0.0, 1.0);
}

vec4 red_ink(vec4 source) {
	// Extract red pigment, never the cream backing of the supplied PNG.
	float redness = max(source.r - max(source.g, source.b), 0.0);
	float mask = smoothstep(paper_cutoff, paper_cutoff + edge_softness, redness) * source.a;
	return vec4(source.rgb * mask, mask);
}

void fragment() {
	float progress = clamp(absorption_progress, 0.0, 1.0);
	vec4 ink = red_ink(texture(TEXTURE, UV));
	float remaining = 1.0;
	if (progress > 0.0) {
		float diffusion = sin(progress * PI);
		vec2 offset = TEXTURE_PIXEL_SIZE * absorption_spread_pixels * diffusion;
		vec4 dispersed = (ink + red_ink(texture(TEXTURE, UV + vec2(offset.x, 0.0)))
			+ red_ink(texture(TEXTURE, UV - vec2(offset.x, 0.0)))
			+ red_ink(texture(TEXTURE, UV + vec2(0.0, offset.y)))
			+ red_ink(texture(TEXTURE, UV - vec2(0.0, offset.y)))) * 0.2;
		ink = mix(ink, dispersed, diffusion * 0.45);
		float field = blotches(UV * blotch_scale);
		float threshold = mix(-blotch_softness, 1.0 + blotch_softness, progress);
		remaining = 1.0 - smoothstep(field - blotch_softness, field + blotch_softness, threshold);
	}
	vec3 ink_color = ink.rgb / max(ink.a, 0.0001);
	// White is neutral for Multiply, including transparent paper and end state.
	vec3 tone = mix(vec3(1.0), ink_color, ink.a * ink_opacity * item_alpha * remaining);
	COLOR = vec4(tone, 1.0);
}
