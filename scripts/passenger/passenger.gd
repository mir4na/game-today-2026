class_name Passenger
extends Interactable
## Visual passenger shell. All identity and mystery facts live in PassengerData.

signal inspection_requested(passenger: Passenger)

@export var data: PassengerData
@export var use_placeholder_art: bool = true
var inspected: bool = false
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

const CARRIAGE_BASE_X: Dictionary = {
	1: 3840.0,
	2: 2880.0,
	3: 1920.0,
	4: 960.0,
}
const PASSENGER_WALK_SPEED: float = 92.0

@onready var _shadow: Polygon2D = %Shadow
@onready var _placeholder_visual: Node2D = %PlaceholderVisual
@onready var _body_tint: Node2D = %BodyTint
@onready var _baby_mark: Polygon2D = %BabyMark
@onready var _animated_sprite: AnimatedSprite2D = %AnimatedSprite2D

func _ready() -> void:
	runtime_carriage = _carriage_from_world_x(position.x)
	_ai_target_x = position.x
	_rng.seed = absi(hash(data.passenger_name)) if data != null else 1
	_ai_timer = 2.5 if data != null and not data.initially_on_train else _next_ai_wait()
	_update_visual()

func _process(delta: float) -> void:
	_sway_time += delta
	if ai_enabled and not night_mode and not departed and data != null:
		_update_day_ai(delta)
	_update_visual()

func interact() -> void:
	if data == null or departed:
		return
	inspected = true
	inspection_requested.emit(self)

func set_night_mode(value: bool) -> void:
	night_mode = value
	ai_enabled = not value
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

func get_runtime_carriage() -> int:
	return runtime_carriage

func get_ai_behavior() -> String:
	return data.ai_behavior if data != null else "still"

func _update_day_ai(delta: float) -> void:
	if data.ai_behavior == "still":
		return
	if _ai_walking:
		position.x = move_toward(position.x, _ai_target_x, PASSENGER_WALK_SPEED * delta)
		_walk_phase += delta * 9.0
		runtime_carriage = _carriage_from_world_x(position.x)
		if is_equal_approx(position.x, _ai_target_x):
			_ai_walking = false
			_ai_timer = _next_ai_wait()
		return
	_ai_timer -= delta
	if _ai_timer <= 0.0:
		_choose_next_ai_target()

func _choose_next_ai_target() -> void:
	var carriage: int = runtime_carriage
	var base_x: float = float(CARRIAGE_BASE_X.get(carriage, 3840.0))
	match data.ai_behavior:
		"wander":
			_ai_target_x = base_x + _rng.randf_range(145.0, 815.0)
		"carriage_roamer":
			var candidates: Array[int] = []
			if carriage > 1:
				candidates.append(carriage - 1)
			if carriage < 4:
				candidates.append(carriage + 1)
			var destination_carriage: int = candidates[_rng.randi_range(0, candidates.size() - 1)]
			_ai_target_x = float(CARRIAGE_BASE_X[destination_carriage]) + _rng.randf_range(230.0, 730.0)
		"window_watcher":
			var window_positions: Array[float] = [235.0, 480.0, 725.0]
			_ai_target_x = base_x + window_positions[_rng.randi_range(0, window_positions.size() - 1)]
		"restless":
			_ai_target_x = clampf(position.x + _rng.randf_range(-125.0, 125.0), base_x + 145.0, base_x + 815.0)
		_:
			_ai_timer = _next_ai_wait()
			return
	if absf(_ai_target_x - position.x) < 28.0:
		_ai_target_x = clampf(_ai_target_x + 85.0, base_x + 145.0, base_x + 815.0)
	_ai_walking = true

func _next_ai_wait() -> float:
	if data == null or data.ai_behavior == "still":
		return 999999.0
	return maxf(3.0, data.ai_interval_seconds + _rng.randf_range(-1.5, 1.5))

func _carriage_from_world_x(world_x: float) -> int:
	var horizontal_segment: int = clampi(int(floor(world_x / 960.0)), 1, 4)
	return clampi(5 - horizontal_segment, 1, 4)

func _update_visual() -> void:
	_placeholder_visual.visible = data != null and not departed and use_placeholder_art
	_animated_sprite.visible = data != null and not departed and not use_placeholder_art
	if data == null or departed:
		return
	var is_baby: bool = data.anomaly_type == "age_mismatch"
	var ghost_alpha: float = 0.72 + sin(_sway_time * 2.2) * 0.08 if night_mode else 1.0
	var body_tint: Color = data.body_color
	body_tint.a = ghost_alpha
	_body_tint.modulate = body_tint
	_placeholder_visual.scale = Vector2(0.78, 0.62) if is_baby else Vector2.ONE
	_placeholder_visual.position.y = (10.0 if is_baby else 0.0) + (sin(_walk_phase) * 1.8 if _ai_walking else 0.0)
	_baby_mark.visible = is_baby
	_shadow.visible = data.anomaly_type != "shadowless"
	_shadow.modulate.a = 0.52 if not night_mode else 0.28
