@tool
class_name NightPathMarker
extends TextureRect
## A small, countable mark on a Night Service station path.

@export var path_node_id: StringName
@export_category("Star Motion")
@export_range(0.0, 0.25, 0.005) var pulse_amount: float = 0.075
@export_range(0.2, 4.0, 0.05) var pulse_speed: float = 1.65
@export_range(0.0, 12.0, 0.25) var idle_rotation_amount_degrees: float = 3.5

var _motion_phase: float = 0.0
var _star_material: ShaderMaterial


func _ready() -> void:
	pivot_offset = size * 0.5
	_motion_phase = float(abs(str(path_node_id).hash() % 997)) / 997.0 * TAU
	_star_material = material as ShaderMaterial
	if _star_material != null:
		_star_material.set_shader_parameter(&"shimmer_offset", _motion_phase / TAU)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var time_seconds: float = Time.get_ticks_msec() * 0.001
	var wave: float = sin(time_seconds * pulse_speed + _motion_phase)
	var pulse: float = 1.0 + wave * pulse_amount
	scale = Vector2.ONE * pulse
	rotation = deg_to_rad(idle_rotation_amount_degrees) * sin(
		time_seconds * pulse_speed * 0.62 + _motion_phase
	)


func get_path_node_center() -> Vector2:
	var authored_anchor := get_node_or_null("PathAnchor") as Node2D
	if is_instance_valid(authored_anchor):
		return position + authored_anchor.position
	return position + size * 0.5
