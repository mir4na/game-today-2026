class_name Interactable
extends Area2D
## Small common contract used by every contextual interaction in the train.

signal interaction_requested(interactable: Interactable)

@export var prompt_text: String = "Interact"
@export var interaction_distance: float = 112.0
@export var enabled: bool = true

func get_prompt() -> String:
	return "[E] %s" % prompt_text

func can_interact() -> bool:
	return enabled and visible

func interact() -> void:
	interaction_requested.emit(self)
