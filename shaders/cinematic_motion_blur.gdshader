shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.72;
uniform float blur_distance : hint_range(0.0, 0.08) = 0.028;


void fragment() {
	vec4 canvas_tint = COLOR;
	vec2 direction = vec2(blur_distance * (0.35 + abs(SCREEN_UV.x - 0.5) * 1.3), 0.0);
	vec3 blurred = texture(screen_texture, SCREEN_UV).rgb * 0.28;
	blurred += texture(screen_texture, clamp(SCREEN_UV - direction * 0.22, vec2(0.0), vec2(1.0))).rgb * 0.22;
	blurred += texture(screen_texture, clamp(SCREEN_UV - direction * 0.5, vec2(0.0), vec2(1.0))).rgb * 0.18;
	blurred += texture(screen_texture, clamp(SCREEN_UV - direction * 0.85, vec2(0.0), vec2(1.0))).rgb * 0.13;
	blurred += texture(screen_texture, clamp(SCREEN_UV - direction * 1.25, vec2(0.0), vec2(1.0))).rgb * 0.1;
	blurred += texture(screen_texture, clamp(SCREEN_UV - direction * 1.75, vec2(0.0), vec2(1.0))).rgb * 0.06;
	blurred += texture(screen_texture, clamp(SCREEN_UV - direction * 2.35, vec2(0.0), vec2(1.0))).rgb * 0.03;
	COLOR = vec4(blurred * canvas_tint.rgb, canvas_tint.a * strength);
}
