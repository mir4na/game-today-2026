class_name NightStationTarget
extends Control
## Drop target for one scene-authored constellation node.

signal passenger_dropped(station_name: String, passenger_name: String)
signal selected(station_name: String)

@export var station_name: String
@export var face_token_scene: PackedScene

@onready var _station_label: Label = %StationLabel
@onready var _assignment_label: Label = %AssignmentLabel
@onready var _assignment_faces: HBoxContainer = %AssignmentFaces
@onready var _pin: TextureRect = %Pin
@onready var _drop_glow: Panel = %DropGlow


func _ready() -> void:
	_station_label.text = station_name.to_upper()
	set_assignments([], {})


func set_assignments(passenger_names: Array, passenger_data_by_name: Dictionary) -> void:
	for child: Node in _assignment_faces.get_children():
		_assignment_faces.remove_child(child)
		child.free()
	var valid_names: Array[String] = []
	for passenger_value: Variant in passenger_names:
		var passenger_name: String = str(passenger_value)
		if not passenger_data_by_name.has(passenger_name):
			continue
		var data := passenger_data_by_name[passenger_name] as PassengerData
		if data == null or data.get_character_artwork() == null:
			continue
		valid_names.append(passenger_name)
		if face_token_scene == null:
			continue
		var token := face_token_scene.instantiate() as NightStationFaceToken
		if token == null:
			continue
		_assignment_faces.add_child(token)
		token.configure(passenger_name, data.get_character_artwork())
	_assignment_faces.visible = not valid_names.is_empty()
	_pin.visible = valid_names.is_empty()
	if valid_names.is_empty():
		_assignment_label.text = ""
	elif valid_names.size() == 1:
		_assignment_label.text = valid_names[0].to_upper()
	else:
		_assignment_label.text = "%d SOULS" % valid_names.size()


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
