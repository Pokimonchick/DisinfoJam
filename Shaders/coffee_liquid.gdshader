shader_type canvas_item;
render_mode unshaded;

uniform float animation_time = 0.0;
uniform float speed : hint_range(0.0, 2.0, 0.01) = 0.55;
uniform float ripple_strength : hint_range(0.0, 0.15, 0.005) = 0.055;
uniform float opacity : hint_range(0.0, 1.0) = 0.85;

varying vec4 item_modulate;

void vertex() {
	item_modulate = COLOR;
}

void fragment() {
	vec2 surface = (UV - vec2(0.5)) * 2.0;
	float radius = length(surface);
	// All motion shares a full-turn period, so the surface loops without a jump.
	float phase = mod(animation_time * speed, 6.28318530718);
	float angle = phase + ripple_strength * sin(radius * 7.0 - phase * 2.0);
	float cosine = cos(angle);
	float sine = sin(angle);
	vec2 flow = vec2(
		cosine * surface.x - sine * surface.y,
		sine * surface.x + cosine * surface.y
	);
	flow += vec2(sin(phase + surface.y * 5.0), cos(phase * 2.0 + surface.x * 4.0))
		* ripple_strength * max(0.0, 1.0 - radius);
	vec2 sample_uv = flow * 0.5 + vec2(0.5);
	vec4 liquid = texture(TEXTURE, sample_uv);
	float inside_texture = step(0.0, sample_uv.x) * step(sample_uv.x, 1.0)
		* step(0.0, sample_uv.y) * step(sample_uv.y, 1.0);
	// Clip the moving artwork to the coffee, keeping the cup's rim untouched.
	float surface_mask = 1.0 - smoothstep(0.94, 1.0, radius);
	COLOR = liquid * item_modulate;
	COLOR.a *= inside_texture * surface_mask * opacity;
}
