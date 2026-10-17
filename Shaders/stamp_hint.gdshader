shader_type canvas_item;

uniform bool hint_active = false;
uniform float hint_strength : hint_range(0.0, 0.5) = 0.22;
uniform float hint_speed : hint_range(0.1, 2.0) = 0.45;
uniform vec4 hint_color : source_color = vec4(1.0, 0.80, 0.40, 1.0);
varying vec4 canvas_tint;

void vertex() {
	canvas_tint = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV) * canvas_tint;
	if (hint_active) {
		// A slow breath in the 2D image; the 3D viewport stays cached at rest.
		float pulse = 0.65 + 0.35 * sin(TIME * hint_speed * 6.283185);
		vec2 step_uv = TEXTURE_PIXEL_SIZE * 5.0;
		float nearby = 0.0;
		nearby += texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a;
		nearby += texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a;
		nearby += texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a;
		nearby += texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a;
		nearby += texture(TEXTURE, UV + step_uv * 0.7071).a;
		nearby += texture(TEXTURE, UV - step_uv * 0.7071).a;
		nearby += texture(TEXTURE, UV + vec2(step_uv.x, -step_uv.y) * 0.7071).a;
		nearby += texture(TEXTURE, UV + vec2(-step_uv.x, step_uv.y) * 0.7071).a;
		float glow = nearby * 0.125 * (1.0 - base.a) * hint_strength * pulse * canvas_tint.a;
		float alpha = base.a + glow;
		vec3 tinted = mix(base.rgb, hint_color.rgb, hint_strength * pulse * 0.45);
		base = vec4((tinted * base.a + hint_color.rgb * glow) / max(alpha, 0.0001), alpha);
	}
	COLOR = base;
}
