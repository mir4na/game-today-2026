shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform bool outline_enabled = false;
uniform vec4 outline_color : source_color = vec4(0.96, 0.78, 0.32, 1.0);
uniform float outline_width : hint_range(1.0, 8.0, 0.5) = 4.0;
uniform float dead_effect_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float dead_desaturation : hint_range(0.0, 1.0, 0.01) = 0.72;
uniform vec4 dead_tint : source_color = vec4(0.30, 0.52, 0.66, 0.24);
uniform float interaction_lock_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float radar_detection_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 radar_detection_color : source_color = vec4(1.0, 0.08, 0.035, 0.95);
uniform float radar_outline_width : hint_range(2.0, 18.0, 0.5) = 8.0;
uniform float radar_inner_tint : hint_range(0.0, 0.5, 0.01) = 0.12;


float read_alpha(vec2 screen_uv, vec2 screen_offset) {
	return textureLod(screen_texture, screen_uv + screen_offset, 0.0).a;
}


void fragment() {
	vec4 source = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (source.a > 0.0001) {
		source.rgb /= source.a;
	}
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desaturated = mix(source.rgb, vec3(luminance), dead_desaturation);
	vec3 death_graded = mix(desaturated, dead_tint.rgb, dead_tint.a);
	source.rgb = mix(source.rgb, death_graded, dead_effect_strength);
	float locked_luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	source.rgb = mix(source.rgb, vec3(locked_luminance), interaction_lock_strength);
	float radar_pulse = mix(
		1.0,
		0.78 + sin(TIME * 7.0) * 0.22,
		radar_detection_strength
	);
	float radar_strength = radar_detection_strength * radar_pulse;
	source.rgb = mix(
		source.rgb,
		radar_detection_color.rgb,
		radar_strength * radar_inner_tint * source.a
	);

	if (!outline_enabled && radar_strength <= 0.001) {
		COLOR *= source;
	} else {
		float active_outline_width = mix(
			outline_width,
			radar_outline_width,
			radar_detection_strength
		);
		vec4 active_outline_color = mix(
			outline_color,
			radar_detection_color,
			radar_detection_strength
		);
		vec2 pixel_step = SCREEN_PIXEL_SIZE * active_outline_width;
		float surrounding_alpha = 0.0;
		surrounding_alpha = max(surrounding_alpha, read_alpha(SCREEN_UV, vec2(pixel_step.x, 0.0)));
		surrounding_alpha = max(surrounding_alpha, read_alpha(SCREEN_UV, vec2(-pixel_step.x, 0.0)));
		surrounding_alpha = max(surrounding_alpha, read_alpha(SCREEN_UV, vec2(0.0, pixel_step.y)));
		surrounding_alpha = max(surrounding_alpha, read_alpha(SCREEN_UV, vec2(0.0, -pixel_step.y)));
		surrounding_alpha = max(surrounding_alpha, read_alpha(SCREEN_UV, vec2(pixel_step.x, pixel_step.y)));
		surrounding_alpha = max(surrounding_alpha, read_alpha(SCREEN_UV, vec2(-pixel_step.x, pixel_step.y)));
		surrounding_alpha = max(surrounding_alpha, read_alpha(SCREEN_UV, vec2(pixel_step.x, -pixel_step.y)));
		surrounding_alpha = max(surrounding_alpha, read_alpha(SCREEN_UV, vec2(-pixel_step.x, -pixel_step.y)));

		float border_strength = max(outline_enabled ? 1.0 : 0.0, radar_strength);
		float border_alpha = surrounding_alpha * (1.0 - source.a) * active_outline_color.a * border_strength;
		float final_alpha = clamp(source.a + border_alpha, 0.0, 1.0);
		vec3 final_rgb = source.rgb;
		if (final_alpha > 0.0001) {
			final_rgb = (source.rgb * source.a + active_outline_color.rgb * border_alpha) / final_alpha;
		}
		COLOR *= vec4(final_rgb, final_alpha);
	}
}
