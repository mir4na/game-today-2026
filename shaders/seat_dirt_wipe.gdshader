shader_type canvas_item;
render_mode unshaded;

uniform sampler2D erase_mask : filter_linear, repeat_disable;
uniform vec2 surface_size = vec2(280.0, 435.0);
uniform vec4 stain_a = vec4(0.50, 0.28, 40.0, 1.0);
uniform vec4 stain_b = vec4(0.38, 0.49, 34.0, 2.0);
uniform vec4 stain_c = vec4(0.63, 0.61, 38.0, 3.0);
uniform vec4 stain_d = vec4(0.47, 0.78, 32.0, 4.0);
uniform vec4 dirt_color : source_color = vec4(0.20, 0.105, 0.045, 0.90);


float stain_blob(vec2 uv, vec4 stain) {
	vec2 pixel_delta = (uv - stain.xy) * surface_size;
	float normalized_distance = length(pixel_delta) / max(stain.z, 1.0);
	float irregularity = sin(pixel_delta.x * 0.18 + stain.w * 2.7) * 0.055;
	irregularity += sin(pixel_delta.y * 0.23 - stain.w * 1.9) * 0.045;
	float core = 1.0 - smoothstep(0.68 + irregularity, 1.0 + irregularity, normalized_distance);
	float speckle = 0.88 + 0.12 * sin((pixel_delta.x + pixel_delta.y) * 0.31 + stain.w);
	return clamp(core * speckle, 0.0, 1.0);
}


void fragment() {
	float dirt = max(max(stain_blob(UV, stain_a), stain_blob(UV, stain_b)), max(stain_blob(UV, stain_c), stain_blob(UV, stain_d)));
	float erased = texture(erase_mask, UV).r;
	COLOR = vec4(dirt_color.rgb, dirt_color.a * dirt * (1.0 - erased));
}
