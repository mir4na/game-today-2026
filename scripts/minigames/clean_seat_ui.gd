class_name CleanSeatUI
extends Control
## Full-screen cleaning task using the project seat and cloth assets.

signal closed
signal completed(event: Node)

@export_category("Inspector Copy")
@export var progress_template: String = "CLEANING  %d%%"

@onready var _surface: CleanSeatSurface = %WipeSurface
@onready var _progress_label: Label = %ProgressLabel
@onready var _shade: ColorRect = $Shade
@onready var _cleaning_window: Control = %CleaningWindow

var _active_event: Node
var _completed: bool = false
var _open_tween: Tween
var _window_rest_modulate: Color


func _ready() -> void:
	_window_rest_modulate = _cleaning_window.modulate
	_cleaning_window.pivot_offset = _cleaning_window.size * 0.5


func open_cleaning(event: Node) -> void:
	if event != _active_event:
		_active_event = event
		_completed = false
		_progress_label.show()
		_surface.reset_cleaning()
	show()
	_play_open_animation()


func request_close() -> void:
	if not visible or _completed:
		return
	_surface.cancel_wipe()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"interact"):
		request_close()
		get_viewport().set_input_as_handled()


func _on_close_button_pressed() -> void:
	request_close()


func _on_cleaning_progress(value: float) -> void:
	if is_instance_valid(_progress_label):
		var percentage: int = floori(clampf(value, 0.0, 1.0) * 100.0)
		if not _completed:
			percentage = mini(percentage, 99)
		_progress_label.text = progress_template % percentage


func _on_surface_cleaned() -> void:
	if _completed:
		return
	_completed = true
	_progress_label.text = progress_template % 100
	await get_tree().create_timer(0.18, false).timeout
	if not is_inside_tree():
		return
	hide()
	completed.emit(_active_event)
	_active_event = null


func _play_open_animation() -> void:
	if is_instance_valid(_open_tween) and _open_tween.is_valid():
		_open_tween.kill()
	_cleaning_window.scale = Vector2.ONE * 0.88
	_cleaning_window.modulate = Color(
		_window_rest_modulate.r,
		_window_rest_modulate.g,
		_window_rest_modulate.b,
		0.0
	)
	_shade.modulate.a = 0.0
	_open_tween = create_tween().set_parallel(true)
	_open_tween.tween_property(_shade, ^"modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(_cleaning_window, ^"scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(_cleaning_window, ^"modulate", _window_rest_modulate, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
