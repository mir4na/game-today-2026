shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 glow_color : source_color = vec4(1.0, 0.035, 0.02, 0.78);
uniform float edge_feather : hint_range(0.01, 0.35, 0.01) = 0.12;
uniform float center_strength : hint_range(0.0, 2.0, 0.05) = 0.9;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float edge_x = 1.0 - smoothstep(0.5 - edge_feather, 0.5, abs(centered_uv.x));
	float edge_y = 1.0 - smoothstep(0.5 - edge_feather, 0.5, abs(centered_uv.y));
	float radial = 1.0 - smoothstep(0.08, 0.72, length(vec2(centered_uv.x, centered_uv.y * 1.45)));
	float intensity = (0.22 + radial * center_strength) * edge_x * edge_y;
	COLOR = vec4(glow_color.rgb * intensity, glow_color.a * intensity);
}
