shader_type canvas_item;
render_mode unshaded, blend_add;

// Scene-bounded inspection grid. A radial wave expands from the player inside
// the current passenger coach; every visual property remains editable here.
uniform float scan_progress : hint_range(0.0, 1.0) = 0.0;
uniform float scan_aspect : hint_range(0.25, 8.0) = 2.85;
uniform vec2 scan_origin = vec2(0.5, 0.88);
uniform float band_width : hint_range(0.04, 0.5, 0.01) = 0.24;
uniform float grid_density : hint_range(3.0, 32.0, 1.0) = 11.0;
uniform float grid_line_width : hint_range(0.005, 0.15, 0.005) = 0.035;
uniform float grid_feather : hint_range(0.001, 0.08, 0.001) = 0.018;
uniform float edge_width : hint_range(0.002, 0.08, 0.002) = 0.004;
uniform float edge_glow_width : hint_range(0.005, 0.2, 0.005) = 0.022;
uniform float fill_strength : hint_range(0.0, 0.5, 0.01) = 0.04;
uniform float scanned_grid_strength : hint_range(0.0, 1.0, 0.01) = 0.46;
uniform float scanned_fill_strength : hint_range(0.0, 0.25, 0.005) = 0.025;
uniform float trail_falloff : hint_range(0.25, 6.0, 0.05) = 2.25;
uniform float warp_strength : hint_range(0.0, 0.08, 0.002) = 0.004;
uniform vec4 grid_color : source_color = vec4(0.24, 1.0, 0.56, 0.68);
uniform vec4 edge_color : source_color = vec4(0.52, 1.0, 0.70, 0.92);


float grid_axis(float coordinate) {
	float distance_to_line = min(fract(coordinate), 1.0 - fract(coordinate));
	return 1.0 - smoothstep(grid_line_width, grid_line_width + grid_feather, distance_to_line);
}


void fragment() {
	float lifecycle = smoothstep(0.0, 0.025, scan_progress);
	vec2 radial_delta = UV - scan_origin;
	radial_delta.x *= scan_aspect;
	float radial_distance = length(radial_delta);
	float maximum_radius = 0.0;
	maximum_radius = max(maximum_radius, length(vec2((0.0 - scan_origin.x) * scan_aspect, 0.0 - scan_origin.y)));
	maximum_radius = max(maximum_radius, length(vec2((1.0 - scan_origin.x) * scan_aspect, 0.0 - scan_origin.y)));
	maximum_radius = max(maximum_radius, length(vec2((0.0 - scan_origin.x) * scan_aspect, 1.0 - scan_origin.y)));
	maximum_radius = max(maximum_radius, length(vec2((1.0 - scan_origin.x) * scan_aspect, 1.0 - scan_origin.y)));
	float scan_radius = mix(-band_width, maximum_radius + band_width, scan_progress);
	float distance_behind = scan_radius - radial_distance;
	float scanned_area = step(radial_distance, scan_radius);
	float inside_band = step(0.0, distance_behind) * step(distance_behind, band_width);
	float trail = pow(clamp(1.0 - distance_behind / max(band_width, 0.001), 0.0, 1.0), trail_falloff);

	// A slight wave keeps the projected mesh from looking like a flat UI table.
	vec2 warped_uv = UV;
	warped_uv.x += sin(UV.y * 18.0 + scan_progress * 8.0) * warp_strength;
	warped_uv.y += sin(UV.x * 15.0 - scan_progress * 6.0) * warp_strength * 0.55;
	vec2 square_grid = vec2(warped_uv.x * scan_aspect, warped_uv.y) * grid_density;
	float grid = max(grid_axis(square_grid.x), grid_axis(square_grid.y));

	float leading_edge = 1.0 - smoothstep(edge_width, edge_width + edge_glow_width, abs(radial_distance - scan_radius));
	float band_alpha = inside_band * lifecycle;
	// The scanned coach surface keeps a readable square mesh behind the wave.
	// It is cleared together with the effect once this carriage scan completes.
	float retained_grid_alpha = grid * scanned_area * lifecycle * scanned_grid_strength;
	float active_grid_alpha = grid * band_alpha * mix(0.34, 1.0, trail);
	float grid_alpha = max(retained_grid_alpha, active_grid_alpha);
	float retained_fill_alpha = scanned_area * lifecycle * scanned_fill_strength;
	float fill_alpha = retained_fill_alpha + band_alpha * fill_strength * mix(0.35, 1.0, trail);
	float edge_alpha = leading_edge * lifecycle;
	vec3 color = grid_color.rgb * (grid_alpha + fill_alpha) + edge_color.rgb * edge_alpha * edge_color.a;
	float alpha = clamp(
		grid_alpha * grid_color.a + fill_alpha + edge_alpha * edge_color.a,
		0.0,
		1.0
	);
	COLOR = vec4(color, alpha);
}
