class_name NightTransitionCutsceneUI
extends Control
## Scene-authored passage through the veil before the nightly assignment shift.

signal veil_crossed
signal sequence_finished

@export var transition_animation: StringName = &"transition"
@export_range(0.0, 30.0, 0.05) var veil_crossing_time: float = 5.25
@export_range(0.0, 10.0, 0.05) var skip_unlock_seconds: float = 1.5

@onready var _animation_player: AnimationPlayer = %TransitionAnimation

var _elapsed: float = 0.0
var _veil_crossed: bool = false
var _finished: bool = false


func _ready() -> void:
	set_process(false)


func play_transition() -> void:
	_elapsed = 0.0
	_veil_crossed = false
	_finished = false
	show()
	set_process(true)
	_animation_player.play(&"RESET")
	_animation_player.advance(0.0)
	_animation_player.play(transition_animation)


func _process(delta: float) -> void:
	_elapsed += delta
	if not _veil_crossed and _elapsed >= veil_crossing_time:
		_emit_veil_crossed()


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
	_emit_veil_crossed()
	_finish_sequence()


func _on_transition_animation_finished(animation_name: StringName) -> void:
	if animation_name == transition_animation:
		_finish_sequence()


func _emit_veil_crossed() -> void:
	if _veil_crossed:
		return
	_veil_crossed = true
	veil_crossed.emit()


func _finish_sequence() -> void:
	if _finished:
		return
	_finished = true
	_emit_veil_crossed()
	set_process(false)
	hide()
	sequence_finished.emit()
