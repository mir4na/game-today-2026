@tool
class_name NightPathSegment
extends Line2D
## One graph edge whose ends follow scene-authored station or small-mark anchors.

@export_node_path("Control") var from_anchor_path: NodePath
@export_node_path("Control") var to_anchor_path: NodePath


func _ready() -> void:
	_sync_to_anchors()
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	_sync_to_anchors()


func get_endpoint_ids() -> PackedStringArray:
	return PackedStringArray([
		_resolve_anchor_id(get_node_or_null(from_anchor_path)),
		_resolve_anchor_id(get_node_or_null(to_anchor_path)),
	])


func _sync_to_anchors() -> void:
	var from_anchor := get_node_or_null(from_anchor_path) as Control
	var to_anchor := get_node_or_null(to_anchor_path) as Control
	if from_anchor == null or to_anchor == null:
		return
	points = PackedVector2Array([
		_anchor_center(from_anchor),
		_anchor_center(to_anchor),
	])


func _anchor_center(anchor: Control) -> Vector2:
	# Read the scene-authored marker directly. Calling methods on instanced
	# @tool scripts can fail while Godot is refreshing placeholder instances,
	# which previously left one end of a route at (0, 0) in the editor.
	var path_anchor := anchor.get_node_or_null("PathAnchor") as Node2D
	if is_instance_valid(path_anchor):
		return to_local(path_anchor.global_position)
	return to_local(anchor.global_position + anchor.size * 0.5)


func _resolve_anchor_id(anchor: Node) -> String:
	if anchor is NightStationTarget:
		return (anchor as NightStationTarget).station_name
	if anchor is NightPathMarker:
		return str((anchor as NightPathMarker).path_node_id)
	return ""
