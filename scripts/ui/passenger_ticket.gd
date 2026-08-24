class_name PassengerTicketDocument
extends Control

signal stamp_toggle_requested
signal stamp_animation_finished

@export_category("Service Copy")
@export var service_date_text: String
@export var train_number_text: String
@export var missing_value_text: String
@export_category("Stamp Animation")
@export var reset_stamp_animation: StringName = &"RESET"
@export var stamped_state_animation: StringName = &"STAMPED"
@export var apply_stamp_animation: StringName = &"apply_disembark_stamp"
@export var remove_stamp_animation: StringName = &"remove_disembark_stamp"
@export var unstamped_tooltip: String = "Stamp this ticket for the next stop"
@export var stamped_tooltip: String = "Remove the disembark stamp"

var _data: PassengerData
var _is_stamped: bool = false
var _interaction_enabled: bool = false

@onready var _passenger_name: Label = %PassengerName
@onready var _origin: Label = %Origin
@onready var _destination: Label = %Destination
@onready var _service_date: Label = %ServiceDate
@onready var _train_number: Label = %TrainNumber
@onready var _ticket_number: Label = %TicketNumber
@onready var _validation_stamp: TextureRect = %ValidationStamp
@onready var _stamp_animation: AnimationPlayer = %StampAnimation


func _ready() -> void:
	_apply_service_copy()
	_apply_passenger_data()
	_apply_stamp_immediately(false)
	set_stamp_interaction_enabled(false)


func set_passenger(data: PassengerData) -> void:
	_data = data
	if not is_node_ready():
		await ready
	_apply_passenger_data()


func set_disembark_stamped(value: bool, animate: bool = false) -> void:
	if not is_node_ready():
		await ready
	if _is_stamped == value and not _stamp_animation.is_playing():
		_apply_stamp_immediately(value)
		return
	_is_stamped = value
	_update_tooltip()
	if not animate:
		_apply_stamp_immediately(value)
		return
	set_stamp_interaction_enabled(false)
	_stamp_animation.play(apply_stamp_animation if value else remove_stamp_animation)


func set_stamp_interaction_enabled(value: bool) -> void:
	_interaction_enabled = value
	mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE
	_update_tooltip()


func is_stamp_animating() -> bool:
	return _stamp_animation.is_playing()


func _apply_service_copy() -> void:
	_service_date.text = _display_or_fallback(service_date_text)
	_train_number.text = _display_or_fallback(train_number_text)


func _apply_passenger_data() -> void:
	if not is_node_ready():
		return
	if _data == null:
		_passenger_name.text = missing_value_text
		_origin.text = missing_value_text
		_destination.text = missing_value_text
		_ticket_number.text = missing_value_text
		return

	var printed_name: String = _data.ticket_owner.strip_edges()
	if printed_name.is_empty():
		printed_name = _data.passenger_name.strip_edges()
	_passenger_name.text = _display_or_fallback(printed_name).to_upper()
	_origin.text = _display_or_fallback(_data.origin_station).to_upper()
	_destination.text = _display_or_fallback(_data.destination_station).to_upper()
	_train_number.text = _display_or_fallback(_data.ticket_train_number).to_upper()
	_ticket_number.text = _display_or_fallback(_data.ticket_number).to_upper()


func _display_or_fallback(value: String) -> String:
	var cleaned_value: String = value.strip_edges()
	return missing_value_text if cleaned_value.is_empty() else cleaned_value


func _gui_input(event: InputEvent) -> void:
	if not _interaction_enabled or _stamp_animation.is_playing():
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	accept_event()
	stamp_toggle_requested.emit()


func _apply_stamp_immediately(value: bool) -> void:
	_stamp_animation.stop()
	_stamp_animation.play(stamped_state_animation if value else reset_stamp_animation)
	_stamp_animation.advance(0.0)
	_stamp_animation.stop()
	_update_tooltip()


func _update_tooltip() -> void:
	tooltip_text = stamped_tooltip if _is_stamped else unstamped_tooltip


func _on_stamp_animation_finished(_animation_name: StringName) -> void:
	_apply_stamp_immediately(_is_stamped)
	stamp_animation_finished.emit()
