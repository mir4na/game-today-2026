class_name DocumentOverlayUI
extends Control
## Modal document viewer. Passenger mode projects only the authored ID and ticket scenes.

signal closed
signal station_assignment_toggled(passenger_name: String, should_assign: bool)

enum ViewMode {
	NONE,
	PASSENGER_DOCUMENTS,
	READER,
	NEWSPAPER,
}

@export_category("Newspaper Cases")
@export_group("Ordinary News", "non_death_")
@export var non_death_headline: String
@export_multiline var non_death_primary_template: String
@export var non_death_secondary_headline: String
@export_multiline var non_death_secondary_template: String
@export_group("Ordinary News — Alternate", "non_death_alt_")
@export var non_death_alt_headline: String
@export_multiline var non_death_alt_primary_template: String
@export var non_death_alt_secondary_headline: String
@export_multiline var non_death_alt_secondary_template: String
@export_group("External Death", "external_death_")
@export var external_death_headline: String
@export_multiline var external_death_primary_template: String
@export var external_death_secondary_headline: String
@export_multiline var external_death_secondary_template: String
@export_group("External Death — Alternate", "external_death_alt_")
@export var external_death_alt_headline: String
@export_multiline var external_death_alt_primary_template: String
@export var external_death_alt_secondary_headline: String
@export_multiline var external_death_alt_secondary_template: String
@export_group("Matching Death", "matching_death_")
@export var matching_death_headline: String
@export_multiline var matching_death_primary_template: String
@export var matching_death_secondary_headline: String
@export_multiline var matching_death_secondary_template: String
@export_group("Matching Death — Alternate", "matching_death_alt_")
@export var matching_death_alt_headline: String
@export_multiline var matching_death_alt_primary_template: String
@export var matching_death_alt_secondary_headline: String
@export_multiline var matching_death_alt_secondary_template: String
@export_group("")
@export_category("Departure Statement")
@export var departure_statement_title: String
@export_multiline var departure_statement_template: String
@export var departure_statement_recorded_text: String
@export var departure_statement_reread_text: String
@export_multiline var missing_departure_statement_text: String

var _data: PassengerData
var _view_mode: ViewMode = ViewMode.NONE
var _closing: bool = false
var _view_revision: int = 0
var _is_assigned_to_next_station: bool = false
var _newspaper_headline: String = ""
var _newspaper_primary_body: String = ""
var _newspaper_secondary_headline: String = ""
var _newspaper_secondary_body: String = ""

# These scene-owned children stay dynamic so a cold import can register their scripts in any order.
@onready var _documents: Variant = %PassengerDocuments
@onready var _passenger_close_button: Button = %PassengerCloseButton
@onready var _reader_panel: PanelContainer = %ReaderPanel
@onready var _reader_title: Label = %ReaderTitle
@onready var _reader_content: RichTextLabel = %ReaderContent
@onready var _newspaper_reader: Variant = %NewspaperReader


func show_passenger(data: PassengerData) -> void:
	_view_revision += 1
	_closing = false
	_data = data
	_view_mode = ViewMode.PASSENGER_DOCUMENTS
	_is_assigned_to_next_station = false
	_reader_panel.hide()
	_newspaper_reader.hide()
	_passenger_close_button.show()
	_documents.show()
	_documents.set_passenger(data)
	_documents.set_stamp_locked(false)
	_documents.reset_to_id_card()
	show()


func get_random_outside_subject(
	rng: RandomNumberGenerator,
	shared_name_pool: PackedStringArray,
	excluded_names: PackedStringArray,
	case_label: String
) -> String:
	return _pick_outside_name(shared_name_pool, rng, excluded_names, case_label)


func compose_non_death_newspaper(
	subject_name: String,
	edition_station: String,
	rng: RandomNumberGenerator = null
) -> String:
	var use_alternate: bool = _roll_alternate_copy(rng, non_death_alt_primary_template)
	var headline: String = non_death_alt_headline if use_alternate else non_death_headline
	var primary_template: String = non_death_alt_primary_template if use_alternate else non_death_primary_template
	var secondary_headline: String = non_death_alt_secondary_headline if use_alternate else non_death_secondary_headline
	var secondary_template: String = non_death_alt_secondary_template if use_alternate else non_death_secondary_template
	_set_newspaper_copy(
		headline,
		primary_template % subject_name.to_upper(),
		secondary_headline,
		secondary_template % edition_station
	)
	return _compose_newspaper_document()


