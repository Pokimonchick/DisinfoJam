shader_type canvas_item;
render_mode unshaded;

uniform float absorption_progress : hint_range(0.0, 1.0) = 0.0;
uniform float reveal_progress : hint_range(0.0, 1.0) = 1.0;
uniform float blotch_scale : hint_range(10.0, 240.0) = 80.0;
uniform float blotch_softness : hint_range(0.01, 0.3) = 0.09;
uniform float blotch_motion : hint_range(0.0, 2.0) = 0.45;
uniform float ink_time = 0.0;
uniform vec2 ink_origin = vec2(0.0);

varying vec2 ink_canvas_position;

void vertex() {
	// Glyph atlas UV repeats per letter. Canvas coordinates form one paper mask.
	ink_canvas_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
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
	return noise(warped + vec2(time * 0.18, -time * 0.14)) * 0.78
		+ noise(warped * 2.4 + vec2(-time * 0.22, time * 0.17)) * 0.22;
}

void fragment() {
	// Fully readable text needs no procedural noise during ordinary reading.
	if (absorption_progress > 0.0 || reveal_progress < 1.0) {
		float field = blotches((ink_canvas_position - ink_origin) / max(blotch_scale, 1.0));
		float dissolve = mix(-blotch_softness, 1.0 + blotch_softness, clamp(absorption_progress, 0.0, 1.0));
		float reveal = mix(-blotch_softness, 1.0 + blotch_softness, clamp(reveal_progress, 0.0, 1.0));
		float remaining = 1.0 - smoothstep(field - blotch_softness, field + blotch_softness, dissolve);
		float appearing = smoothstep(field - blotch_softness, field + blotch_softness, reveal);
		COLOR.a *= remaining * appearing;
	}
}
