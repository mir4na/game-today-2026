shader_type canvas_item;

// A soft moving glint keeps every station star alive. The outline is enabled
// only by its owning drop target while a Soul Record is dragged over it.
uniform float shimmer_strength : hint_range(0.0, 1.0) = 0.62;
uniform float shimmer_speed : hint_range(0.0, 2.0) = 0.34;
uniform float shimmer_width : hint_range(0.01, 0.4) = 0.11;
uniform float shimmer_offset : hint_range(0.0, 1.0) = 0.0;
uniform float outline_strength : hint_range(0.0, 1.0) = 0.0;
uniform float outline_size : hint_range(0.0, 16.0) = 8.0;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 pixel = TEXTURE_PIXEL_SIZE * outline_size;
	float nearby_alpha = 0.0;
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(-pixel.x, 0.0)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(0.0, pixel.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(0.0, -pixel.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(pixel.x, pixel.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(-pixel.x, pixel.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(pixel.x, -pixel.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - pixel).a);

	float sweep_position = fract(TIME * shimmer_speed + shimmer_offset) * 2.0 - 0.5;
	float diagonal = (UV.x + UV.y) * 0.5;
	float glint = 1.0 - smoothstep(0.0, shimmer_width, abs(diagonal - sweep_position));
	float twinkle = 0.5 + 0.5 * sin(TIME * 2.4 + shimmer_offset * 6.283185);
	float light_amount = clamp(
		glint * shimmer_strength + twinkle * 0.12 + outline_strength * 0.20,
		0.0,
		0.9
	);
	vec3 shimmering_color = mix(
		source.rgb,
		vec3(1.0, 0.94, 0.72),
		light_amount * source.a
	);

	float outline_alpha = max(nearby_alpha - source.a, 0.0) * outline_strength;
	float use_outline = step(source.a + 0.001, outline_alpha);
	vec3 final_color = mix(shimmering_color, outline_color.rgb, use_outline);
	float final_alpha = max(source.a, outline_alpha * outline_color.a);
	COLOR = vec4(final_color, final_alpha) * COLOR;
}
