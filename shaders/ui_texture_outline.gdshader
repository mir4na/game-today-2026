shader_type canvas_item;
render_mode unshaded;

uniform vec4 outline_color : source_color = vec4(0.015, 0.018, 0.024, 0.96);
uniform float outline_size : hint_range(0.0, 16.0, 0.5) = 9.0;

void fragment() {
	vec4 vertex_modulate = COLOR;
	vec4 source = texture(TEXTURE, UV);
	vec2 pixel_step = TEXTURE_PIXEL_SIZE * outline_size;
	vec2 diagonal_step = pixel_step * 0.70710678;
	float surrounding_alpha = 0.0;
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(pixel_step.x, 0.0)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(pixel_step.x, 0.0)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(0.0, pixel_step.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(0.0, pixel_step.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + diagonal_step).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - diagonal_step).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(diagonal_step.x, -diagonal_step.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(-diagonal_step.x, diagonal_step.y)).a);

	vec4 base_color = source * vertex_modulate;
	float outline_alpha = surrounding_alpha * (1.0 - source.a) * outline_color.a * vertex_modulate.a;
	COLOR = base_color;
	if (outline_alpha > base_color.a) {
		COLOR = vec4(outline_color.rgb, outline_alpha);
	}
}
