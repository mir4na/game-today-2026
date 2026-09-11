class_name PauseVolumeSlider
extends Control
## Compact ticket-styled slider used by the pause menu audio controls.

signal value_changed(value: int)

@export_range(0, 100, 1) var value: int = 80
@export_range(1, 25, 1) var step: int = 10
@export var ink_color: Color = Color("353540")

var _dragging: bool = false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()


func set_value_no_signal(new_value: int) -> void:
	value = clampi(new_value, 0, 100)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			grab_focus()
			_set_value_from_x(event.position.x)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_value_from_x(event.position.x)
		accept_event()
	elif event.is_action_pressed(&"ui_left"):
		_set_value(value - step)
		accept_event()
	elif event.is_action_pressed(&"ui_right"):
		_set_value(value + step)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT or what == NOTIFICATION_RESIZED:
		queue_redraw()


func _set_value_from_x(mouse_x: float) -> void:
	var usable_width: float = maxf(size.x - 10.0, 1.0)
	var ratio: float = clampf((mouse_x - 5.0) / usable_width, 0.0, 1.0)
	_set_value(int(round(ratio * 100.0 / float(step))) * step)


func _set_value(new_value: int) -> void:
	var clamped_value: int = clampi(new_value, 0, 100)
	if clamped_value == value:
		return
	value = clamped_value
	queue_redraw()
	value_changed.emit(value)


func _draw() -> void:
	var center_y: float = size.y * 0.5
	var start_x: float = 5.0
	var end_x: float = maxf(size.x - 5.0, start_x)
	var handle_x: float = lerpf(start_x, end_x, float(value) / 100.0)
	draw_line(Vector2(start_x, center_y), Vector2(end_x, center_y), Color(ink_color, 0.32), 4.0, true)
	draw_line(Vector2(start_x, center_y), Vector2(handle_x, center_y), ink_color, 4.0, true)
	draw_rect(Rect2(handle_x - 2.0, center_y - 10.0, 4.0, 20.0), ink_color, true)
	if has_focus():
		draw_circle(Vector2(handle_x, center_y), 6.0, Color(ink_color, 0.16), false, 2.0, true)
