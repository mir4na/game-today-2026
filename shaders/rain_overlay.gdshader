shader_type canvas_item;
render_mode unshaded;

uniform vec4 rain_color : source_color = vec4(0.72, 0.86, 1.0, 0.82);
uniform float intensity : hint_range(0.0, 1.5) = 1.0;
uniform float density : hint_range(0.0, 1.0) = 0.48;
uniform float fall_speed : hint_range(0.1, 8.0) = 2.4;
uniform float slant : hint_range(-1.0, 1.0) = -0.22;
uniform float streak_length : hint_range(0.02, 0.48) = 0.22;
uniform float streak_width : hint_range(0.002, 0.08) = 0.018;
uniform float motion_boost : hint_range(0.25, 5.0) = 1.0;


float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453123);
}


float rain_layer(vec2 uv, float cell_count, float speed_scale, float seed) {
	vec2 position = uv;
	position.x += position.y * slant;
	position *= vec2(cell_count, cell_count * 0.58);
	position.y += TIME * fall_speed * speed_scale * motion_boost;
	vec2 cell = floor(position);
	vec2 local = fract(position) - 0.5;
	float random_value = hash21(cell + vec2(seed, seed * 1.73));
	float active = smoothstep(1.0 - density, 1.0, random_value);
	float line_center = (hash21(cell + vec2(seed + 19.3, 7.1)) - 0.5) * 0.76;
	float width = streak_width * (0.72 + hash21(cell + 3.7) * 0.7);
	float length = streak_length * (0.62 + hash21(cell + 8.9) * 0.82) * mix(0.9, 1.45, clamp(motion_boost / 5.0, 0.0, 1.0));
	float horizontal = 1.0 - smoothstep(width, width * 2.35, abs(local.x - line_center));
	float vertical = 1.0 - smoothstep(length, length + 0.1, abs(local.y));
	float highlight = mix(0.55, 1.0, smoothstep(-length, length, local.y));
	return horizontal * vertical * highlight * active;
}


void fragment() {
	vec4 canvas_tint = COLOR;
	float rain = rain_layer(UV, 18.0, 0.82, 2.1);
	rain += rain_layer(UV + vec2(0.13, 0.0), 29.0, 1.08, 11.7) * 0.72;
	rain += rain_layer(UV + vec2(0.31, 0.0), 43.0, 1.36, 27.4) * 0.48;
	float edge_fade = smoothstep(0.0, 0.08, UV.y) * (1.0 - smoothstep(0.9, 1.0, UV.y));
	float alpha = clamp(rain * intensity * edge_fade, 0.0, 1.0);
	COLOR = vec4(rain_color.rgb * canvas_tint.rgb, rain_color.a * canvas_tint.a * alpha);
}
