class_name DocumentOverlayUI
extends Control
## Modal document viewer. Passenger mode projects only the authored ID and ticket scenes.

signal closed
signal station_assignment_toggled(passenger_name: String, should_assign: bool)
signal station_stamp_applied(passenger_name: String, station_name: String, ticket_position: Vector2)

enum ViewMode {
	NONE,
	PASSENGER_DOCUMENTS,
	READER,
	NEWSPAPER,
}

@export_category("Newspaper Cases")
@export_group("Type 1 — Non-Death", "non_death_")
@export var non_death_headline: String
@export_multiline var non_death_primary_template: String
@export var non_death_secondary_headline: String
@export_multiline var non_death_secondary_template: String
@export_group("Type 2 — Non-Death", "non_death_alt_")
@export var non_death_alt_headline: String
@export_multiline var non_death_alt_primary_template: String
@export var non_death_alt_secondary_headline: String
@export_multiline var non_death_alt_secondary_template: String
@export_group("Type 1 — Death", "matching_death_")
@export var matching_death_headline: String
@export_multiline var matching_death_primary_template: String
@export var matching_death_secondary_headline: String
@export_multiline var matching_death_secondary_template: String
@export_group("Type 2 — Death", "matching_death_alt_")
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
@export_category("Document Presentation")
@export_range(0.2, 1.5, 0.01) var pop_in_duration: float = 0.86
@export_range(100.0, 1000.0, 10.0) var pop_in_vertical_distance: float = 760.0
@export_range(0.0, 5.0, 0.05) var pop_in_tilt_degrees: float = 1.03
@export_range(0.7, 1.0, 0.01) var pop_in_start_scale: float = 0.94
@export_range(0.0, 40.0, 1.0) var pop_in_overshoot_pixels: float = 16.0
@export_range(1.0, 1.1, 0.005) var pop_in_overshoot_scale: float = 1.018

var _data: PassengerData
var _view_mode: ViewMode = ViewMode.NONE
var _closing: bool = false
var _view_revision: int = 0
var _is_assigned_to_next_station: bool = false
var _newspaper_headline: String = ""
var _newspaper_primary_body: String = ""
var _newspaper_secondary_headline: String = ""
var _newspaper_secondary_body: String = ""
var _content_presentation_tween: Tween
var _presented_control: Control
var _presentation_rest_position: Vector2
var _presentation_rest_rotation: float
var _presentation_rest_scale: Vector2
var _presentation_rest_modulate: Color

# These scene-owned children stay dynamic so a cold import can register their scripts in any order.
@onready var _documents: Variant = %PassengerDocuments
@onready var _passenger_close_button: Button = %PassengerCloseButton
@onready var _reader_panel: PanelContainer = %ReaderPanel
@onready var _reader_title: Label = %ReaderTitle
@onready var _reader_content: RichTextLabel = %ReaderContent
@onready var _newspaper_reader: Variant = %NewspaperReader
@onready var _stamp_tray: StampTrayUI = %StampTrayUI


func show_passenger(data: PassengerData) -> void:
	GameSFX.play(&"paper_rustle", -7.0, 0.98, 0.025, 0.1)
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
	_stamp_tray.configure(
		_documents.get_ticket_surface(),
		not data.stamped_station.is_empty(),
		false
	)
	_stamp_tray.set_ticket_visible(false)
	show()
	_present_document_control(_documents as Control)


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
	_rng: RandomNumberGenerator = null
) -> String:
	var use_alternate: bool = _newspaper_reader.get_selected_variant() == 1
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
	_newspaper_reader.set_case_is_death(false)
	return _compose_newspaper_document()


func compose_matching_death_newspaper(
	subject: PassengerData,
	edition_station: String,
	_rng: RandomNumberGenerator = null
) -> String:
	if subject == null:
		push_error("Matching-death newspaper requires a generated passenger subject.")
		return ""
	var use_alternate: bool = _newspaper_reader.get_selected_variant() == 1
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
	_newspaper_reader.set_case_is_death(true)
	return _compose_newspaper_document()


func show_newspaper(document: String) -> void:
	GameSFX.play(&"paper_rustle", -6.0, 0.94, 0.02, 0.1)
	_view_revision += 1
	_closing = false
	_restore_presented_control()
	_data = null
	_view_mode = ViewMode.NEWSPAPER
	_documents.hide()
	_stamp_tray.set_ticket_visible(false)
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
	if is_assigned:
		_stamp_tray.mark_committed()


func configure_stamp_lock(is_locked: bool) -> void:
	if _view_mode != ViewMode.PASSENGER_DOCUMENTS:
		return
	_documents.set_stamp_locked(is_locked)
	_stamp_tray.set_stamp_locked(is_locked)


func request_close() -> void:
	if not visible or _closing:
		return
	_closing = true
	_stamp_tray.cancel_drag()
	_stamp_tray.set_ticket_visible(false)
	GameSFX.play(&"paper_rustle", -10.0, 0.88, 0.02, 0.1)
	var closing_revision: int = _view_revision
	if _view_mode == ViewMode.NEWSPAPER:
		await _newspaper_reader.dismiss()
		if closing_revision != _view_revision:
			return
	elif _view_mode == ViewMode.PASSENGER_DOCUMENTS:
		await _dismiss_document_control(_documents as Control)
		if closing_revision != _view_revision:
			return
	elif _view_mode == ViewMode.READER:
		await _dismiss_document_control(_reader_panel)
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


func _on_ticket_visibility_changed(is_ticket_visible: bool) -> void:
	# PassengerDocuments enters its reset state before this parent's @onready
	# references are assigned during scene construction.
	if not is_instance_valid(_stamp_tray):
		return
	if _view_mode != ViewMode.PASSENGER_DOCUMENTS or _data == null:
		_stamp_tray.set_ticket_visible(false)
		return
	_stamp_tray.set_ticket_visible(is_ticket_visible)


