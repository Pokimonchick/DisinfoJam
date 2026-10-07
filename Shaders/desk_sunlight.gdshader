shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 light_color : source_color = vec4(1.0, 0.95, 0.79, 1.0);
uniform float strength : hint_range(0.0, 0.8, 0.01) = 0.30;
uniform float speed : hint_range(0.0, 2.0, 0.01) = 0.55;
uniform float sway : hint_range(0.0, 0.262, 0.001) = 0.0610865;
uniform float reach : hint_range(500.0, 3000.0, 10.0) = 1700.0;
uniform float source_glow : hint_range(0.0, 1.0) = 0.38;
uniform float direction = 0.0;
uniform float ray_width : hint_range(0.25, 3.0) = 1.0;
uniform float ray_spacing : hint_range(0.25, 2.5) = 1.0;
uniform float width_variation : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float shimmer : hint_range(0.0, 1.0, 0.01) = 0.70;
// Position is relative to the effect rectangle; the source sits just off screen.
uniform vec2 light_position = vec2(0.975, -0.035);
uniform vec2 rect_size = vec2(2120.0, 1240.0);
uniform float animation_time = 0.0;

varying float item_alpha;

void vertex() {
	item_alpha = COLOR.a;
}

float ray(float angle, float distance, float center, float width, float phase, float time) {
	center = 0.90 + (center - 0.90) * ray_spacing;
	// Each shaft drifts at its own pace rather than rocking the entire fan.
	float drift = sin(time * (0.82 + phase * 0.025) + phase);
	drift += 0.35 * sin(time * 1.63 + phase * 2.7);
	center += drift * sway / 1.35;
	float moving_width = width * ray_width;
	moving_width *= 1.0 + sin(time * 0.9 + phase * 1.4) * width_variation * 0.55;
	float angle_delta = mod(angle - center + 3.14159265, 6.28318531) - 3.14159265;
	float profile = angle_delta / moving_width;
	float pulse = 0.5 + 0.5 * sin(time * (1.08 + phase * 0.04) + phase * 1.7);
	float breathing = mix(1.0, smoothstep(0.1, 0.9, pulse), shimmer);
	// Light travels along the shafts, as if thin haze passes through them.
	float flow = 0.76 + 0.24 * sin(distance * 0.006 - time * 2.4 + phase);
	return exp(-profile * profile) * breathing * mix(1.0, flow, shimmer);
}

void fragment() {
	// Pixel coordinates keep the fan undistorted on the wide desk canvas.
	vec2 from_light = (UV - light_position) * rect_size;
	float distance_from_light = length(from_light);
	float angle = atan(from_light.y, -from_light.x) - direction;
	float time = animation_time * speed;

	// Unequal, feathered shafts open towards the lower left, like the reference.
	float beams = ray(angle, distance_from_light, 0.30, 0.032, 0.4, time) * 0.45;
	beams += ray(angle, distance_from_light, 0.49, 0.048, 2.1, time) * 0.65;
	beams += ray(angle, distance_from_light, 0.71, 0.038, 4.0, time) * 0.55;
	beams += ray(angle, distance_from_light, 0.93, 0.070, 1.2, time) * 0.80;
	beams += ray(angle, distance_from_light, 1.17, 0.045, 3.2, time) * 0.65;
	beams += ray(angle, distance_from_light, 1.42, 0.085, 5.3, time);
	float falloff = exp(-distance_from_light / reach);
	float corner_glow = exp(-dot(from_light, from_light) / (460.0 * 460.0));
	float light = (beams * falloff + corner_glow * source_glow) * strength;
	COLOR = vec4(light_color.rgb, light * light_color.a * item_alpha);
}
