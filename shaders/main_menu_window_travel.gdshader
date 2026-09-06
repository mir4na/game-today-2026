shader_type canvas_item;
render_mode unshaded;

uniform vec4 cloud_color : source_color = vec4(1.0, 0.91, 0.92, 0.18);
uniform vec4 distant_color : source_color = vec4(0.45, 0.35, 0.46, 0.20);
uniform vec4 near_color : source_color = vec4(0.18, 0.22, 0.29, 0.32);
uniform vec4 glint_color : source_color = vec4(1.0, 0.86, 0.78, 0.20);
uniform float cloud_speed : hint_range(0.0, 0.2, 0.001) = 0.012;
uniform float distant_speed : hint_range(0.0, 0.5, 0.005) = 0.055;
uniform float near_speed : hint_range(0.0, 2.0, 0.01) = 0.48;
uniform float effect_strength : hint_range(0.0, 1.5, 0.05) = 0.85;

float soft_box(float value, float start, float end, float feather) {
	return smoothstep(start - feather, start + feather, value)
		* (1.0 - smoothstep(end - feather, end + feather, value));
}

float window_mask(vec2 uv) {
	// These normalized bounds sit just inside the scene-authored window frames,
	// keeping the procedural scenery off the carriage interior artwork.
	float left_right_edge = mix(0.426, 0.486, smoothstep(0.0, 0.16, uv.y));
	float left_window = smoothstep(0.111, 0.119, uv.x)
		* (1.0 - smoothstep(left_right_edge - 0.008, left_right_edge, uv.x));

	float right_top_edge = mix(0.095, 0.235, clamp((uv.x - 0.702) / 0.25, 0.0, 1.0));
	float right_window = smoothstep(0.700, 0.710, uv.x)
		* (1.0 - smoothstep(0.936, 0.946, uv.x))
		* smoothstep(right_top_edge, right_top_edge + 0.018, uv.y)
		* (1.0 - smoothstep(0.965, 0.985, uv.y));
	return clamp(max(left_window, right_window), 0.0, 1.0);
}

float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float mask = window_mask(uv);

	// Long, translucent cloud bands drift slowly enough to establish depth.
	float cloud_x = uv.x + TIME * cloud_speed;
	float cloud_wave = sin(cloud_x * 18.0) * 0.018 + sin(cloud_x * 41.0 + 1.7) * 0.008;
	float cloud_a = soft_box(uv.y, 0.22 + cloud_wave, 0.255 + cloud_wave, 0.018);
	float cloud_b = soft_box(uv.y, 0.38 - cloud_wave * 0.7, 0.402 - cloud_wave * 0.7, 0.014);
	float clouds = (cloud_a * 0.72 + cloud_b * 0.45) * cloud_color.a;

	// Two softly layered horizons move at different speeds for train parallax.
	float far_x = uv.x + TIME * distant_speed;
	float far_horizon = 0.70 + sin(far_x * 9.0) * 0.027 + sin(far_x * 19.0 + 0.8) * 0.010;
	float far_land = smoothstep(far_horizon - 0.018, far_horizon + 0.018, uv.y)
		* (1.0 - smoothstep(0.91, 0.98, uv.y));

	float mid_x = uv.x + TIME * distant_speed * 1.8;
	float mid_horizon = 0.79 + sin(mid_x * 15.0 + 1.1) * 0.020 + sin(mid_x * 31.0) * 0.008;
	float mid_land = smoothstep(mid_horizon - 0.012, mid_horizon + 0.014, uv.y)
		* (1.0 - smoothstep(0.94, 0.985, uv.y));

	// Sparse poles and short glints pass quickly in the foreground. Their
	// irregular spacing prevents the movement from reading like a conveyor belt.
	vec2 pole_grid = vec2((uv.x + TIME * near_speed) * 8.0, floor(uv.y * 3.0));
	float pole_cell = floor(pole_grid.x);
	float pole_local = fract(pole_grid.x);
	float pole_enabled = step(0.58, hash21(vec2(pole_cell, 2.0)));
	float pole = (1.0 - smoothstep(0.025, 0.075, abs(pole_local - 0.5)))
		* pole_enabled
		* smoothstep(0.48, 0.72, uv.y)
		* (1.0 - smoothstep(0.955, 0.99, uv.y));

	vec2 streak_grid = vec2((uv.x + TIME * near_speed * 0.72) * 7.0, uv.y * 18.0);
	vec2 streak_cell = floor(streak_grid);
	vec2 streak_local = fract(streak_grid);
	float streak_enabled = step(0.77, hash21(streak_cell));
	float streak = streak_enabled
		* soft_box(streak_local.y, 0.45, 0.52, 0.08)
		* soft_box(streak_local.x, 0.08, 0.62, 0.12);

	float far_amount = far_land * distant_color.a;
	float mid_amount = mid_land * near_color.a * 0.72;
	float pole_amount = pole * near_color.a;
	float streak_amount = streak * glint_color.a;
	float total_amount = clouds + far_amount + mid_amount + pole_amount + streak_amount;
	vec3 mixed_color = (
		cloud_color.rgb * clouds
		+ distant_color.rgb * far_amount
		+ near_color.rgb * (mid_amount + pole_amount)
		+ glint_color.rgb * streak_amount
	) / max(total_amount, 0.0001);
	COLOR = vec4(
		mixed_color,
		clamp(total_amount * mask * effect_strength, 0.0, 0.72)
	);
}
