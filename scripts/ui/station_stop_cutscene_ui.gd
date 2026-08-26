class_name StationStopCutsceneUI
extends Control
## Letterbox and passenger staging layered over the unchanged gameplay camera.

signal sequence_finished
signal sequence_timeline_changed(elapsed: float)
signal camera_return_started
signal boarding_actor_entered(actor_index: int, door_screen_position: Vector2)

@export_category("Scene Copy")
@export var opening_heading_template: String = "%s • INITIAL BOARDING"
@export var exchange_heading_template: String = "%s • PASSENGER EXCHANGE"
@export var opening_subtitle_text: String = "INITIAL BOARDING"
@export var exchange_subtitle_text: String = "PASSENGER EXCHANGE"
@export var opening_status_template: String = "%d BOARDING     [E / SPACE / ESC] SKIP"
@export var exchange_status_template: String = "%d OFF  •  %d ON     [E / SPACE / ESC] SKIP"
@export_category("Letterbox Animation")
@export var letterbox_in_animation: StringName = &"letterbox_in"
@export var letterbox_out_animation: StringName = &"letterbox_out"
@export var title_reveal_animation: StringName = &"title_reveal"
@export_category("Runtime Presentation")
@export_range(0.25, 1.5, 0.05) var camera_return_lead_time: float = 0.75
@export_range(80.0, 220.0, 1.0) var platform_vertical_offset: float = 138.0
@export_range(20.0, 100.0, 1.0) var platform_horizontal_offset: float = 52.0
@export_range(0.0, 160.0, 1.0) var door_visibility_margin: float = 48.0
@export_category("Passenger Timing")
@export_range(4.0, 12.0, 0.05) var stop_duration: float = 6.55
@export_range(0.0, 2.0, 0.05) var stop_arrival_end: float = 0.35
@export_range(2.0, 8.0, 0.05) var stop_departure_start: float = 4.35
@export_range(4.0, 12.0, 0.05) var opening_duration: float = 7.1
@export_range(2.0, 8.0, 0.05) var opening_departure_start: float = 4.9
@export_range(0.0, 3.0, 0.05) var departing_start_time: float = 0.55
@export_range(0.05, 0.5, 0.01) var departing_stagger: float = 0.26
@export_range(0.5, 2.0, 0.05) var departing_walk_duration: float = 1.35
@export_range(0.0, 3.0, 0.05) var opening_boarding_start_time: float = 0.65
@export_range(0.05, 0.5, 0.01) var opening_boarding_stagger: float = 0.28
@export_range(0.5, 2.0, 0.05) var opening_boarding_walk_duration: float = 1.45
@export_range(0.0, 3.0, 0.05) var exchange_boarding_start_time: float = 2.15
@export_range(0.05, 0.5, 0.01) var exchange_boarding_stagger: float = 0.1
@export_range(0.5, 2.0, 0.05) var exchange_boarding_walk_duration: float = 1.2

var _elapsed: float = 0.0
var _station_name: String = "Station"
var _departing_actors: Array[Dictionary] = []
var _boarding_actors: Array[Dictionary] = []
var _door_markers: Dictionary = {}
var _finished: bool = false
var _opening_mode: bool = false
var _duration: float = 6.55
var _arrival_end: float = 0.35
var _departure_start: float = 4.35
var _letterbox_exit_started: bool = false
var _letterbox_exit_lead_time: float = 0.0
var _camera_return_started: bool = false
var _entered_boarding_actor_indices: Dictionary = {}

@onready var _actor_slots: Array[Node2D] = [
	%Actor0, %Actor1, %Actor2, %Actor3, %Actor4,
	%Actor5, %Actor6, %Actor7, %Actor8, %Actor9,
	%Actor10, %Actor11, %Actor12, %Actor13, %Actor14,
	%Actor15, %Actor16, %Actor17, %Actor18, %Actor19,
]
@onready var _streaks: Array[Line2D] = [%Streak0, %Streak1, %Streak2, %Streak3, %Streak4, %Streak5]
@onready var _heading_label: Label = %HeadingLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _status_label: Label = %StatusLabel
@onready var _letterbox_animation: AnimationPlayer = %LetterboxAnimation
@onready var _cinematic_title_animation: AnimationPlayer = %CinematicTitleAnimation

