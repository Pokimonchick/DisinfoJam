shader_type canvas_item;
render_mode blend_mul, unshaded;

uniform float paper_cutoff : hint_range(0.0, 0.3) = 0.08;
uniform float edge_softness : hint_range(0.01, 0.3) = 0.12;
uniform float ink_opacity : hint_range(0.0, 1.0) = 0.95;

varying float item_alpha;

void vertex() {
	item_alpha = COLOR.a;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	// The supplied PNG has a cream paper background. Keep only the red ink;
	// white is neutral for Multiply and leaves the existing article visible.
	float redness = max(source.r - max(source.g, source.b), 0.0);
	float mask = smoothstep(paper_cutoff, paper_cutoff + edge_softness, redness) * source.a;
	vec3 tone = mix(vec3(1.0), source.rgb, mask * ink_opacity * item_alpha);
	COLOR = vec4(tone, 1.0);
}
