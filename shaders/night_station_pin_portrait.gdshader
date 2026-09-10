shader_type canvas_item;
// Keeps the upper-body portrait inside the round head of a station pin.

void fragment() {
	vec4 portrait = texture(TEXTURE, UV) * COLOR;
	vec2 from_center = UV * 2.0 - vec2(1.0);
	float circle_distance = dot(from_center, from_center);
	float circle_alpha = 1.0 - smoothstep(0.90, 1.0, circle_distance);
	COLOR = vec4(portrait.rgb, portrait.a * circle_alpha);
}
