shader_type canvas_item;
render_mode blend_mul, unshaded;

uniform vec4 shadow_color : source_color = vec4(0.32, 0.27, 0.20, 1.0);
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.26;
uniform float blur_pixels : hint_range(0.0, 8.0) = 3.0;

varying float item_alpha;

void vertex() {
	item_alpha = COLOR.a;
}

float silhouette(sampler2D mask_texture, vec2 uv) {
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return 0.0;
	}
	return texture(mask_texture, uv).a;
}

void fragment() {
	vec2 blur = TEXTURE_PIXEL_SIZE * blur_pixels;
	float mask = silhouette(TEXTURE, UV) * 0.25;
	mask += (
		silhouette(TEXTURE, UV + vec2(blur.x, 0.0)) +
		silhouette(TEXTURE, UV - vec2(blur.x, 0.0)) +
		silhouette(TEXTURE, UV + vec2(0.0, blur.y)) +
		silhouette(TEXTURE, UV - vec2(0.0, blur.y))
	) * 0.125;
	mask += (
		silhouette(TEXTURE, UV + blur) +
		silhouette(TEXTURE, UV - blur) +
		silhouette(TEXTURE, UV + vec2(blur.x, -blur.y)) +
		silhouette(TEXTURE, UV + vec2(-blur.x, blur.y))
	) * 0.0625;
	// Multiply requires white outside the silhouette; alpha alone does not mask it.
	// Apply inherited opacity here so the shadow fades with the whole card.
	vec3 tone = mix(vec3(1.0), shadow_color.rgb, mask * shadow_strength * item_alpha);
	COLOR = vec4(tone, 1.0);
}
