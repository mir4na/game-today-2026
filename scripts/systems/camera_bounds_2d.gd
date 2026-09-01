class_name CameraBounds2D
extends Node2D
## Applies scene-authored Min/Max markers to a Camera2D's built-in view limits.

@export_node_path("Camera2D") var camera_path: NodePath
@export_node_path("Marker2D") var min_marker_path: NodePath
@export_node_path("Marker2D") var max_marker_path: NodePath
@export var bounds_enabled: bool = true
@export var bounds_padding: Vector2 = Vector2.ZERO

@onready var _camera: Camera2D = get_node_or_null(camera_path) as Camera2D
@onready var _min_marker: Marker2D = get_node_or_null(min_marker_path) as Marker2D
@onready var _max_marker: Marker2D = get_node_or_null(max_marker_path) as Marker2D


func _ready() -> void:
	apply_bounds_from_markers()


func apply_bounds_from_markers() -> void:
	if not bounds_enabled:
		return
	if not is_instance_valid(_camera):
		push_error("CameraBounds2D requires a Camera2D assigned through camera_path.")
		return
	if not is_instance_valid(_min_marker) or not is_instance_valid(_max_marker):
		push_error("CameraBounds2D requires both Min and Max Marker2D nodes.")
		return

	var first_corner: Vector2 = _min_marker.global_position + bounds_padding
	var second_corner: Vector2 = _max_marker.global_position - bounds_padding
	var bounds_min := Vector2(
		minf(first_corner.x, second_corner.x),
		minf(first_corner.y, second_corner.y)
	)
	var bounds_max := Vector2(
		maxf(first_corner.x, second_corner.x),
		maxf(first_corner.y, second_corner.y)
	)

	_camera.limit_left = floori(bounds_min.x)
	_camera.limit_top = floori(bounds_min.y)
	_camera.limit_right = ceili(bounds_max.x)
	_camera.limit_bottom = ceili(bounds_max.y)
	_camera.reset_smoothing()
