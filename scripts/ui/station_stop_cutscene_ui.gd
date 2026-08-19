class_name StationStopCutsceneUI
extends Control
## Letterbox and passenger staging layered over the unchanged gameplay camera.

signal sequence_finished

const STOP_DURATION: float = 6.0
const STOP_ARRIVAL_END: float = 0.35
const STOP_DEPARTURE_START: float = 4.35
const OPENING_DURATION: float = 7.1
const OPENING_DEPARTURE_START: float = 4.9

@export_category("Scene Copy")
@export var opening_heading_template: String = "%s • INITIAL BOARDING"
@export var exchange_heading_template: String = "%s • PASSENGER EXCHANGE"
@export var opening_status_template: String = "%d BOARDING     [E / SPACE / ESC] SKIP"
@export var exchange_status_template: String = "%d OFF  •  %d ON     [E / SPACE / ESC] SKIP"
@export_category("Letterbox Animation")
@export var letterbox_in_animation: StringName = &"letterbox_in"
@export var letterbox_out_animation: StringName = &"letterbox_out"
@export_category("Runtime Presentation")
@export var fallback_actor_color: Color

var _elapsed: float = 0.0
var _station_name: String = "Station"
var _departing_actors: Array[Dictionary] = []
var _boarding_actors: Array[Dictionary] = []
var _door_screen_positions: PackedVector2Array = PackedVector2Array()
var _finished: bool = false
var _opening_mode: bool = false
var _duration: float = STOP_DURATION
var _arrival_end: float = STOP_ARRIVAL_END
var _departure_start: float = STOP_DEPARTURE_START
var _letterbox_exit_started: bool = false
var _letterbox_exit_lead_time: float = 0.0

@onready var _actor_slots: Array[Node2D] = [
	%Actor0, %Actor1, %Actor2, %Actor3, %Actor4,
	%Actor5, %Actor6, %Actor7, %Actor8, %Actor9,
]
@onready var _streaks: Array[Line2D] = [%Streak0, %Streak1, %Streak2, %Streak3, %Streak4, %Streak5]
@onready var _heading_label: Label = %HeadingLabel
@onready var _status_label: Label = %StatusLabel
@onready var _letterbox_animation: AnimationPlayer = %LetterboxAnimation

func play_stop(station_name: String, departing_actors: Array[Dictionary], boarding_actors: Array[Dictionary], door_positions: PackedVector2Array = PackedVector2Array()) -> void:
	_opening_mode = false
	_duration = STOP_DURATION
	_arrival_end = STOP_ARRIVAL_END
	_departure_start = STOP_DEPARTURE_START
	_begin_sequence(station_name, departing_actors, boarding_actors, door_positions)

func play_opening(station_name: String, boarding_actors: Array[Dictionary], door_positions: PackedVector2Array = PackedVector2Array()) -> void:
	_opening_mode = true
	_duration = OPENING_DURATION
	_arrival_end = 0.0
	_departure_start = OPENING_DEPARTURE_START
	_begin_sequence(station_name, [], boarding_actors, door_positions)

func _begin_sequence(station_name: String, departing_actors: Array[Dictionary], boarding_actors: Array[Dictionary], door_positions: PackedVector2Array) -> void:
	_station_name = station_name
	_departing_actors = departing_actors.duplicate(true)
	_boarding_actors = boarding_actors.duplicate(true)
	_door_screen_positions = door_positions.duplicate()
	_elapsed = 0.0
	_finished = false
	_letterbox_exit_started = false
	_letterbox_exit_lead_time = _get_animation_duration(letterbox_out_animation)
	_update_scene_copy()
	show()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_play_letterbox_animation(letterbox_in_animation)
	_update_visuals()

func skip_sequence() -> void:
	if visible:
		_finish_sequence()

func _process(delta: float) -> void:
	_elapsed += delta
	_update_visuals()
	if not _letterbox_exit_started and _elapsed >= maxf(_duration - _letterbox_exit_lead_time, 0.0):
		_letterbox_exit_started = true
		_play_letterbox_animation(letterbox_out_animation)
	if _elapsed >= _duration:
		_finish_sequence()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _elapsed < 0.8:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
		skip_sequence()
		get_viewport().set_input_as_handled()

