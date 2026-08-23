class_name ArrivalClockUI
extends Control
## Read-only station schedule opened from the crew-cab arrival clock.

signal closed

@export_category("Inspector Copy")
@export var route_template: String = "%s  →  %s"
@export var completed_route_template: String = "%s  •  DAY ROUTE COMPLETE"
@export var clock_template: String = "%02d:%02d %s"
@export var countdown_template: String = "%02d:%02d"
@export var travel_status: String = "The next station cutscene begins automatically on arrival."
@export var completed_status: String = "No further daytime stations are scheduled."

@onready var _route_label: Label = %RouteLabel
@onready var _current_time_value: Label = %CurrentTimeValue
@onready var _arrival_time_value: Label = %ArrivalTimeValue
@onready var _countdown_value: Label = %CountdownValue
@onready var _status_label: Label = %StatusLabel
@onready var _close_button: Button = %CloseButton

func open_schedule(current_station: String, next_station: String, current_minutes: int, arrival_minutes: int, remaining_seconds: int, route_active: bool) -> void:
	_current_time_value.text = _format_clock(current_minutes)
	if route_active:
		_route_label.text = route_template % [current_station.to_upper(), next_station.to_upper()]
		_arrival_time_value.text = _format_clock(arrival_minutes)
		_countdown_value.text = countdown_template % [remaining_seconds / 60, remaining_seconds % 60]
		_status_label.text = travel_status
	else:
		_route_label.text = completed_route_template % current_station.to_upper()
		_arrival_time_value.text = "--:--"
		_countdown_value.text = "ARRIVED"
		_status_label.text = completed_status
	show()
	_close_button.grab_focus()

func request_close() -> void:
	if not visible:
		return
	hide()
	closed.emit()

func _format_clock(total_minutes: int) -> String:
	var wrapped_minutes: int = posmod(total_minutes, 24 * 60)
	var hour_24: int = wrapped_minutes / 60
	var minute: int = wrapped_minutes % 60
	var suffix: String = "AM" if hour_24 < 12 else "PM"
	var hour_12: int = hour_24 % 12
	if hour_12 == 0:
		hour_12 = 12
	return clock_template % [hour_12, minute, suffix]
