class_name TrainWorld
extends Node2D

signal exterior_fade_out_finished
signal station_travel_offset_changed(offset: Vector2)

@export_category("Station Arrival & Departure")
@export_range(2500.0, 6000.0, 50.0) var station_arrival_distance: float = 4400.0
@export_range(2500.0, 6000.0, 50.0) var station_departure_distance: float = 4400.0

var _scroll: float = 0.0
var _night_strength: float = 0.0
var _day_cycle_progress: float = 0.0
var _sway_time: float = 0.0
var _motion_strength: float = 1.0
var _carriages: Array[CarriageVisual] = []
var _cars_station_rest_position: Vector2
var _station_arrival_progress: float = 1.0
var _station_departure_progress: float = 0.0

@onready var _cars: Node2D = %Cars
@onready var _exterior_sequence: TrainExteriorBody = %ExteriorSequence

func _ready() -> void:
	_cars_station_rest_position = _cars.position
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


func set_blocked_connector_effect(observer_world_x: float, connector_world_x: float, immediate: bool = false) -> void:
	var observer_is_left: bool = observer_world_x < connector_world_x
	for carriage: CarriageVisual in _carriages:
		if carriage.carriage_type != "passenger":
			continue
		var carriage_center_x: float = carriage.global_position.x + carriage.carriage_width * 0.5
		var carriage_is_left: bool = carriage_center_x < connector_world_x
		carriage.set_blocked_by_aisle(carriage_is_left != observer_is_left, immediate)


func clear_blocked_connector_effect(immediate: bool = false) -> void:
	for carriage: CarriageVisual in _carriages:
		if carriage.carriage_type == "passenger":
			carriage.set_blocked_by_aisle(false, immediate)

func show_exterior_body(duration: float, arrival_end: float, departure_start: float) -> void:
	_station_arrival_progress = 0.0
	_station_departure_progress = 0.0
	_apply_station_travel_position()
	for carriage: CarriageVisual in _carriages:
		carriage.begin_exterior_mode()
	_exterior_sequence.begin_sequence(duration, arrival_end, departure_start)

func hide_exterior_body() -> void:
	_exterior_sequence.end_sequence()
	_station_arrival_progress = 1.0
	_station_departure_progress = 0.0
	_apply_station_travel_position()
	for carriage: CarriageVisual in _carriages:
		carriage.end_exterior_mode()

func set_station_arrival_progress(value: float) -> void:
	_station_arrival_progress = clampf(value, 0.0, 1.0)
	_apply_station_travel_position()

func set_station_departure_progress(value: float) -> void:
	_station_departure_progress = clampf(value, 0.0, 1.0)
	_apply_station_travel_position()

func _apply_station_travel_position() -> void:
	var arrival_offset: float = station_arrival_distance * (1.0 - _station_arrival_progress)
	var departure_offset: float = -station_departure_distance * _station_departure_progress
	var travel_offset := Vector2(arrival_offset + departure_offset, 0.0)
	_cars.position = _cars_station_rest_position + travel_offset
	station_travel_offset_changed.emit(travel_offset)

func is_station_departure_complete() -> bool:
	return _station_departure_progress >= 0.999

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


func get_passenger_door_station_rest_positions() -> Dictionary:
	# Door markers move together with Cars while the train enters the station.
	# Return their eventual stopped world positions so waiting passengers can
	# already stand on the stationary platform before the train arrives.
	var result: Dictionary = {}
	var rest_origin: Vector2 = _cars.get_parent().to_global(_cars_station_rest_position)
	var travel_offset: Vector2 = rest_origin - _cars.global_position
	for carriage: CarriageVisual in _carriages:
		if carriage.carriage_type != "passenger":
			continue
		var positions: Array[Vector2] = []
		for marker: Marker2D in carriage.get_passenger_door_slots():
			positions.append(marker.global_position + travel_offset)
		if not positions.is_empty():
			result[carriage.carriage_number] = positions
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


func can_play_radar_scan(carriage_number: int) -> bool:
	for carriage: CarriageVisual in _carriages:
		if carriage.carriage_type == "passenger" and carriage.carriage_number == carriage_number:
			return carriage.has_radar_scan_effect()
	return false


func play_radar_scan(carriage_number: int, duration: float, origin_world_position: Vector2) -> void:
	for carriage: CarriageVisual in _carriages:
		if carriage.carriage_type == "passenger" and carriage.carriage_number == carriage_number:
			carriage.play_radar_scan(duration, origin_world_position)
			return


func show_radar_anomaly_signal(carriage_number: int, duration: float) -> void:
	for carriage: CarriageVisual in _carriages:
		if carriage.carriage_type == "passenger" and carriage.carriage_number == carriage_number:
			carriage.show_radar_anomaly_signal(duration)
			return


func clear_radar_anomaly_signals(immediate: bool = false) -> void:
	for carriage: CarriageVisual in _carriages:
		if carriage.carriage_type == "passenger":
			carriage.clear_radar_anomaly_signal(immediate)


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


func get_nearest_carriage_number_at_world_x(world_x: float) -> int:
	if _carriages.is_empty():
		return 0
	var carriage_index: int = get_carriage_index_at_world_x(world_x)
	return _carriages[carriage_index].carriage_number
