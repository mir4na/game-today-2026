shader_type canvas_item;
render_mode unshaded, blend_add;

// One-shot, scene-bounded radar wave. The controlling script only supplies
// the player's local origin and animates scan_progress; all visual tuning lives
// in the ShaderMaterial assigned to RadarScanEffect.
uniform vec2 scan_origin_uv = vec2(0.5, 0.72);
uniform float scan_progress : hint_range(0.0, 1.0) = 0.0;
uniform float scan_aspect : hint_range(0.25, 8.0) = 2.85;
uniform float ring_width : hint_range(0.002, 0.12, 0.001) = 0.009;
uniform float ring_feather : hint_range(0.001, 0.08, 0.001) = 0.007;
uniform float echo_gap : hint_range(0.01, 0.5, 0.005) = 0.095;
uniform float echo_width_scale : hint_range(0.25, 2.0, 0.05) = 0.72;
uniform float echo_strength : hint_range(0.0, 1.0, 0.01) = 0.20;
uniform float source_radius : hint_range(0.005, 0.2, 0.005) = 0.04;
uniform float source_strength : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform vec4 ring_color : source_color = vec4(0.20, 0.91, 1.0, 0.86);
uniform vec4 echo_color : source_color = vec4(0.05, 0.42, 0.72, 0.32);

float soft_ring(float distance_from_origin, float radius, float width, float feather) {
	return 1.0 - smoothstep(width, width + feather, abs(distance_from_origin - radius));
}

void fragment() {
	vec2 aspect = vec2(scan_aspect, 1.0);
	vec2 origin = scan_origin_uv * aspect;
	float distance_from_origin = length(UV * aspect - origin);

	// Normalize the animation against the farthest corner. Progress 1.0 always
	// carries the ring outside this coach, regardless of where the player stands.
	float farthest_corner = max(
		max(length(origin), length(vec2(scan_aspect, 0.0) - origin)),
		max(length(vec2(0.0, 1.0) - origin), length(aspect - origin))
	);
	float radius = scan_progress * farthest_corner;
	float lifecycle = smoothstep(0.0, 0.035, scan_progress)
		* (1.0 - smoothstep(0.93, 1.0, scan_progress));
	float primary = soft_ring(distance_from_origin, radius, ring_width, ring_feather) * lifecycle;

	float echo_radius = max(radius - echo_gap, 0.0);
	float echo_ready = smoothstep(echo_gap, echo_gap + ring_feather, radius);
	float echo = soft_ring(
		distance_from_origin,
		echo_radius,
		ring_width * echo_width_scale,
		ring_feather
	) * echo_ready * lifecycle * echo_strength;

	float source = (1.0 - smoothstep(source_radius, source_radius + ring_feather, distance_from_origin))
		* (1.0 - smoothstep(0.12, 0.38, scan_progress))
		* source_strength;
	float alpha = clamp(primary * ring_color.a + echo * echo_color.a + source * ring_color.a, 0.0, 1.0);
	vec3 color = ring_color.rgb * (primary + source) + echo_color.rgb * echo;
	COLOR = vec4(color, alpha);
}
