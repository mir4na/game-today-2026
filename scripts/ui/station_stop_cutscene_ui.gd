class_name StationStopCutsceneUI
extends Control
## Scene-authored station exchange layered over the temporary wide station camera.

signal sequence_finished
signal timeline_completed
signal sequence_timeline_changed(elapsed: float)
signal train_motion_changed(strength: float)
signal camera_return_started
signal boarding_actor_entered(actor_id: int, door_screen_position: Vector2)
signal sequence_skip_requested

@export_category("Scene Copy")
@export var show_station_title: bool = true
@export var show_terminal_title: bool = true
@export var opening_heading_template: String = "%s • INITIAL BOARDING"
@export var exchange_heading_template: String = "%s • PASSENGER EXCHANGE"
@export var opening_subtitle_text: String = "INITIAL BOARDING"
@export var exchange_subtitle_text: String = "PASSENGER EXCHANGE"
@export var terminal_heading_text: String = ""
@export var terminal_subtitle_text: String = ""
@export var opening_status_template: String = "%d BOARDING"
@export var exchange_status_template: String = "%d OFF  •  %d ON"
@export var terminal_status_template: String = "%d DISEMBARKING"
@export var skip_hint_text: String = "PRESS [SPACE] TO"
@export var skip_button_text: String = "SKIP"
@export_category("Scene Animation")
@export var letterbox_in_animation: StringName = &"letterbox_in"
@export var letterbox_out_animation: StringName = &"letterbox_out"
@export var title_reveal_animation: StringName = &"title_reveal"
@export_range(0.1, 2.0, 0.05) var screen_fade_duration: float = 0.85
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
@export_range(0.1, 2.0, 0.05) var camera_return_hold_seconds: float = 0.85
@export_range(0.5, 1.0, 0.01) var camera_return_departure_progress: float = 0.82
@export_category("Passenger Staging")
@export_range(45.0, 140.0, 1.0) var platform_vertical_offset: float = 78.0
@export_range(20.0, 120.0, 1.0) var platform_horizontal_offset: float = 82.0
@export_range(0.0, 160.0, 1.0) var door_visibility_margin: float = 48.0
@export_range(0.5, 1.5, 0.05) var actor_world_scale_multiplier: float = 1.0
@export_range(0.0, 12.0, 0.05) var departing_start_time: float = 7.390431
@export_range(0.02, 0.6, 0.01) var departing_stagger_min: float = 0.1
@export_range(0.02, 0.6, 0.01) var departing_stagger_max: float = 0.22
@export_range(0.4, 2.5, 0.05) var departing_walk_duration_min: float = 1.65
@export_range(0.4, 2.5, 0.05) var departing_walk_duration_max: float = 2.2
@export_range(0.0, 12.0, 0.05) var opening_boarding_start_time: float = 7.390431
@export_range(0.02, 0.6, 0.01) var opening_boarding_stagger_min: float = 0.07
@export_range(0.02, 0.6, 0.01) var opening_boarding_stagger_max: float = 0.36
@export_range(0.4, 2.5, 0.05) var opening_boarding_walk_duration_min: float = 1.7
@export_range(0.4, 2.5, 0.05) var opening_boarding_walk_duration_max: float = 2.25
@export_range(0.0, 12.0, 0.05) var exchange_boarding_start_time: float = 7.690431
@export_range(0.02, 0.6, 0.01) var exchange_boarding_stagger_min: float = 0.09
@export_range(0.02, 0.6, 0.01) var exchange_boarding_stagger_max: float = 0.36
@export_range(0.4, 2.5, 0.05) var exchange_boarding_walk_duration_min: float = 1.65
@export_range(0.4, 2.5, 0.05) var exchange_boarding_walk_duration_max: float = 2.2
@export_range(0.0, 30.0, 1.0) var minimum_path_curve: float = 7.0
@export_range(0.0, 40.0, 1.0) var maximum_path_curve: float = 19.0
@export_range(0.0, 20.0, 1.0) var maximum_step_lift: float = 8.0
@export_range(0.0, 0.1, 0.005) var maximum_walk_tilt: float = 0.025
@export_range(0.15, 0.55, 0.01) var doorway_step_ratio: float = 0.42
@export_range(0.0, 0.15, 0.01) var doorway_pause_ratio: float = 0.04
@export_range(0.7, 1.0, 0.01) var boarding_handoff_progress: float = 0.9
@export_range(0.0, 60.0, 1.0) var doorway_landing_vertical_offset: float = 20.0
@export_range(0.0, 60.0, 1.0) var doorway_inside_horizontal_offset: float = 26.0
@export_range(40.0, 140.0, 1.0) var doorway_inside_vertical_offset: float = 58.0
@export_category("Station Crowd")
@export_range(0, 12, 1) var ambient_actor_count: int = 6
@export_range(0.1, 2.0, 0.05) var ambient_walk_speed_scale: float = 0.5
@export_range(2.0, 14.0, 0.1) var ambient_walk_duration_min: float = 8.0
@export_range(2.0, 16.0, 0.1) var ambient_walk_duration_max: float = 11.0
@export_range(0.0, 80.0, 1.0) var ambient_lane_spread: float = 42.0
@export_range(20.0, 160.0, 1.0) var ambient_edge_margin: float = 72.0
@export_range(1.0, 8.0, 0.1) var boarding_entry_lead_min: float = 2.2
@export_range(1.0, 10.0, 0.1) var boarding_entry_lead_max: float = 4.8
@export_range(0, 8, 1) var concourse_entry_interval: int = 3

