shader_type canvas_item;
render_mode blend_mix, unshaded;
// Screen-space glass crack overlay. Adapts the reference 3D Voronoi shatter to
// a 2D canvas_item: cells and impact points live in normalized screen UV, so it
// can sit on a full-rect ColorRect above any UI. crack_level drives 1->2->3
// (hairline, spreading, full shatter); beyond that the whole screen fractures.

// Impact points are normalized (0..1) screen coordinates, 3 max. Unused slots
// should be shoved far off screen so they never draw.
uniform float crack_level : hint_range(0.0, 3.0) = 0.0;
uniform vec2 impact_points[3];
uniform float fracture_scale : hint_range(2.0, 80.0) = 17.0;
uniform float edge_thickness : hint_range(0.01, 0.5) = 0.055;
uniform float impact_range : hint_range(0.05, 1.5) = 0.5;
uniform float line_alpha : hint_range(0.0, 1.0) = 0.0;
uniform vec4 crack_color : source_color = vec4(0.93, 0.98, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.34, 0.6, 1.0, 1.0);
uniform float glow_strength : hint_range(0.0, 2.0) = 0.7;
uniform float aspect : hint_range(0.1, 4.0) = 1.7778;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 feature_point(vec2 cell) {
	return cell + vec2(hash2(cell), hash2(cell.yx + 1.7));
}

// Returns 0 on a cell edge and 1 deep inside a cell, like the reference
// second-nearest minus nearest Voronoi distance.
float voronoi_edge(vec2 uv) {
	vec2 cell = floor(uv);
	float min_dist = 1e9;
	float second_dist = 1e9;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 neighbor = cell + vec2(float(i), float(j));
			vec2 f = feature_point(neighbor);
			vec2 diff = uv - f;
			float d = dot(diff, diff);
			if (d < min_dist) {
				second_dist = min_dist;
				min_dist = d;
			} else if (d < second_dist) {
				second_dist = d;
			}
		}
	}
	return smoothstep(0.0, edge_thickness, second_dist - min_dist);
}

void fragment() {
	if (crack_level <= 0.0 || line_alpha <= 0.0) {
		discard;
	}
	vec2 aspect_uv = UV * vec2(aspect, 1.0);
	vec2 uv = aspect_uv * fracture_scale;
	float edge = voronoi_edge(uv);
	float crack = 1.0 - edge;

	float mask = 0.0;
	float glow = 0.0;
	for (int i = 0; i < 3; i++) {
		if (float(i) < crack_level) {
			float d = distance(aspect_uv, impact_points[i]);
			mask = max(mask, 1.0 - smoothstep(impact_range * 0.55, impact_range, d));
			glow = max(glow, 1.0 - smoothstep(0.0, impact_range, d));
		}
	}
	// Third strike: the whole pane is fractured, not just around impacts.
	if (crack_level >= 3.0) {
		mask = 1.0;
	}

	float lines = crack * mask;
	float glow_ring = glow * (1.0 - crack) * glow_strength;
	vec3 color = mix(glow_color.rgb, crack_color.rgb, clamp(lines, 0.0, 1.0));
	color += glow_color.rgb * glow_ring * 0.35;
	float alpha = clamp(lines * line_alpha + glow_ring * line_alpha * 0.5, 0.0, 1.0);
	COLOR = vec4(color, alpha);
}
