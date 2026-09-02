class_name DirtySeatEvent
extends Interactable
## A scene-authored dirty seat that locks daylight drop-off stamping in its coach.

signal cleaning_requested(event: Node)
signal resolved(event: Node)

@export_category("Coach Assignment")
@export_range(1, 4, 1) var carriage_number: int = 1
@export var random_spawn_enabled: bool = true
@export_category("Scene Nodes")
@export_node_path("CollisionShape2D") var interaction_collision_path: NodePath
@export_node_path("Marker2D") var seat_marker_path: NodePath
@export_node_path("CollisionShape2D") var npc_exclusion_collision_path: NodePath
@export_node_path("Marker2D") var tracker_anchor_path: NodePath

@onready var _interaction_collision: CollisionShape2D = get_node_or_null(interaction_collision_path) as CollisionShape2D
@onready var _npc_exclusion_collision: CollisionShape2D = get_node_or_null(npc_exclusion_collision_path) as CollisionShape2D

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


func can_spawn_random_event() -> bool:
	return random_spawn_enabled


func get_tracker_anchor() -> Node2D:
	var configured_anchor := get_node_or_null(tracker_anchor_path) as Node2D
	return configured_anchor if is_instance_valid(configured_anchor) else self


func set_event_active(value: bool) -> void:
	_resolved = false if value else _resolved
	visible = value
	enabled = value
	if is_instance_valid(_interaction_collision):
		_interaction_collision.set_deferred(&"disabled", not value)
	_set_collision_enabled(_npc_exclusion_collision, value)


func mark_solved() -> void:
	if _resolved:
		return
	_resolved = true
	enabled = false
	if is_instance_valid(_interaction_collision):
		_interaction_collision.set_deferred(&"disabled", true)
	_set_collision_enabled(_npc_exclusion_collision, false)
	hide()
	resolved.emit(self)


func is_resolved() -> bool:
	return _resolved


func _set_collision_enabled(collision: CollisionShape2D, value: bool) -> void:
	if is_instance_valid(collision):
		collision.set_deferred(&"disabled", not value)
