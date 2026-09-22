shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
// Driven by gameplay time so animation stops with the work clock.
uniform float effect_time = 0.0;

float noise_value(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	// An elliptical vignette reaches every screen edge and keeps the center clear.
	float edge = smoothstep(0.28, 1.12, length(centered));
	float breath = 0.5 + 0.5 * sin(effect_time * 1.7);
	float frame = floor(effect_time * 6.0);
	float band = floor(uv.y * 28.0);
	float event = step(0.93, noise_value(vec2(frame, 7.0)));
	float strip = step(0.70, noise_value(vec2(band, frame)));
	float glitch = event * strip;
	float shift = (noise_value(vec2(frame, band)) - 0.5) * 12.0;
	uv.x += SCREEN_PIXEL_SIZE.x * shift * glitch * intensity;
	// Glitching bands split the red/blue channels much farther than the idle fringe.
	float aberration = 0.3 + edge * 1.7 + breath * 0.4;
	aberration += glitch * (8.0 + 6.0 * noise_value(vec2(band, frame + 19.0)));
	vec2 split = vec2(SCREEN_PIXEL_SIZE.x * aberration * intensity, 0.0);
	vec3 color;
	color.r = textureLod(screen_texture, uv + split, 0.0).r;
	color.g = textureLod(screen_texture, uv, 0.0).g;
	color.b = textureLod(screen_texture, uv - split, 0.0).b;
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(gray), intensity * 0.18);
	float vignette = edge * min(0.95, intensity * 1.45) * (0.92 + breath * 0.08);
	color *= 1.0 - vignette;
	COLOR = vec4(color, 1.0);
}
