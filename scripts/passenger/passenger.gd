class_name Passenger
extends Interactable
## Visual passenger shell. All identity and mystery facts live in PassengerData.

signal documents_requested(passenger: Passenger)

@export var data: PassengerData
@export_category("Passenger AI")
@export_range(50.0, 140.0, 5.0) var minimum_activity_spacing: float = 90.0
@export_range(0.0, 1.0, 0.05) var initial_seated_chance: float = 0.25
@export_range(0.0, 1.0, 0.05) var initial_idle_at_activity_chance: float = 0.35
@export_range(0, 6, 1) var minimum_roaming_source_population: int = 2
@export_range(1, 8, 1) var maximum_roaming_target_population: int = 3
@export_category("Interaction Copy")
@export var night_prompt_text: String = "Hear Departure Statement"
@export_category("Visual Scale")
@export var uses_authored_character_artwork: bool = false
var documents_checked: bool = false
var night_mode: bool = false
var departed: bool = false
var ai_enabled: bool = true
var runtime_carriage: int = 1
var boarding_staged: bool = false
var _sway_time: float = 0.0
var _ai_timer: float = 0.0
var _ai_target_position: Vector2
var _ai_walking: bool = false
var _boarding_handoff_active: bool = false
var _walk_phase: float = 0.0
var _inspection_paused: bool = false
var _inspection_resume_walking: bool = false
var _cross_carriage_roaming_enabled: bool = true
var _rng := RandomNumberGenerator.new()
var _assigned_seat_position: Vector2
var _activity_points := PackedVector2Array()
var _carriage_ranges: Dictionary = {}
var _day_prompt_text: String = ""

const PASSENGER_WALK_SPEED: float = 92.0

@onready var _shadow: Polygon2D = %Shadow
@onready var _passenger_visual: Node2D = %PassengerVisual
@onready var _body_tint: Node2D = %BodyTint

func _ready() -> void:
	super._ready()
	runtime_carriage = _carriage_from_world_x(position.x)
	_ai_target_position = position
	_rng.randomize()
	_day_prompt_text = prompt_text
	_ai_timer = _next_ai_wait()
	_update_visual()

func _process(delta: float) -> void:
	_sway_time += delta
	if _boarding_handoff_active and not night_mode and not departed and data != null:
		_update_boarding_handoff(delta)
	elif ai_enabled and not night_mode and not departed and data != null:
		_update_day_ai(delta)
	_update_visual()

func interact() -> void:
	if data == null or departed:
		return
	documents_checked = true
	documents_requested.emit(self)

func set_night_mode(value: bool) -> void:
	night_mode = value
	ai_enabled = not value
	prompt_text = night_prompt_text if value and data != null and data.is_dead else _day_prompt_text
	if data != null and not data.is_dead:
		visible = not value
	_update_visual()

func depart_train() -> void:
	departed = true
	boarding_staged = false
	_inspection_paused = false
	_ai_walking = false
	_boarding_handoff_active = false
	visible = false
	enabled = false

func set_ai_enabled(value: bool) -> void:
	ai_enabled = value and not departed and not night_mode and not boarding_staged and not _inspection_paused


func set_cross_carriage_roaming_enabled(value: bool) -> void:
	_cross_carriage_roaming_enabled = value
	if (
		not value
		and _ai_walking
		and _carriage_from_world_x(_ai_target_position.x) != runtime_carriage
	):
		_ai_target_position = position
		_ai_walking = false
		_ai_timer = _next_ai_wait()

func configure_seat_navigation(seat_position: Vector2, activity_points: PackedVector2Array, carriage_ranges: Dictionary) -> void:
	_assigned_seat_position = seat_position
	_activity_points = activity_points.duplicate()
	_carriage_ranges = carriage_ranges.duplicate(true)
	runtime_carriage = _carriage_from_world_x(position.x)

func stage_boarding(boarding_position: Vector2) -> void:
	if departed:
		return
	boarding_staged = true
	ai_enabled = false
	_ai_walking = false
	_boarding_handoff_active = false
	position = boarding_position
	_ai_target_position = boarding_position
	runtime_carriage = _carriage_from_world_x(position.x)
	visible = false
	enabled = false

func finish_boarding() -> void:
	if departed or not boarding_staged:
		return
	boarding_staged = false
	visible = true
	enabled = true
	randomize_initial_activity()
	_boarding_handoff_active = _ai_walking

