class_name PauseUI
extends Control

signal resume_requested
signal restart_requested
signal main_menu_requested

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()

func open_pause() -> void:
	show()
	%ResumeButton.grab_focus()

func _on_resume_button_pressed() -> void:
	resume_requested.emit()

func _on_restart_button_pressed() -> void:
	restart_requested.emit()

func _on_main_menu_button_pressed() -> void:
	main_menu_requested.emit()
