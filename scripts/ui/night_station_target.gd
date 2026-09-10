class_name NightStationTarget
extends Control
## Drop target for one scene-authored station-path node.

signal passenger_dropped(station_name: String, passenger_name: String)
signal selected(station_name: String)
signal validation_impact(succeeded: bool)

@export var station_name: String
@export var assignment_pin_scene: PackedScene
@export_category("Assignment Pin Layout")
## Positions are local to this station target. Edit these on each target
## instance to compose the pin stack around a particular station star.
@export var assignment_pin_offsets: PackedVector2Array = PackedVector2Array([
	Vector2(68.0, -42.0),
	Vector2(101.0, -42.0),
	Vector2(35.0, -42.0),
	Vector2(52.0, -8.0),
	Vector2(85.0, -8.0),
])
@export var path_anchor_offset: Vector2 = Vector2(90.0, 94.0)
@export_category("Validation Animation")
@export_range(0.01, 1.0, 0.01) var pointer_pop_seconds: float = 0.11
@export_range(0.01, 1.0, 0.01) var pointer_shrink_seconds: float = 0.18
@export_range(0.01, 1.0, 0.01) var star_pulse_seconds: float = 0.22
@export_range(0.01, 1.0, 0.01) var failure_burst_seconds: float = 0.55
@export var success_glow_color: Color = Color.WHITE
@export var failure_glow_color: Color = Color(1.0, 0.20, 0.24, 0.92)
@export_category("Star Idle Motion")
@export_range(0.0, 0.2, 0.005) var idle_scale_amount: float = 0.055
@export_range(0.0, 8.0, 0.25) var idle_rotation_degrees: float = 1.8
@export_range(0.2, 4.0, 0.05) var idle_motion_speed: float = 1.25

@onready var _station_label: Label = %StationLabel
@onready var _assignment_label: Label = %AssignmentLabel
@onready var _assignment_pins: Control = %AssignmentPins
@onready var _drop_glow: Panel = %DropGlow
@onready var _star: TextureRect = %Star
@onready var _validation_glow: TextureRect = %ValidationGlow
@onready var _success_particles: CPUParticles2D = %SuccessParticles
@onready var _failure_particles: CPUParticles2D = %FailureParticles
@onready var _station_plate: TextureRect = %StationPlate

var _validation_tween: Tween
var _star_material: ShaderMaterial
var _idle_phase: float = 0.0
var _idle_motion_enabled: bool = true


func _ready() -> void:
	_station_label.text = station_name.to_upper()
	_station_plate.pivot_offset = _station_plate.size * 0.5
	_station_label.pivot_offset = _station_label.size * 0.5
	_assignment_label.pivot_offset = _assignment_label.size * 0.5
	_star.pivot_offset = _star.size * 0.5
	_validation_glow.texture = _star.texture
	_star_material = _star.material as ShaderMaterial
	if _star_material != null:
		var station_phase: float = float(abs(station_name.hash() % 997)) / 997.0
		_star_material.set_shader_parameter(&"shimmer_offset", station_phase)
		_idle_phase = station_phase * TAU
	set_assignments([], {})
	reset_validation_visual()


func _process(_delta: float) -> void:
	if not _idle_motion_enabled or not is_instance_valid(_star):
		return
	var time_seconds: float = Time.get_ticks_msec() * 0.001
	var wave: float = sin(time_seconds * idle_motion_speed + _idle_phase)
	var scale_factor: float = 1.0 + wave * idle_scale_amount
	_star.scale = Vector2.ONE * scale_factor
	_star.rotation = deg_to_rad(idle_rotation_degrees) * sin(
		time_seconds * idle_motion_speed * 0.7 + _idle_phase
	)


func set_assignments(passenger_names: Array, passenger_data_by_name: Dictionary) -> void:
	for child: Node in _assignment_pins.get_children():
		_assignment_pins.remove_child(child)
		child.free()
	var valid_names: Array[String] = []
	for index: int in passenger_names.size():
		var passenger_value: Variant = passenger_names[index]
		var passenger_name: String = str(passenger_value)
		if not passenger_data_by_name.has(passenger_name):
			continue
		var data := passenger_data_by_name[passenger_name] as PassengerData
		if data == null or data.get_character_artwork() == null:
			continue
		valid_names.append(passenger_name)
		if assignment_pin_scene == null:
			continue
		var pin := assignment_pin_scene.instantiate() as Control
		if pin == null:
			continue
		_assignment_pins.add_child(pin)
		pin.position = _get_assignment_pin_offset(valid_names.size() - 1)
		pin.call(&"configure", passenger_name, data.get_character_artwork())
	_assignment_pins.visible = not valid_names.is_empty()
	if valid_names.is_empty():
		_assignment_label.text = ""
	elif valid_names.size() == 1:
		_assignment_label.text = valid_names[0].to_upper()
	else:
		_assignment_label.text = "%d SOULS" % valid_names.size()
	_assignment_pins.pivot_offset = size * 0.5


func _get_assignment_pin_offset(index: int) -> Vector2:
	if not assignment_pin_offsets.is_empty():
		return assignment_pin_offsets[index % assignment_pin_offsets.size()]
	return Vector2(68.0 + float(index % 3) * 33.0, -42.0 + float(index / 3) * 34.0)


