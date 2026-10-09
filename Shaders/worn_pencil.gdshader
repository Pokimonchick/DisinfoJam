shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 paint_color : source_color = vec4(0.74, 0.055, 0.025, 1.0);
uniform vec4 wood_color : source_color = vec4(0.82, 0.70, 0.49, 1.0);
uniform sampler2D lacquer_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float wear : hint_range(0.0, 1.0) = 0.36;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.20;
uniform float bite_strength : hint_range(0.0, 1.0) = 0.65;

float dent(vec2 uv, vec2 center, vec2 radius) {
	vec2 distance = (uv - center) / radius;
	return 1.0 - smoothstep(0.3, 1.0, dot(distance, distance));
}
float bites(vec2 uv) {
	return max(max(dent(uv, vec2(0.24, 0.92), vec2(0.035, 0.025)),
		dent(uv, vec2(0.28, 0.97), vec2(0.028, 0.020))),
		max(dent(uv, vec2(0.73, 0.91), vec2(0.032, 0.025)),
		dent(uv, vec2(0.77, 0.965), vec2(0.028, 0.022))));
}
void vertex() {
	// Extra rings let the small tooth dents change the actual silhouette.
	// Subdivided faces keep a six-sided profile while sampling dents inside a face.
	float angle = atan(VERTEX.z, VERTEX.x);
	float sector = mod(angle + 0.5235988, 1.0471976) - 0.5235988;
	float bevel = smoothstep(0.39, 0.5235988, abs(sector));
	VERTEX.xz *= 0.8660254 / cos(sector) * mix(1.0, 0.98, bevel);
	VERTEX.xz *= 1.0 - bites(UV) * bite_strength * 0.10;
	if (abs(NORMAL.y) < 0.5) {
		vec2 face = vec2(cos(angle - sector), sin(angle - sector));
		vec2 round_edge = vec2(cos(angle), sin(angle));
		vec2 normal = normalize(mix(face, round_edge, bevel));
		NORMAL = vec3(normal.x, 0.0, normal.y);
	}
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1)), f.x), f.y);
}
void fragment() {
	float patches = noise(UV * vec2(18.0, 14.0));
	float grain = noise(UV * vec2(65.0, 5.0));
	float scratches = noise(UV * vec2(100.0, 8.0));
	float tooth_chips = smoothstep(0.18, 0.55, bites(UV)) * smoothstep(0.0, 0.2, bite_strength);
	float chip_noise = noise(UV * vec2(95.0, 130.0));
	float spots = max(max(dent(UV, vec2(0.24, 0.47), vec2(0.022, 0.014)),
		dent(UV, vec2(0.72, 0.64), vec2(0.022, 0.014))),
		max(dent(UV, vec2(0.24, 0.68), vec2(0.020, 0.011)),
		dent(UV, vec2(0.73, 0.27), vec2(0.025, 0.009))));
	// Wear changes the chipped area; each exposed patch is actual wood, not pink paint.
	float threshold = mix(1.25, 0.45, wear);
	float chips = max(tooth_chips, smoothstep(threshold, threshold + 0.12, spots + chip_noise * 0.30));
	float facet_edge = abs(fract(UV.x * 6.0 + 0.5) - 0.5);
	float edge_chips = (1.0 - smoothstep(0.006, 0.025, facet_edge))
		* smoothstep(1.0 - wear * 0.70, 1.12 - wear * 0.70, noise(UV * vec2(18.0, 28.0)));
	chips = max(chips, edge_chips);
	vec3 lacquer = mix(paint_color.rgb, texture(lacquer_texture, UV).rgb, 0.90);
	lacquer *= 0.98 + (patches - 0.5) * 0.04 + (grain - 0.5) * grain_strength * 0.25;
	lacquer *= 1.0 - (scratches - 0.5) * wear * 0.14;
	vec3 wood = wood_color.rgb * (1.0 - grain * grain_strength * 0.4);
	ALBEDO = mix(lacquer, wood, chips);
	METALLIC = 0.0;
	SPECULAR = 0.30;
	ROUGHNESS = mix(0.56, 0.90, chips);
}
