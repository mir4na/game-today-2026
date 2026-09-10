class_name PassengerTicketDocument
extends Control

signal stamp_toggle_requested
signal stamp_animation_finished

const STAMP_RESULT_SIZE := Vector2(122.0, 122.0)
const DEFAULT_STAMP_CENTER := Vector2(502.0, 152.0)
const RESULT_TEXTURES := {
	"Alderwick": preload("res://assets/ui/Stamp/StampResult_A.png"),
	"Brambleford": preload("res://assets/ui/Stamp/StampResult_B.png"),
	"Cinderfield": preload("res://assets/ui/Stamp/StampResult_C.png"),
	"Dunmere": preload("res://assets/ui/Stamp/StampResult_d.png"),
	"Eastmere": preload("res://assets/ui/Stamp/StampResult_E.png"),
}

@export_category("Service Copy")
@export var service_date_text: String
@export var train_number_text: String
@export var missing_value_text: String
@export_category("Stamp Animation")
## Kept for scene compatibility with the previous click-to-toggle stamp system.
@export var reset_stamp_animation: StringName = &"RESET"
@export var stamped_state_animation: StringName = &"STAMPED"
@export var apply_stamp_animation: StringName = &"apply_disembark_stamp"
@export var remove_stamp_animation: StringName = &"remove_disembark_stamp"
@export var unstamped_tooltip: String = "Drag a station stamp onto this ticket"
@export var stamped_tooltip: String = "This ticket has already been stamped"
@export var locked_tooltip: String = "Clean the dirty seat before stamping tickets"

var _data: PassengerData
var _is_stamped: bool = false
var _interaction_enabled: bool = false
var _stamp_locked: bool = false
var _stamp_tween: Tween

@onready var _ticket_surface: Control = $TicketSurface
@onready var _passenger_name: Label = %PassengerName
@onready var _origin: Label = %Origin
@onready var _destination: Label = %Destination
@onready var _service_date: Label = %ServiceDate
@onready var _train_number: Label = %TrainNumber
@onready var _ticket_number: Label = %TicketNumber
@onready var _validation_stamp: TextureRect = %ValidationStamp
@onready var _legacy_stamp_animation: AnimationPlayer = %StampAnimation


func _ready() -> void:
	_prepare_stamp_visual()
	_apply_service_copy()
	_apply_passenger_data()
	_apply_saved_stamp(false)
	set_stamp_interaction_enabled(false)


func set_passenger(data: PassengerData) -> void:
	_data = data
	if not is_node_ready():
		await ready
	_apply_passenger_data()
	_apply_saved_stamp(false)


func get_ticket_surface() -> Control:
	return _ticket_surface


func set_station_stamp(station_name: String, ticket_position: Vector2, animate: bool = false) -> void:
	if not is_node_ready():
		await ready
	var result_texture := get_stamp_result_texture(station_name)
	if result_texture == null:
		push_warning("No ticket stamp result is configured for station '%s'." % station_name)
		return
	_is_stamped = true
	_validation_stamp.texture = result_texture
	_position_stamp(ticket_position)
	_update_tooltip()
	if animate:
		_animate_stamp_impact()
	else:
		_apply_stamp_state_immediately(true)


func clear_station_stamp() -> void:
	if not is_node_ready():
		await ready
	_is_stamped = false
	_apply_stamp_state_immediately(false)
	_update_tooltip()


func set_disembark_stamped(value: bool, animate: bool = false) -> void:
	# Compatibility entry point for older tests and callers. Player-facing input no
	# longer calls this toggle; a placed stamp is permanent for that passenger.
	if not value:
		clear_station_stamp()
		return
	var station_name: String = ""
	var ticket_position := DEFAULT_STAMP_CENTER
	if _data != null:
		station_name = _data.stamped_station
		if station_name.is_empty():
			station_name = _data.get_required_day_dropoff_station()
		if not _data.stamp_ticket_position.is_zero_approx():
			ticket_position = _data.stamp_ticket_position
	set_station_stamp(station_name, ticket_position, animate)


func set_stamp_interaction_enabled(value: bool) -> void:
	_interaction_enabled = value and not _stamp_locked and not _is_stamped
	# Drag-and-drop is owned by StampTrayUI. The ticket itself must never swallow
	# the pointer or behave like the old full-ticket toggle button.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_update_tooltip()


func set_stamp_locked(value: bool) -> void:
	_stamp_locked = value
	if _stamp_locked:
		_interaction_enabled = false
	_update_tooltip()


func is_stamp_animating() -> bool:
	return is_instance_valid(_stamp_tween) and _stamp_tween.is_valid()


