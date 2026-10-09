shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 paint_color : source_color = vec4(0.56, 0.24, 0.20, 1.0);
uniform vec4 wood_color : source_color = vec4(0.73, 0.62, 0.43, 1.0);
uniform float wear : hint_range(0.0, 1.0) = 0.48;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.18;

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
	float face_edge = 1.0 - smoothstep(0.0, 0.11, min(fract(UV.x * 6.0), 1.0 - fract(UV.x * 6.0)));
	float patches = noise(UV * vec2(47.0, 18.0));
	float end_wear = smoothstep(0.70, 0.98, UV.y);
	float large_chips = noise(UV * vec2(18.0, 11.0));
	float threshold = mix(1.1, 0.69, wear);
	float chips = smoothstep(threshold, threshold + 0.05, large_chips + face_edge * wear * 0.34 + end_wear * wear * 0.34);
	float flecks = smoothstep(0.71, 0.77, noise(UV * vec2(200.0, 95.0))) * wear;
	float scratches = smoothstep(0.68, 0.82, noise(UV * vec2(230.0, 6.0))) * noise(UV * vec2(38.0, 55.0)) * wear;
	float grain = noise(UV * vec2(180.0, 10.0));
	vec3 lacquer = paint_color.rgb * (0.9 + 0.16 * patches);
	vec3 wood = wood_color.rgb * (1.0 - grain * grain_strength);
	ALBEDO = mix(lacquer, wood, clamp(chips + flecks * 0.85 + scratches * 0.65, 0.0, 1.0));
	ROUGHNESS = mix(0.65, 0.92, chips);
}
