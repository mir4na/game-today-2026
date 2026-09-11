shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 ray_tint : source_color = vec4(1.0, 1.0, 1.0, 0.55);
uniform float pulse_speed : hint_range(0.0, 4.0) = 0.75;
uniform float pulse_amount : hint_range(0.0, 0.75) = 0.18;
uniform float drift_amount : hint_range(0.0, 0.04) = 0.008;
uniform float phase : hint_range(0.0, 6.283) = 0.0;

void fragment() {
	vec2 uv = UV;
	uv.x += sin(TIME * pulse_speed + UV.y * 5.0 + phase) * drift_amount;
	vec4 ray = texture(TEXTURE, uv);
	float pulse = 1.0 - pulse_amount + pulse_amount * (0.5 + 0.5 * sin(TIME * pulse_speed + phase));
	COLOR = vec4(ray.rgb * ray_tint.rgb, ray.a * ray_tint.a * pulse) * COLOR;
}
