shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float threshold : hint_range(0.0, 1.5, 0.01) = 0.72;
uniform float soft_knee : hint_range(0.01, 0.5, 0.01) = 0.18;
uniform float intensity : hint_range(0.0, 1.5, 0.01) = 0.34;
uniform float radius : hint_range(0.5, 8.0, 0.1) = 4.2;
uniform vec4 bloom_tint : source_color = vec4(1.0, 0.9, 0.78, 1.0);


vec3 extract_highlights(vec3 color) {
	float brightness = max(color.r, max(color.g, color.b));
	float contribution = smoothstep(
		threshold - soft_knee,
		threshold + soft_knee,
		brightness
	);
	return color * contribution;
}


void fragment() {
	vec4 source = textureLod(screen_texture, SCREEN_UV, 0.0);
	float lod = max(radius, 0.5);

	// Mip levels provide a stable, inexpensive blur on the Mobile renderer.
	// Mixing three scales gives small highlights a soft core and a wide halo.
	vec3 tight_glow = extract_highlights(textureLod(screen_texture, SCREEN_UV, lod * 0.55).rgb);
	vec3 medium_glow = extract_highlights(textureLod(screen_texture, SCREEN_UV, lod).rgb);
	vec3 wide_glow = extract_highlights(textureLod(screen_texture, SCREEN_UV, lod * 1.45).rgb);
	vec3 bloom = tight_glow * 0.5 + medium_glow * 0.32 + wide_glow * 0.18;

	COLOR = vec4(source.rgb + bloom * bloom_tint.rgb * intensity, source.a);
}
