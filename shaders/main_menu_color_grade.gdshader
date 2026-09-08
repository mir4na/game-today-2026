shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform sampler2D overlay_1 : source_color, filter_linear;
uniform sampler2D overlay_2 : source_color, filter_linear;
uniform float overlay_1_strength : hint_range(0.0, 1.5, 0.01) = 1.0;
uniform float overlay_2_strength : hint_range(0.0, 1.5, 0.01) = 1.0;

vec3 overlay_blend(vec3 base, vec3 blend) {
	vec3 dark_result = 2.0 * base * blend;
	vec3 light_result = 1.0 - 2.0 * (1.0 - base) * (1.0 - blend);
	return mix(dark_result, light_result, step(vec3(0.5), base));
}

vec3 soft_light_blend(vec3 base, vec3 blend) {
	vec3 low_curve = ((16.0 * base - 12.0) * base + 4.0) * base;
	vec3 high_curve = sqrt(max(base, vec3(0.0)));
	vec3 curve = mix(low_curve, high_curve, step(vec3(0.25), base));
	vec3 dark_result = base - (1.0 - 2.0 * blend) * base * (1.0 - base);
	vec3 light_result = base + (2.0 * blend - 1.0) * (curve - base);
	return mix(dark_result, light_result, step(vec3(0.5), blend));
}

void fragment() {
	vec4 base = texture(screen_texture, SCREEN_UV);
	vec4 first_overlay = texture(overlay_1, UV);
	vec4 second_overlay = texture(overlay_2, UV);

	float first_amount = clamp(first_overlay.a * overlay_1_strength, 0.0, 1.0);
	float second_amount = clamp(second_overlay.a * overlay_2_strength, 0.0, 1.0);
	vec3 graded = mix(
		base.rgb,
		overlay_blend(base.rgb, first_overlay.rgb),
		first_amount
	);
	float graded_luminance = dot(graded, vec3(0.2126, 0.7152, 0.0722));
	// Preserve dark costume detail while still pushing the carriage frame toward
	// the warm magenta tone in the authored reference.
	second_amount *= mix(0.35, 1.0, smoothstep(0.16, 0.72, graded_luminance));
	graded = mix(
		graded,
		soft_light_blend(graded, second_overlay.rgb),
		second_amount
	);
	COLOR = vec4(graded, base.a);
}
