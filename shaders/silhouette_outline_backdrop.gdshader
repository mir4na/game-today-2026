shader_type canvas_item;
render_mode unshaded;

uniform bool outline_enabled = false;
uniform vec4 outline_color : source_color = vec4(0.96, 0.78, 0.32, 1.0);
uniform float outline_width : hint_range(1.0, 8.0, 0.5) = 4.0;
uniform float interaction_lock_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float radar_detection_strength : hint_range(0.0, 1.0, 0.01) = 0.0;

void vertex() {
	if (outline_enabled) {
		VERTEX += (UV * 2.0 - vec2(1.0)) * outline_width;
	}
}

void fragment() {
	float source_alpha = texture(TEXTURE, UV).a;
	float enabled_alpha = outline_enabled ? 1.0 : 0.0;
	COLOR = vec4(outline_color.rgb, source_alpha * outline_color.a * enabled_alpha);
}
