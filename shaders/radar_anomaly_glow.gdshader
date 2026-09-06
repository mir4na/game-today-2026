shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 glow_color : source_color = vec4(1.0, 0.24, 0.035, 0.68);
uniform float glow_aspect : hint_range(0.25, 8.0) = 2.85;
uniform float edge_width : hint_range(0.002, 0.2, 0.002) = 0.012;
uniform float edge_feather : hint_range(0.002, 0.2, 0.002) = 0.018;

void fragment() {
	float horizontal_edge_distance = min(UV.x, 1.0 - UV.x) * glow_aspect;
	float vertical_edge_distance = min(UV.y, 1.0 - UV.y);
	float edge_distance = min(horizontal_edge_distance, vertical_edge_distance);
	float perimeter = 1.0 - smoothstep(edge_width, edge_width + edge_feather, edge_distance);
	COLOR = vec4(glow_color.rgb * perimeter, glow_color.a * perimeter);
}