func play_validation(is_correct: bool) -> void:
	if is_instance_valid(_validation_tween) and _validation_tween.is_valid():
		_validation_tween.kill()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_idle_motion_enabled = false
	_drop_glow.hide()
	_assignment_pins.pivot_offset = size * 0.5
	_station_plate.pivot_offset = _station_plate.size * 0.5
	_station_label.pivot_offset = _station_label.size * 0.5
	_star.pivot_offset = _star.size * 0.5
	_validation_glow.pivot_offset = _validation_glow.size * 0.5

	_validation_tween = create_tween()
	_validation_tween.tween_property(
		_assignment_pins, ^"scale", Vector2(1.16, 1.16), pointer_pop_seconds
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_validation_tween.parallel().tween_property(
		_assignment_label, ^"scale", Vector2.ZERO, pointer_pop_seconds + pointer_shrink_seconds
	)
	_validation_tween.parallel().tween_property(
		_assignment_label, ^"modulate:a", 0.0, pointer_pop_seconds + pointer_shrink_seconds
	)
	_validation_tween.parallel().tween_property(
		_station_plate, ^"scale", Vector2.ZERO, pointer_pop_seconds + pointer_shrink_seconds
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_validation_tween.parallel().tween_property(
		_station_label, ^"scale", Vector2.ZERO, pointer_pop_seconds + pointer_shrink_seconds
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_validation_tween.tween_property(
		_assignment_pins, ^"scale", Vector2.ZERO, pointer_shrink_seconds
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_validation_tween.parallel().tween_property(
		_assignment_pins, ^"modulate:a", 0.0, pointer_shrink_seconds
	)
	await _validation_tween.finished
	validation_impact.emit(is_correct)
	if is_correct:
		await _play_success_pulse()
	else:
		await _play_failure_burst()


func reset_validation_visual() -> void:
	if is_instance_valid(_validation_tween) and _validation_tween.is_valid():
		_validation_tween.kill()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_assignment_pins.scale = Vector2.ONE
	_assignment_pins.modulate = Color.WHITE
	_assignment_label.scale = Vector2.ONE
	_assignment_label.modulate = Color.WHITE
	_station_plate.scale = Vector2.ONE
	_station_plate.modulate = Color.WHITE
	_station_label.scale = Vector2.ONE
	_station_label.modulate = Color.WHITE
	_star.scale = Vector2.ONE
	_star.rotation = 0.0
	_star.modulate = Color.WHITE
	_validation_glow.scale = Vector2.ONE
	_validation_glow.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_success_particles.emitting = false
	_failure_particles.emitting = false
	_idle_motion_enabled = true
	_set_result_light(0.0, 0.0)
	_set_drop_highlight(false)


func get_path_node_center() -> Vector2:
	var authored_anchor := get_node_or_null("PathAnchor") as Node2D
	if is_instance_valid(authored_anchor):
		return position + authored_anchor.position
	return position + path_anchor_offset


func _play_success_pulse() -> void:
	_validation_glow.modulate = Color(success_glow_color, 0.0)
	_success_particles.restart()
	_success_particles.emitting = true
	_set_result_light(0.0, 0.0)
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
	_validation_tween.parallel().tween_property(
		_star, ^"modulate", Color(1.34, 1.34, 1.34, 1.0), star_pulse_seconds
	)
	_validation_tween.parallel().tween_method(
		_set_success_result_light, 0.0, 1.0, star_pulse_seconds
	)
	_validation_tween.tween_property(
		_star, ^"scale", Vector2.ONE, star_pulse_seconds * 0.55
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_validation_tween.parallel().tween_property(
		_validation_glow, ^"scale", Vector2(1.12, 1.12), star_pulse_seconds * 0.55
	)
	await _validation_tween.finished
	_star.modulate = Color(1.55, 1.55, 1.55, 1.0)
	_set_result_light(1.0, 0.72)


func _play_failure_burst() -> void:
	_validation_glow.modulate = failure_glow_color
	_failure_particles.restart()
	_failure_particles.emitting = true
	_validation_tween = create_tween()
	_validation_tween.tween_property(
		_star, ^"scale", Vector2(1.12, 1.12), star_pulse_seconds * 0.45
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_validation_tween.parallel().tween_property(
		_star, ^"modulate", Color(1.0, 0.34, 0.38, 1.0), star_pulse_seconds * 0.45
	)
	_validation_tween.tween_property(
		_star, ^"scale", Vector2.ZERO, star_pulse_seconds * 1.2
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_validation_tween.parallel().tween_property(
		_star, ^"modulate:a", 0.0, star_pulse_seconds
	)
	_validation_tween.parallel().tween_property(
		_validation_glow, ^"scale", Vector2(1.7, 1.7), star_pulse_seconds
	)
	_validation_tween.parallel().tween_property(
		_validation_glow, ^"modulate:a", 0.0, star_pulse_seconds * 1.2
	)
	_validation_tween.tween_interval(failure_burst_seconds)
	await _validation_tween.finished


func _set_success_result_light(value: float) -> void:
	_set_result_light(value, value * 0.72)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		_set_drop_highlight(false)
		return false
	var payload: Dictionary = data
	var accepted: bool = (
		payload.get("kind", &"") == &"night_soul_card"
		and not str(payload.get("passenger_name", "")).is_empty()
	)
	_set_drop_highlight(accepted)
	return accepted


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_drop_highlight(false)
	if not data is Dictionary:
		return
	var payload: Dictionary = data
	passenger_dropped.emit(station_name, str(payload.get("passenger_name", "")))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_set_drop_highlight(false)


func _set_drop_highlight(active: bool) -> void:
	if is_instance_valid(_drop_glow):
		_drop_glow.hide()
	if _star_material != null:
		_star_material.set_shader_parameter(&"outline_strength", 1.0 if active else 0.0)


func _set_result_light(whiten: float, energy: float) -> void:
	if _star_material == null:
		return
	_star_material.set_shader_parameter(&"result_whiten", clampf(whiten, 0.0, 1.0))
	_star_material.set_shader_parameter(&"result_energy", clampf(energy, 0.0, 1.0))


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		selected.emit(station_name)
