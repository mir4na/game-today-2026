class_name TrainWorld
extends Node2D

signal exterior_fade_out_finished

var _scroll: float = 0.0
var _night_strength: float = 0.0
var _day_cycle_progress: float = 0.0
var _sway_time: float = 0.0
var _motion_strength: float = 1.0
var _carriages: Array[CarriageVisual] = []

@onready var _cars: Node2D = %Cars
@onready var _exterior_sequence: TrainExteriorBody = %ExteriorSequence

func _ready() -> void:
	for child: Node in _cars.get_children():
		if child is CarriageVisual:
			_carriages.append(child as CarriageVisual)
	_carriages.sort_custom(func(left: CarriageVisual, right: CarriageVisual) -> bool: return left.position.x < right.position.x)
	_exterior_sequence.doors_open_changed.connect(_on_exterior_doors_open_changed)
	_exterior_sequence.fade_out_finished.connect(_on_exterior_fade_out_finished)
	_exterior_sequence.hide()

func _process(delta: float) -> void:
	_sway_time += delta * _motion_strength
	_scroll = fmod(_scroll + delta * lerpf(95.0, 48.0, _night_strength) * _motion_strength, 10000.0)
	for carriage: CarriageVisual in _carriages:
		carriage.set_environment(_scroll, _night_strength, _day_cycle_progress, _sway_time)
		if _exterior_sequence.visible:
			carriage.set_exterior_transition(
				_exterior_sequence.modulate.a,
				_exterior_sequence.position.y,
				_exterior_sequence.wipe_progress
			)

func set_night_strength(value: float) -> void:
	_night_strength = clampf(value, 0.0, 1.0)

func set_day_cycle_progress(value: float) -> void:
	_day_cycle_progress = clampf(value, 0.0, 1.0)

func set_motion_strength(value: float) -> void:
	_motion_strength = clampf(value, 0.0, 1.0)
	for carriage: CarriageVisual in _carriages:
		carriage.set_motion_strength(_motion_strength)

func show_exterior_body(duration: float, arrival_end: float, departure_start: float) -> void:
	for carriage: CarriageVisual in _carriages:
		carriage.begin_exterior_mode()
	_exterior_sequence.begin_sequence(duration, arrival_end, departure_start)

func hide_exterior_body() -> void:
	_exterior_sequence.end_sequence()
	for carriage: CarriageVisual in _carriages:
		carriage.end_exterior_mode()

func set_exterior_sequence_elapsed(value: float) -> void:
	_exterior_sequence.set_sequence_elapsed(value)

func ensure_exterior_fade_out_started() -> void:
	_exterior_sequence.ensure_fade_out_started()

func is_exterior_fade_out_complete() -> bool:
	return _exterior_sequence.is_fade_out_complete()

func is_exterior_body_visible() -> bool:
	return _exterior_sequence.visible

func _on_exterior_doors_open_changed(is_open: bool) -> void:
	for carriage: CarriageVisual in _carriages:
		carriage.set_exterior_doors_open(is_open)

func _on_exterior_fade_out_finished() -> void:
	exterior_fade_out_finished.emit()

func get_passenger_seat_slots(carriage_number: int) -> Array[Marker2D]:
	for carriage: CarriageVisual in _carriages:
		if carriage.carriage_type == "passenger" and carriage.carriage_number == carriage_number:
			return carriage.get_passenger_seat_slots()
	return []

func get_all_passenger_activity_slots() -> Array[Marker2D]:
	var result: Array[Marker2D] = []
	for carriage: CarriageVisual in _carriages:
		if carriage.carriage_type == "passenger":
			result.append_array(carriage.get_passenger_activity_slots())
	return result

func get_passenger_door_markers() -> Dictionary:
	var result: Dictionary = {}
	for carriage: CarriageVisual in _carriages:
		if carriage.carriage_type != "passenger":
			continue
		var markers: Array[Marker2D] = carriage.get_passenger_door_slots()
		if not markers.is_empty():
			result[carriage.carriage_number] = markers
	return result

func get_passenger_carriage_world_ranges() -> Dictionary:
	var result: Dictionary = {}
	for carriage: CarriageVisual in _carriages:
		if carriage.carriage_type != "passenger":
			continue
		var start_x: float = carriage.global_position.x
		result[carriage.carriage_number] = Vector2(start_x, start_x + carriage.carriage_width)
	return result

func get_right_edge_world_x() -> float:
	var right_edge: float = global_position.x
	for carriage: CarriageVisual in _carriages:
		right_edge = maxf(right_edge, carriage.global_position.x + carriage.carriage_width)
	return right_edge


func get_passenger_carriage_number_at_world_x(world_x: float) -> int:
	var local_x: float = to_local(Vector2(world_x, global_position.y)).x
	for carriage: CarriageVisual in _carriages:
		if carriage.carriage_type != "passenger":
			continue
		if local_x >= carriage.position.x and local_x <= carriage.position.x + carriage.carriage_width:
			return carriage.carriage_number
	return 0


func show_radar_anomaly_glow(carriage_number: int, duration: float) -> void:
	for carriage: CarriageVisual in _carriages:
		if carriage.carriage_type == "passenger" and carriage.carriage_number == carriage_number:
			carriage.show_radar_anomaly_glow(duration)
			return


func can_play_radar_scan(carriage_number: int) -> bool:
	for carriage: CarriageVisual in _carriages:
		if carriage.carriage_type == "passenger" and carriage.carriage_number == carriage_number:
			return carriage.has_radar_scan_effect()
	return false


func play_radar_scan(carriage_number: int, world_origin: Vector2, duration: float) -> void:
	for carriage: CarriageVisual in _carriages:
		if carriage.carriage_type == "passenger" and carriage.carriage_number == carriage_number:
			await carriage.play_radar_scan(world_origin, duration)
			return

func get_carriage_index_at_world_x(world_x: float) -> int:
	if _carriages.is_empty():
		return 0
	var local_x: float = to_local(Vector2(world_x, global_position.y)).x
	var nearest_index: int = 0
	var nearest_distance: float = INF
	for carriage_index: int in range(_carriages.size()):
		var carriage: CarriageVisual = _carriages[carriage_index]
		var start_x: float = carriage.position.x
		var end_x: float = start_x + carriage.carriage_width
		if local_x >= start_x and local_x <= end_x:
			return carriage_index
		var distance: float = absf(local_x - clampf(local_x, start_x, end_x))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = carriage_index
	return nearest_index
