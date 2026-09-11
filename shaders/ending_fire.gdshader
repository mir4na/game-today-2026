shader_type canvas_item;
render_mode unshaded;

uniform float speed : hint_range(0.0, 5.0) = 1.7;
uniform float wobble : hint_range(0.0, 0.04) = 0.009;
uniform float pulse_amount : hint_range(0.0, 0.6) = 0.16;
uniform float phase : hint_range(0.0, 6.283) = 0.0;
uniform vec4 fire_tint : source_color = vec4(1.0, 0.88, 0.74, 1.0);

void fragment() {
	vec2 uv = UV;
	float height_fade = smoothstep(0.0, 0.24, uv.y);
	uv.x += sin(uv.y * 22.0 + TIME * speed + phase) * wobble * height_fade;
	uv.y += sin(uv.x * 15.0 - TIME * speed * 0.72 + phase) * wobble * 0.42;
	vec4 fire = texture(TEXTURE, uv);
	float pulse = 1.0 + sin(TIME * speed * 1.3 + uv.x * 9.0 + phase) * pulse_amount;
	COLOR = vec4(fire.rgb * fire_tint.rgb * pulse, fire.a * fire_tint.a) * COLOR;
}
