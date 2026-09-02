shader_type canvas_item;
render_mode unshaded;

uniform vec2 surface_size = vec2(280.0, 435.0);
uniform vec2 foam_center = vec2(0.5, 0.5);
uniform float foam_active : hint_range(0.0, 1.0) = 0.0;
uniform vec4 foam_color : source_color = vec4(0.87, 0.97, 1.0, 0.84);


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


void fragment() {
	vec2 pixel_delta = (UV - foam_center) * surface_size;
	pixel_delta.x *= 0.82;
	float slow_time = TIME * 0.75;
	vec2 noise_position = pixel_delta * 0.045 + vec2(slow_time, -slow_time * 0.63);
	float cloud_noise = value_noise(noise_position);
	cloud_noise = mix(cloud_noise, value_noise(noise_position * 1.9 + 7.3), 0.38);
	float irregular_radius = 43.0 + (cloud_noise - 0.5) * 22.0;
	float lather = 1.0 - smoothstep(irregular_radius - 9.0, irregular_radius + 7.0, length(pixel_delta));
	float soft_swirl = 0.72 + 0.28 * sin(pixel_delta.x * 0.10 + pixel_delta.y * 0.07 + slow_time * 2.0);
	float alpha = lather * mix(0.58, 0.92, cloud_noise) * soft_swirl * foam_active;
	vec3 highlight = mix(foam_color.rgb * 0.88, vec3(1.0), cloud_noise * 0.42);
	COLOR = vec4(highlight, foam_color.a * alpha);
}