func play_stop(station_name: String, departing_actors: Array[Dictionary], boarding_actors: Array[Dictionary], door_markers: Dictionary = {}) -> void:
	_opening_mode = false
	_duration = stop_duration
	_arrival_end = stop_arrival_end
	_departure_start = stop_departure_start
	_begin_sequence(station_name, departing_actors, boarding_actors, door_markers)

func play_opening(station_name: String, boarding_actors: Array[Dictionary], door_markers: Dictionary = {}) -> void:
	_opening_mode = true
	_duration = opening_duration
	_arrival_end = 0.0
	_departure_start = opening_departure_start
	_begin_sequence(station_name, [], boarding_actors, door_markers)

func get_stop_timeline() -> Vector3:
	return Vector3(stop_duration, stop_arrival_end, stop_departure_start)

func get_opening_timeline() -> Vector3:
	return Vector3(opening_duration, 0.0, opening_departure_start)

func _begin_sequence(station_name: String, departing_actors: Array[Dictionary], boarding_actors: Array[Dictionary], door_markers: Dictionary) -> void:
	_station_name = station_name
	_departing_actors = departing_actors.duplicate(true)
	_boarding_actors = boarding_actors.duplicate(true)
	_door_markers = door_markers.duplicate()
	_elapsed = 0.0
	_finished = false
	_letterbox_exit_started = false
	_camera_return_started = false
	_entered_boarding_actor_indices.clear()
	_letterbox_exit_lead_time = _get_animation_duration(letterbox_out_animation)
	_update_scene_copy()
	show()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_play_letterbox_animation(letterbox_in_animation)
	_play_cinematic_title_animation()
	_update_visuals()
	sequence_timeline_changed.emit(_elapsed)

func skip_sequence() -> void:
	if not visible or _camera_return_started:
		return
	_elapsed = maxf(_elapsed, _duration - camera_return_lead_time)
	_start_camera_return_if_needed()
	sequence_timeline_changed.emit(_elapsed)
	_update_visuals()

func _process(delta: float) -> void:
	_elapsed = minf(_elapsed + delta, _duration)
	_start_camera_return_if_needed()
	sequence_timeline_changed.emit(_elapsed)
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
	for actor_index: int in range(_boarding_actors.size()):
		var door_position: Vector2 = _actor_door_position(_boarding_actors[actor_index], actor_index + _departing_actors.size())
		_emit_boarding_actor_entered(actor_index, door_position)
	_start_camera_return_if_needed(true)
	_letterbox_animation.stop()
	_cinematic_title_animation.stop()
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()
	sequence_finished.emit()

func _start_camera_return_if_needed(force: bool = false) -> void:
	if _camera_return_started:
		return
	if not force and _elapsed < _duration - camera_return_lead_time:
		return
	_camera_return_started = true
	camera_return_started.emit()

func _update_visuals() -> void:
	_update_exchange_actors()
	_update_departure_streaks()

func _update_scene_copy() -> void:
	_heading_label.text = opening_heading_template % _station_name.to_upper() if _opening_mode else exchange_heading_template % _station_name.to_upper()
	_subtitle_label.text = opening_subtitle_text if _opening_mode else exchange_subtitle_text
	_status_label.text = opening_status_template % _boarding_actors.size() if _opening_mode else exchange_status_template % [_departing_actors.size(), _boarding_actors.size()]

func _play_letterbox_animation(animation_name: StringName) -> void:
	if not _letterbox_animation.has_animation(animation_name):
		push_warning("Missing cutscene animation: %s" % animation_name)
		return
	_letterbox_animation.play(animation_name)

func _play_cinematic_title_animation() -> void:
	if not _cinematic_title_animation.has_animation(title_reveal_animation):
		push_warning("Missing station title animation: %s" % title_reveal_animation)
		return
	_cinematic_title_animation.stop()
	_cinematic_title_animation.play(title_reveal_animation)

func _get_animation_duration(animation_name: StringName) -> float:
	if not _letterbox_animation.has_animation(animation_name):
		return 0.0
	var animation: Animation = _letterbox_animation.get_animation(animation_name)
	return animation.length

