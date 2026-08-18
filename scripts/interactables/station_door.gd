class_name StationDoorInteractable
extends Interactable

signal door_activated

@export_category("Prompt Copy")
@export var station_prompt_format: String

func set_station(station_name: String) -> void:
	prompt_text = station_prompt_format % station_name

func interact() -> void:
	door_activated.emit()
	enabled = false
