class_name Passenger
extends Interactable
## Visual passenger shell. All identity and mystery facts live in PassengerData.

signal documents_requested(passenger: Passenger)

@export var data: PassengerData
@export_category("Passenger AI")
@export_range(50.0, 140.0, 5.0) var minimum_activity_spacing: float = 90.0
@export_range(0.0, 1.0, 0.05) var initial_seated_chance: float = 0.25
@export_range(0.0, 1.0, 0.05) var initial_idle_at_activity_chance: float = 0.35
@export_category("Interaction Copy")
@export var night_prompt_text: String = "Hear Departure Statement"
@export_category("Visual Scale")
@export_range(0.3, 1.0, 0.01) var baby_visual_scale: float = 0.68
var documents_checked: bool = false
var night_mode: bool = false
var departed: bool = false
var ai_enabled: bool = true
var runtime_carriage: int = 1
var _sway_time: float = 0.0
var _ai_timer: float = 0.0
var _ai_target_x: float = 0.0
var _ai_walking: bool = false
var _walk_phase: float = 0.0
var _rng := RandomNumberGenerator.new()
var _assigned_seat_position: Vector2
var _activity_points := PackedVector2Array()
var _carriage_ranges: Dictionary = {}
var _day_prompt_text: String = ""

const PASSENGER_WALK_SPEED: float = 92.0

@onready var _shadow: Polygon2D = %Shadow
@onready var _passenger_visual: Node2D = %PassengerVisual
@onready var _body_tint: Node2D = %BodyTint
@onready var _baby_mark: Polygon2D = %BabyMark

func _ready() -> void:
	super._ready()
	runtime_carriage = _carriage_from_world_x(position.x)
	_ai_target_x = position.x
	_rng.randomize()
	_day_prompt_text = prompt_text
	_ai_timer = _next_ai_wait()
	_update_visual()

func _process(delta: float) -> void:
	_sway_time += delta
	if ai_enabled and not night_mode and not departed and data != null:
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
	_ai_walking = false
	visible = false
	enabled = false

func set_ai_enabled(value: bool) -> void:
	ai_enabled = value and not departed and not night_mode

func configure_seat_navigation(seat_position: Vector2, activity_points: PackedVector2Array, carriage_ranges: Dictionary) -> void:
	_assigned_seat_position = seat_position
	_activity_points = activity_points.duplicate()
	_carriage_ranges = carriage_ranges.duplicate(true)
	runtime_carriage = _carriage_from_world_x(position.x)
	randomize_initial_activity()

func randomize_initial_activity() -> void:
	if data == null or departed:
		return
	_ai_walking = false
	_ai_target_x = position.x
	var candidates: PackedVector2Array = _available_activity_points(runtime_carriage)
	if candidates.is_empty() or _rng.randf() < initial_seated_chance:
		_ai_timer = _next_ai_wait()
		return
	var target: Vector2 = candidates[_rng.randi_range(0, candidates.size() - 1)]
	if _rng.randf() < initial_idle_at_activity_chance:
		position.x = target.x
		runtime_carriage = _carriage_from_world_x(position.x)
		_ai_target_x = position.x
		_ai_timer = _next_ai_wait()
		return
	_ai_target_x = target.x
	_ai_walking = not is_equal_approx(position.x, _ai_target_x)
	if not _ai_walking:
		_ai_timer = _next_ai_wait()

func get_runtime_carriage() -> int:
	return runtime_carriage

func get_ai_behavior() -> String:
	return data.ai_behavior if data != null else "still"

func get_navigation_target_x() -> float:
	return _ai_target_x if _ai_walking else position.x

func _update_day_ai(delta: float) -> void:
	if _ai_walking:
		position.x = move_toward(position.x, _ai_target_x, PASSENGER_WALK_SPEED * delta)
		_walk_phase += delta * 9.0
		runtime_carriage = _carriage_from_world_x(position.x)
		if is_equal_approx(position.x, _ai_target_x):
			_ai_walking = false
			_ai_timer = _next_ai_wait()
		return
	if data.ai_behavior == "still":
		return
	_ai_timer -= delta
	if _ai_timer <= 0.0:
		_choose_next_ai_target()

func _choose_next_ai_target() -> void:
	var carriage: int = runtime_carriage
	var target_carriage: int = carriage
	match data.ai_behavior:
		"carriage_roamer":
			var carriage_candidates: Array[int] = []
			var configured_carriages: Array[int] = _get_configured_carriages()
			var carriage_index: int = configured_carriages.find(carriage)
			if carriage_index > 0:
				carriage_candidates.append(configured_carriages[carriage_index - 1])
			if carriage_index >= 0 and carriage_index < configured_carriages.size() - 1:
				carriage_candidates.append(configured_carriages[carriage_index + 1])
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
		if not _is_navigation_target_claimed(_assigned_seat_position.x):
			candidates.append(_assigned_seat_position)
	if candidates.is_empty():
		_ai_timer = _next_ai_wait()
		return
	var target: Vector2 = candidates[_rng.randi_range(0, candidates.size() - 1)]
	_ai_target_x = target.x
	_ai_walking = true

func _available_activity_points(carriage: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in _activity_points:
		if _carriage_from_world_x(point.x) != carriage:
			continue
		if absf(point.x - position.x) < 28.0 or _is_navigation_target_claimed(point.x):
			continue
		result.append(point)
	return result

func _is_navigation_target_claimed(target_x: float) -> bool:
	var parent: Node = get_parent()
	if parent == null:
		return false
	for sibling: Node in parent.get_children():
		if sibling == self or not sibling is Passenger:
			continue
		var other := sibling as Passenger
		if other.departed or not other.visible:
			continue
		if absf(other.get_navigation_target_x() - target_x) < minimum_activity_spacing:
			return true
	return false

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

func _update_visual() -> void:
	_passenger_visual.visible = data != null and not departed
	if data == null or departed:
		return
	var is_baby: bool = data.anomaly_type == "age_mismatch"
	var ghost_alpha: float = 0.72 + sin(_sway_time * 2.2) * 0.08 if night_mode else 1.0
	var body_tint: Color = data.body_color
	body_tint.a = ghost_alpha
	_body_tint.modulate = body_tint
	_passenger_visual.scale = Vector2.ONE * baby_visual_scale if is_baby else Vector2.ONE
	_passenger_visual.position.y = (10.0 if is_baby else 0.0) + (sin(_walk_phase) * 1.8 if _ai_walking else 0.0)
	_baby_mark.visible = is_baby
	_shadow.visible = data.anomaly_type != "shadowless"
	_shadow.modulate.a = 0.52 if not night_mode else 0.28
