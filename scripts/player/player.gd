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
@export_category("Artwork Direction")
@export var artwork_faces_left: bool = true
@export_category("Scene Animation")
@export var idle_animation: StringName = &"idle"
@export var walk_animation: StringName = &"walk"
@export_range(0.0, 64.0, 0.5) var walk_animation_threshold: float = 2.0
var _interactables: Array[Interactable] = []
var _nearest: Interactable
var _facing: float = 1.0
var _market_speed_bonus: float = 0.0

@onready var _animated_sprite: AnimatedSprite2D = %MCVisual
@onready var _gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))


func _ready() -> void:
	_play_animation(idle_animation)

func _physics_process(delta: float) -> void:
	var direction: float = 0.0
	if movement_enabled:
		direction = Input.get_axis(&"move_left", &"move_right")
	velocity.x = direction * get_effective_move_speed()
	if not is_on_floor():
		velocity.y += _gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if absf(direction) > 0.01:
		_facing = signf(direction)
	_update_visual()
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


func set_market_speed_bonus(value: float) -> void:
	_market_speed_bonus = maxf(0.0, value)


func get_effective_move_speed() -> float:
	return move_speed + _market_speed_bonus

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

func _update_visual() -> void:
	var flip_horizontally: bool = _facing > 0.0 if artwork_faces_left else _facing < 0.0
	_animated_sprite.flip_h = flip_horizontally
	_play_animation(walk_animation if absf(velocity.x) >= walk_animation_threshold else idle_animation)


func _play_animation(animation_name: StringName) -> void:
	if not is_instance_valid(_animated_sprite) or not _animated_sprite.sprite_frames.has_animation(animation_name):
		return
	if _animated_sprite.animation != animation_name or not _animated_sprite.is_playing():
		_animated_sprite.play(animation_name)
