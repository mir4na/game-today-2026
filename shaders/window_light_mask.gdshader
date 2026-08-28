shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float cycle_progress : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform float flare_strength : hint_range(0.0, 1.5, 0.01) = 0.8;

varying vec4 light_tint;

void vertex() {
	// Preserve the per-carriage CanvasItem modulation before sampling the transparent PNG.
	light_tint = COLOR;
}

float rectangle_mask(vec2 uv, vec2 minimum, vec2 maximum, float feather) {
	float horizontal = smoothstep(minimum.x, minimum.x + feather, uv.x)
		* (1.0 - smoothstep(maximum.x - feather, maximum.x, uv.x));
	float vertical = smoothstep(minimum.y, minimum.y + feather, uv.y)
		* (1.0 - smoothstep(maximum.y - feather, maximum.y, uv.y));
	return horizontal * vertical;
}

float rectangle_glow(vec2 uv, vec2 minimum, vec2 maximum, float radius) {
	vec2 nearest = clamp(uv, minimum, maximum);
	vec2 delta = (uv - nearest) * vec2(1.0, 2.2);
	return 1.0 - smoothstep(0.0, radius, length(delta));
}

void fragment() {
	float source_alpha = texture(TEXTURE, UV).a;
	vec2 left_min = vec2(0.075, 0.17);
	vec2 left_max = vec2(0.355, 0.405);
	vec2 right_min = vec2(0.645, 0.17);
	vec2 right_max = vec2(0.925, 0.405);
	vec2 door_left_min = vec2(0.43, 0.235);
	vec2 door_left_max = vec2(0.485, 0.505);
	vec2 door_right_min = vec2(0.515, 0.235);
	vec2 door_right_max = vec2(0.57, 0.505);

	float window_mask = rectangle_mask(UV, left_min, left_max, 0.008);
	window_mask += rectangle_mask(UV, right_min, right_max, 0.008);
	window_mask += rectangle_mask(UV, door_left_min, door_left_max, 0.006);
	window_mask += rectangle_mask(UV, door_right_min, door_right_max, 0.006);
	window_mask = clamp(window_mask, 0.0, 1.0);

	float window_glow = rectangle_glow(UV, left_min, left_max, 0.105);
	window_glow += rectangle_glow(UV, right_min, right_max, 0.105);
	window_glow += rectangle_glow(UV, door_left_min, door_left_max, 0.07);
	window_glow += rectangle_glow(UV, door_right_min, door_right_max, 0.07);
	window_glow = clamp(window_glow, 0.0, 1.0);

	float night_fade = 1.0 - smoothstep(0.72, 1.0, cycle_progress) * 0.58;
	float breathing = 0.965 + sin(TIME * 0.72 + UV.x * 4.0) * 0.035;

	// This material is only the local window glow. Camera flare lives in its own
	// UI CanvasLayer so the carriage texture never becomes overexposed.
	float glass_alpha = window_mask * (1.0 - source_alpha) * 0.38;
	float bounce_alpha = window_glow * source_alpha * 0.075;
	float final_alpha = (glass_alpha + bounce_alpha) * flare_strength;
	final_alpha *= light_tint.a * breathing * night_fade;
	COLOR = vec4(light_tint.rgb, clamp(final_alpha, 0.0, 1.0));
}
