shader_type canvas_item;

uniform float night_strength : hint_range(0.0, 1.0) = 0.0;
uniform bool monochrome_tint = false;
// Exact ink color sampled from the original PauseMenu PNG assets (#353540).
uniform vec4 day_ink : source_color = vec4(0.207843, 0.207843, 0.250980, 1.0);
uniform vec4 night_ink : source_color = vec4(0.957, 0.894, 0.620, 1.0);
uniform vec4 night_paper_top : source_color = vec4(0.220, 0.224, 0.345, 1.0);
uniform vec4 night_paper_bottom : source_color = vec4(0.173, 0.110, 0.235, 1.0);

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec4 canvas_tint = COLOR;
	vec3 result = source.rgb;

	if (monochrome_tint) {
		result = mix(day_ink.rgb, night_ink.rgb, night_strength);
	} else {
		float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
		float ink_mask = 1.0 - smoothstep(0.28, 0.56, luminance);
		float lower_band = smoothstep(0.64, 0.78, UV.y);
		vec3 night_paper = mix(night_paper_top.rgb, night_paper_bottom.rgb, lower_band);
		vec3 night_color = mix(night_paper, night_ink.rgb, ink_mask);
		result = mix(source.rgb, night_color, night_strength);
	}

	COLOR = vec4(result, source.a) * canvas_tint;
}
