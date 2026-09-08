shader_type canvas_item;
render_mode unshaded;

uniform vec4 top_color : source_color = vec4(0.208, 0.208, 0.251, 1.0);
uniform vec4 middle_color : source_color = vec4(0.353, 0.345, 0.533, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.200, 0.106, 0.231, 1.0);
uniform float drift_speed : hint_range(0.0, 0.5) = 0.075;
uniform float drift_amount : hint_range(0.0, 0.05) = 0.012;

void fragment() {
	float drifting_y = clamp(UV.y + sin(UV.x * 5.0 + TIME * drift_speed) * drift_amount, 0.0, 1.0);
	vec3 gradient_color;
	if (drifting_y <= 0.35) {
		gradient_color = mix(top_color.rgb, middle_color.rgb, smoothstep(0.0, 0.35, drifting_y));
	} else {
		gradient_color = mix(middle_color.rgb, bottom_color.rgb, smoothstep(0.35, 0.94, drifting_y));
	}
	float halo = 1.0 - smoothstep(0.0, 0.72, distance(UV, vec2(0.5, 0.28)));
	float pulse = 0.5 + 0.5 * sin(TIME * 0.32);
	gradient_color += middle_color.rgb * halo * (0.025 + pulse * 0.018);
	COLOR = vec4(gradient_color, 1.0) * COLOR;
}