var _elapsed: float = 0.0
var _station_name: String = "Station"
var _departing_actors: Array[Dictionary] = []
var _boarding_actors: Array[Dictionary] = []
var _ambient_actors: Array[Dictionary] = []
var _departing_motion_profiles: Array[Dictionary] = []
var _boarding_motion_profiles: Array[Dictionary] = []
var _ambient_motion_profiles: Array[Dictionary] = []
var _door_markers: Dictionary = {}
var _door_rest_positions: Dictionary = {}
var _station_crowd_layout: Dictionary = {}
var _finished: bool = false
var _timeline_completed: bool = false
var _opening_mode: bool = false
var _terminal_mode: bool = false
var _duration: float = 15.340431
var _deceleration_start: float = 2.0
var _arrival_end: float = 6.690431
var _departure_start: float = 11.340431
var _motion_strength: float = -1.0
var _letterbox_exit_started: bool = false
var _camera_return_started: bool = false
var _camera_return_completed: bool = false
var _skip_requested: bool = false
var _departure_blocked: bool = false
var _entered_boarding_actor_indices: Dictionary = {}
var _ambient_elapsed: float = 0.0
var _ambient_platform_y_cache: float = NAN
var _world_camera_scale: float = 1.0
var _station_environment_alpha: float = 1.0
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
@onready var _skip_prompt_label: Label = %SkipPromptLabel
@onready var _skip_button: Button = %SkipButton
@onready var _cinematic_title: Control = %CinematicTitle
@onready var _screen_fade: ColorRect = %ScreenFade
@onready var _station_actor_canvas: CanvasLayer = %StationActorCanvas
@onready var _cinematic_border_layer: CanvasLayer = %CinematicBorderLayer
@onready var _letterbox_animation: AnimationPlayer = %LetterboxAnimation
@onready var _cinematic_title_animation: AnimationPlayer = %CinematicTitleAnimation


func play_stop(station_name: String, departing_actors: Array[Dictionary], boarding_actors: Array[Dictionary], door_markers: Dictionary = {}, door_rest_positions: Dictionary = {}, ambient_actors: Array[Dictionary] = []) -> void:
	_opening_mode = false
	_terminal_mode = false
	_duration = stop_duration
	_deceleration_start = stop_deceleration_start
	_arrival_end = stop_arrival_end
	_departure_start = stop_departure_start
	_begin_sequence(station_name, departing_actors, boarding_actors, door_markers, door_rest_positions, ambient_actors)


func play_opening(station_name: String, boarding_actors: Array[Dictionary], door_markers: Dictionary = {}, door_rest_positions: Dictionary = {}, ambient_actors: Array[Dictionary] = []) -> void:
	_opening_mode = true
	_terminal_mode = false
	_duration = opening_duration
	_deceleration_start = opening_deceleration_start
	_arrival_end = opening_arrival_end
	_departure_start = opening_departure_start
	_begin_sequence(station_name, [], boarding_actors, door_markers, door_rest_positions, ambient_actors)


func play_terminal(departing_actors: Array[Dictionary], door_markers: Dictionary = {}, ambient_actors: Array[Dictionary] = []) -> void:
	_opening_mode = false
	_terminal_mode = true
	_duration = stop_duration
	_deceleration_start = stop_deceleration_start
	_arrival_end = stop_arrival_end
	_departure_start = stop_departure_start
	_begin_sequence("", departing_actors, [], door_markers, {}, ambient_actors)


func get_stop_timeline() -> Vector3:
	return Vector3(stop_duration, stop_arrival_end, stop_departure_start)


func get_opening_timeline() -> Vector3:
	return Vector3(opening_duration, opening_arrival_end, opening_departure_start)


func get_train_motion_strength() -> float:
	return clampf(_motion_strength, 0.0, 1.0)


func get_active_arrival_end() -> float:
	return _arrival_end


func get_arrival_progress() -> float:
	var linear_progress: float = clampf(_elapsed / maxf(_arrival_end, 0.01), 0.0, 1.0)
	# An ease-out arrival starts at line speed and gently settles at the authored
	# stopping point as the brake SFX reaches its end.
	return 1.0 - pow(1.0 - linear_progress, 2.0)


func get_departure_progress() -> float:
	var movement_start: float = _get_departure_motion_start()
	var linear_progress: float = clampf(
		inverse_lerp(movement_start, _duration, _elapsed),
		0.0,
		1.0
	)
	# Integral of the train's sine acceleration curve. This starts from rest,
	# gains speed naturally, and still reaches the authored exit distance at 1.
	return linear_progress - sin(linear_progress * PI) / PI


