class_name GuidebookUI
extends Control
## Scene-authored conductor guidebook. Scripts only populate daily runtime data.

signal closed

@export_category("Dynamic Copy")
@export var day_badge_template: String
@export var train_badge_template: String
@export var date_badge_template: String
@export_multiline var today_document_template: String
@export var completed_service_text: String
@export_category("Guide Sections")
@export_multiline var procedure_document: String
@export_multiline var newspaper_document: String
@export_multiline var night_service_document: String
@export_multiline var tools_document: String

var _day_number: int = 1
var _service_train_number: String = ""
var _service_date: String = ""
var _service_day_code: String = ""
var _route_stations: PackedStringArray = PackedStringArray()
var _route_index: int = 0

@onready var _day_badge: Label = %DayBadge
@onready var _train_badge: Label = %TrainBadge
@onready var _date_badge: Label = %DateBadge
@onready var _page_title: Label = %PageTitle
@onready var _content: RichTextLabel = %Content
@onready var _today_button: Button = %TodayButton
@onready var _procedure_button: Button = %ProcedureButton
@onready var _anomaly_list: ScrollContainer = %AnomalyList
@onready var _anomalies_button: Button = %AnomaliesButton


func open_guidebook(
	day_number: int,
	service_train_number: String,
	service_date: String,
	service_day_code: String,
	route_stations: PackedStringArray,
	_collected_newspaper: String,
	route_index: int
) -> void:
	_day_number = maxi(1, day_number)
	_service_train_number = service_train_number
	_service_date = service_date
	_service_day_code = service_day_code
	_route_stations = route_stations.duplicate()
	_route_index = clampi(route_index, 0, maxi(0, _route_stations.size() - 1))
	_day_badge.text = day_badge_template % _day_number
	_train_badge.text = train_badge_template % _service_train_number
	_date_badge.text = date_badge_template % _service_date
	show()
	_show_today()
	_today_button.grab_focus()


func request_close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _show_today() -> void:
	var current_station: String = _station_at(_route_index)
	var next_station: String = completed_service_text
	if _route_index + 1 < _route_stations.size():
		next_station = _route_stations[_route_index + 1]
	_set_section(
		_today_button,
		"TODAY'S SERVICE",
		today_document_template % [
			_day_number,
			_service_train_number,
			_service_date,
			_service_day_code,
			current_station,
			next_station,
			_format_route(),
		]
	)


func _show_procedure() -> void:
	_set_section(_procedure_button, "RULES", "\n\n".join([procedure_document, newspaper_document, night_service_document, tools_document]))


func _show_anomalies() -> void:
	_set_section(_anomalies_button, "ANOMALY LIST", "")
	_content.hide()
	_anomaly_list.show()
	_anomaly_list.scroll_vertical = 0


func _set_section(active_button: Button, title: String, document: String) -> void:
	for button: Button in _section_buttons():
		button.disabled = button == active_button
	_content.show()
	_anomaly_list.hide()
	_page_title.text = title
	_content.text = document
	_content.scroll_to_line(0)


func _section_buttons() -> Array[Button]:
	return [_today_button, _procedure_button, _anomalies_button]


func _station_at(index: int) -> String:
	if _route_stations.is_empty():
		return "UNAVAILABLE"
	return _route_stations[clampi(index, 0, _route_stations.size() - 1)]


func _format_route() -> String:
	var parts := PackedStringArray()
	for index: int in range(_route_stations.size()):
		var station: String = _route_stations[index]
		if index < _route_index:
			parts.append("[color=#8d8371]%s[/color]" % station)
		elif index == _route_index:
			parts.append("[color=#7d382d][b][ %s ][/b][/color]" % station)
		else:
			parts.append("[color=#332b23]%s[/color]" % station)
	return "  →  ".join(parts)
