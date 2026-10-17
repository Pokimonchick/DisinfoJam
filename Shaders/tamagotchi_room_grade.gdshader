shader_type canvas_item;
render_mode unshaded;

uniform float contrast : hint_range(0.8, 1.3) = 1.10;
uniform float saturation : hint_range(0.8, 1.3) = 1.08;

void fragment() {
	vec4 room = COLOR;
	float luminance = dot(room.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 color = mix(vec3(luminance), room.rgb, saturation);
	COLOR = vec4(clamp((color - 0.5) * contrast + 0.5, 0.0, 1.0), room.a);
}
