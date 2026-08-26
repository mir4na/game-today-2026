shader_type canvas_item;
render_mode unshaded;

// 0.0 keeps the exterior fully visible. 1.0 removes it from top to bottom.
uniform float wipe_progress : hint_range(0.0, 1.0) = 0.0;
uniform float edge_softness : hint_range(0.01, 0.25) = 0.08;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	// CanvasGroup composites its children through the backbuffer. Sampling TEXTURE
	// here replaces that built-in composite and produces an untextured white quad.
	vec4 group_color = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (group_color.a > 0.0001) {
		group_color.rgb /= group_color.a;
	}

	float boundary = mix(-edge_softness, 1.0 + edge_softness, wipe_progress);
	float visible_mask = smoothstep(boundary - edge_softness, boundary + edge_softness, UV.y);
	COLOR *= group_color;
	COLOR.a *= visible_mask;
}
