shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 flash_color : source_color = vec4(0.9, 0.035, 0.045, 1.0);

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float edge = smoothstep(0.18, 1.05, length(centered));
	float diagonal = 0.5 + 0.5 * sin((UV.x + UV.y) * 34.0 + TIME * 10.0);
	float pulse_alpha = (0.08 + edge * 0.58 + diagonal * 0.08) * strength;
	COLOR = vec4(flash_color.rgb, pulse_alpha * flash_color.a);
}
