shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 aluminum_color : source_color = vec4(0.65, 0.65, 0.60, 1.0);
uniform float bite_strength : hint_range(0.0, 1.0) = 0.65;

float dent(vec2 uv, vec2 center) {
	vec2 distance = (uv - center) / vec2(0.040, 0.095);
	return 1.0 - smoothstep(0.15, 1.0, dot(distance, distance));
}
float bites(vec2 uv) {
	return max(max(dent(uv, vec2(0.25, 0.42)), dent(uv, vec2(0.29, 0.64))),
		max(dent(uv, vec2(0.73, 0.40)), dent(uv, vec2(0.78, 0.66))));
}
void vertex() {
	float ring_distance = min(min(abs(UV.y - 0.10), abs(UV.y - 0.20)),
		min(abs(UV.y - 0.80), abs(UV.y - 0.90)));
	float rib = 1.0 - smoothstep(0.014, 0.045, ring_distance);
	VERTEX.xz *= 1.0 + rib * 0.055 - bites(UV) * bite_strength * 0.16;
}
void fragment() {
	// Broad diffuse planes and subdued reflections match the wooden desk stamp.
	vec3 face_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = dot(face_normal, NORMAL) < 0.0 ? -face_normal : face_normal;
	float mottling = sin(UV.x * 51.0 + sin(UV.y * 17.0)) * 0.015;
	ALBEDO = aluminum_color.rgb * (1.0 + mottling - bites(UV) * bite_strength * 0.08);
	METALLIC = 0.12;
	SPECULAR = 0.15;
	ROUGHNESS = 0.82;
}
