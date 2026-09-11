class_name RunContextState
extends Node
## Small runtime handoff for one-shot launch flags between menu and gameplay.

var _tutorial_requested: bool = false


func request_tutorial() -> void:
	_tutorial_requested = true


func request_standard_game() -> void:
	_tutorial_requested = false


func consume_tutorial_requested() -> bool:
	var requested: bool = _tutorial_requested
	_tutorial_requested = false
	return requested