func _on_stamp_dropped(station_name: String, ticket_position: Vector2) -> void:
	if (
		_data == null
		or not _documents.is_ticket_active()
		or not _data.stamped_station.is_empty()
	):
		return
	station_stamp_applied.emit(_data.passenger_name, station_name, ticket_position)
	# The main game handles authoritative validation synchronously. Only reveal
	# ink after it has accepted and persisted this exact station choice.
	if _data.stamped_station == station_name:
		_documents.set_station_stamp(station_name, ticket_position, true)


func _toggle_station_assignment() -> void:
	if _data == null or not _documents.is_ticket_active():
		return
	station_assignment_toggled.emit(_data.passenger_name, not _is_assigned_to_next_station)


func _show_reader(title: String, document: String) -> void:
	GameSFX.play(&"paper_rustle", -8.0, 1.02, 0.02, 0.1)
	_view_revision += 1
	_closing = false
	_view_mode = ViewMode.READER
	_documents.hide()
	_stamp_tray.set_ticket_visible(false)
	_passenger_close_button.hide()
	_newspaper_reader.hide()
	_reader_title.text = title
	_reader_content.text = document
	_reader_panel.show()
	show()
	_present_document_control(_reader_panel)


func _present_document_control(target: Control) -> void:
	if not is_instance_valid(target):
		return
	_restore_presented_control()
	# CenterContainer owns a fixed-size anchor; this animated target is nested
	# inside that anchor so the container never overwrites the tweened position.
	# Wait one frame for its authored size and pivot to finish resolving.
	var presentation_revision: int = _view_revision
	var authored_modulate: Color = target.self_modulate
	target.self_modulate.a = 0.0
	await get_tree().process_frame
	if (
		presentation_revision != _view_revision
		or _closing
		or not is_instance_valid(target)
		or not target.is_visible_in_tree()
	):
		if is_instance_valid(target):
			target.self_modulate = authored_modulate
		return
	_presented_control = target
	_presentation_rest_position = target.position
	_presentation_rest_rotation = target.rotation
	_presentation_rest_scale = target.scale
	_presentation_rest_modulate = authored_modulate
	if target.pivot_offset.is_zero_approx():
		target.pivot_offset = target.size * 0.5
	target.position = _presentation_rest_position + Vector2(0.0, pop_in_vertical_distance)
	target.rotation = _presentation_rest_rotation + deg_to_rad(pop_in_tilt_degrees)
	target.scale = _presentation_rest_scale * pop_in_start_scale
	var entry_modulate := _presentation_rest_modulate
	entry_modulate.a *= 0.72
	target.self_modulate = entry_modulate
	var lift_duration: float = pop_in_duration * (0.68 / 0.86)
	var settle_duration: float = maxf(pop_in_duration - lift_duration, 0.01)
	_content_presentation_tween = create_tween()
	_content_presentation_tween.tween_property(
		target,
		^"position",
		_presentation_rest_position - Vector2(0.0, pop_in_overshoot_pixels),
		lift_duration
	).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_content_presentation_tween.parallel().tween_property(
		target,
		^"rotation",
		_presentation_rest_rotation - deg_to_rad(pop_in_tilt_degrees * 0.22),
		lift_duration
	).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_content_presentation_tween.parallel().tween_property(
		target,
		^"scale",
		_presentation_rest_scale * pop_in_overshoot_scale,
		lift_duration
	).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_content_presentation_tween.parallel().tween_property(
		target,
		^"self_modulate",
		_presentation_rest_modulate,
		pop_in_duration * (0.26 / 0.86)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_content_presentation_tween.tween_property(
		target,
		^"position",
		_presentation_rest_position,
		settle_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_content_presentation_tween.parallel().tween_property(
		target,
		^"rotation",
		_presentation_rest_rotation,
		settle_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_content_presentation_tween.parallel().tween_property(
		target,
		^"scale",
		_presentation_rest_scale,
		settle_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _dismiss_document_control(target: Control) -> void:
	if not is_instance_valid(target) or target != _presented_control:
		return
	_kill_content_presentation_tween()
	var exit_duration: float = pop_in_duration * 0.62
	var exit_modulate := _presentation_rest_modulate
	exit_modulate.a *= 0.72
	_content_presentation_tween = create_tween()
	_content_presentation_tween.tween_property(
		target,
		^"position",
		_presentation_rest_position + Vector2(0.0, pop_in_vertical_distance),
		exit_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_content_presentation_tween.parallel().tween_property(
		target,
		^"rotation",
		_presentation_rest_rotation + deg_to_rad(pop_in_tilt_degrees),
		exit_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_content_presentation_tween.parallel().tween_property(
		target,
		^"scale",
		_presentation_rest_scale * pop_in_start_scale,
		exit_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_content_presentation_tween.parallel().tween_property(
		target,
		^"self_modulate",
		exit_modulate,
		exit_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _content_presentation_tween.finished
	if target == _presented_control:
		_restore_presented_control()


func _restore_presented_control() -> void:
	_kill_content_presentation_tween()
	if is_instance_valid(_presented_control):
		_presented_control.position = _presentation_rest_position
		_presented_control.rotation = _presentation_rest_rotation
		_presented_control.scale = _presentation_rest_scale
		_presented_control.self_modulate = _presentation_rest_modulate
	_presented_control = null


func _kill_content_presentation_tween() -> void:
	if is_instance_valid(_content_presentation_tween) and _content_presentation_tween.is_valid():
		_content_presentation_tween.kill()
	_content_presentation_tween = null


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
