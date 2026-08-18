class_name ConductorPlayer
extends CharacterBody2D

signal nearby_interactable_changed(interactable: Interactable)
signal interaction_pressed(interactable: Interactable)

@export var move_speed: float = 320.0
@export var min_x: float = 70.0
@export var max_x: float = 5690.0
@export var use_placeholder_art: bool = true
@export var movement_enabled: bool = true
@export var interaction_enabled: bool = true
var _interactables: Array[Interactable] = []
var _nearest: Interactable
var _facing: float = 1.0
var _walk_time: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var _placeholder_visual: Node2D = %PlaceholderVisual

func _physics_process(delta: float) -> void:
	var direction: float = 0.0
	if movement_enabled:
		direction = Input.get_axis(&"move_left", &"move_right")
	velocity = Vector2(direction * move_speed, 0.0)
	move_and_slide()
	global_position.x = clampf(global_position.x, min_x, max_x)
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
	_nearest = null
	nearby_interactable_changed.emit(null)

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
	if candidate != _nearest:
		_nearest = candidate
		nearby_interactable_changed.emit(_nearest)

func _update_visual(direction: float) -> void:
	var bob: float = sin(_walk_time) * 2.0 if absf(velocity.x) > 1.0 else 0.0
	_placeholder_visual.visible = use_placeholder_art
	_placeholder_visual.position.y = bob
	_placeholder_visual.scale.x = _facing
	animated_sprite.visible = not use_placeholder_art
	if use_placeholder_art or animated_sprite.sprite_frames == null:
		return
	animated_sprite.flip_h = _facing < 0.0
	var target_animation: StringName = &"walk" if absf(direction) > 0.01 else &"idle"
	if animated_sprite.sprite_frames.has_animation(target_animation) and animated_sprite.animation != target_animation:
		animated_sprite.play(target_animation)
