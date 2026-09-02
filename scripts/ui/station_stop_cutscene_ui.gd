class_name StationStopCutsceneUI
extends Control
## Scene-authored station cinematic layered over the unchanged gameplay camera.

signal sequence_finished
signal timeline_completed
signal sequence_timeline_changed(elapsed: float)
signal train_motion_changed(strength: float)
signal camera_return_started
signal boarding_actor_entered(actor_index: int, door_screen_position: Vector2)

@export_category("Scene Copy")
@export var opening_heading_template: String = "%s • INITIAL BOARDING"
@export var exchange_heading_template: String = "%s • PASSENGER EXCHANGE"
@export var opening_subtitle_text: String = "INITIAL BOARDING"
@export var exchange_subtitle_text: String = "PASSENGER EXCHANGE"
@export var opening_status_template: String = "%d BOARDING     [E / SPACE / ESC] SKIP"
@export var exchange_status_template: String = "%d OFF  •  %d ON     [E / SPACE / ESC] SKIP"
@export_category("Scene Animation")
@export var letterbox_in_animation: StringName = &"letterbox_in"
@export var letterbox_out_animation: StringName = &"letterbox_out"
@export var title_reveal_animation: StringName = &"title_reveal"
@export_range(0.1, 2.0, 0.05) var screen_fade_duration: float = 0.85
@export_range(0.25, 1.5, 0.05) var camera_return_lead_time: float = 0.75
@export_category("Train Timeline")
@export_range(5.0, 20.0, 0.05) var stop_duration: float = 15.340431
@export_range(0.0, 5.0, 0.05) var stop_deceleration_start: float = 2.0
@export_range(0.5, 10.0, 0.05) var stop_arrival_end: float = 6.690431
@export_range(3.0, 18.0, 0.05) var stop_departure_start: float = 11.340431
@export_range(5.0, 20.0, 0.05) var opening_duration: float = 15.340431
@export_range(0.0, 5.0, 0.05) var opening_deceleration_start: float = 2.0
@export_range(0.5, 10.0, 0.05) var opening_arrival_end: float = 6.690431
@export_range(3.0, 18.0, 0.05) var opening_departure_start: float = 11.340431
@export_range(0.0, 2.0, 0.05) var door_close_motion_delay: float = 0.55
@export_category("Passenger Staging")
@export_range(80.0, 220.0, 1.0) var platform_vertical_offset: float = 148.0
@export_range(20.0, 240.0, 1.0) var platform_horizontal_offset: float = 112.0
@export_range(0.0, 160.0, 1.0) var door_visibility_margin: float = 48.0
@export_range(0.0, 12.0, 0.05) var departing_start_time: float = 7.390431
@export_range(0.02, 0.6, 0.01) var departing_stagger_min: float = 0.1
@export_range(0.02, 0.6, 0.01) var departing_stagger_max: float = 0.22
@export_range(0.4, 2.5, 0.05) var departing_walk_duration_min: float = 1.0
@export_range(0.4, 2.5, 0.05) var departing_walk_duration_max: float = 1.45
@export_range(0.0, 12.0, 0.05) var opening_boarding_start_time: float = 7.390431
@export_range(0.02, 0.6, 0.01) var opening_boarding_stagger_min: float = 0.07
@export_range(0.02, 0.6, 0.01) var opening_boarding_stagger_max: float = 0.36
@export_range(0.4, 2.5, 0.05) var opening_boarding_walk_duration_min: float = 0.95
@export_range(0.4, 2.5, 0.05) var opening_boarding_walk_duration_max: float = 1.35
@export_range(0.0, 12.0, 0.05) var exchange_boarding_start_time: float = 7.690431
@export_range(0.02, 0.6, 0.01) var exchange_boarding_stagger_min: float = 0.09
@export_range(0.02, 0.6, 0.01) var exchange_boarding_stagger_max: float = 0.36
@export_range(0.4, 2.5, 0.05) var exchange_boarding_walk_duration_min: float = 0.95
@export_range(0.4, 2.5, 0.05) var exchange_boarding_walk_duration_max: float = 1.4
@export_range(0.0, 30.0, 1.0) var minimum_path_curve: float = 7.0
@export_range(0.0, 40.0, 1.0) var maximum_path_curve: float = 19.0
@export_range(0.0, 20.0, 1.0) var maximum_step_lift: float = 8.0
@export_range(0.0, 0.1, 0.005) var maximum_walk_tilt: float = 0.025

