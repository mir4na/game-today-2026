shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform bool outline_enabled = false;
uniform vec4 outline_color : source_color = vec4(0.96, 0.78, 0.32, 1.0);
uniform float outline_width : hint_range(1.0, 8.0, 0.5) = 4.0;


float read_alpha(vec2 screen_uv, vec2 screen_offset) {
	return textureLod(screen_texture, screen_uv + screen_offset, 0.0).a;
}


void fragment() {
	vec4 source = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (source.a > 0.0001) {
		source.rgb /= source.a;
	}

	if (!outline_enabled) {
		COLOR *= source;
	} else {
		vec2 pixel_step = SCREEN_PIXEL_SIZE * outline_width;
		float surrounding_alpha = 0.0;
		surrounding_alpha = max(surrounding_alpha, read_alpha(SCREEN_UV, vec2(pixel_step.x, 0.0)));
		surrounding_alpha = max(surrounding_alpha, read_alpha(SCREEN_UV, vec2(-pixel_step.x, 0.0)));
		surrounding_alpha = max(surrounding_alpha, read_alpha(SCREEN_UV, vec2(0.0, pixel_step.y)));
		surrounding_alpha = max(surrounding_alpha, read_alpha(SCREEN_UV, vec2(0.0, -pixel_step.y)));
		surrounding_alpha = max(surrounding_alpha, read_alpha(SCREEN_UV, vec2(pixel_step.x, pixel_step.y)));
		surrounding_alpha = max(surrounding_alpha, read_alpha(SCREEN_UV, vec2(-pixel_step.x, pixel_step.y)));
		surrounding_alpha = max(surrounding_alpha, read_alpha(SCREEN_UV, vec2(pixel_step.x, -pixel_step.y)));
		surrounding_alpha = max(surrounding_alpha, read_alpha(SCREEN_UV, vec2(-pixel_step.x, -pixel_step.y)));

		float border_alpha = surrounding_alpha * (1.0 - source.a) * outline_color.a;
		float final_alpha = clamp(source.a + border_alpha, 0.0, 1.0);
		vec3 final_rgb = source.rgb;
		if (final_alpha > 0.0001) {
			final_rgb = (source.rgb * source.a + outline_color.rgb * border_alpha) / final_alpha;
		}
		COLOR *= vec4(final_rgb, final_alpha);
	}
}
