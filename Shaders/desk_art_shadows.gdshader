shader_type canvas_item;
render_mode blend_mul, unshaded;

uniform float shadow_strength : hint_range(0.0, 1.0) = 1.0;
uniform float blur_pixels : hint_range(0.0, 8.0) = 3.0;
uniform float speed : hint_range(0.0, 1.0) = 0.31;
uniform vec2 motion_pixels = vec2(24.0, 12.0);

vec3 shadow_tone(vec4 shadow) {
	return mix(vec3(1.0), shadow.rgb, shadow.a * shadow_strength);
}

void fragment() {
	// The artist's transparent texture supplies the shapes and color.
	// Slightly different phases across the image keep the broad bands moving gently.
	vec2 drift = vec2(
		sin(TIME * speed + UV.y * 1.2) * motion_pixels.x,
		sin(TIME * speed * 0.8 + UV.x * 1.3 + 1.1) * motion_pixels.y
	);
	vec2 uv = UV + drift * TEXTURE_PIXEL_SIZE;
	vec2 blur = blur_pixels * TEXTURE_PIXEL_SIZE;
	vec3 tone = shadow_tone(texture(TEXTURE, uv)) * 0.5;
	tone += (
		shadow_tone(texture(TEXTURE, uv + vec2(blur.x, 0.0))) +
		shadow_tone(texture(TEXTURE, uv - vec2(blur.x, 0.0))) +
		shadow_tone(texture(TEXTURE, uv + vec2(0.0, blur.y))) +
		shadow_tone(texture(TEXTURE, uv - vec2(0.0, blur.y)))
	) * 0.125;
	COLOR = vec4(tone, 1.0);
}
