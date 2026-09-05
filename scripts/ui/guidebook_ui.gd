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

var _day_number: int = 1
var _pass_target: int = 0
var _net_earnings: int = 0
var _passenger_count: int = 0
var _boarded_today: int = 0
var _stamped_aboard: int = 0
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
	route_index: int,
	pass_target: int
) -> void:
	_day_number = maxi(1, day_number)
	_pass_target = maxi(0, pass_target)
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


func update_shift_progress(route_index: int, net_earnings: int, passenger_count: int, boarded_today: int, stamped_aboard: int) -> void:
	var next_route_index: int = clampi(route_index, 0, maxi(0, _route_stations.size() - 1))
	if _route_index == next_route_index and _net_earnings == net_earnings and _passenger_count == passenger_count and _boarded_today == boarded_today and _stamped_aboard == stamped_aboard:
		return
	_route_index = next_route_index
	_net_earnings = net_earnings
	_passenger_count = maxi(0, passenger_count)
	_boarded_today = maxi(0, boarded_today)
	_stamped_aboard = maxi(0, stamped_aboard)
	if visible and _today_button.disabled:
		var scroll_position: float = _content.get_v_scroll_bar().value
		_show_today()
		_content.get_v_scroll_bar().value = scroll_position


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
			_service_date,
			_service_train_number,
			_pass_target,
			_net_earnings,
			maxi(0, _pass_target - _net_earnings),
			_boarded_today,
			_passenger_count,
			_stamped_aboard,
			_route_index,
			maxi(0, _route_stations.size() - 1),
			_service_day_code,
			current_station,
			next_station,
			_format_route(),
		]
	)


func _show_procedure() -> void:
	_set_section(_procedure_button, "RULES", procedure_document)


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
