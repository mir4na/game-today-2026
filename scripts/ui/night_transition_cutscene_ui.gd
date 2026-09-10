class_name NightTransitionCutsceneUI
extends Control
## Scene-authored passage through the veil before the nightly assignment shift.

signal veil_crossed
signal camera_return_requested
signal sequence_timeline_changed(elapsed: float)
signal sequence_finished

@export var transition_animation: StringName = &"transition"
@export_range(0.0, 30.0, 0.05) var veil_crossing_time: float = 5.25
@export_range(0.0, 10.0, 0.05) var skip_unlock_seconds: float = 1.5
@export_category("Station Train Motion")
@export_range(0.0, 10.0, 0.05) var departure_start_time: float = 0.45
@export_range(0.0, 1.0, 0.01) var veil_departure_progress: float = 0.58
@export_range(0.0, 10.0, 0.05) var departure_end_time: float = 8.35
@export_range(0.0, 10.0, 0.05) var camera_return_time: float = 8.55

@onready var _animation_player: AnimationPlayer = %TransitionAnimation

var _elapsed: float = 0.0
var _veil_crossed: bool = false
var _camera_return_requested: bool = false
var _finished: bool = false


func _ready() -> void:
	set_process(false)


func play_transition() -> void:
	_elapsed = 0.0
	_veil_crossed = false
	_camera_return_requested = false
	_finished = false
	show()
	set_process(true)
	_animation_player.play(&"RESET")
	_animation_player.advance(0.0)
	_animation_player.play(transition_animation)
	sequence_timeline_changed.emit(_elapsed)


func _process(delta: float) -> void:
	_elapsed += delta
	sequence_timeline_changed.emit(_elapsed)
	if not _veil_crossed and _elapsed >= veil_crossing_time:
		_emit_veil_crossed()
	if not _camera_return_requested and _elapsed >= camera_return_time:
		_emit_camera_return_requested()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _elapsed < skip_unlock_seconds:
		return
	if event.is_action_pressed(&"ui_cancel"):
		skip_sequence()
		get_viewport().set_input_as_handled()


func skip_sequence() -> void:
	if _finished:
		return
	_animation_player.stop()
	_elapsed = maxf(_elapsed, departure_end_time)
	sequence_timeline_changed.emit(_elapsed)
	_emit_veil_crossed()
	_emit_camera_return_requested()
	_finish_sequence()


func _on_transition_animation_finished(animation_name: StringName) -> void:
	if animation_name == transition_animation:
		_finish_sequence()


func _emit_veil_crossed() -> void:
	if _veil_crossed:
		return
	_veil_crossed = true
	veil_crossed.emit()


func _emit_camera_return_requested() -> void:
	if _camera_return_requested:
		return
	_camera_return_requested = true
	camera_return_requested.emit()


func get_station_departure_progress() -> float:
	var crossing_time: float = maxf(veil_crossing_time, departure_start_time + 0.01)
	var finish_time: float = maxf(departure_end_time, crossing_time + 0.01)
	if _elapsed <= departure_start_time:
		return 0.0
	if _elapsed <= crossing_time:
		var approach: float = clampf(
			inverse_lerp(departure_start_time, crossing_time, _elapsed),
			0.0,
			1.0
		)
		return _ease_in_out_sine(approach) * veil_departure_progress
	var exit_progress: float = clampf(
		inverse_lerp(crossing_time, finish_time, _elapsed),
		0.0,
		1.0
	)
	return lerpf(
		veil_departure_progress,
		1.0,
		_ease_in_out_sine(exit_progress)
	)


func _finish_sequence() -> void:
	if _finished:
		return
	_finished = true
	_elapsed = maxf(_elapsed, departure_end_time)
	sequence_timeline_changed.emit(_elapsed)
	_emit_veil_crossed()
	_emit_camera_return_requested()
	set_process(false)
	hide()
	sequence_finished.emit()


func _ease_in_out_sine(value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	return -(cos(PI * clamped) - 1.0) * 0.5