func compose_external_death_newspaper(
	subject_name: String,
	edition_station: String,
	rng: RandomNumberGenerator = null
) -> String:
	var use_alternate: bool = _roll_alternate_copy(rng, external_death_alt_primary_template)
	var headline: String = external_death_alt_headline if use_alternate else external_death_headline
	var primary_template: String = external_death_alt_primary_template if use_alternate else external_death_primary_template
	var secondary_headline: String = external_death_alt_secondary_headline if use_alternate else external_death_secondary_headline
	var secondary_template: String = external_death_alt_secondary_template if use_alternate else external_death_secondary_template
	_set_newspaper_copy(
		headline,
		primary_template % subject_name.to_upper(),
		secondary_headline,
		secondary_template % edition_station
	)
	return _compose_newspaper_document()


func compose_matching_death_newspaper(
	subject: PassengerData,
	edition_station: String,
	rng: RandomNumberGenerator = null
) -> String:
	if subject == null:
		push_error("Matching-death newspaper requires a generated passenger subject.")
		return ""
	var use_alternate: bool = _roll_alternate_copy(rng, matching_death_alt_primary_template)
	var headline: String = matching_death_alt_headline if use_alternate else matching_death_headline
	var primary_template: String = matching_death_alt_primary_template if use_alternate else matching_death_primary_template
	var secondary_headline: String = matching_death_alt_secondary_headline if use_alternate else matching_death_secondary_headline
	var secondary_template: String = matching_death_alt_secondary_template if use_alternate else matching_death_secondary_template
	_set_newspaper_copy(
		headline,
		primary_template % [subject.passenger_name.to_upper(), subject.age],
		secondary_headline,
		secondary_template % [subject.origin_station, subject.occupation.to_lower(), edition_station]
	)
	return _compose_newspaper_document()


func show_newspaper(document: String) -> void:
	_view_revision += 1
	_closing = false
	_data = null
	_view_mode = ViewMode.NEWSPAPER
	_documents.hide()
	_passenger_close_button.hide()
	_reader_panel.hide()
	_newspaper_reader.set_content(
		_newspaper_headline,
		_newspaper_primary_body,
		_newspaper_secondary_headline,
		_newspaper_secondary_body
	)
	_newspaper_reader.show()
	show()
	_newspaper_reader.present()


func choose_random_newspaper_visual(rng: RandomNumberGenerator) -> void:
	_newspaper_reader.choose_random_variant(rng)


func configure_newspaper_portrait(texture: Texture2D) -> void:
	_newspaper_reader.set_portrait(texture)


func _set_newspaper_copy(headline: String, primary_body: String, secondary_headline: String, secondary_body: String) -> void:
	_newspaper_headline = headline
	_newspaper_primary_body = primary_body
	_newspaper_secondary_headline = secondary_headline
	_newspaper_secondary_body = secondary_body


func _roll_alternate_copy(rng: RandomNumberGenerator, alternate_primary_template: String) -> bool:
	if rng == null or alternate_primary_template.strip_edges().is_empty():
		return false
	return rng.randi_range(0, 1) == 1


func _compose_newspaper_document() -> String:
	return "[font_size=25][b]%s[/b][/font_size]\n\n%s\n\n[b]%s[/b]\n%s" % [
		_newspaper_headline,
		_newspaper_primary_body,
		_newspaper_secondary_headline,
		_newspaper_secondary_body,
	]


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


func configure_stamp_lock(is_locked: bool) -> void:
	if _view_mode != ViewMode.PASSENGER_DOCUMENTS:
		return
	_documents.set_stamp_locked(is_locked)


func request_close() -> void:
	if not visible or _closing:
		return
	_closing = true
	var closing_revision: int = _view_revision
	if _view_mode == ViewMode.NEWSPAPER:
		await _newspaper_reader.dismiss()
		if closing_revision != _view_revision:
			return
	hide()
	_view_mode = ViewMode.NONE
	_closing = false
	closed.emit()


func is_showing_passenger_documents() -> bool:
	return visible and _view_mode == ViewMode.PASSENGER_DOCUMENTS and _data != null


func is_showing_newspaper() -> bool:
	return visible and _view_mode == ViewMode.NEWSPAPER


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key_event := event as InputEventKey
	if key_event != null and key_event.echo:
		return
	if event.is_action_pressed(&"interact"):
		request_close()
		get_viewport().set_input_as_handled()
		return
	if _view_mode != ViewMode.PASSENGER_DOCUMENTS or _data == null:
		return
	if event.is_action_pressed(&"switch_document") and _documents.toggle_document():
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"stamp_ticket") and _documents.request_stamp_action():
		get_viewport().set_input_as_handled()


func _toggle_station_assignment() -> void:
	if _data == null or not _documents.is_ticket_active():
		return
	station_assignment_toggled.emit(_data.passenger_name, not _is_assigned_to_next_station)


func _show_reader(title: String, document: String) -> void:
	_view_revision += 1
	_closing = false
	_view_mode = ViewMode.READER
	_documents.hide()
	_passenger_close_button.hide()
	_newspaper_reader.hide()
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