var _elapsed: float = 0.0
var _station_name: String = "Station"
var _departing_actors: Array[Dictionary] = []
var _boarding_actors: Array[Dictionary] = []
var _departing_motion_profiles: Array[Dictionary] = []
var _boarding_motion_profiles: Array[Dictionary] = []
var _door_markers: Dictionary = {}
var _finished: bool = false
var _timeline_completed: bool = false
var _opening_mode: bool = false
var _duration: float = 15.340431
var _deceleration_start: float = 2.0
var _arrival_end: float = 6.690431
var _departure_start: float = 11.340431
var _motion_strength: float = -1.0
var _letterbox_exit_started: bool = false
var _camera_return_started: bool = false
var _departure_blocked: bool = false
var _entered_boarding_actor_indices: Dictionary = {}
var _motion_rng := RandomNumberGenerator.new()

@onready var _actor_slots: Array[Node2D] = [
	%Actor0, %Actor1, %Actor2, %Actor3, %Actor4, %Actor5,
	%Actor6, %Actor7, %Actor8, %Actor9, %Actor10, %Actor11,
	%Actor12, %Actor13, %Actor14, %Actor15, %Actor16, %Actor17,
	%Actor18, %Actor19, %Actor20, %Actor21, %Actor22, %Actor23,
	%Actor24, %Actor25, %Actor26, %Actor27, %Actor28, %Actor29,
	%Actor30, %Actor31, %Actor32, %Actor33, %Actor34, %Actor35,
]
@onready var _streaks: Array[Line2D] = [%Streak0, %Streak1, %Streak2, %Streak3, %Streak4, %Streak5]
@onready var _heading_label: Label = %HeadingLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _status_label: Label = %StatusLabel
@onready var _screen_fade: ColorRect = %ScreenFade
@onready var _letterbox_animation: AnimationPlayer = %LetterboxAnimation
@onready var _cinematic_title_animation: AnimationPlayer = %CinematicTitleAnimation


func play_stop(station_name: String, departing_actors: Array[Dictionary], boarding_actors: Array[Dictionary], door_markers: Dictionary = {}) -> void:
	_opening_mode = false
	_duration = stop_duration
	_deceleration_start = stop_deceleration_start
	_arrival_end = stop_arrival_end
	_departure_start = stop_departure_start
	_begin_sequence(station_name, departing_actors, boarding_actors, door_markers)


func play_opening(station_name: String, boarding_actors: Array[Dictionary], door_markers: Dictionary = {}) -> void:
	_opening_mode = true
	_duration = opening_duration
	_deceleration_start = opening_deceleration_start
	_arrival_end = opening_arrival_end
	_departure_start = opening_departure_start
	_begin_sequence(station_name, [], boarding_actors, door_markers)


func get_stop_timeline() -> Vector3:
	return Vector3(stop_duration, stop_arrival_end, stop_departure_start)


func get_opening_timeline() -> Vector3:
	return Vector3(opening_duration, opening_arrival_end, opening_departure_start)


func get_train_motion_strength() -> float:
	return clampf(_motion_strength, 0.0, 1.0)


func set_departure_blocked(blocked: bool) -> void:
	_departure_blocked = blocked


