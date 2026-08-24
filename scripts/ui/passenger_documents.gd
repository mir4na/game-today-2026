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

var _active_document: ActiveDocument = ActiveDocument.ID_CARD

# These document scenes are validated by the authored hierarchy, without global-class parse coupling.
@onready var _id_card: Variant = %IDCard
@onready var _passenger_ticket: Variant = %PassengerTicket
@onready var _animation_player: AnimationPlayer = %DocumentAnimation


func _ready() -> void:
	reset_to_id_card()


func set_passenger(data: PassengerData) -> void:
	_id_card.set_passenger(data)
	_passenger_ticket.set_passenger(data)
	_passenger_ticket.set_disembark_stamped(false)


func reset_to_id_card() -> void:
	_animation_player.stop()
	_animation_player.play(reset_animation)
	_animation_player.advance(0.0)
	_animation_player.stop()
	_active_document = ActiveDocument.ID_CARD
	_passenger_ticket.set_stamp_interaction_enabled(false)


func show_id_card() -> bool:
	if _active_document == ActiveDocument.ID_CARD:
		return true
	if _animation_player.is_playing() or _passenger_ticket.is_stamp_animating():
		return false
	_active_document = ActiveDocument.ID_CARD
	_passenger_ticket.set_stamp_interaction_enabled(false)
	_animation_player.play(show_id_animation)
	return true


func show_ticket() -> bool:
	if _active_document == ActiveDocument.TICKET:
		return true
	if _animation_player.is_playing() or _passenger_ticket.is_stamp_animating():
		return false
	_active_document = ActiveDocument.TICKET
	_passenger_ticket.set_stamp_interaction_enabled(false)
	_animation_player.play(show_ticket_animation)
	return true


func set_disembark_stamped(value: bool, animate: bool = false) -> void:
	_passenger_ticket.set_disembark_stamped(value, animate)


func is_ticket_active() -> bool:
	return _active_document == ActiveDocument.TICKET and not _animation_player.is_playing()


func request_stamp_toggle() -> bool:
	if not is_ticket_active() or _passenger_ticket.is_stamp_animating():
		return false
	stamp_toggle_requested.emit()
	return true


func request_primary_action() -> bool:
	if _animation_player.is_playing() or _passenger_ticket.is_stamp_animating():
		return false
	if _active_document == ActiveDocument.ID_CARD:
		return show_ticket()
	return request_stamp_toggle()


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if _animation_player.is_playing() or _passenger_ticket.is_stamp_animating():
		return
	var switched: bool = show_ticket() if _active_document == ActiveDocument.ID_CARD else show_id_card()
	if switched:
		accept_event()


func _on_ticket_stamp_toggle_requested() -> void:
	request_stamp_toggle()


func _on_document_animation_finished(_animation_name: StringName) -> void:
	_passenger_ticket.set_stamp_interaction_enabled(_active_document == ActiveDocument.TICKET)


func _on_ticket_stamp_animation_finished() -> void:
	_passenger_ticket.set_stamp_interaction_enabled(is_ticket_active())
