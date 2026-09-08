shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 player_screen_uv = vec2(0.5, 0.62);
uniform vec4 slowed_tint : source_color = vec4(0.87, 0.92, 1.0, 1.0);
uniform vec4 light_tint : source_color = vec4(0.72, 0.92, 1.0, 1.0);
uniform float effect_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float burst_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float flow_direction : hint_range(-1.0, 1.0, 1.0) = -1.0;
uniform float elapsed_seconds = 0.0;
uniform float world_brightness : hint_range(0.0, 1.0, 0.01) = 0.84;
uniform float world_saturation : hint_range(0.0, 1.0, 0.01) = 0.68;
uniform float ray_density : hint_range(6.0, 48.0, 1.0) = 24.0;
uniform float ray_speed : hint_range(0.1, 8.0, 0.1) = 2.8;
uniform float ray_intensity : hint_range(0.0, 2.0, 0.01) = 0.38;

float hash_1d(float value) {
	return fract(sin(value * 91.3458) * 47453.5453);
}

void fragment() {
	vec4 source = textureLod(screen_texture, SCREEN_UV, 0.0);
	vec2 centered = SCREEN_UV - player_screen_uv;
	centered.x *= SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.00001);
	float radial_distance = length(centered);

	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 monochrome = mix(vec3(luminance), source.rgb, world_saturation);
	vec3 slowed_world = monochrome * slowed_tint.rgb * world_brightness;
	vec3 color = mix(source.rgb, slowed_world, effect_strength);

	float angle = atan(centered.y, centered.x);
	float spoke_id = floor((angle + 3.14159265) / 6.2831853 * ray_density);
	float spoke_center = (spoke_id + 0.5) / ray_density * 6.2831853 - 3.14159265;
	float spoke_width = abs(sin((angle - spoke_center) * ray_density * 0.5));
	float spoke = pow(1.0 - clamp(spoke_width, 0.0, 1.0), 12.0);
	float random_length = mix(0.28, 0.76, hash_1d(spoke_id + 17.0));
	float traveling_band = fract(radial_distance * 8.0 - elapsed_seconds * ray_speed * flow_direction + hash_1d(spoke_id));
	float ray_head = smoothstep(0.02, 0.16, traveling_band) * (1.0 - smoothstep(0.16, 0.42, traveling_band));
	float distance_fade = smoothstep(0.035, 0.11, radial_distance) * (1.0 - smoothstep(random_length, random_length + 0.18, radial_distance));
	float rays = spoke * ray_head * distance_fade * burst_strength;
	color += mix(source.rgb, light_tint.rgb, 0.64) * rays * ray_intensity;
	COLOR = vec4(color, 1.0);
}
