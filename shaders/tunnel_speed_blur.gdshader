shader_type canvas_item;
render_mode unshaded;

uniform sampler2D tunnel_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform float scroll_offset = 0.0;
uniform float visible_uv_width : hint_range(0.05, 1.0) = 0.46;
uniform float visible_uv_height : hint_range(0.5, 1.0) = 0.93;
uniform float blur_distance : hint_range(0.0, 0.04) = 0.014;
uniform float blur_strength : hint_range(0.0, 1.0) = 0.72;
uniform float gray_strength : hint_range(0.0, 1.0) = 0.58;

varying vec4 canvas_modulate;


void vertex() {
	// Preserve the TextureRect and parent CanvasItem modulation separately from
	// the custom texture sample. Without this, a parent alpha tween is ignored
	// and the tunnel artwork disappears only when the node is finally hidden.
	canvas_modulate = COLOR;
}


vec4 tunnel_sample(vec2 uv, float horizontal_offset) {
	vec2 sample_uv = vec2(fract(uv.x + horizontal_offset), clamp(uv.y, 0.0, 1.0));
	return texture(tunnel_texture, sample_uv);
}


void fragment() {
	vec2 tunnel_uv = vec2(
		UV.x * visible_uv_width - scroll_offset,
		(UV.y - 0.5) * visible_uv_height + 0.5
	);
	vec4 sharp = tunnel_sample(tunnel_uv, 0.0);
	vec4 rightward_streak = sharp * 0.28;
	rightward_streak += tunnel_sample(tunnel_uv, blur_distance * 0.18) * 0.22;
	rightward_streak += tunnel_sample(tunnel_uv, blur_distance * 0.42) * 0.18;
	rightward_streak += tunnel_sample(tunnel_uv, blur_distance * 0.72) * 0.13;
	rightward_streak += tunnel_sample(tunnel_uv, blur_distance * 1.05) * 0.09;
	rightward_streak += tunnel_sample(tunnel_uv, blur_distance * 1.45) * 0.06;
	rightward_streak += tunnel_sample(tunnel_uv, blur_distance * 1.9) * 0.04;
	vec4 result = mix(sharp, rightward_streak, blur_strength);
	float luminance = dot(result.rgb, vec3(0.299, 0.587, 0.114));
	result.rgb = mix(result.rgb, vec3(luminance), gray_strength);
	COLOR = result * canvas_modulate;
}