func _finish_sequence() -> void:
	if _finished:
		return
	_finished = true
	_letterbox_animation.stop()
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()
	sequence_finished.emit()

func _update_visuals() -> void:
	_update_exchange_actors()
	_update_departure_streaks()

func _update_scene_copy() -> void:
	_heading_label.text = opening_heading_template % _station_name.to_upper() if _opening_mode else exchange_heading_template % _station_name.to_upper()
	_status_label.text = opening_status_template % _boarding_actors.size() if _opening_mode else exchange_status_template % [_departing_actors.size(), _boarding_actors.size()]

func _play_letterbox_animation(animation_name: StringName) -> void:
	if not _letterbox_animation.has_animation(animation_name):
		push_warning("Missing cutscene animation: %s" % animation_name)
		return
	_letterbox_animation.play(animation_name)

func _get_animation_duration(animation_name: StringName) -> float:
	if not _letterbox_animation.has_animation(animation_name):
		return 0.0
	var animation: Animation = _letterbox_animation.get_animation(animation_name)
	return animation.length

func _update_exchange_actors() -> void:
	for slot: Node2D in _actor_slots:
		slot.visible = false
	for actor_index: int in range(_departing_actors.size()):
		var start_time: float = 0.55 + actor_index * 0.26
		var progress: float = clampf((_elapsed - start_time) / 1.35, 0.0, 1.0)
		if _elapsed < start_time:
			continue
		var door_position: Vector2 = _actor_door_position(actor_index)
		var side: float = -1.0 if actor_index % 2 == 0 else 1.0
		var platform_position := door_position + Vector2(46.0 * side, 128.0)
		_set_actor_slot(actor_index, _departing_actors[actor_index], door_position.lerp(platform_position, _ease_out_cubic(progress)))

	for actor_index: int in range(_boarding_actors.size()):
		var start_time: float = (0.65 + actor_index * 0.52) if _opening_mode else (2.35 + actor_index * 0.28)
		var walk_duration: float = 1.45 if _opening_mode else 1.3
		var progress: float = clampf((_elapsed - start_time) / walk_duration, 0.0, 1.0)
		if _elapsed < start_time or progress >= 1.0:
			continue
		var door_position: Vector2 = _actor_door_position(actor_index + _departing_actors.size())
		var side: float = 1.0 if actor_index % 2 == 0 else -1.0
		var platform_position := door_position + Vector2(48.0 * side, 128.0)
		_set_actor_slot(actor_index + _departing_actors.size(), _boarding_actors[actor_index], platform_position.lerp(door_position, _ease_in_cubic(progress)))

func _actor_door_position(actor_index: int) -> Vector2:
	if not _door_screen_positions.is_empty():
		return _door_screen_positions[actor_index % _door_screen_positions.size()]
	var fallback_x: float = size.x * (0.34 if actor_index % 2 == 0 else 0.66)
	return Vector2(fallback_x, size.y * 0.72)

func _set_actor_slot(slot_index: int, actor_data: Dictionary, actor_position: Vector2) -> void:
	if slot_index < 0 or slot_index >= _actor_slots.size():
		return
	var slot: Node2D = _actor_slots[slot_index]
	var tint: CanvasItem = slot.get_node("TintedVisual") as CanvasItem
	tint.modulate = actor_data.get("color", fallback_actor_color)
	slot.position = actor_position
	slot.visible = true

func _update_departure_streaks() -> void:
	for streak: Line2D in _streaks:
		streak.visible = _elapsed > _departure_start
	if _elapsed <= _departure_start:
		return
	var progress: float = clampf((_elapsed - _departure_start) / maxf(_duration - _departure_start, 0.01), 0.0, 1.0)
	var alpha: float = sin(progress * PI) * 0.18
	for line_index: int in range(_streaks.size()):
		var streak: Line2D = _streaks[line_index]
		streak.position.x = fmod(_elapsed * 410.0 + line_index * 173.0, size.x + 260.0) - 260.0
		streak.modulate.a = alpha

func _ease_out_cubic(value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped, 3.0)

func _ease_in_cubic(value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	return clamped * clamped * clamped
