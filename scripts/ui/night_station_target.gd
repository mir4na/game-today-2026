class_name NightStationTarget
extends Control
## Drop target for one scene-authored station-path node.

signal passenger_dropped(station_name: String, passenger_name: String)
signal selected(station_name: String)

@export var station_name: String
@export var face_token_scene: PackedScene
@export var path_anchor_offset: Vector2 = Vector2(90.0, 94.0)
@export_category("Validation Animation")
@export_range(0.01, 1.0, 0.01) var pointer_pop_seconds: float = 0.11
@export_range(0.01, 1.0, 0.01) var pointer_shrink_seconds: float = 0.18
@export_range(0.01, 1.0, 0.01) var star_pulse_seconds: float = 0.22
@export_range(0.01, 1.0, 0.01) var failure_burst_seconds: float = 0.55
@export var success_glow_color: Color = Color(1.0, 0.76, 0.30, 0.82)
@export var failure_glow_color: Color = Color(1.0, 0.20, 0.24, 0.92)

@onready var _station_label: Label = %StationLabel
@onready var _assignment_label: Label = %AssignmentLabel
@onready var _assignment_faces: HBoxContainer = %AssignmentFaces
@onready var _pin: TextureRect = %Pin
@onready var _drop_glow: Panel = %DropGlow
@onready var _star: TextureRect = %Star
@onready var _validation_glow: TextureRect = %ValidationGlow
@onready var _failure_particles: CPUParticles2D = %FailureParticles

var _validation_tween: Tween


func _ready() -> void:
	_station_label.text = station_name.to_upper()
	_validation_glow.texture = _star.texture
	set_assignments([], {})
	reset_validation_visual()


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
	_assignment_faces.pivot_offset = _assignment_faces.size * 0.5


func play_validation(is_correct: bool) -> void:
	if is_instance_valid(_validation_tween) and _validation_tween.is_valid():
		_validation_tween.kill()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_glow.hide()
	_assignment_faces.pivot_offset = _assignment_faces.size * 0.5
	_star.pivot_offset = _star.size * 0.5
	_validation_glow.pivot_offset = _validation_glow.size * 0.5

	_validation_tween = create_tween()
	_validation_tween.tween_property(
		_assignment_faces, ^"scale", Vector2(1.16, 1.16), pointer_pop_seconds
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_validation_tween.parallel().tween_property(
		_assignment_label, ^"modulate:a", 0.0, pointer_pop_seconds + pointer_shrink_seconds
	)
	_validation_tween.tween_property(
		_assignment_faces, ^"scale", Vector2.ZERO, pointer_shrink_seconds
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_validation_tween.parallel().tween_property(
		_assignment_faces, ^"modulate:a", 0.0, pointer_shrink_seconds
	)
	await _validation_tween.finished
	if is_correct:
		await _play_success_pulse()
	else:
		await _play_failure_burst()


func reset_validation_visual() -> void:
	if is_instance_valid(_validation_tween) and _validation_tween.is_valid():
		_validation_tween.kill()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_assignment_faces.scale = Vector2.ONE
	_assignment_faces.modulate = Color.WHITE
	_assignment_label.modulate = Color.WHITE
	_star.scale = Vector2.ONE
	_star.modulate = Color.WHITE
	_validation_glow.scale = Vector2.ONE
	_validation_glow.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_failure_particles.emitting = false


func get_path_node_center() -> Vector2:
	return position + path_anchor_offset


func _play_success_pulse() -> void:
	_validation_glow.modulate = Color(success_glow_color, 0.0)
	_validation_tween = create_tween()
	_validation_tween.tween_property(
		_star, ^"scale", Vector2(0.68, 0.68), star_pulse_seconds * 0.55
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_validation_tween.parallel().tween_property(
		_validation_glow, ^"scale", Vector2(0.68, 0.68), star_pulse_seconds * 0.55
	)
	_validation_tween.tween_property(
		_star, ^"scale", Vector2(1.18, 1.18), star_pulse_seconds
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_validation_tween.parallel().tween_property(
		_validation_glow, ^"scale", Vector2(1.34, 1.34), star_pulse_seconds
	)
	_validation_tween.parallel().tween_property(
		_validation_glow, ^"modulate", success_glow_color, star_pulse_seconds
	)
	_validation_tween.tween_property(
		_star, ^"scale", Vector2.ONE, star_pulse_seconds * 0.55
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_validation_tween.parallel().tween_property(
		_validation_glow, ^"scale", Vector2(1.12, 1.12), star_pulse_seconds * 0.55
	)
	await _validation_tween.finished


func _play_failure_burst() -> void:
	_validation_glow.modulate = failure_glow_color
	_failure_particles.restart()
	_failure_particles.emitting = true
	_validation_tween = create_tween()
	_validation_tween.tween_property(
		_star, ^"scale", Vector2(0.76, 0.76), star_pulse_seconds * 0.6
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_validation_tween.parallel().tween_property(
		_star, ^"modulate", Color(1.0, 0.34, 0.38, 1.0), star_pulse_seconds * 0.6
	)
	_validation_tween.tween_property(
		_star, ^"scale", Vector2(1.08, 1.08), star_pulse_seconds
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_validation_tween.parallel().tween_property(
		_validation_glow, ^"scale", Vector2(1.55, 1.55), star_pulse_seconds
	)
	_validation_tween.tween_interval(failure_burst_seconds)
	_validation_tween.tween_property(
		_validation_glow, ^"modulate:a", 0.2, star_pulse_seconds
	)
	await _validation_tween.finished


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
