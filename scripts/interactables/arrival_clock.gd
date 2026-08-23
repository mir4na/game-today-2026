class_name ArrivalClockInteractable
extends Interactable
## Scene-authored route clock mounted in the driver and conductor cab.

signal clock_read

@export_category("Inspector Copy")
@export var clock_template: String = "%02d:%02d %s"

@onready var _display_text: Label = %DisplayText

func interact() -> void:
	clock_read.emit()

func set_clock(total_minutes: int) -> void:
	var wrapped_minutes: int = posmod(total_minutes, 24 * 60)
	var hour_24: int = wrapped_minutes / 60
	var minute: int = wrapped_minutes % 60
	var suffix: String = "AM" if hour_24 < 12 else "PM"
	var hour_12: int = hour_24 % 12
	if hour_12 == 0:
		hour_12 = 12
	_display_text.text = clock_template % [hour_12, minute, suffix]
