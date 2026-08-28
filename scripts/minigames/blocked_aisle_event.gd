class_name BlockedAisleEvent
extends Interactable
## Scene-authored luggage event placed visually at a connector door.
## Luggage uses an Area2D interaction shape, while a separate scene-authored
## doorway barrier prevents passage until the puzzle is resolved.

signal puzzle_requested(event: Node)
signal resolved(event: Node)

@export_category("Blocked Coaches")
@export var adjacent_carriages: Vector2i = Vector2i(1, 2)
@export_category("Scene Nodes")
@export_node_path("CollisionShape2D") var door_blocker_collision_path: NodePath
@export_node_path("CollisionShape2D") var interaction_collision_path: NodePath

@onready var _door_blocker_collision: CollisionShape2D = get_node_or_null(door_blocker_collision_path) as CollisionShape2D
@onready var _interaction_collision: CollisionShape2D = get_node_or_null(interaction_collision_path) as CollisionShape2D

var _resolved: bool = false


func _ready() -> void:
	super._ready()
	set_event_active(false)


func interact() -> void:
	if can_interact() and not _resolved:
		puzzle_requested.emit(self)


func set_event_active(value: bool) -> void:
	_resolved = false if value else _resolved
	visible = value
	enabled = value
	_set_collision_enabled(_door_blocker_collision, value)
	_set_collision_enabled(_interaction_collision, value)


func mark_solved() -> void:
	if _resolved:
		return
	_resolved = true
	enabled = false
	_set_collision_enabled(_door_blocker_collision, false)
	_set_collision_enabled(_interaction_collision, false)
	hide()
	resolved.emit(self)


func is_resolved() -> bool:
	return _resolved


func _set_collision_enabled(collision: CollisionShape2D, value: bool) -> void:
	if is_instance_valid(collision):
		collision.set_deferred(&"disabled", not value)
