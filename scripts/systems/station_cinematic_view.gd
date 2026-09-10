class_name StationCinematicView
extends Node2D
## Owns the temporary wide station framing without changing the gameplay camera setup.

signal camera_handoff_finished

@export_category("Arrival Framing")
@export_range(0.1, 4.0, 0.05) var zoom_out_start_seconds: float = 0.65
@export_range(0.0, 2.0, 0.05) var full_frame_lead_seconds: float = 0.35
@export var target_zoom: Vector2 = Vector2(0.428571, 0.428571)
@export_range(0.1, 2.0, 0.05) var return_duration: float = 0.75
@export_category("Return Transition")
@export_range(0.1, 3.0, 0.05) var departure_follow_duration: float = 1.35
@export_range(0.0, 1.0, 0.01) var station_fade_start_progress: float = 0.08
@export_range(0.0, 1.0, 0.01) var station_fade_end_progress: float = 0.82
@export_category("Time Of Day Tint")
@export_range(0.0, 1.0, 0.01) var afternoon_start: float = 0.25
@export_range(0.0, 1.0, 0.01) var sunset_start: float = 0.56
@export_range(0.0, 1.0, 0.01) var night_start: float = 0.82
@export var sunrise_tint: Color = Color(1.0, 0.96, 0.88, 1.0)
@export var afternoon_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var sunset_tint: Color = Color(1.0, 0.78, 0.62, 1.0)
@export var night_tint: Color = Color(0.46, 0.58, 0.78, 1.0)

var _source_camera: Camera2D
var _handoff_anchor: Node2D
var _gameplay_zoom: Vector2
var _arrival_start_center: Vector2
var _arrival_start_zoom: Vector2
var _active: bool = false
var _returning: bool = false
var _departure_following: bool = false
var _departure_follow_blend: float = 0.0
var _departure_follow_start_center: Vector2
var _camera_handed_off: bool = false
var _return_tween: Tween
var _return_start_center: Vector2
var _return_start_zoom: Vector2
var _return_start_environment_alpha: float = 1.0
var _handoff_composition_offset: Vector2 = Vector2.ZERO
var _handoff_composition_captured: bool = false
var _station_environment_alpha: float = 1.0

@onready var _station_backdrop: Node2D = %StationBackdrop
@onready var _station_sign_layer: Node2D = %StationSignLayer
@onready var _station_sign: Node2D = %StationSign
@onready var _station_name_label: Label = %StationName
@onready var _frame_target: Marker2D = %FrameTarget
@onready var _platform_baseline: Marker2D = %PlatformBaseline
@onready var _left_entrance: Marker2D = %LeftEntrance
@onready var _right_entrance: Marker2D = %RightEntrance
@onready var _bottom_entrance: Marker2D = %BottomEntrance
@onready var _station_camera: Camera2D = %StationCamera


func set_cycle_progress(value: float) -> void:
	var progress: float = clampf(value, 0.0, 1.0)
	var tint: Color = sunrise_tint
	if progress >= night_start:
		tint = night_tint
	elif progress >= sunset_start:
		tint = sunset_tint
	elif progress >= afternoon_start:
		tint = afternoon_tint
	tint.a = 1.0
	_station_backdrop.modulate = tint
	_station_sign.modulate = tint
	_apply_station_environment_alpha()


func begin(source_camera: Camera2D, station_name: String, handoff_anchor: Node2D = null) -> void:
	if not is_instance_valid(source_camera):
		push_error("StationCinematicView requires a valid gameplay Camera2D.")
		return
	if _return_tween and _return_tween.is_valid():
		_return_tween.kill()
	_source_camera = source_camera
	_handoff_anchor = handoff_anchor if is_instance_valid(handoff_anchor) else source_camera
	_gameplay_zoom = _source_camera.zoom
	_handoff_composition_offset = Vector2.ZERO
	_handoff_composition_captured = false
	# Open directly on the foreground station sign, then reveal the complete
	# station through the authored arrival zoom-out.
	_arrival_start_center = _station_sign.global_position
	_arrival_start_zoom = _gameplay_zoom
	_station_camera.global_position = _arrival_start_center
	_station_camera.zoom = _arrival_start_zoom
	var display_name: String = station_name.strip_edges().to_upper()
	_station_name_label.text = display_name if not display_name.is_empty() else "STATION"
	# Keep the station fully opaque before switching cameras so it appears instantly.
	_set_station_environment_alpha(1.0)
	_station_backdrop.show()
	_station_sign.modulate.a = 1.0
	_station_sign_layer.show()
	_returning = false
	_departure_following = false
	_departure_follow_blend = 0.0
	_camera_handed_off = false
	_active = true
	_station_camera.enabled = true
	_source_camera.enabled = false


