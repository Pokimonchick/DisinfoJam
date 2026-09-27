shader_type canvas_item;
render_mode unshaded;

uniform float strength : hint_range(0.0, 0.5) = 0.18;
uniform float speed : hint_range(0.0, 1.0) = 0.12;

void fragment() {
	float drift = sin(TIME * speed) * 0.018;
	float diagonal = UV.y + UV.x * 0.53 + drift;
	float bands = smoothstep(0.06, 0.09, fract(diagonal * 2.15));
	bands *= 1.0 - smoothstep(0.40, 0.44, fract(diagonal * 2.15));
	float warmth = (1.0 - UV.y) * 0.055;
	COLOR = vec4(mix(vec3(1.0, 0.83, 0.40), vec3(0.24, 0.18, 0.05), bands), warmth + bands * strength);
}