func set_departure_blocked(blocked: bool) -> void:
	_departure_blocked = blocked


func set_world_camera_scale(value: float) -> void:
	_world_camera_scale = maxf(value, 0.001)


func set_station_environment_alpha(value: float) -> void:
	_station_environment_alpha = clampf(value, 0.0, 1.0)


func set_station_crowd_layout(layout: Dictionary) -> void:
	_station_crowd_layout = layout.duplicate(true)


func _begin_sequence(station_name: String, departing_actors: Array[Dictionary], boarding_actors: Array[Dictionary], door_markers: Dictionary, door_rest_positions: Dictionary, ambient_actors: Array[Dictionary]) -> void:
	_station_name = station_name
	_departing_actors = departing_actors.duplicate(true)
	_boarding_actors = boarding_actors.duplicate(true)
	_ambient_actors = ambient_actors.duplicate(true)
	_door_markers = door_markers.duplicate()
	_door_rest_positions = door_rest_positions.duplicate(true)
	_elapsed = 0.0
	_ambient_elapsed = 0.0
	_ambient_platform_y_cache = NAN
	_finished = false
	_timeline_completed = false
	_departure_blocked = false
	_letterbox_exit_started = false
	_camera_return_started = false
	_camera_return_completed = false
	_skip_requested = false
	_entered_boarding_actor_indices.clear()
	_motion_rng.randomize()
	_build_actor_motion_profiles()
	_build_ambient_motion_profiles()
	_update_scene_copy()
	_skip_prompt_label.text = skip_hint_text
	_skip_button.text = skip_button_text
	show()
	_station_actor_canvas.show()
	_cinematic_border_layer.show()
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_screen_fade.modulate.a = 1.0
	_motion_strength = -1.0
	_set_train_motion_strength(1.0)
	_play_letterbox_animation(letterbox_in_animation)
	if _should_show_cinematic_title():
		_play_cinematic_title_animation()
	_update_visuals()
	sequence_timeline_changed.emit(_elapsed)


func skip_sequence() -> void:
	if not visible or _camera_return_started or _elapsed < screen_fade_duration:
		return
	_skip_requested = true
	_camera_return_started = true
	# Resolve every actor and train transform on this frame. Main then swaps
	# directly to the gameplay camera instead of replaying the cinematic handoff.
	_elapsed = _duration
	sequence_timeline_changed.emit(_elapsed)
	_update_visuals()
	sequence_skip_requested.emit()


func _process(delta: float) -> void:
	# Platform pedestrians belong to the station, not to the train timeline. They
	# must keep walking while departure waits for the announcement to finish.
	_ambient_elapsed += delta
	var next_elapsed: float = minf(_elapsed + delta, _duration)
	if _departure_blocked:
		var departure_motion_start: float = _get_departure_motion_start()
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
	var key_event := event as InputEventKey
	if key_event != null and key_event.echo:
		return
	if event.is_action_pressed(&"stamp_ticket"):
		skip_sequence()
		get_viewport().set_input_as_handled()


func complete_sequence() -> void:
	if _finished:
		return
	_finished = true
	for actor_index: int in range(_boarding_actors.size()):
		var door_position: Vector2 = _motion_profile_door_position(
			_boarding_motion_profiles,
			actor_index,
			_boarding_actors[actor_index],
			actor_index + _departing_actors.size()
		)
		_emit_boarding_actor_entered(actor_index, door_position)
	_start_camera_return_if_needed()
	_set_train_motion_strength(1.0)
	_screen_fade.modulate.a = 0.0
	if _skip_requested:
		_letterbox_animation.stop()
		_cinematic_title_animation.stop()
		_station_actor_canvas.hide()
		_cinematic_border_layer.hide()
		process_mode = Node.PROCESS_MODE_DISABLED
		hide()
		sequence_finished.emit()
		return
	if _letterbox_animation.has_animation(letterbox_out_animation):
		_letterbox_exit_started = true
		_play_letterbox_animation(letterbox_out_animation)
		var finished_animation: StringName = await _letterbox_animation.animation_finished
		if finished_animation != letterbox_out_animation or not is_inside_tree():
			return
	_letterbox_animation.stop()
	_cinematic_title_animation.stop()
	_station_actor_canvas.hide()
	_cinematic_border_layer.hide()
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()
	sequence_finished.emit()


func _start_camera_return_if_needed() -> void:
	if _camera_return_started:
		return
	_camera_return_started = true
	camera_return_started.emit()


func confirm_camera_return_complete() -> void:
	if not _camera_return_started or _camera_return_completed:
		return
	_camera_return_completed = true
	if not _skip_requested:
		return
	_elapsed = _duration
	sequence_timeline_changed.emit(_elapsed)
	_update_visuals()
	if not _timeline_completed:
		_timeline_completed = true
		timeline_completed.emit()


