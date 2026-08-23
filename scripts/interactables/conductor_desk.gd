class_name ConductorDeskInteractable
extends Interactable

@export_category("Prompt Copy")
@export var day_prompt: String
@export var night_prompt: String

func set_night_mode(is_night: bool) -> void:
	prompt_text = night_prompt if is_night else day_prompt
