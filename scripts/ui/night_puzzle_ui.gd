class_name NightPuzzleUI
extends Control

signal departures_confirmed(assignments: Dictionary)

@export_category("Inspector Copy")
@export var selection_instruction: String
@export var selected_instruction_template: String
@export var empty_station_text: String
@export var station_slot_template: String = "%s\n%s"
@export var no_passenger_error: String
@export var incomplete_assignment_error: String

var _puzzle: DeparturePuzzleData
var _selected_passenger: String = ""
var _assignments: Dictionary = {}
@onready var _statement_label: RichTextLabel = %StatementLabel
@onready var _selection_label: Label = %SelectionLabel
@onready var _error_label: Label = %ErrorLabel
@onready var _confirm_button: Button = %ConfirmButton
@onready var _passenger_slots: Array[Button] = [%PassengerSlot1, %PassengerSlot2, %PassengerSlot3, %PassengerSlot4]
@onready var _station_slots: Array[Button] = [%StationSlot1, %StationSlot2, %StationSlot3, %StationSlot4]
@onready var _station_arrows: Array[Label] = [%StationArrow1, %StationArrow2, %StationArrow3]
var _passenger_buttons: Dictionary = {}
var _station_buttons: Dictionary = {}
var _slot_passenger_names := PackedStringArray()
var _slot_station_names := PackedStringArray()

func open_puzzle(passengers: Array[PassengerData], puzzle: DeparturePuzzleData) -> void:
	_puzzle = puzzle
	_selected_passenger = ""
	_assignments.clear()
	_passenger_buttons.clear()
	_station_buttons.clear()
	_slot_passenger_names.clear()
	_slot_station_names.clear()
	_error_label.text = ""
	for button: Button in _passenger_slots:
		button.hide()
		button.disabled = false
	for button: Button in _station_slots:
		button.hide()
	for arrow: Label in _station_arrows:
		arrow.hide()
	if passengers.size() > _passenger_slots.size() or puzzle.night_stations.size() > _station_slots.size():
		push_error("Night puzzle scene only supports four passenger and station slots.")
		return
	for i: int in range(passengers.size()):
		var data: PassengerData = passengers[i]
		var button: Button = _passenger_slots[i]
		button.text = data.short_name.to_upper()
		button.show()
		_slot_passenger_names.append(data.short_name)
		_passenger_buttons[data.short_name] = button
	for i: int in range(puzzle.night_stations.size()):
		var station: String = puzzle.night_stations[i]
		var button: Button = _station_slots[i]
		button.text = station_slot_template % [station.to_upper(), empty_station_text]
		button.show()
		_slot_station_names.append(station)
		_station_buttons[station] = button
		if i < puzzle.night_stations.size() - 1:
			_station_arrows[i].show()
	_statement_label.text = puzzle.night_stop_clues
	_selection_label.text = selection_instruction
	show()
	if not passengers.is_empty():
		_passenger_slots[0].grab_focus()

func _on_passenger_slot_pressed(index: int) -> void:
	if index < _slot_passenger_names.size():
		_select_passenger(_slot_passenger_names[index])

func _on_station_slot_pressed(index: int) -> void:
	if index < _slot_station_names.size():
		_assign_station(_slot_station_names[index])

func _on_passenger_slot_1_pressed() -> void:
	_on_passenger_slot_pressed(0)

func _on_passenger_slot_2_pressed() -> void:
	_on_passenger_slot_pressed(1)

func _on_passenger_slot_3_pressed() -> void:
	_on_passenger_slot_pressed(2)

func _on_passenger_slot_4_pressed() -> void:
	_on_passenger_slot_pressed(3)

func _on_station_slot_1_pressed() -> void:
	_on_station_slot_pressed(0)

func _on_station_slot_2_pressed() -> void:
	_on_station_slot_pressed(1)

func _on_station_slot_3_pressed() -> void:
	_on_station_slot_pressed(2)

func _on_station_slot_4_pressed() -> void:
	_on_station_slot_pressed(3)

func show_error(message: String) -> void:
	_error_label.text = message

func _select_passenger(passenger_name: String) -> void:
	_selected_passenger = passenger_name
	_selection_label.text = selected_instruction_template % passenger_name
	for name: String in _passenger_buttons:
		var button := _passenger_buttons[name] as Button
		button.disabled = name == passenger_name

func _assign_station(station: String) -> void:
	if _selected_passenger.is_empty():
		_error_label.text = no_passenger_error
		return
	# One passenger and one station per slot; assignments remain freely editable.
	for old_station: String in _assignments.keys():
		if _assignments[old_station] == _selected_passenger:
			_assignments.erase(old_station)
	if _assignments.has(station):
		var displaced: String = _assignments[station]
		if _passenger_buttons.has(displaced):
			(_passenger_buttons[displaced] as Button).disabled = false
	_assignments[station] = _selected_passenger
	_update_station_buttons()
	_error_label.text = ""

func _update_station_buttons() -> void:
	for station: String in _station_buttons:
		var passenger_name: String = _assignments.get(station, empty_station_text)
		(_station_buttons[station] as Button).text = station_slot_template % [station.to_upper(), passenger_name]

func _confirm() -> void:
	if _puzzle == null or _assignments.size() != _puzzle.night_stations.size():
		_error_label.text = incomplete_assignment_error
		return
	departures_confirmed.emit(_assignments.duplicate())