func _begin_sequence(station_name: String, departing_actors: Array[Dictionary], boarding_actors: Array[Dictionary], door_markers: Dictionary) -> void:
	_station_name = station_name
	_departing_actors = departing_actors.duplicate(true)
	_boarding_actors = boarding_actors.duplicate(true)
	_door_markers = door_markers.duplicate()
	_elapsed = 0.0
	_finished = false
	_timeline_completed = false
	_departure_blocked = false
	_letterbox_exit_started = false
	_camera_return_started = false
	_entered_boarding_actor_indices.clear()
	_motion_rng.randomize()
	_build_actor_motion_profiles()
	_update_scene_copy()
	show()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_screen_fade.modulate.a = 1.0
	_motion_strength = -1.0
	_set_train_motion_strength(1.0)
	_play_letterbox_animation(letterbox_in_animation)
	_play_cinematic_title_animation()
	_update_visuals()
	sequence_timeline_changed.emit(_elapsed)


func skip_sequence() -> void:
	if not visible or _camera_return_started:
		return
	# Preserve the station audio beats even when only the visuals are skipped.
	# Reaching zero triggers brake/announcement, then the timeline jump below
	# immediately restores train motion and its authored rail SFX.
	_set_train_motion_strength(0.0)
	_elapsed = maxf(_elapsed, _duration - camera_return_lead_time)
	_start_camera_return_if_needed()
	sequence_timeline_changed.emit(_elapsed)
	_update_visuals()


func _process(delta: float) -> void:
	var next_elapsed: float = minf(_elapsed + delta, _duration)
	if _departure_blocked:
		var departure_motion_start: float = _departure_start + door_close_motion_delay
		if _elapsed <= departure_motion_start:
			next_elapsed = minf(next_elapsed, departure_motion_start)
	_elapsed = next_elapsed
	sequence_timeline_changed.emit(_elapsed)
	_update_visuals()
	if _elapsed >= _duration and not _timeline_completed:
		_timeline_completed = true
		timeline_completed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _elapsed < screen_fade_duration:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
		skip_sequence()
		get_viewport().set_input_as_handled()


func complete_sequence() -> void:
	if _finished:
		return
	_finished = true
	for actor_index: int in range(_boarding_actors.size()):
		var door_position: Vector2 = _actor_door_position(_boarding_actors[actor_index], actor_index + _departing_actors.size())
		_emit_boarding_actor_entered(actor_index, door_position)
	_start_camera_return_if_needed(true)
	_set_train_motion_strength(1.0)
	_screen_fade.modulate.a = 0.0
	if _letterbox_animation.has_animation(letterbox_out_animation):
		_letterbox_exit_started = true
		_play_letterbox_animation(letterbox_out_animation)
		var finished_animation: StringName = await _letterbox_animation.animation_finished
		if finished_animation != letterbox_out_animation or not is_inside_tree():
			return
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
	_update_screen_fade()
	_update_train_motion()
	_update_exchange_actors()
	_update_departure_streaks()


func _update_screen_fade() -> void:
	var fade_progress: float = clampf(_elapsed / maxf(screen_fade_duration, 0.01), 0.0, 1.0)
	_screen_fade.modulate.a = 1.0 - _ease_in_out_sine(fade_progress)


func _update_train_motion() -> void:
	var strength: float = 1.0
	if _elapsed < _deceleration_start:
		strength = 1.0
	elif _elapsed < _arrival_end:
		var deceleration_progress: float = inverse_lerp(_deceleration_start, _arrival_end, _elapsed)
		strength = 1.0 - _ease_in_out_sine(deceleration_progress)
	elif _elapsed < _departure_start + door_close_motion_delay:
		strength = 0.0
	else:
		var acceleration_progress: float = inverse_lerp(_departure_start + door_close_motion_delay, _duration, _elapsed)
		strength = _ease_in_out_sine(acceleration_progress)
	_set_train_motion_strength(strength)


func _set_train_motion_strength(value: float) -> void:
	var clamped_value: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(_motion_strength, clamped_value):
		return
	_motion_strength = clamped_value
	train_motion_changed.emit(_motion_strength)


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


