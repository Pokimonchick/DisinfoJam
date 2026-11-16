shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec4 glint = COLOR;
	vec3 room = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	vec3 overlay = mix(2.0 * room * glint.rgb,
		1.0 - 2.0 * (1.0 - room) * (1.0 - glint.rgb), step(vec3(0.5), room));
	COLOR = vec4(overlay, glint.a);
}