func _update_visuals() -> void:
	_update_screen_fade()
	_update_skip_button()
	_update_camera_return()
	_update_train_motion()
	_update_exchange_actors()
	_update_departure_streaks()


func _update_screen_fade() -> void:
	var fade_progress: float = clampf(_elapsed / maxf(screen_fade_duration, 0.01), 0.0, 1.0)
	_screen_fade.modulate.a = 1.0 - _ease_in_out_sine(fade_progress)


func _update_skip_button() -> void:
	_skip_button.disabled = _camera_return_started or _elapsed < screen_fade_duration


func _update_train_motion() -> void:
	var departure_motion_start: float = _get_departure_motion_start()
	var strength: float = 1.0
	if _elapsed < _deceleration_start:
		strength = 1.0
	elif _elapsed < _arrival_end:
		var deceleration_progress: float = inverse_lerp(_deceleration_start, _arrival_end, _elapsed)
		strength = 1.0 - _ease_in_out_sine(deceleration_progress)
	elif _elapsed < departure_motion_start:
		strength = 0.0
	else:
		var acceleration_progress: float = inverse_lerp(departure_motion_start, _duration, _elapsed)
		strength = _ease_in_out_sine(acceleration_progress)
	_set_train_motion_strength(strength)


func _update_camera_return() -> void:
	if get_departure_progress() >= camera_return_departure_progress:
		_start_camera_return_if_needed()


func _get_departure_motion_start() -> float:
	return _departure_start + door_close_motion_delay + camera_return_hold_seconds


func _set_train_motion_strength(value: float) -> void:
	var clamped_value: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(_motion_strength, clamped_value):
		return
	_motion_strength = clamped_value
	train_motion_changed.emit(_motion_strength)


func _update_scene_copy() -> void:
	if not _should_show_cinematic_title():
		_heading_label.text = ""
		_subtitle_label.text = ""
		_cinematic_title.hide()
		_update_status_copy()
		return
	if _terminal_mode:
		_heading_label.text = terminal_heading_text
		_subtitle_label.text = terminal_subtitle_text
	else:
		_heading_label.text = opening_heading_template % _station_name.to_upper() if _opening_mode else exchange_heading_template % _station_name.to_upper()
		_subtitle_label.text = opening_subtitle_text if _opening_mode else exchange_subtitle_text
	_cinematic_title.visible = not _heading_label.text.is_empty() or not _subtitle_label.text.is_empty()
	_update_status_copy()


func _should_show_cinematic_title() -> bool:
	return show_terminal_title if _terminal_mode else show_station_title


func _update_status_copy() -> void:
	if _terminal_mode:
		_status_label.text = terminal_status_template % _departing_actors.size()
	else:
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
	for profile_index: int in range(_boarding_motion_profiles.size()):
		var profile: Dictionary = _boarding_motion_profiles[profile_index]
		var boarding_time: float = float(profile["start_time"])
		profile["entry_start_time"] = maxf(
			0.0,
			boarding_time - _motion_rng.randf_range(
				minf(boarding_entry_lead_min, boarding_entry_lead_max),
				maxf(boarding_entry_lead_min, boarding_entry_lead_max)
			)
		)
		# Every third passenger approaches from the concourse. The others use the
		# nearest platform edge so both side entrances stay natural across coaches.
		profile["entry_route"] = (
			2
			if concourse_entry_interval > 0 and (profile_index + 1) % concourse_entry_interval == 0
			else 0
		)
		_boarding_motion_profiles[profile_index] = profile


