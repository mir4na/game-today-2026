shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec2 scan_origin_uv = vec2(0.5, 0.72);
uniform float scan_progress : hint_range(0.0, 1.0) = 0.0;
uniform float scan_aspect : hint_range(0.25, 8.0) = 2.85;
uniform float ring_width : hint_range(0.002, 0.2) = 0.025;
uniform float ring_softness : hint_range(0.001, 0.1) = 0.018;
uniform float trail_strength : hint_range(0.0, 1.0) = 0.2;
uniform float grid_strength : hint_range(0.0, 1.0) = 0.16;
uniform vec4 ring_color : source_color = vec4(0.2, 0.9, 1.0, 0.92);
uniform vec4 trail_color : source_color = vec4(0.08, 0.48, 0.78, 0.32);

float grid_line(float coordinate, float cells, float thickness) {
	float cell_distance = abs(fract(coordinate * cells) - 0.5);
	return 1.0 - smoothstep(thickness, thickness + 0.035, cell_distance);
}

void fragment() {
	vec2 delta = UV - scan_origin_uv;
	delta.x *= scan_aspect;

	vec2 farthest_corner = vec2(
		max(scan_origin_uv.x, 1.0 - scan_origin_uv.x) * scan_aspect,
		max(scan_origin_uv.y, 1.0 - scan_origin_uv.y)
	);
	float maximum_radius = max(length(farthest_corner), 0.001);
	float radius = scan_progress * maximum_radius;
	float distance_from_origin = length(delta);

	float ring_distance = abs(distance_from_origin - radius);
	float ring = 1.0 - smoothstep(ring_width, ring_width + ring_softness, ring_distance);
	float swept_area = 1.0 - smoothstep(
		radius - ring_width * 2.0,
		radius + ring_softness,
		distance_from_origin
	);
	float horizontal_grid = grid_line(UV.y, 8.0, 0.035);
	float vertical_grid = grid_line(UV.x, 24.0, 0.035);
	float grid = max(horizontal_grid, vertical_grid) * grid_strength;
	float data_pulse = 0.72 + 0.28 * sin(distance_from_origin * 62.0 - scan_progress * 31.0);
	float source_pulse = 1.0 - smoothstep(0.0, 0.055, distance_from_origin);

	float trail_alpha = swept_area * trail_strength * (0.42 + grid) * data_pulse;
	float alpha = clamp(ring * ring_color.a + trail_alpha * trail_color.a + source_pulse * 0.5, 0.0, 1.0);
	vec3 color = ring_color.rgb * (ring + source_pulse * 0.65) + trail_color.rgb * trail_alpha;
	COLOR = vec4(color, alpha);
}
