shader_type canvas_item;
render_mode unshaded;

uniform vec4 streak_color : source_color = vec4(0.72, 0.9, 1.0, 0.9);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float speed : hint_range(0.1, 8.0) = 3.2;
uniform float streak_length : hint_range(0.02, 0.8) = 0.34;


float hash11(float value) {
	return fract(sin(value * 127.17) * 43758.5453);
}


float streak_layer(vec2 uv, float rows, float speed_scale, float seed) {
	float row = floor(uv.y * rows);
	float local_y = fract(uv.y * rows) - 0.5;
	float random_value = hash11(row + seed);
	float active = smoothstep(0.72, 1.0, random_value);
	float thickness = mix(0.035, 0.16, hash11(row + seed * 2.7));
	float line = 1.0 - smoothstep(thickness, thickness * 2.4, abs(local_y));
	float travel = fract(uv.x + TIME * speed * speed_scale + random_value);
	float length = streak_length * mix(0.45, 1.0, random_value);
	float tail = 1.0 - smoothstep(length, length + 0.12, travel);
	return line * tail * active;
}


void fragment() {
	vec4 canvas_tint = COLOR;
	float streaks = streak_layer(UV, 38.0, 0.82, 4.0);
	streaks += streak_layer(UV + vec2(0.17, 0.013), 67.0, 1.18, 19.0) * 0.62;
	float center_mask = 0.45 + abs(UV.x - 0.5) * 1.1;
	float alpha = clamp(streaks * intensity * center_mask, 0.0, 1.0);
	COLOR = vec4(streak_color.rgb * canvas_tint.rgb, streak_color.a * canvas_tint.a * alpha);
}