func _build_actor_motion_profiles() -> void:
	var boarding_start: float = opening_boarding_start_time if _opening_mode else exchange_boarding_start_time
	var boarding_stagger_minimum: float = opening_boarding_stagger_min if _opening_mode else exchange_boarding_stagger_min
	var boarding_stagger_maximum: float = opening_boarding_stagger_max if _opening_mode else exchange_boarding_stagger_max
	var boarding_walk_minimum: float = opening_boarding_walk_duration_min if _opening_mode else exchange_boarding_walk_duration_min
	var boarding_walk_maximum: float = opening_boarding_walk_duration_max if _opening_mode else exchange_boarding_walk_duration_max
	var actor_deadline: float = maxf(_departure_start - 0.12, boarding_start + 0.5)
	_departing_motion_profiles = _create_motion_profiles(
		_departing_actors.size(), departing_start_time,
		departing_stagger_min, departing_stagger_max,
		departing_walk_duration_min, departing_walk_duration_max,
		actor_deadline
	)
	_boarding_motion_profiles = _create_motion_profiles(
		_boarding_actors.size(), boarding_start,
		boarding_stagger_minimum, boarding_stagger_maximum,
		boarding_walk_minimum, boarding_walk_maximum,
		actor_deadline
	)


func _create_motion_profiles(actor_count: int, first_start: float, stagger_min: float, stagger_max: float, walk_min: float, walk_max: float, deadline: float) -> Array[Dictionary]:
	var profiles: Array[Dictionary] = []
	if actor_count <= 0:
		return profiles
	var minimum_stagger: float = minf(stagger_min, stagger_max)
	var maximum_stagger: float = maxf(stagger_min, stagger_max)
	var minimum_walk: float = minf(walk_min, walk_max)
	var maximum_walk: float = maxf(walk_min, walk_max)
	var available_span: float = maxf(deadline - first_start, 0.5)
	var average_walk: float = (minimum_walk + maximum_walk) * 0.5
	var desired_start_span: float = maxf(available_span - average_walk, 0.0)
	var target_stagger: float = desired_start_span / maxf(float(actor_count - 1), 1.0)
	var effective_stagger_min: float = maxf(minimum_stagger, target_stagger * 0.72)
	var effective_stagger_max: float = maxf(effective_stagger_min, minf(maximum_stagger, target_stagger * 1.18))
	var current_start: float = first_start + _motion_rng.randf_range(0.0, effective_stagger_min * 0.2)
	for actor_index: int in range(actor_count):
		if actor_index > 0:
			current_start += _motion_rng.randf_range(effective_stagger_min, effective_stagger_max)
		var curve_magnitude: float = _motion_rng.randf_range(minimum_path_curve, maximum_path_curve)
		profiles.append({
			"start_time": current_start,
			"walk_duration": _motion_rng.randf_range(minimum_walk, maximum_walk),
			"side": -1.0 if _motion_rng.randf() < 0.5 else 1.0,
			"horizontal_scale": _motion_rng.randf_range(0.82, 1.18),
			"vertical_scale": _motion_rng.randf_range(0.9, 1.12),
			"curve_offset": curve_magnitude * (-1.0 if _motion_rng.randf() < 0.5 else 1.0),
			"step_lift": _motion_rng.randf_range(0.0, maximum_step_lift),
			"walk_phase": _motion_rng.randf_range(0.0, TAU),
		})
	var last_profile: Dictionary = profiles.back()
	var final_end: float = float(last_profile["start_time"]) + float(last_profile["walk_duration"])
	if final_end <= deadline:
		return profiles
	var authored_span: float = maxf(final_end - first_start, 0.01)
	var timing_scale: float = minf(available_span / authored_span, 1.0)
	for profile_index: int in range(profiles.size()):
		var profile: Dictionary = profiles[profile_index]
		var authored_start: float = float(profile["start_time"])
		var adjusted_start: float = first_start + (authored_start - first_start) * timing_scale
		profile["start_time"] = adjusted_start
		profile["walk_duration"] = minf(maxf(float(profile["walk_duration"]) * timing_scale, 0.45), maxf(deadline - adjusted_start, 0.25))
		profiles[profile_index] = profile
	return profiles


