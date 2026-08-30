class_name ConductorDeskInteractable
extends Interactable

@export_category("Prompt Copy")
@export var night_prompt: String

func set_night_mode(is_night: bool) -> void:
	enabled = is_night
	visible = is_night
	if is_night:
		prompt_text = night_prompt
