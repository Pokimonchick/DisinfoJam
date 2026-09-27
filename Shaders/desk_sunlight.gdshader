shader_type canvas_item;
render_mode blend_mul, unshaded;

uniform float shadow_strength : hint_range(0.0, 0.8) = 0.42;
uniform float speed : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	// World-space boundaries follow the two broad diagonals in the desk reference.
	vec2 desk = UV * vec2(2120.0, 1240.0) + vec2(-100.0, -80.0);
	float upper_edge = 630.0 - 0.435 * desk.x + sin(TIME * speed) * 15.0;
	float lower_edge = 1306.0 - 0.32 * desk.x + sin(TIME * speed * 0.83 + 1.1) * 18.0;
	float upper_shadow = 1.0 - smoothstep(-8.0, 8.0, desk.y - upper_edge);
	float lower_shadow = smoothstep(-8.0, 8.0, desk.y - lower_edge);
	float beam_center = 900.0 - 0.40 * desk.x + sin(TIME * speed * 0.72) * 24.0;
	float beam = exp(-pow((desk.y - beam_center) / 135.0, 2.0));
	float brightness = 1.0 - upper_shadow * shadow_strength - lower_shadow * (shadow_strength * 0.55);
	brightness += beam * (1.0 - max(upper_shadow, lower_shadow)) * 0.055;
	COLOR = vec4(vec3(brightness), 1.0);
}