func _build_ambient_motion_profiles() -> void:
	_ambient_motion_profiles.clear()
	if _ambient_actors.is_empty() or ambient_actor_count <= 0:
		return
	var exchange_actor_ids: Dictionary = {}
	for actor_data: Dictionary in _departing_actors + _boarding_actors:
		var actor_id: int = int(actor_data.get("runtime_actor_id", 0))
		if actor_id > 0:
			exchange_actor_ids[actor_id] = true
	var exchange_slot_count: int = _departing_actors.size() + _boarding_actors.size()
	var available_slot_count: int = maxi(_actor_slots.size() - exchange_slot_count, 0)
	var crowd_count: int = mini(ambient_actor_count, available_slot_count)
	var minimum_duration: float = minf(ambient_walk_duration_min, ambient_walk_duration_max)
	var maximum_duration: float = maxf(ambient_walk_duration_min, ambient_walk_duration_max)
	var actor_order: Array[int] = []
	for actor_index: int in range(_ambient_actors.size()):
		var ambient_actor_id: int = int(_ambient_actors[actor_index].get("runtime_actor_id", 0))
		if ambient_actor_id > 0 and exchange_actor_ids.has(ambient_actor_id):
			continue
		actor_order.append(actor_index)
	if actor_order.is_empty():
		return
	for order_index: int in range(actor_order.size() - 1, 0, -1):
		var swap_index: int = _motion_rng.randi_range(0, order_index)
		var held_index: int = actor_order[order_index]
		actor_order[order_index] = actor_order[swap_index]
		actor_order[swap_index] = held_index
	for crowd_index: int in range(crowd_count):
		var direction: float = -1.0 if _motion_rng.randf() < 0.5 else 1.0
		var walk_duration: float = _motion_rng.randf_range(minimum_duration, maximum_duration)
		_ambient_motion_profiles.append({
			"actor_index": actor_order[crowd_index % actor_order.size()],
			# Start within an existing walk cycle so the platform is already active
			# while the train is approaching the station.
			"start_time": -_motion_rng.randf_range(0.0, walk_duration),
			"walk_duration": walk_duration,
			"direction": direction,
			"lane_offset": _motion_rng.randf_range(-ambient_lane_spread, ambient_lane_spread),
			"depth_scale": _motion_rng.randf_range(0.78, 1.0),
			"curve_offset": _motion_rng.randf_range(-4.0, 4.0),
			"step_lift": _motion_rng.randf_range(0.5, maxf(maximum_step_lift * 0.7, 0.5)),
			"walk_phase": _motion_rng.randf_range(0.0, TAU),
		})


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
		slot.z_index = 0
		slot.modulate.a = 1.0
		slot.scale = Vector2.ONE
	for actor_index: int in range(_departing_actors.size()):
		if actor_index >= _departing_motion_profiles.size():
			continue
		var profile: Dictionary = _departing_motion_profiles[actor_index]
		var start_time: float = float(profile["start_time"])
		if _elapsed < start_time:
			continue
		var walk_duration: float = float(profile["walk_duration"])
		var progress: float = clampf((_elapsed - start_time) / walk_duration, 0.0, 1.0)
		var door_position: Vector2 = _motion_profile_door_position(
			_departing_motion_profiles,
			actor_index,
			_departing_actors[actor_index],
			actor_index
		)
		var platform_position: Vector2 = _profile_platform_position(door_position, profile)
		var actor_position: Vector2 = _station_walk_position(door_position, platform_position, progress, profile, false)
		_set_actor_slot(
			actor_index,
			_departing_actors[actor_index],
			actor_position,
			_walk_rotation(progress, profile),
			float(profile["side"]),
			_smoothstep(0.08, doorway_step_ratio, progress) * _station_environment_alpha,
			1.0,
			1.0
		)

	for actor_index: int in range(_boarding_actors.size()):
		if actor_index >= _boarding_motion_profiles.size():
			continue
		var profile: Dictionary = _boarding_motion_profiles[actor_index]
		var start_time: float = float(profile["start_time"])
		if _elapsed < start_time:
			var entry_start_time: float = float(profile.get("entry_start_time", 0.0))
			if _elapsed < entry_start_time:
				continue
			var waiting_door_position: Vector2 = _actor_rest_door_world_position(
				_boarding_actors[actor_index],
				actor_index + _departing_actors.size()
			)
			var waiting_position: Vector2 = _profile_platform_position(waiting_door_position, profile)
			var entry_position: Vector2 = _boarding_entry_position(waiting_position, profile)
			var entry_progress: float = _ease_in_out_sine(
				inverse_lerp(entry_start_time, start_time, _elapsed)
			)
			var actor_position: Vector2 = _platform_walk_position(
				entry_position,
				waiting_position,
				entry_progress,
				profile
			)
			var movement_direction: float = signf(waiting_position.x - entry_position.x)
			if is_zero_approx(movement_direction):
				movement_direction = -float(profile["side"])
			_set_actor_slot(
				actor_index + _departing_actors.size(),
				_boarding_actors[actor_index],
				actor_position,
				_walk_rotation(entry_progress, profile),
				movement_direction,
				_station_environment_alpha,
				1.0,
				1.0
			)
			continue
		var walk_duration: float = float(profile["walk_duration"])
		var progress: float = clampf((_elapsed - start_time) / walk_duration, 0.0, 1.0)
		var door_position: Vector2 = _motion_profile_door_position(
			_boarding_motion_profiles,
			actor_index,
			_boarding_actors[actor_index],
			actor_index + _departing_actors.size()
		)
		var platform_position: Vector2 = _profile_platform_position(door_position, profile)
		# At the doorway, hand presentation back to the real Passenger node. That
		# node is drawn behind the exterior body and can keep walking inside the
		# coach, so no part of the character is sliced by a UI-layer mask.
		if progress >= boarding_handoff_progress:
			_emit_boarding_actor_entered(actor_index, door_position)
			continue
		var actor_position: Vector2 = _station_walk_position(door_position, platform_position, progress, profile, true)
		_set_actor_slot(
			actor_index + _departing_actors.size(),
			_boarding_actors[actor_index],
			actor_position,
			_walk_rotation(progress, profile),
			-float(profile["side"]),
			_station_environment_alpha,
			1.0,
			1.0
		)
	_update_ambient_actors(_departing_actors.size() + _boarding_actors.size())


