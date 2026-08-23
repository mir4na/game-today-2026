class_name TrainExteriorBody
extends Node2D
## Drives scene-authored exterior layers inside each carriage prefab.

signal transition_in_finished
signal transition_out_started
signal doors_open_changed(is_open: bool)

@export_category("Scene Animations")
@export var transition_in_animation: StringName = &"exterior_fade_in"
@export var transition_out_animation: StringName = &"exterior_fade_out"
@export_range(0.0, 3.0, 0.05) var closed_hold_before_exit: float = 1.0

var _elapsed: float = 0.0
var _duration: float = 1.0
var _arrival_end: float = 0.0
var _departure_start: float = 1.0
var _transition_out_started: bool = false
var _doors_open: bool = false

@onready var _transition_animation: AnimationPlayer = %ExteriorTransition

func _ready() -> void:
	_transition_animation.animation_finished.connect(_on_transition_animation_finished)

func begin_sequence(duration: float, arrival_end: float, departure_start: float) -> void:
	_duration = maxf(duration, 0.01)
	_arrival_end = maxf(arrival_end, 0.0)
	_departure_start = clampf(departure_start, 0.0, _duration)
	_elapsed = 0.0
	_transition_out_started = false
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	_update_door_state()
	_play_transition(transition_in_animation)

func end_sequence() -> void:
	_transition_animation.stop()
	_set_doors_open(false)
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()

func set_sequence_elapsed(value: float) -> void:
	_elapsed = clampf(value, 0.0, _duration)
	_update_door_state()
	_update_exit_transition()

func _update_door_state() -> void:
	var doors_open: bool = _elapsed >= _arrival_end and _elapsed < _departure_start
	_set_doors_open(doors_open)

func _set_doors_open(value: bool) -> void:
	if _doors_open == value:
		return
	_doors_open = value
	doors_open_changed.emit(_doors_open)

func _update_exit_transition() -> void:
	if _transition_out_started:
		return
	var exit_start: float = _departure_start + closed_hold_before_exit
	if _elapsed < exit_start:
		return
	_transition_out_started = true
	transition_out_started.emit()
	_play_transition(transition_out_animation)

func _play_transition(animation_name: StringName) -> void:
	if not _transition_animation.has_animation(animation_name):
		push_warning("Missing exterior transition animation: %s" % animation_name)
		return
	_transition_animation.play(animation_name)

func _on_transition_animation_finished(animation_name: StringName) -> void:
	if animation_name == transition_in_animation:
		transition_in_finished.emit()
