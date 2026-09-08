class_name NightPuzzleUI
extends Control
## Scene-authored Night Assignment board. Passenger cards support native Godot
## drag-and-drop while clicks remain available as an accessible fallback.

signal closed
signal departures_confirmed(assignments: Dictionary)

@export_category("Inspector Copy")
@export var instruction_text: String = "Each station is one node. A thread means the two stations are directly connected."
@export_multiline var no_selection_text: String = "Drag a soul card, or select a card and a station.\nFinalizing seals the result."
@export var selection_template: String = "%s selected — choose a station."
@export var incomplete_assignment_error: String = "Assign every soul before finalizing."
@export var assignment_count_template: String = "%d / %d SOULS ASSIGNED"
@export var clue_count_template: String = "%d / %d STATEMENTS RECORDED"

var _puzzle: DeparturePuzzleData
var _selected_passenger: String = ""
var _assignments: Dictionary = {}
var _passenger_data_by_name: Dictionary = {}
var _collected_statements: Dictionary = {}

@onready var _instruction_label: Label = %InstructionLabel
@onready var _selection_label: Label = %SelectionLabel
@onready var _assignment_count_label: Label = %AssignmentCountLabel
@onready var _clue_count_label: Label = %ClueCountLabel
@onready var _error_label: Label = %ErrorLabel
@onready var _confirm_button: Button = %ConfirmButton
@onready var _board_anchor: Control = %BoardAnchor
@onready var _passenger_cards: Array[NightPassengerCard] = [
	%PassengerCard1,
	%PassengerCard2,
	%PassengerCard3,
	%PassengerCard4,
]
@onready var _station_targets: Array[NightStationTarget] = [
	%VesperwickTarget,
	%HollowcrossTarget,
	%BellhavenTarget,
	%MorrowfieldTarget,
]


func _ready() -> void:
	_instruction_label.text = instruction_text
	for card: NightPassengerCard in _passenger_cards:
		card.selected.connect(_on_passenger_selected)
	for target: NightStationTarget in _station_targets:
		target.passenger_dropped.connect(_assign_passenger_to_station)
		target.selected.connect(_on_station_selected)
	hide()


func open_puzzle(
	passengers: Array[PassengerData],
	puzzle: DeparturePuzzleData,
	collected_statements: Dictionary
) -> void:
	var is_new_case: bool = _puzzle != puzzle
	_puzzle = puzzle
	if is_new_case:
		_assignments.clear()
	_selected_passenger = ""
	_passenger_data_by_name.clear()
	_collected_statements = collected_statements.duplicate(true)
	_error_label.text = ""
	_selection_label.text = no_selection_text

	for card: NightPassengerCard in _passenger_cards:
		card.hide()
	for target: NightStationTarget in _station_targets:
		target.hide()

	if puzzle == null:
		show_error("The night constellation is unavailable.")
		show()
		return
	if passengers.size() > _passenger_cards.size() or puzzle.night_stations.size() > _station_targets.size():
		show_error("This ledger supports four souls and four stations.")
		show()
		return

	for index: int in range(passengers.size()):
		var data: PassengerData = passengers[index]
		_passenger_data_by_name[data.short_name] = data
		var card: NightPassengerCard = _passenger_cards[index]
		card.configure(
			data,
			str(_collected_statements.get(data.short_name, "")),
			puzzle.get_anomaly_label(data.anomaly_type)
		)
		card.show()

	for index: int in range(puzzle.night_stations.size()):
		var target: NightStationTarget = _station_targets[index]
		if target.station_name != puzzle.night_stations[index]:
			push_error("Night constellation scene order does not match the puzzle resource.")
		target.show()

	_remove_invalid_assignments()
	_update_assignment_visuals()
	show()
	_present_board()


func refresh_collected_statements(collected_statements: Dictionary) -> void:
	_collected_statements = collected_statements.duplicate(true)
	if not visible or _puzzle == null:
		return
	for card: NightPassengerCard in _passenger_cards:
		if not card.visible or not _passenger_data_by_name.has(card.passenger_name):
			continue
		var data := _passenger_data_by_name[card.passenger_name] as PassengerData
		card.configure(
			data,
			str(_collected_statements.get(card.passenger_name, "")),
			_puzzle.get_anomaly_label(data.anomaly_type)
		)
		card.set_assignment(_station_for_passenger(card.passenger_name))
	_update_counts()


func request_close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func show_error(message: String) -> void:
	_error_label.text = message


func _on_passenger_selected(passenger_name: String) -> void:
	_selected_passenger = passenger_name
	_selection_label.text = selection_template % passenger_name
	_error_label.text = ""


func _on_station_selected(station_name: String) -> void:
	if _selected_passenger.is_empty():
		_selection_label.text = no_selection_text
		return
	_assign_passenger_to_station(station_name, _selected_passenger)


func _assign_passenger_to_station(station_name: String, passenger_name: String) -> void:
	if _puzzle == null or not _puzzle.night_stations.has(station_name):
		return
	if not _passenger_data_by_name.has(passenger_name):
		return
	for old_station: String in _assignments.keys():
		if _assignments[old_station] == passenger_name:
			_assignments.erase(old_station)
	_assignments[station_name] = passenger_name
	_selected_passenger = passenger_name
	_selection_label.text = "%s assigned to %s." % [passenger_name, station_name]
	_error_label.text = ""
	_update_assignment_visuals()


func _update_assignment_visuals() -> void:
	for target: NightStationTarget in _station_targets:
		if not target.visible:
			continue
		var passenger_name: String = str(_assignments.get(target.station_name, ""))
		var portrait: Texture2D
		if _passenger_data_by_name.has(passenger_name):
			portrait = (_passenger_data_by_name[passenger_name] as PassengerData).id_photo
		target.set_assignment(passenger_name, portrait)
	for card: NightPassengerCard in _passenger_cards:
		if card.visible:
			card.set_assignment(_station_for_passenger(card.passenger_name))
	_update_counts()


func _update_counts() -> void:
	var total: int = _passenger_data_by_name.size()
	_assignment_count_label.text = assignment_count_template % [_assignments.size(), total]
	var clue_count: int = 0
	for passenger_name: String in _passenger_data_by_name:
		if not str(_collected_statements.get(passenger_name, "")).is_empty():
			clue_count += 1
	_clue_count_label.text = clue_count_template % [clue_count, total]
	_confirm_button.disabled = total == 0 or _assignments.size() != total


func _station_for_passenger(passenger_name: String) -> String:
	for station_name: String in _assignments:
		if _assignments[station_name] == passenger_name:
			return station_name
	return ""


func _remove_invalid_assignments() -> void:
	for station_name: String in _assignments.keys():
		if (
			not _puzzle.night_stations.has(station_name)
			or not _passenger_data_by_name.has(str(_assignments[station_name]))
		):
			_assignments.erase(station_name)


func _confirm() -> void:
	if _puzzle == null or _assignments.size() != _passenger_data_by_name.size():
		_error_label.text = incomplete_assignment_error
		return
	departures_confirmed.emit(_assignments.duplicate(true))


func _present_board() -> void:
	_board_anchor.pivot_offset = _board_anchor.size * 0.5
	_board_anchor.modulate.a = 0.0
	_board_anchor.scale = Vector2(0.97, 0.97)
	var tween: Tween = create_tween()
	tween.tween_property(_board_anchor, ^"modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(_board_anchor, ^"scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key_event := event as InputEventKey
	if key_event != null and key_event.echo:
		return
	if event.is_action_pressed(&"interact"):
		request_close()
		get_viewport().set_input_as_handled()
