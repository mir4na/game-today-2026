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
@export_multiline var passenger_empty_document: String
@export var passenger_header_template: String
@export_multiline var passenger_line_template: String
@export_multiline var evidence_document_template: String
@export_multiline var evidence_empty_document: String
@export_category("Guide Sections")
@export_multiline var procedure_document: String
@export_multiline var anomaly_document: String
@export_multiline var newspaper_document: String
@export_multiline var night_service_document: String
@export_multiline var tools_document: String

var _day_number: int = 1
var _service_train_number: String = ""
var _service_date: String = ""
var _service_day_code: String = ""
var _route_stations: PackedStringArray = PackedStringArray()
var _route_index: int = 0
var _passengers: Array[PassengerData] = []
var _collected_newspaper: String = ""

@onready var _day_badge: Label = %DayBadge
@onready var _train_badge: Label = %TrainBadge
@onready var _date_badge: Label = %DateBadge
@onready var _page_title: Label = %PageTitle
@onready var _content: RichTextLabel = %Content
@onready var _today_button: Button = %TodayButton
@onready var _procedure_button: Button = %ProcedureButton
@onready var _records_button: Button = %RecordsButton
@onready var _evidence_button: Button = %EvidenceButton
@onready var _anomalies_button: Button = %AnomaliesButton
@onready var _newspaper_button: Button = %NewspaperButton
@onready var _night_button: Button = %NightButton
@onready var _tools_button: Button = %ToolsButton


func open_guidebook(
	day_number: int,
	service_train_number: String,
	service_date: String,
	service_day_code: String,
	route_stations: PackedStringArray,
	passengers: Array[PassengerData],
	collected_newspaper: String,
	route_index: int
) -> void:
	_day_number = maxi(1, day_number)
	_service_train_number = service_train_number
	_service_date = service_date
	_service_day_code = service_day_code
	_route_stations = route_stations.duplicate()
	_passengers = passengers.duplicate()
	_collected_newspaper = collected_newspaper
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
	_set_section(_procedure_button, "DAY PROCEDURE", procedure_document)


func _show_records() -> void:
	var document: String = passenger_empty_document
	if not _passengers.is_empty():
		var lines := PackedStringArray([passenger_header_template % _passengers.size()])
		for data: PassengerData in _passengers:
			lines.append(passenger_line_template % [
				data.passenger_name.to_upper(),
				data.age,
				data.origin_station,
				data.destination_station,
				data.ticket_number,
				data.ticket_train_number,
				data.ticket_service_date,
			])
		document = "\n".join(lines)
	_set_section(_records_button, "PASSENGER RECORDS", document)


func _show_evidence() -> void:
	var document: String = evidence_empty_document
	if not _collected_newspaper.is_empty():
		document = evidence_document_template % _collected_newspaper
	_set_section(_evidence_button, "COLLECTED EVIDENCE", document)


func _show_anomalies() -> void:
	_set_section(_anomalies_button, "ANOMALY CATALOGUE", anomaly_document)


func _show_newspaper() -> void:
	_set_section(_newspaper_button, "NEWSPAPER RULES", newspaper_document)


func _show_night_service() -> void:
	_set_section(_night_button, "NIGHT SERVICE", night_service_document)


func _show_tools() -> void:
	_set_section(_tools_button, "TOOLS & CONTROLS", tools_document)


func _set_section(active_button: Button, title: String, document: String) -> void:
	for button: Button in _section_buttons():
		button.disabled = button == active_button
	_page_title.text = title
	_content.text = document
	_content.scroll_to_line(0)


func _section_buttons() -> Array[Button]:
	return [
		_today_button,
		_procedure_button,
		_records_button,
		_evidence_button,
		_anomalies_button,
		_newspaper_button,
		_night_button,
		_tools_button,
	]


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
