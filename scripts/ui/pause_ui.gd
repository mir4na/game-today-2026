class_name PauseUI
extends Control

signal resume_requested
signal restart_requested
signal main_menu_requested

func open_pause() -> void:
	show()
	%ResumeButton.grab_focus()

func _on_resume_button_pressed() -> void:
	resume_requested.emit()

func _on_restart_button_pressed() -> void:
	restart_requested.emit()

func _on_main_menu_button_pressed() -> void:
	main_menu_requested.emit()
