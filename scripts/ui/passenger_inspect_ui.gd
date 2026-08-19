class_name PassengerInspectUI
extends Control

signal closed
signal station_assignment_toggled(passenger_name: String, should_assign: bool)

@export_category("Inspector Copy")
@export var inspection_title: String
@export var newspaper_title: String
@export_multiline var relevant_newspaper_template: String
@export_multiline var unrelated_newspaper_document: String
@export_multiline var biodata_template: String
@export_multiline var ticket_template: String
@export var assignment_status_template: String
@export var assign_button_text: String
@export var remove_assignment_text: String

var _data: PassengerData
@onready var _title: Label = %Title
@onready var _portrait: PassengerPortrait = %Portrait
@onready var _bio_button: Button = %BioButton
@onready var _ticket_button: Button = %TicketButton
@onready var _tab_row: HBoxContainer = %TabRow
@onready var _content: RichTextLabel = %Content
var _document_mode: bool = false
@onready var _assignment_panel: PanelContainer = %AssignmentPanel
@onready var _assignment_status: Label = %AssignmentStatus
@onready var _assignment_button: Button = %AssignmentButton
@onready var _assignment_error: Label = %AssignmentError
var _is_assigned_to_next_station: bool = false

func show_passenger(data: PassengerData) -> void:
	_data = data
	_document_mode = false
	_assignment_panel.hide()
	_assignment_error.text = ""
	_title.text = inspection_title
	_tab_row.visible = true
	_portrait.visible = true
	_portrait.set_passenger(data)
	_show_biodata()
	show()
	_bio_button.grab_focus()

func compose_newspaper_document(subject: PassengerData) -> String:
	if subject == null:
		return unrelated_newspaper_document
	return relevant_newspaper_template % [subject.occupation.to_upper(), subject.passenger_name, subject.age, subject.origin_station, subject.occupation.to_lower()]

func show_newspaper(document: String) -> void:
	_data = null
	_document_mode = true
	_title.text = newspaper_title
	_tab_row.visible = false
	_portrait.visible = false
	_assignment_panel.hide()
	_content.text = document
	show()

func configure_station_assignment(next_station: String, is_assigned: bool, assigned_count: int) -> void:
	if _data == null:
		return
	_is_assigned_to_next_station = is_assigned
	_assignment_status.text = assignment_status_template % [next_station.to_upper(), assigned_count]
	_assignment_button.text = remove_assignment_text if is_assigned else assign_button_text
	_assignment_button.disabled = false
	_assignment_error.text = ""
	_assignment_panel.show()

func show_assignment_error(message: String) -> void:
	_assignment_error.text = message

func request_close() -> void:
	hide()
	closed.emit()

func _show_biodata() -> void:
	if _data == null:
		return
	_bio_button.disabled = true
	_ticket_button.disabled = false
	_content.text = biodata_template % [_data.passenger_name.to_upper(), _data.age, _data.occupation, _data.origin_station, _data.destination_station]

func _show_ticket() -> void:
	if _data == null:
		return
	_bio_button.disabled = false
	_ticket_button.disabled = true
	_content.text = ticket_template % [_data.passenger_name.to_upper(), _data.origin_station, _data.destination_station, _data.ticket_owner]

func _toggle_station_assignment() -> void:
	if _data == null:
		return
	station_assignment_toggled.emit(_data.passenger_name, not _is_assigned_to_next_station)