func finish_boarding_at(boarding_position: Vector2) -> void:
	if departed or not boarding_staged:
		return
	position = boarding_position
	runtime_carriage = _carriage_from_world_x(position.x)
	finish_boarding()

func set_inspection_paused(value: bool) -> void:
	if departed or _inspection_paused == value:
		return
	_inspection_paused = value
	if value:
		_inspection_resume_walking = _ai_walking
		_ai_walking = false
		ai_enabled = false
	else:
		_ai_walking = _inspection_resume_walking and position.distance_to(_ai_target_position) > 1.0
		_inspection_resume_walking = false
		if not _ai_walking:
			_ai_timer = maxf(_ai_timer, 0.25)

func randomize_initial_activity() -> void:
	if data == null or departed:
		return
	_ai_walking = false
	_ai_target_position = position
	var candidates: PackedVector2Array = _available_activity_points(runtime_carriage)
	var target: Vector2 = _assigned_seat_position
	if not candidates.is_empty() and _rng.randf() >= initial_seated_chance:
		target = (
			_find_closest_activity_point(candidates)
			if _rng.randf() < initial_idle_at_activity_chance
			else candidates[_rng.randi_range(0, candidates.size() - 1)]
		)
	_ai_target_position = target
	_ai_walking = position.distance_to(_ai_target_position) > 1.0
	if not _ai_walking:
		_ai_timer = _next_ai_wait()

func get_runtime_carriage() -> int:
	return runtime_carriage

func get_ai_behavior() -> String:
	return data.ai_behavior if data != null else "still"

func get_navigation_target_position() -> Vector2:
	return _ai_target_position if _ai_walking else position

func get_reserved_seat_position() -> Vector2:
	return _assigned_seat_position

func _update_day_ai(delta: float) -> void:
	if _ai_walking:
		position = position.move_toward(_ai_target_position, PASSENGER_WALK_SPEED * delta)
		_walk_phase += delta * 9.0
		runtime_carriage = _carriage_from_world_x(position.x)
		if position.distance_to(_ai_target_position) <= 1.0:
			position = _ai_target_position
			_ai_walking = false
			_ai_timer = _next_ai_wait()
		return
	if data.ai_behavior == "still":
		return
	_ai_timer -= delta
	if _ai_timer <= 0.0:
		_choose_next_ai_target()

func _update_boarding_handoff(delta: float) -> void:
	if not _ai_walking:
		_boarding_handoff_active = false
		return
	position = position.move_toward(_ai_target_position, PASSENGER_WALK_SPEED * delta)
	_walk_phase += delta * 9.0
	runtime_carriage = _carriage_from_world_x(position.x)
	if position.distance_to(_ai_target_position) <= 1.0:
		position = _ai_target_position
		_ai_walking = false
		_boarding_handoff_active = false
		_ai_timer = _next_ai_wait()

func _choose_next_ai_target() -> void:
	var carriage: int = runtime_carriage
	var target_carriage: int = carriage
	match data.ai_behavior:
		"carriage_roamer":
			var carriage_candidates: Array[int] = []
			if _cross_carriage_roaming_enabled:
				var configured_carriages: Array[int] = _get_configured_carriages()
				var carriage_index: int = configured_carriages.find(carriage)
				if carriage_index > 0:
					var previous_carriage: int = configured_carriages[carriage_index - 1]
					if _can_roam_to_carriage(carriage, previous_carriage):
						carriage_candidates.append(previous_carriage)
				if carriage_index >= 0 and carriage_index < configured_carriages.size() - 1:
					var next_carriage: int = configured_carriages[carriage_index + 1]
					if _can_roam_to_carriage(carriage, next_carriage):
						carriage_candidates.append(next_carriage)
			if not carriage_candidates.is_empty():
				target_carriage = carriage_candidates[_rng.randi_range(0, carriage_candidates.size() - 1)]
		"wander", "window_watcher", "restless":
			pass
		_:
			_ai_timer = _next_ai_wait()
			return

	var candidates: PackedVector2Array = _available_activity_points(target_carriage)
	var assigned_carriage: int = _carriage_from_world_x(_assigned_seat_position.x)
	if target_carriage == carriage and assigned_carriage == carriage and absf(position.x - _assigned_seat_position.x) > 28.0 and _rng.randf() < 0.25:
		if not _is_navigation_target_claimed(_assigned_seat_position):
			candidates.append(_assigned_seat_position)
	if candidates.is_empty():
		_ai_timer = _next_ai_wait()
		return
	var target: Vector2 = candidates[_rng.randi_range(0, candidates.size() - 1)]
	_ai_target_position = target
	_ai_walking = true

