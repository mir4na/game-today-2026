shader_type canvas_item;
render_mode unshaded, blend_add;

// The effect is drawn inside the scene-authored RadarEffectBounds Control.
// Distance is normalized independently toward each of its four sides, so the
// wavefront grows from the player into the exact carriage rectangle instead
// of producing a circle that leaks across the roof or neighbouring coaches.
uniform vec2 scan_origin_uv = vec2(0.5, 0.72);
uniform float scan_progress : hint_range(0.0, 1.0) = 0.0;
uniform float scan_aspect : hint_range(0.25, 8.0) = 2.85;
uniform float front_width : hint_range(0.002, 0.2) = 0.018;
uniform float front_softness : hint_range(0.001, 0.1) = 0.012;
uniform float trail_length : hint_range(0.02, 0.8) = 0.14;
uniform float trail_strength : hint_range(0.0, 1.0) = 0.2;
uniform float residue_strength : hint_range(0.0, 1.0) = 0.05;
uniform float grid_strength : hint_range(0.0, 1.0) = 0.08;
uniform float boundary_strength : hint_range(0.0, 1.0) = 0.28;
uniform vec4 front_color : source_color = vec4(0.28, 0.94, 1.0, 0.96);
uniform vec4 trail_color : source_color = vec4(0.06, 0.42, 0.72, 0.34);

float grid_line(float coordinate, float cells, float thickness) {
	float cell_distance = abs(fract(coordinate * cells) - 0.5);
	return 1.0 - smoothstep(thickness, thickness + 0.035, cell_distance);
}

void fragment() {
	vec2 delta = UV - scan_origin_uv;
	vec2 travel_to_side = mix(
		max(scan_origin_uv, vec2(0.001)),
		max(vec2(1.0) - scan_origin_uv, vec2(0.001)),
		step(vec2(0.0), delta)
	);
	vec2 side_progress = abs(delta) / travel_to_side;

	// Chebyshev distance creates a rectangular contour. Because each axis is
	// normalized to the relevant side, progress 1.0 touches all four bounds at
	// once even when the player is not standing in the carriage centre.
	float carriage_distance = max(side_progress.x, side_progress.y);
	float front_distance = abs(carriage_distance - scan_progress);
	float front = 1.0 - smoothstep(
		front_width,
		front_width + front_softness,
		front_distance
	);
	float swept = 1.0 - smoothstep(
		scan_progress - front_softness,
		scan_progress + front_softness,
		carriage_distance
	);
	float distance_behind_front = max(scan_progress - carriage_distance, 0.0);
	float trail_falloff = 1.0 - smoothstep(0.0, trail_length, distance_behind_front);

	// A restrained carriage-aligned grid makes the scan read as a volume of
	// light rather than a flat rectangle. scan_aspect keeps its cells square.
	float horizontal_grid = grid_line(UV.y, 8.0, 0.035);
	float vertical_grid = grid_line(UV.x, 8.0 * scan_aspect, 0.035);
	float grid = max(horizontal_grid, vertical_grid) * grid_strength;
	float data_pulse = 0.78 + 0.22 * sin(carriage_distance * 52.0 - scan_progress * 26.0);

	float boundary_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float boundary = (1.0 - smoothstep(0.0, 0.018, boundary_distance)) * swept;
	float trail = swept * (residue_strength + trail_falloff * trail_strength) * (0.72 + grid) * data_pulse;

	// The ignition point may remain softly rounded; only the travelling scan
	// front changes shape and conforms to the carriage.
	vec2 source_delta = delta * vec2(scan_aspect, 1.0);
	float source = 1.0 - smoothstep(0.0, 0.055, length(source_delta));
	float alpha = clamp(
		front * front_color.a
		+ trail * trail_color.a
		+ boundary * boundary_strength
		+ source * 0.42,
		0.0,
		1.0
	);
	vec3 color = (
		front_color.rgb * (front + boundary * boundary_strength + source * 0.55)
		+ trail_color.rgb * trail
	);
	COLOR = vec4(color, alpha);
}