static func get_stamp_result_texture(station_name: String) -> Texture2D:
	return RESULT_TEXTURES.get(station_name) as Texture2D


func _prepare_stamp_visual() -> void:
	_legacy_stamp_animation.stop()
	_validation_stamp.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_validation_stamp.size = STAMP_RESULT_SIZE
	_validation_stamp.pivot_offset = STAMP_RESULT_SIZE * 0.5
	_validation_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_validation_stamp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_validation_stamp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _apply_saved_stamp(animate: bool) -> void:
	if _data == null or _data.stamped_station.is_empty():
		_is_stamped = false
		_apply_stamp_state_immediately(false)
		return
	var saved_position := _data.stamp_ticket_position
	if saved_position.is_zero_approx():
		saved_position = DEFAULT_STAMP_CENTER
	set_station_stamp(_data.stamped_station, saved_position, animate)


func _position_stamp(ticket_position: Vector2) -> void:
	var half_size := STAMP_RESULT_SIZE * 0.5
	var safe_center := Vector2(
		clampf(ticket_position.x, half_size.x, _ticket_surface.size.x - half_size.x),
		clampf(ticket_position.y, half_size.y, _ticket_surface.size.y - half_size.y)
	)
	_validation_stamp.position = safe_center - half_size
	_validation_stamp.rotation = deg_to_rad(float((abs(hash(_data.passenger_name if _data != null else "ticket")) % 9) - 4))


func _animate_stamp_impact() -> void:
	_kill_stamp_tween()
	_validation_stamp.show()
	_validation_stamp.self_modulate = Color(1.0, 1.0, 1.0, 0.08)
	_validation_stamp.scale = Vector2(1.34, 0.72)
	var rest_position := _ticket_surface.position
	var rest_scale := _ticket_surface.scale
	_stamp_tween = create_tween()
	_stamp_tween.set_parallel(true)
	_stamp_tween.tween_property(_validation_stamp, ^"scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_stamp_tween.tween_property(_validation_stamp, ^"self_modulate", Color(1.0, 1.0, 1.0, 0.72), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_stamp_tween.tween_property(_ticket_surface, ^"scale", rest_scale * Vector2(1.012, 0.974), 0.085).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_stamp_tween.tween_property(_ticket_surface, ^"position", rest_position + Vector2(0.0, 4.0), 0.085).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_stamp_tween.chain().set_parallel(true)
	_stamp_tween.tween_property(_ticket_surface, ^"scale", rest_scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_stamp_tween.tween_property(_ticket_surface, ^"position", rest_position, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_stamp_tween.chain().tween_callback(_on_custom_stamp_animation_finished)
	GameSFX.play(&"stamp_impact", -5.0, 1.0, 0.025, 0.12)


func _apply_stamp_state_immediately(value: bool) -> void:
	_kill_stamp_tween()
	_validation_stamp.visible = value
	_validation_stamp.scale = Vector2.ONE
	_validation_stamp.self_modulate = Color(1.0, 1.0, 1.0, 0.72 if value else 0.0)
	_ticket_surface.position = Vector2.ZERO
	_ticket_surface.scale = Vector2.ONE


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
		_service_date.text = _display_or_fallback(service_date_text)
		_ticket_number.text = missing_value_text
		return

	var printed_name: String = _data.ticket_owner.strip_edges()
	if printed_name.is_empty():
		printed_name = _data.passenger_name.strip_edges()
	_passenger_name.text = _display_or_fallback(printed_name).to_upper()
	_origin.text = _display_or_fallback(_data.origin_station).to_upper()
	_destination.text = _display_or_fallback(_data.destination_station).to_upper()
	_service_date.text = _display_or_fallback(_data.ticket_service_date).to_upper()
	_train_number.text = _display_or_fallback(_data.ticket_train_number).to_upper()
	_ticket_number.text = _display_or_fallback(_data.ticket_number).to_upper()


func _display_or_fallback(value: String) -> String:
	var cleaned_value: String = value.strip_edges()
	return missing_value_text if cleaned_value.is_empty() else cleaned_value


func _update_tooltip() -> void:
	if _stamp_locked:
		tooltip_text = locked_tooltip
	else:
		tooltip_text = stamped_tooltip if _is_stamped else unstamped_tooltip


func _on_custom_stamp_animation_finished() -> void:
	_stamp_tween = null
	stamp_animation_finished.emit()


func _on_stamp_animation_finished(_animation_name: StringName) -> void:
	# Kept because the authored scene still contains the legacy AnimationPlayer.
	pass


func _kill_stamp_tween() -> void:
	if is_instance_valid(_stamp_tween) and _stamp_tween.is_valid():
		_stamp_tween.kill()
	_stamp_tween = null
