class_name DeadSelectionUI
extends Control
## Persistent drag-and-drop abnormality log, auto-filed when daylight service ends.

signal closed

const DragCardScript := preload("res://scripts/ui/abnormal_passenger_drag_card.gd")
const LOG_SLOT_COUNT: int = 5

@export_category("Inspector Copy")
@export_multiline var notes_instruction_template: String

var _slot_names := PackedStringArray(["", "", "", "", ""])
var _passenger_cards: Dictionary = {}
@onready var _passenger_grid: GridContainer = %PassengerGrid
@onready var _entries: Array[Button] = [%LogSlot1, %LogSlot2, %LogSlot3, %LogSlot4, %LogSlot5]
@onready var _instruction_label: Label = %InstructionLabel
@onready var _close_button: Button = %CancelButton

func _ready() -> void:
	for entry: Button in _entries:
		entry.connect("passenger_dropped", _on_passenger_dropped)
		entry.connect("clear_requested", _on_slot_clear_requested)

func open_notes(passengers: Array[PassengerData]) -> void:
	_instruction_label.text = notes_instruction_template % passengers.size()
	_rebuild_passenger_cards(passengers)
	_refresh_log_slots()
	show()
	_close_button.grab_focus()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		request_close()
		get_viewport().set_input_as_handled()

func request_close() -> void:
	hide()
	closed.emit()

func get_typed_names() -> PackedStringArray:
	var selected := PackedStringArray()
	for passenger_name: String in _slot_names:
		if not passenger_name.is_empty():
			selected.append(passenger_name)
	return selected

func set_typed_names(names: PackedStringArray) -> void:
	for index: int in range(LOG_SLOT_COUNT):
		_slot_names[index] = names[index] if index < names.size() else ""
	_refresh_log_slots()

func _rebuild_passenger_cards(passengers: Array[PassengerData]) -> void:
	for child: Node in _passenger_grid.get_children():
		child.queue_free()
	_passenger_cards.clear()
	for data: PassengerData in passengers:
		var card := DragCardScript.new() as Button
		card.configure(data)
		_passenger_grid.add_child(card)
		_passenger_cards[data.short_name] = card
	_update_passenger_cards()

func _on_passenger_dropped(target_slot: int, passenger_name: String, source_slot: int) -> void:
	if target_slot < 0 or target_slot >= LOG_SLOT_COUNT or passenger_name.is_empty():
		return
	var previous_target: String = _slot_names[target_slot]
	var existing_slot: int = _slot_names.find(passenger_name)
	if source_slot >= 0 and source_slot < LOG_SLOT_COUNT and source_slot != target_slot:
		_slot_names[source_slot] = previous_target
	elif existing_slot >= 0 and existing_slot != target_slot:
		_slot_names[existing_slot] = ""
	_slot_names[target_slot] = passenger_name
	_refresh_log_slots()

func _on_slot_clear_requested(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= LOG_SLOT_COUNT:
		return
	_slot_names[slot_index] = ""
	_refresh_log_slots()

func _refresh_log_slots() -> void:
	if not is_node_ready():
		return
	for index: int in range(_entries.size()):
		_entries[index].call(&"set_assignment", _slot_names[index])
	_update_passenger_cards()

func _update_passenger_cards() -> void:
	for passenger_name: String in _passenger_cards:
		var card := _passenger_cards[passenger_name] as Button
		if is_instance_valid(card):
			card.call(&"set_logged", _slot_names.has(passenger_name))
