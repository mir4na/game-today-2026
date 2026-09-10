shader_type canvas_item;
render_mode unshaded;

uniform vec3 reference_background_color : source_color = vec3(0.266667, 0.266667, 0.266667);
uniform float solid_cutoff : hint_range(0.0, 0.1, 0.001) = 0.012;
uniform float feather_cutoff : hint_range(0.0, 0.1, 0.001) = 0.035;
uniform vec4 reference_content_bounds = vec4(0.15, 0.10, 0.85, 0.90);
uniform vec2 pixel_grid = vec2(30.0, 40.0);
uniform float color_levels : hint_range(2.0, 16.0, 1.0) = 6.0;
uniform float newsprint_mix : hint_range(0.0, 1.0, 0.01) = 0.28;


void fragment() {
	vec2 safe_grid = max(pixel_grid, vec2(1.0));
	vec2 censored_uv = (floor(UV * safe_grid) + vec2(0.5)) / safe_grid;
	vec4 source_pixel = texture(TEXTURE, UV);
	vec4 censored_pixel = texture(TEXTURE, censored_uv);
	float background_distance = distance(source_pixel.rgb, reference_background_color);
	float cutout_alpha = smoothstep(solid_cutoff, feather_cutoff, background_distance);
	if (
		UV.x < reference_content_bounds.x
		|| UV.y < reference_content_bounds.y
		|| UV.x > reference_content_bounds.z
		|| UV.y > reference_content_bounds.w
	) {
		cutout_alpha = 0.0;
	}
	vec3 quantized = floor(censored_pixel.rgb * color_levels + 0.5) / color_levels;
	float luminance = dot(quantized, vec3(0.299, 0.587, 0.114));
	vec3 newsprint = vec3(luminance) * vec3(0.95, 0.88, 0.76);
	vec3 final_color = mix(quantized, newsprint, newsprint_mix);
	COLOR = vec4(final_color, censored_pixel.a * cutout_alpha);
}
