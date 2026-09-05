class_name CleanSeatUI
extends Control
## Full-screen cleaning task using the project seat and cloth assets.

signal closed
signal completed(event: Node)

@export_category("Inspector Copy")
@export var progress_template: String = "CLEANING  %d%%"

@onready var _surface: CleanSeatSurface = %WipeSurface
@onready var _progress_label: Label = %ProgressLabel
@onready var _success_label: Label = %SuccessLabel

var _active_event: Node
var _completed: bool = false


func open_cleaning(event: Node) -> void:
	if event != _active_event:
		_active_event = event
		_completed = false
		_success_label.hide()
		_progress_label.show()
		_surface.reset_cleaning()
	show()


func request_close() -> void:
	if not visible or _completed:
		return
	_surface.cancel_wipe()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		request_close()
		get_viewport().set_input_as_handled()


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
	_progress_label.hide()
	_success_label.show()
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return
	hide()
	completed.emit(_active_event)
	_active_event = null
