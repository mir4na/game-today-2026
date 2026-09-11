shader_type canvas_item;

// The identity artwork is full-body. This scene material frames its upper,
// central region so constellation assignments read as faces at small sizes.
void fragment() {
	vec2 face_uv = vec2(
		mix(0.18, 0.82, UV.x),
		mix(0.06, 0.48, UV.y)
	);
	vec4 portrait = texture(TEXTURE, face_uv);
	float circle = smoothstep(0.52, 0.47, distance(UV, vec2(0.5)));
	COLOR = vec4(portrait.rgb, portrait.a * circle);
}