func _update_exchange_actors() -> void:
	for slot: Node2D in _actor_slots:
		slot.visible = false
	for actor_index: int in range(_departing_actors.size()):
		var start_time: float = departing_start_time + actor_index * departing_stagger
		var progress: float = clampf((_elapsed - start_time) / departing_walk_duration, 0.0, 1.0)
		if _elapsed < start_time:
			continue
		var door_position: Vector2 = _actor_door_position(_departing_actors[actor_index], actor_index)
		var side: float = -1.0 if actor_index % 2 == 0 else 1.0
		var platform_position := door_position + Vector2(platform_horizontal_offset * side, platform_vertical_offset)
		_set_actor_slot(actor_index, _departing_actors[actor_index], door_position.lerp(platform_position, _ease_out_cubic(progress)))

	for actor_index: int in range(_boarding_actors.size()):
		var start_time: float = (
			opening_boarding_start_time + actor_index * opening_boarding_stagger
			if _opening_mode
			else exchange_boarding_start_time + actor_index * exchange_boarding_stagger
		)
		var walk_duration: float = opening_boarding_walk_duration if _opening_mode else exchange_boarding_walk_duration
		var progress: float = clampf((_elapsed - start_time) / walk_duration, 0.0, 1.0)
		if _elapsed < start_time:
			continue
		var door_position: Vector2 = _actor_door_position(_boarding_actors[actor_index], actor_index + _departing_actors.size())
		if progress >= 1.0:
			_emit_boarding_actor_entered(actor_index, door_position)
			continue
		var side: float = 1.0 if actor_index % 2 == 0 else -1.0
		var platform_position := door_position + Vector2(platform_horizontal_offset * side, platform_vertical_offset)
		_set_actor_slot(actor_index + _departing_actors.size(), _boarding_actors[actor_index], platform_position.lerp(door_position, _ease_in_cubic(progress)))

func _emit_boarding_actor_entered(actor_index: int, door_screen_position: Vector2) -> void:
	if _entered_boarding_actor_indices.has(actor_index):
		return
	_entered_boarding_actor_indices[actor_index] = true
	boarding_actor_entered.emit(actor_index, door_screen_position)

func _actor_door_position(actor_data: Dictionary, actor_index: int) -> Vector2:
	var carriage_number: int = int(actor_data.get("carriage", 0))
	var preferred_markers: Array = _door_markers.get(carriage_number, [])
	var preferred_marker: Marker2D = _marker_from_array(preferred_markers, actor_index)
	if is_instance_valid(preferred_marker):
		var preferred_position: Vector2 = _marker_screen_position(preferred_marker)
		if _is_door_visible(preferred_position):
			return preferred_position

	var visible_markers: Array[Marker2D] = []
	for marker_group: Variant in _door_markers.values():
		if not marker_group is Array:
			continue
		for marker_candidate: Variant in marker_group:
			var marker := marker_candidate as Marker2D
			if is_instance_valid(marker) and _is_door_visible(_marker_screen_position(marker)):
				visible_markers.append(marker)
	if not visible_markers.is_empty():
		return _marker_screen_position(visible_markers[actor_index % visible_markers.size()])
	if is_instance_valid(preferred_marker):
		return _marker_screen_position(preferred_marker)
	push_warning("Station cutscene has no scene-authored passenger door marker.")
	return Vector2(size.x * 0.5, size.y * 0.72)

func _marker_from_array(markers: Array, actor_index: int) -> Marker2D:
	if markers.is_empty():
		return null
	return markers[actor_index % markers.size()] as Marker2D

func _marker_screen_position(marker: Marker2D) -> Vector2:
	return get_viewport().get_canvas_transform() * marker.global_position

func _is_door_visible(screen_position: Vector2) -> bool:
	return (
		screen_position.x >= -door_visibility_margin
		and screen_position.x <= size.x + door_visibility_margin
		and screen_position.y >= -door_visibility_margin
		and screen_position.y <= size.y + door_visibility_margin
	)

func _set_actor_slot(slot_index: int, actor_data: Dictionary, actor_position: Vector2) -> void:
	if slot_index < 0 or slot_index >= _actor_slots.size():
		return
	var slot: Node2D = _actor_slots[slot_index]
	var actor_sprite: Sprite2D = slot.get_node("CharacterSprite") as Sprite2D
	var actor_texture := actor_data.get("texture") as Texture2D
	if actor_texture == null:
		push_warning("Station cutscene actor %s has no scene-authored identity texture." % actor_data.get("name", "Unknown"))
		slot.visible = false
		return
	actor_sprite.texture = actor_texture
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
