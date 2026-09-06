shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float edge_softness : hint_range(0.0, 0.02) = 0.003;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 from_hub = vec2(UV.x - 0.5, 1.0 - UV.y);
	float angle = atan(from_hub.y, from_hub.x);
	float segment_progress = clamp(1.0 - angle / PI, 0.0, 1.0);
	float reveal = smoothstep(
		segment_progress - edge_softness,
		segment_progress + edge_softness,
		progress
	);
	COLOR = vec4(source.rgb, source.a * reveal);
}
