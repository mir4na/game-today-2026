shader_type canvas_item;
render_mode unshaded;

// 0.0 keeps the complete composite visible. 1.0 removes it from top to bottom.
// Exterior body, underframe, and animated doors share one runtime material, so
// a single horizontal feather crosses every sprite at the same world height.
uniform float wipe_progress : hint_range(0.0, 1.0) = 0.0;
uniform float edge_softness : hint_range(0.01, 0.25) = 0.08;
uniform float wipe_top_screen_y : hint_range(-1.0, 2.0) = 0.0;
uniform float wipe_bottom_screen_y : hint_range(-1.0, 2.0) = 1.0;

void fragment() {
	// Normalize the screen-space height supplied by the scene's top and bottom
	// Marker2D nodes so the wipe always travels roof-to-floor despite camera zoom.
	float top_y = min(wipe_top_screen_y, wipe_bottom_screen_y);
	float bottom_y = max(wipe_top_screen_y, wipe_bottom_screen_y);
	float normalized_height = clamp(
		(SCREEN_UV.y - top_y) / max(bottom_y - top_y, 0.0001),
		0.0,
		1.0
	);
	float boundary = mix(-edge_softness, 1.0 + edge_softness, wipe_progress);
	float visible_mask = smoothstep(boundary - edge_softness, boundary + edge_softness, normalized_height);
	if (visible_mask <= 0.001) {
		discard;
	}
	COLOR.a *= visible_mask;
}
