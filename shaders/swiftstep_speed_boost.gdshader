shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 streak_tint : source_color = vec4(1.0, 0.86, 0.38, 1.0);
uniform float effect_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float burst_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float elapsed_seconds = 0.0;
uniform float streak_density : hint_range(8.0, 80.0, 1.0) = 36.0;
uniform float streak_speed : hint_range(0.1, 12.0, 0.1) = 5.2;
uniform float streak_intensity : hint_range(0.0, 1.0, 0.01) = 0.2;

float hash_1d(float value) {
	return fract(sin(value * 91.3458) * 47453.5453);
}

void fragment() {
	vec4 source = textureLod(screen_texture, SCREEN_UV, 0.0);
	float lane = floor(SCREEN_UV.y * streak_density);
	float random_offset = hash_1d(lane + 11.0);
	float random_length = mix(0.025, 0.13, hash_1d(lane + 37.0));
	float moving_x = fract(SCREEN_UV.x + elapsed_seconds * streak_speed + random_offset);
	float streak = 1.0 - smoothstep(random_length * 0.25, random_length, moving_x);
	float lane_center = fract(SCREEN_UV.y * streak_density);
	float lane_shape = 1.0 - smoothstep(0.04, 0.2, abs(lane_center - 0.5));
	float edge_mask = smoothstep(0.08, 0.34, abs(SCREEN_UV.y - 0.5));
	float active_streak = streak * lane_shape * edge_mask * effect_strength;
	float edge_flash = smoothstep(0.18, 0.5, abs(SCREEN_UV.y - 0.5)) * burst_strength;
	vec3 color = source.rgb;
	color += streak_tint.rgb * active_streak * streak_intensity;
	color += streak_tint.rgb * edge_flash * 0.12;
	COLOR = vec4(color, 1.0);
}
