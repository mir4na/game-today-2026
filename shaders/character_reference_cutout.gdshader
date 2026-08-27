shader_type canvas_item;

uniform vec3 reference_background_color : source_color = vec3(0.266667, 0.266667, 0.266667);
uniform float solid_cutoff : hint_range(0.0, 0.1, 0.001) = 0.012;
uniform float feather_cutoff : hint_range(0.0, 0.1, 0.001) = 0.035;
uniform vec4 reference_content_bounds = vec4(0.15, 0.10, 0.85, 0.90);

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float background_distance = distance(pixel.rgb, reference_background_color);
	float cutout_alpha = smoothstep(solid_cutoff, feather_cutoff, background_distance);
	if (
		UV.x < reference_content_bounds.x
		|| UV.y < reference_content_bounds.y
		|| UV.x > reference_content_bounds.z
		|| UV.y > reference_content_bounds.w
	) {
		cutout_alpha = 0.0;
	}
	pixel.a *= cutout_alpha;
	COLOR = pixel;
}
