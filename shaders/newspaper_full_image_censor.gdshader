shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 pixel_block_size = vec2(14.0, 14.0);


void fragment() {
	vec2 safe_block_size = max(pixel_block_size, vec2(1.0));
	vec2 block_uv = SCREEN_PIXEL_SIZE * safe_block_size;
	vec2 censored_uv = (floor(SCREEN_UV / block_uv) + vec2(0.5)) * block_uv;
	censored_uv = clamp(censored_uv, vec2(0.0), vec2(1.0));
	vec4 censored_color = textureLod(screen_texture, censored_uv, 0.0);
	if (censored_color.a > 0.0001) {
		censored_color.rgb /= censored_color.a;
	}
	COLOR *= censored_color;
}
