shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform vec4 dim_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float dim_alpha : hint_range(0.0, 1.0) = 0.62;
uniform vec2 spotlight_center = vec2(0.5, 0.5);
uniform float spotlight_radius : hint_range(0.01, 0.6) = 0.115;
uniform float spotlight_softness : hint_range(0.001, 0.5) = 0.12;
uniform float viewport_aspect : hint_range(0.1, 4.0) = 1.7778;
uniform float inner_alpha : hint_range(0.0, 0.4) = 0.0;

void fragment() {
	vec2 delta = SCREEN_UV - spotlight_center;
	delta.x *= viewport_aspect;
	float distance_from_center = length(delta);
	float outside_spotlight = smoothstep(
		spotlight_radius,
		spotlight_radius + spotlight_softness,
		distance_from_center
	);
	float alpha = mix(inner_alpha, dim_alpha, outside_spotlight);
	COLOR = vec4(dim_color.rgb, alpha * dim_color.a);
}
