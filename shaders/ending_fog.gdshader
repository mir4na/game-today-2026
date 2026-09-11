shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 fog_color : source_color = vec4(0.86, 0.95, 1.0, 0.28);
uniform vec2 flow = vec2(0.025, -0.006);
uniform float scale : hint_range(1.0, 12.0) = 4.2;
uniform float density : hint_range(0.0, 1.0) = 0.48;
uniform float edge_fade : hint_range(0.0, 0.5) = 0.16;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * scale + TIME * flow;
	float n = noise(p) * 0.62 + noise(p * 2.03 + 7.1) * 0.27 + noise(p * 4.11 - 3.7) * 0.11;
	float horizontal_fade = smoothstep(0.0, edge_fade, UV.x) * smoothstep(0.0, edge_fade, 1.0 - UV.x);
	float alpha = smoothstep(0.34, 0.82, n) * density * horizontal_fade * fog_color.a;
	COLOR = vec4(fog_color.rgb, alpha) * COLOR;
}
