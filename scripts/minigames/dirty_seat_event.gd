class_name DirtySeatEvent
extends Interactable
## A scene-authored dirty seat that locks daylight drop-off stamping in its coach.

signal cleaning_requested(event: Node)
signal resolved(event: Node)

@export_category("Coach Assignment")
@export_range(1, 4, 1) var carriage_number: int = 1
@export_category("Scene Nodes")
@export_node_path("CollisionShape2D") var interaction_collision_path: NodePath
@export_node_path("Marker2D") var seat_marker_path: NodePath

@onready var _interaction_collision: CollisionShape2D = get_node_or_null(interaction_collision_path) as CollisionShape2D

var _resolved: bool = false


func _ready() -> void:
	super._ready()
	set_event_active(false)


func interact() -> void:
	if can_interact() and not _resolved:
		cleaning_requested.emit(self)


func set_carriage_number(value: int) -> void:
	carriage_number = value


func get_seat_marker() -> Marker2D:
	return get_node_or_null(seat_marker_path) as Marker2D


func set_event_active(value: bool) -> void:
	_resolved = false if value else _resolved
	visible = value
	enabled = value
	if is_instance_valid(_interaction_collision):
		_interaction_collision.set_deferred(&"disabled", not value)


func mark_solved() -> void:
	if _resolved:
		return
	_resolved = true
	enabled = false
	if is_instance_valid(_interaction_collision):
		_interaction_collision.set_deferred(&"disabled", true)
	hide()
	resolved.emit(self)


func is_resolved() -> bool:
	return _resolved