func update_arrival(elapsed: float, arrival_end: float) -> void:
	if not _active or _returning or _camera_handed_off:
		return
	# The train is at its authored rest position when arrival completes. Capture
	# the exact bounded gameplay composition there, then carry that offset with
	# the moving train during departure. This prevents the cinematic camera from
	# colliding with the fixed gameplay limits while it follows the MC offscreen.
	if elapsed >= arrival_end - 0.001:
		_capture_handoff_composition()
	var frame_end: float = maxf(arrival_end - full_frame_lead_seconds, zoom_out_start_seconds + 0.01)
	var progress: float = clampf(inverse_lerp(zoom_out_start_seconds, frame_end, elapsed), 0.0, 1.0)
	var eased_progress: float = _smoothstep(progress)
	_station_camera.global_position = _arrival_start_center.lerp(_frame_target.global_position, eased_progress)
	_station_camera.zoom = _arrival_start_zoom.lerp(target_zoom, eased_progress)


func return_to_gameplay() -> void:
	if not _active or _returning:
		return
	_returning = true
	_departure_following = false
	_capture_handoff_composition()
	if _return_tween and _return_tween.is_valid():
		_return_tween.kill()
	_return_start_center = _station_camera.global_position
	_return_start_zoom = _station_camera.zoom
	_return_start_environment_alpha = _station_environment_alpha
	_return_tween = create_tween()
	_return_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_return_tween.tween_method(_update_camera_return, 0.0, 1.0, return_duration)
	_return_tween.tween_callback(_begin_following_gameplay_camera)


func begin_departure_follow() -> void:
	if not _active or _returning or _camera_handed_off or _departure_following:
		return
	_capture_handoff_composition()
	if _return_tween and _return_tween.is_valid():
		_return_tween.kill()
	_departure_following = true
	_departure_follow_blend = 0.0
	_departure_follow_start_center = _station_camera.global_position
	_return_tween = create_tween()
	_return_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_return_tween.tween_method(
		_update_departure_follow,
		0.0,
		1.0,
		departure_follow_duration
	)


func set_transition_environment_alpha(value: float) -> void:
	if _active:
		_set_station_environment_alpha(value)


func skip_to_gameplay() -> void:
	if not _active:
		return
	if _return_tween and _return_tween.is_valid():
		_return_tween.kill()
	_activate_gameplay_camera()
	_station_backdrop.hide()
	_station_sign_layer.hide()
	_set_station_environment_alpha(0.0)
	_returning = false
	_departure_following = false
	_camera_handed_off = true
	camera_handoff_finished.emit()


func _process(_delta: float) -> void:
	if _active and _departure_following:
		_update_departure_follow(_departure_follow_blend)
	elif _active and _camera_handed_off:
		_follow_gameplay_camera_transform()


func align_handoff_vertical_to_gameplay() -> void:
	if not _active or not is_instance_valid(_source_camera):
		return
	var anchor: Node2D = _handoff_anchor if is_instance_valid(_handoff_anchor) else _source_camera
	if not is_instance_valid(anchor):
		return
	var gameplay_center: Vector2 = _bounded_camera_center(anchor.global_position)
	_handoff_composition_offset.y = gameplay_center.y - anchor.global_position.y
	_handoff_composition_captured = true
	sync_follow_target()


func sync_follow_target() -> void:
	# Train travel offsets are signal-driven. Sync immediately on that signal so
	# a large skipped timeline step cannot leave the cinematic camera one frame
	# behind the player and passengers.
	if _active and _departure_following:
		_update_departure_follow(_departure_follow_blend)
	elif _active and _camera_handed_off:
		_follow_gameplay_camera_transform()


func get_active_camera_scale() -> float:
	var active_zoom: Vector2 = _station_camera.zoom if _station_camera.enabled else _gameplay_zoom
	return (absf(active_zoom.x) + absf(active_zoom.y)) * 0.5


func get_station_environment_alpha() -> float:
	return _station_environment_alpha


func has_active_camera_handoff() -> bool:
	return _active


func get_station_crowd_layout() -> Dictionary:
	return {
		"platform_baseline_y": _platform_baseline.global_position.y,
		"left_entrance": _left_entrance.global_position,
		"right_entrance": _right_entrance.global_position,
		"bottom_entrance": _bottom_entrance.global_position,
	}


func finish() -> void:
	if _return_tween and _return_tween.is_valid():
		_return_tween.kill()
	_activate_gameplay_camera()
	_station_backdrop.hide()
	_station_sign_layer.hide()
	_set_station_environment_alpha(1.0)
	_active = false
	_returning = false
	_departure_following = false
	_departure_follow_blend = 0.0
	_camera_handed_off = false
	_handoff_anchor = null
	_handoff_composition_captured = false


