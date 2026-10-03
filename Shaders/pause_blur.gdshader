shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 6.0, 0.1) = 3.0;
uniform vec4 dim_color : source_color = vec4(0.08, 0.06, 0.04, 0.34);

void fragment() {
	vec3 backdrop = textureLod(screen_texture, SCREEN_UV, blur_amount).rgb;
	// Alpha controls the translucent tint over the blurred game, not the menu.
	COLOR = vec4(mix(backdrop, dim_color.rgb, dim_color.a), 1.0);
}
