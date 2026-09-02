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
@export_node_path("Node2D") var left_spawn_anchor_path: NodePath
@export_node_path("Node2D") var right_spawn_anchor_path: NodePath
@export_node_path("Node2D") var door_center_anchor_path: NodePath
@export_node_path("Node2D") var luggage_visual_path: NodePath
@export_node_path("CollisionShape2D") var door_blocker_collision_path: NodePath
@export_node_path("CollisionShape2D") var interaction_collision_path: NodePath
@export_node_path("CollisionShape2D") var npc_exclusion_collision_path: NodePath
@export_node_path("Marker2D") var tracker_anchor_path: NodePath

@onready var _left_spawn_anchor: Node2D = get_node_or_null(left_spawn_anchor_path) as Node2D
@onready var _right_spawn_anchor: Node2D = get_node_or_null(right_spawn_anchor_path) as Node2D
@onready var _door_center_anchor: Node2D = get_node_or_null(door_center_anchor_path) as Node2D
@onready var _luggage_visual: Node2D = get_node_or_null(luggage_visual_path) as Node2D
@onready var _door_blocker_collision: CollisionShape2D = get_node_or_null(door_blocker_collision_path) as CollisionShape2D
@onready var _interaction_collision: CollisionShape2D = get_node_or_null(interaction_collision_path) as CollisionShape2D
@onready var _npc_exclusion_collision: CollisionShape2D = get_node_or_null(npc_exclusion_collision_path) as CollisionShape2D

var _resolved: bool = false
var _interaction_offset_from_luggage: Vector2 = Vector2.ZERO
var _active_spawn_side: StringName = &"left"


func _ready() -> void:
	super._ready()
	if is_instance_valid(_interaction_collision) and is_instance_valid(_luggage_visual):
		_interaction_offset_from_luggage = _interaction_collision.position - _luggage_visual.position
	_validate_placement_nodes()
	set_event_active(false)


func interact() -> void:
	if can_interact() and not _resolved:
		puzzle_requested.emit(self)


func set_event_active(value: bool, observer_global_x: float = NAN) -> void:
	_resolved = false if value else _resolved
	if value:
		_place_luggage_for_observer(observer_global_x)
	visible = value
	enabled = value
	_set_collision_enabled(_door_blocker_collision, value)
	_set_collision_enabled(_interaction_collision, value)
	_set_collision_enabled(_npc_exclusion_collision, value)


func mark_solved() -> void:
	if _resolved:
		return
	_resolved = true
	enabled = false
	_set_collision_enabled(_door_blocker_collision, false)
	_set_collision_enabled(_interaction_collision, false)
	_set_collision_enabled(_npc_exclusion_collision, false)
	hide()
	resolved.emit(self)


func is_resolved() -> bool:
	return _resolved


func get_active_spawn_side() -> StringName:
	return _active_spawn_side


func get_tracker_anchor() -> Node2D:
	var configured_anchor := get_node_or_null(tracker_anchor_path) as Node2D
	return configured_anchor if is_instance_valid(configured_anchor) else self


func _place_luggage_for_observer(observer_global_x: float) -> void:
	if not is_instance_valid(_luggage_visual):
		return
	var selected_anchor: Node2D = _left_spawn_anchor
	_active_spawn_side = &"left"
	if (
		not is_nan(observer_global_x)
		and is_instance_valid(_door_center_anchor)
		and observer_global_x > _door_center_anchor.global_position.x
	):
		selected_anchor = _right_spawn_anchor
		_active_spawn_side = &"right"
	if not is_instance_valid(selected_anchor):
		return
	_luggage_visual.position = selected_anchor.position
	if is_instance_valid(_interaction_collision):
		_interaction_collision.position = selected_anchor.position + _interaction_offset_from_luggage


func _validate_placement_nodes() -> void:
	var missing_nodes: Array[String] = []
	if not is_instance_valid(_left_spawn_anchor):
		missing_nodes.append("LeftSpawnAnchor")
	if not is_instance_valid(_right_spawn_anchor):
		missing_nodes.append("RightSpawnAnchor")
	if not is_instance_valid(_door_center_anchor):
		missing_nodes.append("DoorCenterAnchor")
	if not is_instance_valid(_luggage_visual):
		missing_nodes.append("LuggageVisual")
	if not missing_nodes.is_empty():
		push_warning("%s is missing scene placement nodes: %s" % [name, ", ".join(missing_nodes)])


func _set_collision_enabled(collision: CollisionShape2D, value: bool) -> void:
	if is_instance_valid(collision):
		collision.set_deferred(&"disabled", not value)
