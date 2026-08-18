class_name NotebookUI
extends Control

signal closed

@export_category("Inspector Copy")
@export var route_stations: PackedStringArray
@export_multiline var passenger_empty_document: String
@export var passenger_header_template: String
@export_multiline var passenger_line_template: String
@export_multiline var route_document_template: String
@export_multiline var evidence_document_template: String
@export_multiline var evidence_empty_document: String

var _passengers: Array[PassengerData] = []
var _newspaper_document: String = ""
var _route_index: int = 0
@onready var _content: RichTextLabel = %Content
@onready var _passenger_button: Button = %PassengerButton
@onready var _route_button: Button = %RouteButton
@onready var _evidence_button: Button = %EvidenceButton

func open_notebook(passengers: Array[PassengerData], newspaper_document: String, route_index: int) -> void:
	_passengers = passengers
	_newspaper_document = newspaper_document
	_route_index = route_index
	show()
	_show_passengers()
	_passenger_button.grab_focus()

func request_close() -> void:
	hide()
	closed.emit()

func _show_passengers() -> void:
	_set_active_tab(_passenger_button)
	if _passengers.is_empty():
		_content.text = passenger_empty_document
		return
	var lines: PackedStringArray = PackedStringArray([passenger_header_template % _passengers.size()])
	for data: PassengerData in _passengers:
		lines.append(passenger_line_template % [data.passenger_name.to_upper(), data.age, data.origin_station, data.destination_station])
	_content.text = "\n".join(lines)

func _show_route() -> void:
	_set_active_tab(_route_button)
	var parts: PackedStringArray = PackedStringArray()
	for i: int in range(route_stations.size()):
		if i < _route_index:
			parts.append("[color=#746f69]%s[/color]" % route_stations[i])
		elif i == _route_index:
			parts.append("[color=#e4bc72][b][ %s ][/b][/color]" % route_stations[i])
		else:
			parts.append("[color=#e7ded0]%s[/color]" % route_stations[i])
	_content.text = route_document_template % "  →  ".join(parts)

func _show_evidence() -> void:
	_set_active_tab(_evidence_button)
	if not _newspaper_document.is_empty():
		_content.text = evidence_document_template % _newspaper_document
	else:
		_content.text = evidence_empty_document

func _set_active_tab(active: Button) -> void:
	_passenger_button.disabled = active == _passenger_button
	_route_button.disabled = active == _route_button
	_evidence_button.disabled = active == _evidence_button