func _update_ambient_actors(first_slot_index: int) -> void:
	if _ambient_motion_profiles.is_empty() or _ambient_actors.is_empty():
		return
	for crowd_index: int in range(_ambient_motion_profiles.size()):
		var profile: Dictionary = _ambient_motion_profiles[crowd_index]
		var active_time: float = _ambient_elapsed - float(profile["start_time"])
		if active_time < 0.0:
			continue
		# Resolve the scene-authored foot line once. It stays fixed while the train
		# and camera move, so pedestrians cannot jump vertically during departure.
		if is_nan(_ambient_platform_y_cache):
			_ambient_platform_y_cache = _ambient_platform_y()
		var walk_duration: float = maxf(float(profile["walk_duration"]), 0.01)
		var progress: float = fmod(active_time * ambient_walk_speed_scale / walk_duration, 1.0)
		var direction: float = float(profile["direction"])
		var lane_y: float = _ambient_platform_y_cache + float(profile["lane_offset"])
		var left_position: Vector2 = _station_layout_position(
			"left_entrance",
			Vector2(_active_camera_world_rect().position.x - ambient_edge_margin, lane_y)
		)
		var right_position: Vector2 = _station_layout_position(
			"right_entrance",
			Vector2(_active_camera_world_rect().end.x + ambient_edge_margin, lane_y)
		)
		left_position.y = lane_y
		right_position.y = lane_y
		var start_position: Vector2 = left_position if direction > 0.0 else right_position
		var end_position: Vector2 = right_position if direction > 0.0 else left_position
		var actor_position: Vector2 = _platform_walk_position(start_position, end_position, progress, profile)
		var slot_index: int = first_slot_index + crowd_index
		var actor_index: int = int(profile["actor_index"])
		_set_actor_slot(
			slot_index,
			_ambient_actors[actor_index],
			actor_position,
			_walk_rotation(progress, profile),
			direction,
			_station_environment_alpha,
			1.0,
			ambient_walk_speed_scale
		)
		if slot_index >= 0 and slot_index < _actor_slots.size():
			var slot: Node2D = _actor_slots[slot_index]
			slot.scale *= float(profile["depth_scale"])


func _ambient_platform_y() -> float:
	if _station_crowd_layout.has("platform_baseline_y"):
		return float(_station_crowd_layout["platform_baseline_y"])
	var total_y: float = 0.0
	var visible_marker_count: int = 0
	for marker_group: Variant in _door_markers.values():
		if not marker_group is Array:
			continue
		for marker_candidate: Variant in marker_group:
			var marker := marker_candidate as Marker2D
			if not is_instance_valid(marker):
				continue
			var marker_position: Vector2 = marker.global_position
			if not _is_world_position_visible(marker_position):
				continue
			total_y += marker_position.y
			visible_marker_count += 1
	var world_rect: Rect2 = _active_camera_world_rect()
	if visible_marker_count <= 0:
		return world_rect.position.y + world_rect.size.y * 0.68
	return clampf(
		total_y / float(visible_marker_count) + platform_vertical_offset,
		world_rect.position.y + world_rect.size.y * 0.52,
		world_rect.position.y + world_rect.size.y * 0.82
	)


func _profile_platform_position(door_position: Vector2, profile: Dictionary) -> Vector2:
	var platform_y: float = door_position.y + platform_vertical_offset * float(profile["vertical_scale"])
	if _station_crowd_layout.has("platform_baseline_y"):
		platform_y = float(_station_crowd_layout["platform_baseline_y"])
	return Vector2(
		door_position.x + platform_horizontal_offset * float(profile["side"]) * float(profile["horizontal_scale"]),
		platform_y
	)


func _actor_rest_door_world_position(actor_data: Dictionary, actor_index: int) -> Vector2:
	var carriage_number: int = int(actor_data.get("carriage", 0))
	var preferred_positions: Array = _door_rest_positions.get(carriage_number, [])
	if not preferred_positions.is_empty():
		var rest_position: Vector2 = preferred_positions[actor_index % preferred_positions.size()]
		return rest_position
	return _actor_door_position(actor_data, actor_index)


func _boarding_entry_position(waiting_position: Vector2, profile: Dictionary) -> Vector2:
	var world_rect: Rect2 = _active_camera_world_rect()
	var left_entrance: Vector2 = _station_layout_position(
		"left_entrance",
		Vector2(world_rect.position.x - ambient_edge_margin, waiting_position.y)
	)
	var right_entrance: Vector2 = _station_layout_position(
		"right_entrance",
		Vector2(world_rect.end.x + ambient_edge_margin, waiting_position.y)
	)
	var bottom_entrance: Vector2 = _station_layout_position(
		"bottom_entrance",
		Vector2(waiting_position.x, world_rect.end.y + ambient_edge_margin)
	)
	var entry_route: int = int(profile.get("entry_route", 0))
	if entry_route == 2:
		return Vector2(waiting_position.x, bottom_entrance.y)
	# Enter from the closest horizontal platform edge so a passenger assigned to
	# a far coach never sprints across the entire station.
	var entrance: Vector2 = left_entrance
	if waiting_position.distance_squared_to(right_entrance) < waiting_position.distance_squared_to(left_entrance):
		entrance = right_entrance
	entrance.y = waiting_position.y
	return entrance


