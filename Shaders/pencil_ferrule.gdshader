shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 aluminum_color : source_color = vec4(0.72, 0.72, 0.70, 1.0);
uniform float bite_strength : hint_range(0.0, 1.0) = 0.65;
uniform float ferrule_length = 0.286667;
uniform float ferrule_radius = 0.128;

float dent(vec2 uv, vec2 center) {
	vec2 distance = (uv - center) / vec2(0.040, 0.095);
	return 1.0 - smoothstep(0.15, 1.0, dot(distance, distance));
}
float bites(vec2 uv) {
	return max(max(dent(uv, vec2(0.25, 0.42)), dent(uv, vec2(0.29, 0.64))),
		max(dent(uv, vec2(0.73, 0.40)), dent(uv, vec2(0.78, 0.66))));
}
float profile(vec2 uv) {
	float ring_distance = min(min(abs(uv.y - 0.10), abs(uv.y - 0.20)),
		min(abs(uv.y - 0.80), abs(uv.y - 0.90)));
	float rib = 1.0 - smoothstep(0.014, 0.045, ring_distance);
	return 1.0 + rib * 0.055 - bites(uv) * bite_strength * 0.16;
}
void vertex() {
	float radius = profile(UV);
	if (abs(NORMAL.y) < 0.5) {
		vec3 radial = normalize(vec3(VERTEX.x, 0.0, VERTEX.z));
		vec3 tangent = normalize(TANGENT);
		float along = (profile(UV + vec2(0.0, 0.002)) - profile(UV - vec2(0.0, 0.002))) / 0.004;
		float across = (profile(UV + vec2(0.002, 0.0)) - profile(UV - vec2(0.002, 0.0))) / 0.004;
		// Smooth normals follow the rings and tooth dents rather than a plain cylinder.
		NORMAL = normalize(radial - tangent * across / (6.2831853 * radius)
			+ vec3(0.0, along * ferrule_radius / ferrule_length, 0.0));
	}
	VERTEX.xz *= radius;
}
void fragment() {
	float mottling = sin(UV.x * 51.0 + sin(UV.y * 17.0)) * 0.015;
	ALBEDO = aluminum_color.rgb * (1.0 + mottling - bites(UV) * bite_strength * 0.08);
	METALLIC = 0.65;
	SPECULAR = 0.40;
	ROUGHNESS = 0.44;
}