func _available_activity_points(carriage: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in _activity_points:
		if _carriage_from_world_x(point.x) != carriage:
			continue
		if point.distance_to(position) < 28.0 or _is_navigation_target_claimed(point):
			continue
		result.append(point)
	return result

func _is_navigation_target_claimed(target_position: Vector2) -> bool:
	var parent: Node = get_parent()
	if parent == null:
		return false
	for sibling: Node in parent.get_children():
		if sibling == self or not sibling is Passenger:
			continue
		var other := sibling as Passenger
		if other.departed:
			continue
		if other.get_reserved_seat_position().distance_to(target_position) < minimum_activity_spacing:
			return true
		if other.visible:
			# Reserve both ends of an NPC's walk. Looking only at its destination
			# allowed another NPC to choose the position it was still occupying.
			if other.position.distance_to(target_position) < minimum_activity_spacing:
				return true
			if other.get_navigation_target_position().distance_to(target_position) < minimum_activity_spacing:
				return true
	return false

func _find_closest_activity_point(candidates: PackedVector2Array) -> Vector2:
	var closest: Vector2 = candidates[0]
	var closest_distance: float = position.distance_squared_to(closest)
	for point: Vector2 in candidates:
		var distance: float = position.distance_squared_to(point)
		if distance < closest_distance:
			closest = point
			closest_distance = distance
	return closest

func _next_ai_wait() -> float:
	if data == null or data.ai_behavior == "still":
		return 999999.0
	return maxf(3.0, data.ai_interval_seconds + _rng.randf_range(-1.5, 1.5))

func _carriage_from_world_x(world_x: float) -> int:
	var fallback_carriage: int = data.current_carriage if data != null else 1
	var nearest_carriage: int = fallback_carriage
	var nearest_distance: float = INF
	for carriage_key: Variant in _carriage_ranges:
		var carriage_number: int = int(carriage_key)
		var carriage_range: Vector2 = _carriage_ranges[carriage_key]
		if world_x >= carriage_range.x and world_x <= carriage_range.y:
			return carriage_number
		var distance: float = absf(world_x - clampf(world_x, carriage_range.x, carriage_range.y))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_carriage = carriage_number
	return nearest_carriage

func _get_configured_carriages() -> Array[int]:
	var result: Array[int] = []
	for carriage_key: Variant in _carriage_ranges:
		result.append(int(carriage_key))
	result.sort()
	if result.is_empty():
		result.append(runtime_carriage)
	return result


func _can_roam_to_carriage(source_carriage: int, target_carriage: int) -> bool:
	if source_carriage == target_carriage:
		return true
	var parent: Node = get_parent()
	if parent == null:
		return false
	var source_population: int = 0
	var target_population: int = 0
	for sibling: Node in parent.get_children():
		if not sibling is Passenger:
			continue
		var other := sibling as Passenger
		if other.departed or not other.visible:
			continue
		var planned_carriage: int = other.get_runtime_carriage()
		if other._ai_walking:
			planned_carriage = other._carriage_from_world_x(other.get_navigation_target_position().x)
		if planned_carriage == source_carriage:
			source_population += 1
		if planned_carriage == target_carriage:
			target_population += 1
	return (
		source_population > minimum_roaming_source_population
		and target_population < maximum_roaming_target_population
	)

func _update_visual() -> void:
	_passenger_visual.visible = data != null and not departed
	if data == null or departed:
		return
	var ghost_alpha: float = 0.72 + sin(_sway_time * 2.2) * 0.08 if night_mode else 1.0
	var body_tint: Color = data.body_color
	body_tint.a = ghost_alpha
	_body_tint.modulate = body_tint if not uses_authored_character_artwork else Color.WHITE
	_passenger_visual.modulate = Color(1.0, 1.0, 1.0, ghost_alpha) if uses_authored_character_artwork else Color.WHITE
	_passenger_visual.scale = Vector2.ONE
	_passenger_visual.position.y = sin(_walk_phase) * 1.8 if _ai_walking else 0.0
	_shadow.visible = data.anomaly_type != "shadowless"
	_shadow.modulate.a = 0.52 if not night_mode else 0.28
