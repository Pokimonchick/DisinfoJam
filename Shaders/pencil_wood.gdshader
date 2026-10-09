shader_type spatial;

uniform vec4 wood_color : source_color = vec4(0.82, 0.70, 0.49, 1.0);
uniform vec4 paint_color : source_color = vec4(0.74, 0.055, 0.025, 1.0);
uniform sampler2D lacquer_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float tip_length = 0.34;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.32;

varying float tip_along;
varying float tip_angle;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 part = fract(point);
	part = part * part * (3.0 - 2.0 * part);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), part.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), part.x), part.y);
}

void vertex() {
	tip_along = clamp(VERTEX.y / tip_length + 0.5, 0.0, 1.0);
	tip_angle = atan(VERTEX.z, VERTEX.x);
	float sector = mod(tip_angle + 0.5235988, 1.0471976) - 0.5235988;
	float bevel = smoothstep(0.39, 0.5235988, abs(sector));
	float rounding = smoothstep(0.0, 0.8, tip_along);
	float hexagon = 0.8660254 / cos(sector) * mix(1.0, 0.98, bevel);
	VERTEX.xz *= mix(hexagon, 1.0, rounding);
	if (abs(NORMAL.y) < 0.9) {
		vec2 face = vec2(cos(tip_angle - sector), sin(tip_angle - sector));
		vec2 radial = vec2(cos(tip_angle), sin(tip_angle));
		vec2 normal = normalize(mix(face, radial, max(bevel, rounding)));
		NORMAL = normalize(vec3(normal.x * length(NORMAL.xz), NORMAL.y, normal.y * length(NORMAL.xz)));
	}
}

void fragment() {
	float fibers = noise(UV * vec2(180.0, 3.0));
	float fine_fibers = noise(UV * vec2(420.0, 12.0));
	float cuts = noise(UV * vec2(38.0, 9.0));
	vec3 wood = wood_color.rgb * (1.0 + (fibers - 0.5) * grain_strength
		+ (fine_fibers - 0.5) * grain_strength * 0.55 + (cuts - 0.5) * 0.08);
	// A sharpener leaves six scallops where lacquer meets the exposed wood.
	float paint_edge = 0.055 + pow(abs(cos(tip_angle * 3.0)), 2.0) * 0.13;
	paint_edge += (noise(UV * vec2(60.0, 15.0)) - 0.5) * 0.02;
	float painted = 1.0 - smoothstep(paint_edge - 0.004, paint_edge + 0.004, tip_along);
	vec3 lacquer = mix(paint_color.rgb, texture(lacquer_texture, vec2(UV.x, tip_along * 0.12)).rgb, 0.90);
	ALBEDO = mix(wood, lacquer, painted);
	METALLIC = 0.0;
	SPECULAR = mix(0.16, 0.30, painted);
	ROUGHNESS = mix(0.90, 0.56, painted);
}
