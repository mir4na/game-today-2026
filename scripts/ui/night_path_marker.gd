@tool
class_name NightPathMarker
extends TextureRect
## A small, countable mark on a Night Service station path.

@export var path_node_id: StringName


func get_path_node_center() -> Vector2:
	var authored_anchor := get_node_or_null("PathAnchor") as Node2D
	if is_instance_valid(authored_anchor):
		return position + authored_anchor.position
	return position + size * 0.5
