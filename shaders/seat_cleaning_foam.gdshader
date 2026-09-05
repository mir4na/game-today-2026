shader_type canvas_item;
render_mode unshaded;

uniform vec2 surface_size = vec2(280.0, 435.0);
uniform sampler2D foam_mask : filter_linear, repeat_disable;
uniform vec2 foam_center = vec2(0.5, 0.5);
uniform float brush_active : hint_range(0.0, 1.0) = 0.0;
uniform vec4 foam_color : source_color = vec4(0.84, 0.96, 1.0, 0.92);


float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 345.45));
	point += dot(point, point + 34.345);
	return fract(point.x * point.y);
}


float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 blend = fract(point);
	blend = blend * blend * (3.0 - 2.0 * blend);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y);
}


float bubble_ring(vec2 pixel_position, float cell_size, float seed) {
	vec2 grid_position = pixel_position / cell_size;
	vec2 cell = floor(grid_position);
	vec2 local_position = fract(grid_position);
	float random_value = hash21(cell + seed);
	vec2 center = vec2(
		0.22 + 0.56 * hash21(cell + seed + 17.1),
		0.22 + 0.56 * hash21(cell + seed + 39.7)
	);
	float radius = mix(0.14, 0.34, random_value);
	float ring_width = mix(0.025, 0.065, hash21(cell + seed + 8.4));
	float distance_to_ring = abs(length(local_position - center) - radius);
	float ring = 1.0 - smoothstep(ring_width, ring_width + 0.045, distance_to_ring);
	return ring * smoothstep(0.18, 0.46, random_value);
}


void fragment() {
	vec2 pixel_position = UV * surface_size;
	vec2 brush_delta = (UV - foam_center) * surface_size;
	float trail = texture(foam_mask, UV).r;
	float fresh_lather = (1.0 - smoothstep(24.0, 52.0, length(brush_delta))) * brush_active;
	float coverage = max(trail, fresh_lather * 0.9);

	float slow_time = TIME * 0.35;
	float cloud_noise = value_noise(pixel_position * 0.055 + vec2(slow_time, -slow_time * 0.6));
	cloud_noise = mix(cloud_noise, value_noise(pixel_position * 0.105 + 9.7), 0.36);
	float lather_body = smoothstep(0.08, 0.72, coverage) * mix(0.42, 0.78, cloud_noise);

	float small_bubbles = bubble_ring(pixel_position + vec2(slow_time * 2.0, 0.0), 12.0, 3.1);
	float medium_bubbles = bubble_ring(pixel_position, 21.0, 11.8);
	float bubble_detail = max(small_bubbles * 0.72, medium_bubbles);
	float bubble_alpha = bubble_detail * smoothstep(0.03, 0.38, coverage);
	float alpha = max(lather_body, bubble_alpha) * smoothstep(0.01, 0.16, coverage);

	float glint = bubble_detail * (0.72 + 0.28 * sin(TIME * 2.1 + pixel_position.x * 0.08));
	vec3 base_color = mix(foam_color.rgb * 0.82, foam_color.rgb, cloud_noise);
	vec3 final_color = mix(base_color, vec3(1.0), glint * 0.7);
	COLOR = vec4(final_color, foam_color.a * alpha);
}
