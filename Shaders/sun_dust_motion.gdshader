shader_type particles;
render_mode disable_force, disable_velocity;

uniform vec2 area_origin = vec2(380.0, 0.0);
uniform vec2 area_size = vec2(1560.0, 1080.0);
uniform vec2 size_range = vec2(3.0, 7.0);
uniform vec2 speed_range = vec2(5.0, 12.0);
uniform float drift_direction = -1.3962634;
uniform float direction_spread = 2.6179939;
uniform float sway = 3.0;
uniform float layer_opacity = 0.9;

float random_value(float seed, float salt) {
	return fract(sin(seed * 12.9898 + salt * 78.233) * 43758.5453);
}

void start() {
	float seed = float(NUMBER) + float(RANDOM_SEED % 4096u);
	vec2 scatter = vec2(random_value(seed, 1.0), random_value(seed, 2.0));
	float diameter = mix(size_range.x, size_range.y, random_value(seed, 3.0));
	TRANSFORM = mat4(1.0);
	TRANSFORM[0].x = diameter / 32.0;
	TRANSFORM[1].y = diameter / 32.0;
	TRANSFORM[3].xy = area_origin + scatter * area_size;
	float heading = drift_direction + (random_value(seed, 4.0) - 0.5) * direction_spread;
	float speed = mix(speed_range.x, speed_range.y, random_value(seed, 5.0));
	VELOCITY = vec3(cos(heading) * speed, sin(heading) * speed, 0.0);
	CUSTOM = vec4(0.0, random_value(seed, 6.0) * TAU, mix(0.25, 0.55, random_value(seed, 7.0)), 0.0);
	COLOR = vec4(1.0, 1.0, 1.0, 0.0);
}

void process() {
	CUSTOM.x += DELTA;
	// Individual age/phase keep trajectories smooth and freeze when speed_scale is zero.
	vec2 air = vec2(sin(CUSTOM.x * CUSTOM.z + CUSTOM.y), cos(CUSTOM.x * CUSTOM.z * 0.73 + CUSTOM.y));
	TRANSFORM[3].xy += (VELOCITY.xy + air * sway) * DELTA;
	float age = CUSTOM.x / LIFETIME;
	COLOR.a = layer_opacity * smoothstep(0.0, 0.15, age) * (1.0 - smoothstep(0.75, 1.0, age));
}
