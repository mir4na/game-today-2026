shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float grayscale_strength : hint_range(0.0, 1.0, 0.01) = 0.0;

void fragment() {
	vec4 source = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (source.a > 0.0001) {
		source.rgb /= source.a;
	}
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	source.rgb = mix(source.rgb, vec3(luminance), grayscale_strength);
	COLOR *= source;
}
