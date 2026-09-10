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
@export var tracker_icon: Texture2D
@export_category("Interaction Flash")
@export_node_path("CanvasItem") var flash_visual_path: NodePath
@export_node_path("AnimationPlayer") var flash_animation_player_path: NodePath
@export var flash_animation_name: StringName = &"interaction_flash"

@onready var _interaction_collision: CollisionShape2D = get_node_or_null(interaction_collision_path) as CollisionShape2D
@onready var _npc_exclusion_collision: CollisionShape2D = get_node_or_null(npc_exclusion_collision_path) as CollisionShape2D
@onready var _flash_visual: CanvasItem = get_node_or_null(flash_visual_path) as CanvasItem
@onready var _flash_animation_player: AnimationPlayer = get_node_or_null(flash_animation_player_path) as AnimationPlayer

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


func get_tracker_icon() -> Texture2D:
	return tracker_icon


func get_maintenance_bounds(_observer_global_x: float = NAN) -> Rect2:
	if not is_instance_valid(_npc_exclusion_collision) or _npc_exclusion_collision.shape == null:
		return Rect2(global_position, Vector2.ZERO)
	var rectangle := _npc_exclusion_collision.shape as RectangleShape2D
	if rectangle == null:
		return Rect2(_npc_exclusion_collision.global_position, Vector2.ZERO)
	var half_size: Vector2 = rectangle.size * 0.5
	var corners := PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	var collision_transform: Transform2D = _npc_exclusion_collision.global_transform
	var first_corner: Vector2 = collision_transform * corners[0]
	var minimum: Vector2 = first_corner
	var maximum: Vector2 = first_corner
	for index: int in range(1, corners.size()):
		var world_corner: Vector2 = collision_transform * corners[index]
		minimum = minimum.min(world_corner)
		maximum = maximum.max(world_corner)
	return Rect2(minimum, maximum - minimum)


func set_event_active(value: bool) -> void:
	_resolved = false if value else _resolved
	visible = value
	enabled = value
	refresh_interaction_outline()
	_set_flash_active(value)
	if is_instance_valid(_interaction_collision):
		_interaction_collision.set_deferred(&"disabled", not value)
	_set_collision_enabled(_npc_exclusion_collision, value)


func mark_solved() -> void:
	if _resolved:
		return
	_resolved = true
	enabled = false
	refresh_interaction_outline()
	_set_flash_active(false)
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


func _set_flash_active(value: bool) -> void:
	if is_instance_valid(_flash_visual):
		_flash_visual.visible = value
	if not is_instance_valid(_flash_animation_player):
		return
	if value and _flash_animation_player.has_animation(flash_animation_name):
		_flash_animation_player.play(flash_animation_name)
	else:
		_flash_animation_player.stop()
