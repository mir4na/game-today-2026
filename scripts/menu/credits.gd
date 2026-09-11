class_name GameCredits
extends Control
## Buttonless epilogue styled after the main menu. Credits travel from the top
## of the train window to the bottom, then the game returns to the menu.

const MAIN_MENU_SCENE_PATH := "res://scenes/menu/main_menu.tscn"

@export_range(3.0, 30.0, 0.25) var scroll_seconds: float = 11.0
@export_range(0.1, 3.0, 0.05) var fade_seconds: float = 0.8
@export_range(0.0, 4.0, 0.05) var finish_hold_seconds: float = 1.1

@onready var _credits_block: VBoxContainer = %CreditsBlock
@onready var _fade: ColorRect = %Fade

var _finishing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade.color.a = 1.0
	_credits_block.position.y = -_credits_block.size.y - 60.0
	var tween := create_tween().set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade, ^"color:a", 0.0, fade_seconds)
	tween.tween_property(_credits_block, ^"position:y", size.y + 80.0, scroll_seconds).set_trans(Tween.TRANS_LINEAR)
	await get_tree().create_timer(scroll_seconds + finish_hold_seconds, true, false, true).timeout
	_finish()


func _unhandled_input(event: InputEvent) -> void:
	if _finishing:
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel") or (
		event is InputEventMouseButton and event.pressed
	):
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if _finishing:
		return
	_finishing = true
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade, ^"color:a", 1.0, fade_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