func _station_layout_position(key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _station_crowd_layout.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _station_walk_position(door_position: Vector2, platform_position: Vector2, progress: float, profile: Dictionary, boarding: bool) -> Vector2:
	# Passengers continue beyond the door rather than ending directly on its
	# center. The curved threshold segment reads as walking through a doorway
	# instead of being pulled vertically into a point.
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	var landing_position := door_position + Vector2(0.0, doorway_landing_vertical_offset)
	var side: float = float(profile["side"])
	var inside_position := door_position + Vector2(
		-side * doorway_inside_horizontal_offset,
		-doorway_inside_vertical_offset
	)
	var pause_duration: float = minf(doorway_pause_ratio, 1.0 - doorway_step_ratio)
	if boarding:
		var approach_end: float = maxf(1.0 - doorway_step_ratio - pause_duration, 0.01)
		if clamped_progress < approach_end:
			var approach_progress: float = _ease_in_out_sine(clamped_progress / approach_end)
			return _platform_walk_position(platform_position, landing_position, approach_progress, profile)
		if clamped_progress < approach_end + pause_duration:
			return landing_position
		var board_progress: float = inverse_lerp(approach_end + pause_duration, 1.0, clamped_progress)
		var threshold_control: Vector2 = landing_position.lerp(door_position, 0.65)
		return _quadratic_path(landing_position, threshold_control, door_position, _ease_in_out_sine(board_progress))

	if clamped_progress < doorway_step_ratio:
		var exit_progress: float = clamped_progress / maxf(doorway_step_ratio, 0.01)
		return _quadratic_path(inside_position, door_position, landing_position, _ease_in_out_sine(exit_progress))
	if clamped_progress < doorway_step_ratio + pause_duration:
		return landing_position
	var platform_progress: float = inverse_lerp(doorway_step_ratio + pause_duration, 1.0, clamped_progress)
	return _platform_walk_position(landing_position, platform_position, _ease_in_out_sine(platform_progress), profile)


func _quadratic_path(start: Vector2, control: Vector2, finish: Vector2, progress: float) -> Vector2:
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	var first_half: Vector2 = start.lerp(control, clamped_progress)
	var second_half: Vector2 = control.lerp(finish, clamped_progress)
	return first_half.lerp(second_half, clamped_progress)


func _platform_walk_position(start_position: Vector2, end_position: Vector2, progress: float, profile: Dictionary) -> Vector2:
	var position_on_path: Vector2 = start_position.lerp(end_position, progress)
	var path_envelope: float = sin(progress * PI)
	position_on_path.x += path_envelope * float(profile["curve_offset"]) * 0.2
	var step_cycle: float = abs(sin(progress * PI * 4.0 + float(profile["walk_phase"])))
	position_on_path.y -= step_cycle * float(profile["step_lift"]) * path_envelope
	return position_on_path


func _walk_rotation(progress: float, profile: Dictionary) -> float:
	return sin(progress * PI * 2.0 + float(profile["walk_phase"])) * maximum_walk_tilt * sin(progress * PI)


func _emit_boarding_actor_entered(actor_index: int, door_screen_position: Vector2) -> void:
	if _entered_boarding_actor_indices.has(actor_index):
		return
	_entered_boarding_actor_indices[actor_index] = true
	var actor_id: int = actor_index
	if actor_index >= 0 and actor_index < _boarding_actors.size():
		actor_id = int(_boarding_actors[actor_index].get("runtime_actor_id", actor_index))
	boarding_actor_entered.emit(actor_id, door_screen_position)


func _motion_profile_door_position(profiles: Array[Dictionary], profile_index: int, actor_data: Dictionary, marker_index: int) -> Vector2:
	if profile_index >= 0 and profile_index < profiles.size():
		var profile: Dictionary = profiles[profile_index]
		if profile.has("door_position"):
			var stored_position: Vector2 = profile["door_position"]
			return stored_position
		var cached_position: Vector2 = _actor_door_position(actor_data, marker_index)
		profile["door_position"] = cached_position
		profiles[profile_index] = profile
		return cached_position
	return _actor_door_position(actor_data, marker_index)


func _actor_door_position(actor_data: Dictionary, actor_index: int) -> Vector2:
	# Follow each passenger's randomized runtime carriage so station exchanges
	# are spread across the whole train instead of converging on one coach.
	var carriage_number: int = int(actor_data.get("carriage", 0))
	var preferred_markers: Array = _door_markers.get(carriage_number, [])
	var preferred_marker: Marker2D = _marker_from_array(preferred_markers, actor_index)
	if is_instance_valid(preferred_marker):
		var preferred_position: Vector2 = preferred_marker.global_position
		if _is_world_position_visible(preferred_position):
			return preferred_position

	var visible_markers: Array[Marker2D] = []
	for marker_group: Variant in _door_markers.values():
		if not marker_group is Array:
			continue
		for marker_candidate: Variant in marker_group:
			var marker := marker_candidate as Marker2D
			if is_instance_valid(marker) and _is_world_position_visible(marker.global_position):
				visible_markers.append(marker)
	if not visible_markers.is_empty():
		return visible_markers[actor_index % visible_markers.size()].global_position
	if is_instance_valid(preferred_marker):
		return preferred_marker.global_position
	push_warning("Station cutscene has no scene-authored passenger door marker.")
	var world_rect: Rect2 = _active_camera_world_rect()
	return world_rect.position + world_rect.size * Vector2(0.5, 0.72)


func _marker_from_array(markers: Array, actor_index: int) -> Marker2D:
	if markers.is_empty():
		return null
	return markers[actor_index % markers.size()] as Marker2D


func _active_camera_zoom() -> float:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if is_instance_valid(camera):
		return maxf((absf(camera.zoom.x) + absf(camera.zoom.y)) * 0.5, 0.001)
	return maxf(_world_camera_scale, 0.001)


func _active_camera_world_rect() -> Rect2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var camera: Camera2D = get_viewport().get_camera_2d()
	var center: Vector2 = Vector2.ZERO
	var zoom := Vector2(_active_camera_zoom(), _active_camera_zoom())
	if is_instance_valid(camera):
		center = camera.get_screen_center_position()
		zoom = Vector2(maxf(absf(camera.zoom.x), 0.001), maxf(absf(camera.zoom.y), 0.001))
	var world_size := Vector2(viewport_size.x / zoom.x, viewport_size.y / zoom.y)
	return Rect2(center - world_size * 0.5, world_size)


func _is_world_position_visible(world_position: Vector2) -> bool:
	var world_rect: Rect2 = _active_camera_world_rect().grow(
		door_visibility_margin / maxf(_active_camera_zoom(), 0.001)
	)
	return world_rect.has_point(world_position)


func _set_actor_slot(slot_index: int, actor_data: Dictionary, actor_position: Vector2, actor_rotation: float, movement_direction: float, visibility: float = 1.0, transition_scale: float = 1.0, animation_speed_scale: float = 1.0) -> void:
	if slot_index < 0 or slot_index >= _actor_slots.size():
		return
	var slot: Node2D = _actor_slots[slot_index]
	var actor_sprite: Sprite2D = slot.get_node("CharacterSprite") as Sprite2D
	var walking_sprite: AnimatedSprite2D = slot.get_node("WalkingSprite") as AnimatedSprite2D
	var visual_position: Vector2 = actor_data.get("visual_position", Vector2(0.0, -91.0))
	var visual_scale: Vector2 = actor_data.get("visual_scale", Vector2(0.32, 0.32))
	var faces_left: bool = bool(actor_data.get("faces_left", true))
	var flip_h: bool = movement_direction > 0.0 if faces_left else movement_direction < 0.0
	var sprite_frames := actor_data.get("sprite_frames") as SpriteFrames
	var animation_name: StringName = actor_data.get("animation", &"walk")
	if (
		sprite_frames != null
		and sprite_frames.has_animation(animation_name)
		and sprite_frames.get_frame_count(animation_name) > 0
	):
		actor_sprite.visible = false
		walking_sprite.visible = true
		walking_sprite.position = visual_position
		walking_sprite.scale = visual_scale
		walking_sprite.flip_h = flip_h
		walking_sprite.speed_scale = animation_speed_scale
		if walking_sprite.sprite_frames != sprite_frames:
			walking_sprite.sprite_frames = sprite_frames
		if walking_sprite.animation != animation_name or not walking_sprite.is_playing():
			walking_sprite.play(animation_name)
	else:
		walking_sprite.stop()
		walking_sprite.visible = false
		actor_sprite.visible = true
		actor_sprite.position = visual_position
		actor_sprite.scale = visual_scale
		actor_sprite.flip_h = flip_h
	var actor_texture := actor_data.get("texture") as Texture2D
	if sprite_frames == null and actor_texture == null:
		push_warning("Station cutscene actor %s has no scene-authored character visual." % actor_data.get("name", "Unknown"))
		slot.visible = false
		return
	if actor_sprite.visible:
		actor_sprite.texture = actor_texture
	slot.position = actor_position
	slot.rotation = actor_rotation
	# ActorSlots uses Y-sort for crowd depth. Keep every actor on the same local
	# z-index so none can rise above the station sign's foreground canvas.
	slot.z_index = 0
	slot.modulate.a = clampf(visibility, 0.0, 1.0)
	# StationActorCanvas follows the world viewport, so the camera supplies the
	# visual zoom. Keeping the local scale stable prevents actors from following
	# the screen during the return pan or receiving camera scale twice.
	slot.scale = Vector2.ONE * actor_world_scale_multiplier * transition_scale
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


func _smoothstep(edge_start: float, edge_end: float, value: float) -> float:
	if is_equal_approx(edge_start, edge_end):
		return 1.0 if value >= edge_end else 0.0
	var normalized: float = clampf(inverse_lerp(edge_start, edge_end, value), 0.0, 1.0)
	return normalized * normalized * (3.0 - 2.0 * normalized)