func _update_exchange_actors() -> void:
	for slot: Node2D in _actor_slots:
		slot.visible = false
		slot.rotation = 0.0
	for actor_index: int in range(_departing_actors.size()):
		if actor_index >= _departing_motion_profiles.size():
			continue
		var profile: Dictionary = _departing_motion_profiles[actor_index]
		var start_time: float = float(profile["start_time"])
		if _elapsed < start_time:
			continue
		var walk_duration: float = float(profile["walk_duration"])
		var progress: float = clampf((_elapsed - start_time) / walk_duration, 0.0, 1.0)
		var door_position: Vector2 = _actor_door_position(_departing_actors[actor_index], actor_index)
		var platform_position: Vector2 = _profile_platform_position(door_position, profile)
		var actor_position: Vector2 = _curved_walk_position(door_position, platform_position, _ease_out_cubic(progress), profile)
		_set_actor_slot(actor_index, _departing_actors[actor_index], actor_position, _walk_rotation(progress, profile))

	for actor_index: int in range(_boarding_actors.size()):
		if actor_index >= _boarding_motion_profiles.size():
			continue
		var profile: Dictionary = _boarding_motion_profiles[actor_index]
		var start_time: float = float(profile["start_time"])
		if _elapsed < start_time:
			continue
		var walk_duration: float = float(profile["walk_duration"])
		var progress: float = clampf((_elapsed - start_time) / walk_duration, 0.0, 1.0)
		var door_position: Vector2 = _actor_door_position(_boarding_actors[actor_index], actor_index + _departing_actors.size())
		if progress >= 1.0:
			_emit_boarding_actor_entered(actor_index, door_position)
			continue
		var platform_position: Vector2 = _profile_platform_position(door_position, profile)
		var actor_position: Vector2 = _curved_walk_position(platform_position, door_position, _ease_in_cubic(progress), profile)
		_set_actor_slot(actor_index + _departing_actors.size(), _boarding_actors[actor_index], actor_position, _walk_rotation(progress, profile))


func _profile_platform_position(door_position: Vector2, profile: Dictionary) -> Vector2:
	return door_position + Vector2(
		platform_horizontal_offset * float(profile["side"]) * float(profile["horizontal_scale"]),
		platform_vertical_offset * float(profile["vertical_scale"])
	)


func _curved_walk_position(start_position: Vector2, end_position: Vector2, progress: float, profile: Dictionary) -> Vector2:
	var position_on_path: Vector2 = start_position.lerp(end_position, progress)
	var arc: float = sin(progress * PI)
	position_on_path.x += arc * float(profile["curve_offset"])
	position_on_path.y -= arc * float(profile["step_lift"])
	return position_on_path


func _walk_rotation(progress: float, profile: Dictionary) -> float:
	return sin(progress * PI * 2.0 + float(profile["walk_phase"])) * maximum_walk_tilt * sin(progress * PI)


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


func _set_actor_slot(slot_index: int, actor_data: Dictionary, actor_position: Vector2, actor_rotation: float) -> void:
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
	slot.rotation = actor_rotation
	slot.visible = true


func _update_departure_streaks() -> void:
	var acceleration_start: float = _departure_start + door_close_motion_delay
	for streak: Line2D in _streaks:
		streak.visible = _elapsed > acceleration_start
	if _elapsed <= acceleration_start:
		return
	var progress: float = clampf((_elapsed - acceleration_start) / maxf(_duration - acceleration_start, 0.01), 0.0, 1.0)
	var alpha: float = sin(progress * PI) * 0.18
	for line_index: int in range(_streaks.size()):
		var streak: Line2D = _streaks[line_index]
		streak.position.x = fmod(_elapsed * lerpf(180.0, 460.0, progress) + line_index * 173.0, size.x + 260.0) - 260.0
		streak.modulate.a = alpha


func _ease_out_cubic(value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped, 3.0)


func _ease_in_cubic(value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	return clamped * clamped * clamped


func _ease_in_out_sine(value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	return -(cos(PI * clamped) - 1.0) * 0.5
