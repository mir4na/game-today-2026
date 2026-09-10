class_name PassengerDocuments
extends Control

signal stamp_toggle_requested
signal ticket_visibility_changed(is_ticket_visible: bool)

enum ActiveDocument {
	ID_CARD,
	TICKET,
}

@export_category("Animation")
@export var reset_animation: StringName
@export var show_id_animation: StringName
@export var show_ticket_animation: StringName
@export_category("Instruction Copy")
@export var id_instruction: String
@export var unstamped_ticket_instruction: String
@export var stamped_ticket_instruction: String
@export var locked_ticket_instruction: String

var _active_document: ActiveDocument = ActiveDocument.ID_CARD
var _is_stamped: bool = false
var _stamp_locked: bool = false

# These document scenes are validated by the authored hierarchy, without global-class parse coupling.
@onready var _id_card: Variant = %IDCard
@onready var _passenger_ticket: Variant = %PassengerTicket
@onready var _animation_player: AnimationPlayer = %DocumentAnimation
@onready var _instruction_label: Label = %InstructionLabel


func _ready() -> void:
	reset_to_id_card()


func set_passenger(data: PassengerData) -> void:
	_id_card.set_passenger(data)
	_passenger_ticket.set_passenger(data)
	_is_stamped = data != null and not data.stamped_station.is_empty()
	_update_instruction()


func set_stamp_locked(value: bool) -> void:
	_stamp_locked = value
	_passenger_ticket.set_stamp_locked(value)
	_passenger_ticket.set_stamp_interaction_enabled(is_ticket_active() and not _stamp_locked)
	_update_instruction()


func reset_to_id_card() -> void:
	_animation_player.stop()
	_animation_player.play(reset_animation)
	_animation_player.advance(0.0)
	_animation_player.stop()
	_active_document = ActiveDocument.ID_CARD
	_passenger_ticket.set_stamp_interaction_enabled(false)
	ticket_visibility_changed.emit(false)
	_update_instruction()


func show_id_card() -> bool:
	if _active_document == ActiveDocument.ID_CARD:
		return true
	if _animation_player.is_playing() or _passenger_ticket.is_stamp_animating():
		return false
	_active_document = ActiveDocument.ID_CARD
	_passenger_ticket.set_stamp_interaction_enabled(false)
	ticket_visibility_changed.emit(false)
	_animation_player.play(show_id_animation)
	GameSFX.play(&"paper_rustle", -9.0, 0.97, 0.025, 0.08)
	_update_instruction()
	return true


func show_ticket() -> bool:
	if _active_document == ActiveDocument.TICKET:
		return true
	if _animation_player.is_playing() or _passenger_ticket.is_stamp_animating():
		return false
	_active_document = ActiveDocument.TICKET
	_passenger_ticket.set_stamp_interaction_enabled(false)
	_animation_player.play(show_ticket_animation)
	GameSFX.play(&"paper_rustle", -9.0, 1.03, 0.025, 0.08)
	_update_instruction()
	return true


func set_disembark_stamped(value: bool, animate: bool = false) -> void:
	_is_stamped = value
	_passenger_ticket.set_disembark_stamped(value, animate)
	_update_instruction()


func set_station_stamp(station_name: String, ticket_position: Vector2, animate: bool = false) -> void:
	_is_stamped = true
	_passenger_ticket.set_station_stamp(station_name, ticket_position, animate)
	_update_instruction()


func get_ticket_surface() -> Control:
	return _passenger_ticket.get_ticket_surface() as Control


func has_stamp() -> bool:
	return _is_stamped


func is_ticket_active() -> bool:
	return _active_document == ActiveDocument.TICKET and not _animation_player.is_playing()


func request_stamp_toggle() -> bool:
	# Station stamps are now selected and dragged from the drawer. Keyboard/click
	# toggling is deliberately disabled because placed ink cannot be removed.
	return false


func toggle_document() -> bool:
	if _animation_player.is_playing() or _passenger_ticket.is_stamp_animating():
		return false
	return show_ticket() if _active_document == ActiveDocument.ID_CARD else show_id_card()


func request_stamp_action() -> bool:
	return request_stamp_toggle()


func _on_ticket_stamp_toggle_requested() -> void:
	request_stamp_toggle()


func _on_document_animation_finished(_animation_name: StringName) -> void:
	_passenger_ticket.set_stamp_interaction_enabled(_active_document == ActiveDocument.TICKET and not _stamp_locked)
	ticket_visibility_changed.emit(_active_document == ActiveDocument.TICKET)
	_update_instruction()


func _on_ticket_stamp_animation_finished() -> void:
	_passenger_ticket.set_stamp_interaction_enabled(is_ticket_active() and not _stamp_locked)
	_update_instruction()


func _update_instruction() -> void:
	if not is_node_ready():
		return
	if _active_document == ActiveDocument.ID_CARD:
		_instruction_label.text = id_instruction
	elif _stamp_locked:
		_instruction_label.text = locked_ticket_instruction
	elif _is_stamped:
		_instruction_label.text = stamped_ticket_instruction
	else:
		_instruction_label.text = unstamped_ticket_instruction
