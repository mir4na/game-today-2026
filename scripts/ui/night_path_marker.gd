@tool
class_name NightPathMarker
extends TextureRect
## A small, countable mark on a Night Service station path.

@export var path_node_id: StringName


func get_path_node_center() -> Vector2:
	return position + size * 0.5
