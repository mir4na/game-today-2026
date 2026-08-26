class_name PassengerDocuments
extends Control

signal stamp_toggle_requested

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

var _active_document: ActiveDocument = ActiveDocument.ID_CARD
var _is_stamped: bool = false

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
	_is_stamped = false
	_passenger_ticket.set_disembark_stamped(false)
	_update_instruction()


func reset_to_id_card() -> void:
	_animation_player.stop()
	_animation_player.play(reset_animation)
	_animation_player.advance(0.0)
	_animation_player.stop()
	_active_document = ActiveDocument.ID_CARD
	_passenger_ticket.set_stamp_interaction_enabled(false)
	_update_instruction()


func show_id_card() -> bool:
	if _active_document == ActiveDocument.ID_CARD:
		return true
	if _animation_player.is_playing() or _passenger_ticket.is_stamp_animating():
		return false
	_active_document = ActiveDocument.ID_CARD
	_passenger_ticket.set_stamp_interaction_enabled(false)
	_animation_player.play(show_id_animation)
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
	_update_instruction()
	return true


func set_disembark_stamped(value: bool, animate: bool = false) -> void:
	_is_stamped = value
	_passenger_ticket.set_disembark_stamped(value, animate)
	_update_instruction()


func is_ticket_active() -> bool:
	return _active_document == ActiveDocument.TICKET and not _animation_player.is_playing()


func request_stamp_toggle() -> bool:
	if not is_ticket_active() or _passenger_ticket.is_stamp_animating():
		return false
	stamp_toggle_requested.emit()
	return true


func toggle_document() -> bool:
	if _animation_player.is_playing() or _passenger_ticket.is_stamp_animating():
		return false
	return show_ticket() if _active_document == ActiveDocument.ID_CARD else show_id_card()


func request_stamp_action() -> bool:
	return request_stamp_toggle()


func _on_ticket_stamp_toggle_requested() -> void:
	request_stamp_toggle()


func _on_document_animation_finished(_animation_name: StringName) -> void:
	_passenger_ticket.set_stamp_interaction_enabled(_active_document == ActiveDocument.TICKET)
	_update_instruction()


func _on_ticket_stamp_animation_finished() -> void:
	_passenger_ticket.set_stamp_interaction_enabled(is_ticket_active())
	_update_instruction()


func _update_instruction() -> void:
	if not is_node_ready():
		return
	if _active_document == ActiveDocument.ID_CARD:
		_instruction_label.text = id_instruction
	elif _is_stamped:
		_instruction_label.text = stamped_ticket_instruction
	else:
		_instruction_label.text = unstamped_ticket_instruction
