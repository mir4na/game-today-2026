class_name ServiceHintUI
extends Control
## Centered, level-specific onboarding for the two daytime distractions.

signal dismissed

@onready var _blocked_aisle: Control = %BlockedAisle
@onready var _clean_the_seat: Control = %CleanTheSeat

var _closing: bool = false


func _ready() -> void:
	hide()


func show_hint(hint_id: StringName) -> void:
	_blocked_aisle.visible = hint_id == &"blocked_aisle"
	_clean_the_seat.visible = hint_id == &"clean_the_seat"
	if not _blocked_aisle.visible and not _clean_the_seat.visible:
		push_warning("Unknown service hint '%s'." % hint_id)
		return
	_closing = false
	modulate.a = 0.0
	show()
	var fade_in := create_tween()
	fade_in.tween_property(self, ^"modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)


func _input(event: InputEvent) -> void:
	if not visible or _closing:
		return
	var should_close: bool = event is InputEventKey and event.is_pressed() and not event.is_echo()
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		should_close = mouse_event.is_pressed() and mouse_event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
	if not should_close:
		return
	get_viewport().set_input_as_handled()
	_dismiss()


func _dismiss() -> void:
	_closing = true
	var fade_out := create_tween()
	fade_out.tween_property(self, ^"modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE)
	fade_out.tween_callback(func() -> void:
		hide()
		dismissed.emit()
	)
