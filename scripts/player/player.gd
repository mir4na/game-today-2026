class_name ConductorPlayer
extends CharacterBody2D

signal nearby_interactable_changed(interactable: Interactable)
signal interaction_pressed(interactable: Interactable)

@export var move_speed: float = 320.0
@export var movement_enabled: bool = true
@export var interaction_enabled: bool = true:
	set(value):
		interaction_enabled = value
		if not interaction_enabled and is_inside_tree():
			_set_nearest(null)
@export_category("Interaction Presentation")
@export_node_path("Marker2D") var interaction_prompt_anchor_path: NodePath
@export_category("Artwork Direction")
@export var artwork_faces_left: bool = true
@export_category("Camera Transitions")
@export var cutscene_zoom_out_animation: StringName = &"cutscene_zoom_out"
@export var gameplay_camera_return_animation: StringName = &"gameplay_camera_return"
var _interactables: Array[Interactable] = []
var _nearest: Interactable
var _facing: float = 1.0
var _walk_time: float = 0.0

@onready var _static_sprite: Sprite2D = %MCVisual
@onready var _camera_transition: AnimationPlayer = %CameraTransition
@onready var _interaction_prompt_anchor: Marker2D = get_node_or_null(interaction_prompt_anchor_path) as Marker2D
@onready var _gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
@onready var _static_sprite_base_y: float = _static_sprite.position.y

func _physics_process(delta: float) -> void:
	var direction: float = 0.0
	if movement_enabled:
		direction = Input.get_axis(&"move_left", &"move_right")
	velocity.x = direction * move_speed
	if not is_on_floor():
		velocity.y += _gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if absf(direction) > 0.01:
		_facing = signf(direction)
		_walk_time += delta * 10.0
	_update_visual(direction)
	_update_nearest()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and interaction_enabled and is_instance_valid(_nearest):
		interaction_pressed.emit(_nearest)
		get_viewport().set_input_as_handled()

func set_interactables(nodes: Array[Interactable]) -> void:
	_interactables = nodes
	_update_nearest()

func clear_interactable() -> void:
	_set_nearest(null)

func get_interaction_prompt_global_position() -> Vector2:
	return _interaction_prompt_anchor.global_position if is_instance_valid(_interaction_prompt_anchor) else global_position

func begin_station_cutscene_camera() -> void:
	_play_camera_transition(cutscene_zoom_out_animation)

func begin_gameplay_camera_return() -> void:
	_play_camera_transition(gameplay_camera_return_animation)

func _play_camera_transition(animation_name: StringName) -> void:
	if not _camera_transition.has_animation(animation_name):
		push_warning("Missing player camera animation: %s" % animation_name)
		return
	_camera_transition.play(animation_name)

func _update_nearest() -> void:
	var candidate: Interactable = null
	var closest_distance: float = INF
	if interaction_enabled:
		for interactable: Interactable in _interactables:
			if not is_instance_valid(interactable) or not interactable.can_interact():
				continue
			var distance: float = global_position.distance_to(interactable.global_position)
			if distance <= interactable.interaction_distance and distance < closest_distance:
				candidate = interactable
				closest_distance = distance
	_set_nearest(candidate)

func _set_nearest(candidate: Interactable) -> void:
	if candidate == _nearest:
		return
	if is_instance_valid(_nearest):
		_nearest.set_interaction_focus(false)
	_nearest = candidate
	if is_instance_valid(_nearest):
		_nearest.set_interaction_focus(true)
	nearby_interactable_changed.emit(_nearest)

func _update_visual(_direction: float) -> void:
	var bob: float = sin(_walk_time) * 2.0 if absf(velocity.x) > 1.0 else 0.0
	var flip_horizontally: bool = _facing > 0.0 if artwork_faces_left else _facing < 0.0
	_static_sprite.position.y = _static_sprite_base_y + bob
	_static_sprite.flip_h = flip_horizontally
