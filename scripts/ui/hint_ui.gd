class_name ServiceHintUI
extends Control
## Centered, level-specific onboarding for the two daytime distractions.

signal dismissed

@onready var _blocked_aisle: Control = %BlockedAisle
@onready var _clean_the_seat: Control = %CleanTheSeat
@onready var _shade: ColorRect = $Shade
@onready var _content: Control = $Content

var _closing: bool = false
var _opening: bool = false


func _ready() -> void:
	hide()


func show_hint(hint_id: StringName) -> void:
	_blocked_aisle.visible = hint_id == &"blocked_aisle"
	_clean_the_seat.visible = hint_id == &"clean_the_seat"
	if not _blocked_aisle.visible and not _clean_the_seat.visible:
		push_warning("Unknown service hint '%s'." % hint_id)
		return
	_closing = false
	_opening = true
	modulate.a = 1.0
	_shade.modulate.a = 0.0
	_content.modulate.a = 0.0
	_content.pivot_offset = _content.size * 0.5
	_content.scale = Vector2(0.94, 0.94)
	show()
	# The dimmed world arrives first, then the instruction card settles in. This
	# makes the Day 2/3 onboarding read as one deliberate sequence.
	var reveal := create_tween()
	reveal.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal.tween_property(_shade, ^"modulate:a", 1.0, 0.22)
	reveal.tween_interval(0.06)
	reveal.tween_property(_content, ^"modulate:a", 1.0, 0.18)
	reveal.parallel().tween_property(_content, ^"scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_callback(func() -> void: _opening = false)


func _input(event: InputEvent) -> void:
	if not visible or _closing or _opening:
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
	fade_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade_out.tween_property(_content, ^"modulate:a", 0.0, 0.1)
	fade_out.parallel().tween_property(_content, ^"scale", Vector2(0.96, 0.96), 0.1)
	fade_out.tween_property(_shade, ^"modulate:a", 0.0, 0.14)
	fade_out.tween_callback(func() -> void:
		hide()
		_opening = false
		dismissed.emit()
	)
