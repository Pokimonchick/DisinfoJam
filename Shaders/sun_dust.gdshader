shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 dust_color : source_color = vec4(1.0, 0.97, 0.88, 1.0);
uniform float opacity = 0.85;
uniform float brightness = 1.6;
uniform float softness = 0.65;
uniform float light_gain = 14.0;
uniform float visibility_floor = 0.12;
// Read-only copies of the existing Sunlight material, synchronized by SunDust.
uniform vec4 light_color : source_color = vec4(1.0, 0.95, 0.79, 1.0);
uniform float strength = 0.0;
uniform float speed = 0.0;
uniform float sway = 0.0;
uniform float reach = 1700.0;
uniform float source_glow = 0.38;
uniform float direction = 0.0;
uniform float ray_width = 1.0;
uniform float ray_spacing = 1.0;
uniform float width_variation = 0.0;
uniform float shimmer = 0.24;
uniform vec2 light_position = vec2(0.975, -0.035);
uniform vec2 rect_size = vec2(2120.0, 1240.0);
uniform float animation_time = 0.0;
uniform vec2 light_inverse_x = vec2(1.0, 0.0);
uniform vec2 light_inverse_y = vec2(0.0, 1.0);
uniform vec2 light_inverse_origin = vec2(100.0, 80.0);

varying vec2 light_local_position;
varying vec4 particle_color;

void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	light_local_position = light_inverse_origin + light_inverse_x * world.x + light_inverse_y * world.y;
	particle_color = COLOR;
}

// The shaft profile follows desk_sunlight.gdshader without changing that shader.
float ray(float angle, float distance, float center, float width, float phase, float time) {
	center = 0.90 + (center - 0.90) * ray_spacing;
	float drift = sin(time * (0.82 + phase * 0.025) + phase);
	drift += 0.35 * sin(time * 1.63 + phase * 2.7);
	center += drift * sway / 1.35;
	float moving_width = width * ray_width;
	moving_width *= 1.0 + sin(time * 0.9 + phase * 1.4) * width_variation * 0.55;
	float angle_delta = mod(angle - center + PI, TAU) - PI;
	float profile = angle_delta / max(moving_width, 0.0001);
	float pulse = 0.5 + 0.5 * sin(time * (1.08 + phase * 0.04) + phase * 1.7);
	float breathing = mix(1.0, smoothstep(0.1, 0.9, pulse), shimmer);
	float flow = 0.76 + 0.24 * sin(distance * 0.006 - time * 2.4 + phase);
	return exp(-profile * profile) * breathing * mix(1.0, flow, shimmer);
}

void fragment() {
	vec2 from_light = light_local_position - light_position * rect_size;
	float distance_from_light = length(from_light);
	float angle = atan(from_light.y, -from_light.x) - direction;
	float time = animation_time * speed;
	float beams = ray(angle, distance_from_light, 0.30, 0.032, 0.4, time) * 0.45;
	beams += ray(angle, distance_from_light, 0.49, 0.048, 2.1, time) * 0.65;
	beams += ray(angle, distance_from_light, 0.71, 0.038, 4.0, time) * 0.55;
	beams += ray(angle, distance_from_light, 0.93, 0.070, 1.2, time) * 0.80;
	beams += ray(angle, distance_from_light, 1.17, 0.045, 3.2, time) * 0.65;
	beams += ray(angle, distance_from_light, 1.42, 0.085, 5.3, time);
	float falloff = exp(-distance_from_light / max(reach, 1.0));
	float glow = exp(-dot(from_light, from_light) / (460.0 * 460.0)) * source_glow;
	float illumination = clamp((beams * falloff + glow) * strength * light_gain * light_color.a, 0.0, 1.0);
	illumination = max(illumination, visibility_floor * clamp(strength * light_color.a * 8.0, 0.0, 1.0));
	// A readable core with feathered edges; the texture supplies the particle quad size.
	float core_radius = 0.5 * (1.0 - clamp(softness, 0.05, 1.0));
	float grain = 1.0 - smoothstep(core_radius, 0.5, length(UV - vec2(0.5)));
	vec3 tint = dust_color.rgb * mix(vec3(1.0), light_color.rgb, 0.35) * brightness;
	COLOR = vec4(tint, grain * particle_color.a * opacity * dust_color.a * illumination);
}
