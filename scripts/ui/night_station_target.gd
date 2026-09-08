class_name NightStationTarget
extends Control
## Drop target for one scene-authored constellation node.

signal passenger_dropped(station_name: String, passenger_name: String)
signal selected(station_name: String)

@export var station_name: String

@onready var _station_label: Label = %StationLabel
@onready var _assignment_label: Label = %AssignmentLabel
@onready var _assignment_portrait: TextureRect = %AssignmentPortrait
@onready var _drop_glow: Panel = %DropGlow


func _ready() -> void:
	_station_label.text = station_name.to_upper()
	set_assignment("", null)


func set_assignment(passenger_name: String, portrait: Texture2D) -> void:
	_assignment_label.text = passenger_name.to_upper()
	_assignment_portrait.texture = portrait
	_assignment_portrait.visible = portrait != null


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		_drop_glow.hide()
		return false
	var payload: Dictionary = data
	var accepted: bool = (
		payload.get("kind", &"") == &"night_soul_card"
		and not str(payload.get("passenger_name", "")).is_empty()
	)
	_drop_glow.visible = accepted
	return accepted


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_drop_glow.hide()
	if not data is Dictionary:
		return
	var payload: Dictionary = data
	passenger_dropped.emit(station_name, str(payload.get("passenger_name", "")))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and is_instance_valid(_drop_glow):
		_drop_glow.hide()


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		selected.emit(station_name)
