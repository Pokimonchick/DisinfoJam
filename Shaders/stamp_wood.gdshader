shader_type spatial;

uniform vec4 wood_color : source_color = vec4(0.40, 0.25, 0.14, 1.0);
uniform vec3 grain_direction = vec3(0.0, 0.3, 1.0);
uniform vec3 flow_direction = vec3(1.0, 0.0, 0.0);
uniform float grain_frequency : hint_range(8.0, 80.0) = 38.0;
uniform float grain_strength : hint_range(0.0, 0.3) = 0.14;

varying vec3 wood_position;

void vertex() {
	wood_position = VERTEX;
}

void fragment() {
	float along = dot(wood_position, flow_direction);
	float across = dot(wood_position, grain_direction);
	float phase = across * grain_frequency;
	phase += sin(along * 5.7 + across * 3.0) * 0.52;
	phase += sin(along * 11.5) * 0.14;
	float grain = sin(phase) * 0.38;
	grain += sin(phase * 2.11 + sin(along * 9.0)) * 0.12;
	ALBEDO = wood_color.rgb * (1.0 + grain * grain_strength);
	METALLIC = 0.0;
	SPECULAR = 0.16;
	ROUGHNESS = 0.88;
}