func _update_camera_return(progress: float) -> void:
	if not is_instance_valid(_source_camera):
		return
	var eased_progress: float = _smoothstep(progress)
	_station_camera.global_position = _return_start_center.lerp(
		_handoff_target_position(),
		eased_progress
	)
	_station_camera.zoom = _return_start_zoom.lerp(_source_camera.zoom, eased_progress)
	var fade_start: float = minf(station_fade_start_progress, station_fade_end_progress)
	var fade_end: float = maxf(station_fade_start_progress, station_fade_end_progress)
	var fade_progress: float = clampf(inverse_lerp(fade_start, maxf(fade_end, fade_start + 0.001), progress), 0.0, 1.0)
	_set_station_environment_alpha(
		lerpf(_return_start_environment_alpha, 0.0, _smoothstep(fade_progress))
	)


func _update_departure_follow(progress: float) -> void:
	if not _departure_following:
		return
	_departure_follow_blend = clampf(progress, 0.0, 1.0)
	_station_camera.global_position = _departure_follow_start_center.lerp(
		_handoff_target_position(),
		_smoothstep(_departure_follow_blend)
	)


func _begin_following_gameplay_camera() -> void:
	if _camera_handed_off:
		return
	_camera_handed_off = true
	_returning = false
	_departure_following = false
	_set_station_environment_alpha(0.0)
	_follow_gameplay_camera_transform()
	camera_handoff_finished.emit()


func _follow_gameplay_camera_transform() -> void:
	if is_instance_valid(_source_camera):
		_station_camera.global_position = _handoff_target_position()
		_station_camera.zoom = _source_camera.zoom


func _set_station_environment_alpha(value: float) -> void:
	_station_environment_alpha = clampf(value, 0.0, 1.0)
	_apply_station_environment_alpha()


func _apply_station_environment_alpha() -> void:
	if is_instance_valid(_station_backdrop):
		_station_backdrop.modulate.a = _station_environment_alpha
	if is_instance_valid(_station_sign_layer):
		_station_sign_layer.modulate.a = _station_environment_alpha


func _capture_handoff_composition() -> void:
	if _handoff_composition_captured or not is_instance_valid(_source_camera):
		return
	var anchor: Node2D = _handoff_anchor if is_instance_valid(_handoff_anchor) else _source_camera
	_handoff_composition_offset = _bounded_camera_center(anchor.global_position) - anchor.global_position
	_handoff_composition_captured = true


func _handoff_target_position() -> Vector2:
	var anchor: Node2D = _handoff_anchor if is_instance_valid(_handoff_anchor) else _source_camera
	if not is_instance_valid(anchor):
		return _station_camera.global_position
	if not _handoff_composition_captured:
		_capture_handoff_composition()
	return anchor.global_position + _handoff_composition_offset


func _bounded_camera_center(desired_center: Vector2) -> Vector2:
	# Camera2D does not expose the effective center while it is disabled. Mirror
	# its limit calculation at the gameplay zoom so the cinematic handoff lands
	# on the same frame that Camera2D will render when it becomes active again.
	var viewport_size: Vector2 = get_viewport_rect().size
	var safe_zoom := Vector2(
		maxf(absf(_source_camera.zoom.x), 0.001),
		maxf(absf(_source_camera.zoom.y), 0.001)
	)
	var half_view := Vector2(
		viewport_size.x / safe_zoom.x,
		viewport_size.y / safe_zoom.y
	) * 0.5
	var minimum_center := Vector2(
		float(_source_camera.limit_left),
		float(_source_camera.limit_top)
	) + half_view
	var maximum_center := Vector2(
		float(_source_camera.limit_right),
		float(_source_camera.limit_bottom)
	) - half_view
	var bounded := desired_center
	if maximum_center.x < minimum_center.x:
		bounded.x = (minimum_center.x + maximum_center.x) * 0.5
	else:
		bounded.x = clampf(bounded.x, minimum_center.x, maximum_center.x)
	if maximum_center.y < minimum_center.y:
		bounded.y = (minimum_center.y + maximum_center.y) * 0.5
	else:
		bounded.y = clampf(bounded.y, minimum_center.y, maximum_center.y)
	return bounded


func _activate_gameplay_camera() -> void:
	if is_instance_valid(_source_camera):
		_source_camera.enabled = true
		_source_camera.reset_smoothing()
	_station_camera.enabled = false
	_returning = false
	_departure_following = false


func _smoothstep(value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)
