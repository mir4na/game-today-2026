shader_type canvas_item;
render_mode unshaded;

uniform float cycle_progress : hint_range(0.0, 1.0, 0.001) = 0.0;

uniform vec3 morning_top : source_color = vec3(0.486275, 0.827451, 0.996078);
uniform vec3 morning_middle : source_color = vec3(0.717647, 1.0, 0.952941);
uniform vec3 morning_bottom : source_color = vec3(0.988235, 0.984314, 0.909804);

uniform vec3 sunset_top : source_color = vec3(0.996078, 0.627451, 0.486275);
uniform vec3 sunset_middle : source_color = vec3(0.996078, 0.992157, 0.666667);
uniform vec3 sunset_bottom : source_color = vec3(0.988235, 0.984314, 0.909804);

uniform vec3 night_top : source_color = vec3(0.0, 0.160784, 0.231373);
uniform vec3 night_middle : source_color = vec3(0.039216, 0.345098, 0.494118);
uniform vec3 night_bottom : source_color = vec3(0.227451, 0.635294, 0.913725);

vec3 three_stop_gradient(vec3 top, vec3 middle, vec3 bottom, float vertical_position) {
	float upper_blend = smoothstep(0.0, 0.52, vertical_position);
	float lower_blend = smoothstep(0.48, 1.0, vertical_position);
	vec3 upper_color = mix(top, middle, upper_blend);
	return mix(upper_color, bottom, lower_blend);
}

void fragment() {
	vec3 morning = three_stop_gradient(morning_top, morning_middle, morning_bottom, UV.y);
	vec3 sunset = three_stop_gradient(sunset_top, sunset_middle, sunset_bottom, UV.y);
	vec3 night = three_stop_gradient(night_top, night_middle, night_bottom, UV.y);

	float sunset_blend = smoothstep(0.08, 0.62, cycle_progress);
	float night_blend = smoothstep(0.70, 0.98, cycle_progress);
	vec3 sky_color = mix(morning, sunset, sunset_blend);
	sky_color = mix(sky_color, night, night_blend);
	COLOR = vec4(sky_color, 1.0);
}
