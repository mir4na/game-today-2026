class_name DocumentOverlayUI
extends Control
## Modal document viewer. Passenger mode projects only the authored ID and ticket scenes.

signal closed
signal station_assignment_toggled(passenger_name: String, should_assign: bool)

enum ViewMode {
	NONE,
	PASSENGER_DOCUMENTS,
	READER,
}

@export_category("Newspaper Cases")
@export var newspaper_title: String
@export var non_death_subject_names: PackedStringArray
@export_multiline var non_death_newspaper_template: String
@export var external_death_subject_names: PackedStringArray
@export_multiline var external_death_newspaper_template: String
@export_multiline var matching_death_newspaper_template: String
@export_category("Departure Statement")
@export var departure_statement_title: String
@export_multiline var departure_statement_template: String
@export var departure_statement_recorded_text: String
@export var departure_statement_reread_text: String
@export_multiline var missing_departure_statement_text: String

var _data: PassengerData
var _view_mode: ViewMode = ViewMode.NONE
var _is_assigned_to_next_station: bool = false

# These scene-owned children stay dynamic so a cold import can register their scripts in any order.
@onready var _documents: Variant = %PassengerDocuments
@onready var _reader_panel: PanelContainer = %ReaderPanel
@onready var _reader_title: Label = %ReaderTitle
@onready var _reader_content: RichTextLabel = %ReaderContent


func show_passenger(data: PassengerData) -> void:
	_data = data
	_view_mode = ViewMode.PASSENGER_DOCUMENTS
	_is_assigned_to_next_station = false
	_reader_panel.hide()
	_documents.show()
	_documents.set_passenger(data)
	_documents.reset_to_id_card()
	show()


func get_random_non_death_subject(rng: RandomNumberGenerator, excluded_names: PackedStringArray) -> String:
	return _pick_outside_name(non_death_subject_names, rng, excluded_names, "non-death newspaper")


func get_random_external_death_subject(rng: RandomNumberGenerator, excluded_names: PackedStringArray) -> String:
	return _pick_outside_name(external_death_subject_names, rng, excluded_names, "external-death newspaper")


func compose_non_death_newspaper(subject_name: String, edition_station: String) -> String:
	return non_death_newspaper_template % [subject_name, edition_station]


func compose_external_death_newspaper(subject_name: String, edition_station: String) -> String:
	return external_death_newspaper_template % [subject_name, edition_station]


func compose_matching_death_newspaper(subject: PassengerData, edition_station: String) -> String:
	if subject == null:
		push_error("Matching-death newspaper requires a generated passenger subject.")
		return ""
	return matching_death_newspaper_template % [
		subject.occupation.to_upper(),
		subject.passenger_name,
		subject.age,
		subject.origin_station,
		subject.occupation.to_lower(),
		edition_station,
	]


func show_newspaper(document: String) -> void:
	_data = null
	_show_reader(newspaper_title, document)


func show_departure_statement(data: PassengerData, statement: String, newly_recorded: bool) -> void:
	_data = null
	var document: String = missing_departure_statement_text
	if not statement.is_empty():
		var record_status: String = departure_statement_recorded_text if newly_recorded else departure_statement_reread_text
		document = departure_statement_template % [data.short_name.to_upper(), statement, record_status]
	_show_reader(departure_statement_title, document)


func configure_station_assignment(is_assigned: bool, animate_stamp: bool = false) -> void:
	if _data == null or _view_mode != ViewMode.PASSENGER_DOCUMENTS:
		return
	_is_assigned_to_next_station = is_assigned
	_documents.set_disembark_stamped(is_assigned, animate_stamp)


func request_close() -> void:
	hide()
	_view_mode = ViewMode.NONE
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _view_mode != ViewMode.PASSENGER_DOCUMENTS or _data == null:
		return
	if event.is_action_pressed(&"interact") and _documents.request_primary_action():
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_left") and _documents.show_id_card():
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_right") and _documents.show_ticket():
		get_viewport().set_input_as_handled()


func _toggle_station_assignment() -> void:
	if _data == null or not _documents.is_ticket_active():
		return
	station_assignment_toggled.emit(_data.passenger_name, not _is_assigned_to_next_station)


func _show_reader(title: String, document: String) -> void:
	_view_mode = ViewMode.READER
	_documents.hide()
	_reader_title.text = title
	_reader_content.text = document
	_reader_panel.show()
	show()


func _pick_outside_name(
	configured_names: PackedStringArray,
	rng: RandomNumberGenerator,
	excluded_names: PackedStringArray,
	case_label: String
) -> String:
	var candidates := PackedStringArray()
	for configured_name: String in configured_names:
		var normalized_name: String = configured_name.strip_edges().to_lower()
		if not normalized_name.is_empty() and not excluded_names.has(normalized_name):
			candidates.append(configured_name.strip_edges())
	if candidates.is_empty():
		push_error("Document Overlay UI needs at least one outside name for the %s case." % case_label)
		return "Unknown"
	return candidates[rng.randi_range(0, candidates.size() - 1)]
