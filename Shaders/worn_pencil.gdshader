shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 paint_color : source_color = vec4(0.74, 0.055, 0.025, 1.0);
uniform vec4 wood_color : source_color = vec4(0.82, 0.70, 0.49, 1.0);
uniform float wear : hint_range(0.0, 1.0) = 0.24;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.10;
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
	VERTEX.xz *= 0.8660254 / cos(sector);
	VERTEX.xz *= 1.0 - bites(UV) * bite_strength * 0.10;
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
	vec3 face_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = dot(face_normal, NORMAL) < 0.0 ? -face_normal : face_normal;
	float patches = noise(UV * vec2(18.0, 14.0));
	float grain = noise(UV * vec2(65.0, 5.0));
	float scratches = noise(UV * vec2(100.0, 8.0));
	float tooth_chips = smoothstep(0.35, 0.65, bites(UV)) * bite_strength;
	float chip_noise = noise(UV * vec2(95.0, 130.0));
	float spots = max(dent(UV, vec2(0.24, 0.47), vec2(0.018, 0.012)),
		dent(UV, vec2(0.72, 0.64), vec2(0.022, 0.014)));
	float chips = clamp(tooth_chips + smoothstep(0.4, 0.75, spots + chip_noise * 0.18) * wear, 0.0, 1.0);
	vec3 lacquer = paint_color.rgb * (0.97 + (patches - 0.5) * 0.06 + (grain - 0.5) * grain_strength);
	lacquer *= 1.0 - (scratches - 0.5) * wear * 0.06;
	vec3 wood = wood_color.rgb * (1.0 - grain * grain_strength * 0.4);
	ALBEDO = mix(lacquer, wood, chips);
	METALLIC = 0.0;
	SPECULAR = 0.12;
	ROUGHNESS = 0.86;
}
