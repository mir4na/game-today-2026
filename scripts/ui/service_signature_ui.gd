extends Control
## Optional daytime service confirmation. The player traces a scene-authored
## mark to sign off the current route leg and advance to the next station.

signal closed
signal service_signed
signal signature_rejected

@export_category("Trace Validation")
@export_range(8.0, 64.0, 1.0) var average_tolerance: float = 27.0
@export_range(20.0, 120.0, 1.0) var maximum_tolerance: float = 62.0
@export_range(0.4, 0.95, 0.05) var minimum_length_ratio: float = 0.7
@export_range(1.05, 2.0, 0.05) var maximum_length_ratio: float = 1.45
@export_category("Question Buttons")
@export var confirm_texture_normal: Texture2D
@export var confirm_texture_hover: Texture2D
@export var confirm_texture_pressed: Texture2D
@export var not_yet_texture_normal: Texture2D
@export var not_yet_texture_hover: Texture2D
@export var not_yet_texture_pressed: Texture2D
@export_category("Success Transition")
@export_range(200.0, 900.0, 10.0) var success_drop_distance: float = 560.0
@export_range(0.15, 0.8, 0.05) var success_drop_duration: float = 0.42
@export_range(0.15, 0.8, 0.05) var fade_to_black_duration: float = 0.34
@export_range(0.2, 1.0, 0.05) var fade_from_black_duration: float = 0.52

var _drawing: bool = false
var _accepted: bool = false
var _active_pattern: Line2D
var _feedback_tween: Tween
var _transition_tween: Tween
var _panel_rest_position: Vector2

@onready var _panel: Control = %Panel
@onready var _confirm_button: TextureButton = %ConfirmButton
@onready var _not_yet_button: TextureButton = %NotYetButton
@onready var _question_stage: Control = %QuestionStage
@onready var _question_actions: Control = %QuestionActions
@onready var _signature_stage: Control = %SignatureStage
@onready var _route_label: Label = %RouteLabel
@onready var _drawing_area: Control = %DrawingArea
@onready var _pulse_pattern: Line2D = %PulsePattern
@onready var _loop_pattern: Line2D = %LoopPattern
@onready var _user_stroke: Line2D = %UserStroke
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _feedback_flash: TextureRect = %FeedbackFlash
@onready var _transition_fade: ColorRect = %TransitionFade


func _ready() -> void:
	_panel_rest_position = _panel.position
	_apply_button_textures(_confirm_button, confirm_texture_normal, confirm_texture_hover, confirm_texture_pressed)
	_apply_button_textures(_not_yet_button, not_yet_texture_normal, not_yet_texture_hover, not_yet_texture_pressed)
	_drawing_area.gui_input.connect(_on_drawing_area_gui_input)
	hide()


func _apply_button_textures(button: TextureButton, normal: Texture2D, hover: Texture2D, pressed: Texture2D) -> void:
	if not is_instance_valid(button):
		return
	if normal != null:
		button.texture_normal = normal
	if hover != null:
		button.texture_hover = hover
	if pressed != null:
		button.texture_pressed = pressed


func open_signature(from_station: String, to_station: String, route_leg: int) -> void:
	_accepted = false
	_drawing = false
	_user_stroke.clear_points()
	_feedback_label.text = ""
	_feedback_flash.modulate.a = 0.0
	_transition_fade.modulate.a = 0.0
	_transition_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(_feedback_tween):
		_feedback_tween.kill()
	if is_instance_valid(_transition_tween):
		_transition_tween.kill()
	_route_label.text = "%s  →  %s" % [
		from_station.to_upper(),
		to_station.to_upper(),
	]
	_active_pattern = _pulse_pattern if route_leg % 2 == 0 else _loop_pattern
	_pulse_pattern.visible = _active_pattern == _pulse_pattern
	_loop_pattern.visible = _active_pattern == _loop_pattern
	_question_stage.show()
	_question_actions.show()
	_signature_stage.hide()
	show()
	_panel.position = _panel_rest_position + Vector2(0.0, 24.0)
	_panel.scale = Vector2.ONE
	_panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_panel, ^"position", _panel_rest_position, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, ^"modulate:a", 1.0, 0.16)


func request_close() -> void:
	if not visible or _accepted:
		return
	_drawing = false
	_user_stroke.clear_points()
	if is_instance_valid(_feedback_tween):
		_feedback_tween.kill()
	if is_instance_valid(_transition_tween):
		_transition_tween.kill()
	_feedback_flash.modulate.a = 0.0
	_transition_fade.modulate.a = 0.0
	_transition_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.position = _panel_rest_position
	_panel.scale = Vector2.ONE
	_panel.modulate.a = 1.0
	hide()
	closed.emit()


func _on_confirm_pressed() -> void:
	_question_actions.hide()
	_signature_stage.show()
	_user_stroke.clear_points()
	_feedback_label.text = "Hold and trace the mark."


func _on_not_yet_pressed() -> void:
	request_close()


func _on_drawing_area_gui_input(event: InputEvent) -> void:
	if _accepted or not _signature_stage.visible:
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		if mouse_button.pressed:
			_begin_stroke(mouse_button.position)
		else:
			_finish_stroke()
		accept_event()
		return
	var mouse_motion := event as InputEventMouseMotion
	if mouse_motion != null and _drawing and (mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_append_stroke_point(mouse_motion.position)
		accept_event()
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_begin_stroke(touch.position)
		else:
			_finish_stroke()
		accept_event()
		return
	var drag := event as InputEventScreenDrag
	if drag != null and _drawing:
		_append_stroke_point(drag.position)
		accept_event()


func _begin_stroke(point: Vector2) -> void:
	_drawing = true
	_user_stroke.default_color = Color(0.0, 0.0, 0.0, 1.0)
	_user_stroke.clear_points()
	_user_stroke.add_point(_clamp_to_drawing_area(point))
	_feedback_label.text = ""


func _append_stroke_point(point: Vector2) -> void:
	var clamped_point := _clamp_to_drawing_area(point)
	if _user_stroke.get_point_count() == 0 or _user_stroke.get_point_position(_user_stroke.get_point_count() - 1).distance_to(clamped_point) >= 4.0:
		_user_stroke.add_point(clamped_point)


func _finish_stroke() -> void:
	if not _drawing:
		return
	_drawing = false
	if _trace_matches_pattern(_user_stroke.points, _pattern_effective_points(_active_pattern)):
		_play_acceptance()
	else:
		_play_rejection()


## Pattern nodes carry scene-authored position/scale, while the user stroke
## lives in DrawingArea space. Compare in one space so edited line shapes
## stay traceable.
func _pattern_effective_points(pattern: Line2D) -> PackedVector2Array:
	var result := PackedVector2Array()
	if not is_instance_valid(pattern) or not is_instance_valid(_drawing_area):
		return result
	var to_drawing: Transform2D = (
		_drawing_area.get_global_transform_with_canvas().affine_inverse()
		* pattern.get_global_transform_with_canvas()
	)
	for point: Vector2 in pattern.points:
		result.append(to_drawing * point)
	return result


func _trace_matches_pattern(trace: PackedVector2Array, pattern: PackedVector2Array) -> bool:
	if trace.size() < 5 or pattern.size() < 2:
		return false
	var trace_length: float = _polyline_length(trace)
	var pattern_length: float = _polyline_length(pattern)
	if pattern_length <= 0.0:
		return false
	var length_ratio: float = trace_length / pattern_length
	if length_ratio < minimum_length_ratio or length_ratio > maximum_length_ratio:
		return false
	var direct_error: Vector2 = _ordered_trace_error(trace, pattern, false)
	var reverse_error: Vector2 = _ordered_trace_error(trace, pattern, true)
	var best_error: Vector2 = direct_error if direct_error.x <= reverse_error.x else reverse_error
	return best_error.x <= average_tolerance and best_error.y <= maximum_tolerance


func _ordered_trace_error(trace: PackedVector2Array, pattern: PackedVector2Array, reverse: bool) -> Vector2:
	var trace_samples: PackedVector2Array = _resample_polyline(trace, 48)
	var pattern_samples: PackedVector2Array = _resample_polyline(pattern, 48)
	var total_error: float = 0.0
	var largest_error: float = 0.0
	for index: int in range(pattern_samples.size()):
		var trace_index: int = pattern_samples.size() - 1 - index if reverse else index
		var distance: float = pattern_samples[index].distance_to(trace_samples[trace_index])
		total_error += distance
		largest_error = maxf(largest_error, distance)
	return Vector2(total_error / float(pattern_samples.size()), largest_error)


func _resample_polyline(points: PackedVector2Array, sample_count: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	var total_length: float = _polyline_length(points)
	if points.size() < 2 or total_length <= 0.0:
		return result
	var segment_index: int = 0
	var segment_start_distance: float = 0.0
	var segment_length: float = points[0].distance_to(points[1])
	for sample_index: int in range(sample_count):
		var target_distance: float = total_length * float(sample_index) / float(sample_count - 1)
		while segment_index < points.size() - 2 and target_distance > segment_start_distance + segment_length:
			segment_start_distance += segment_length
			segment_index += 1
			segment_length = points[segment_index].distance_to(points[segment_index + 1])
		var segment_progress: float = 0.0
		if segment_length > 0.0:
			segment_progress = clampf((target_distance - segment_start_distance) / segment_length, 0.0, 1.0)
		result.append(points[segment_index].lerp(points[segment_index + 1], segment_progress))
	return result


func _polyline_length(points: PackedVector2Array) -> float:
	var result: float = 0.0
	for index: int in range(1, points.size()):
		result += points[index - 1].distance_to(points[index])
	return result


func _clamp_to_drawing_area(point: Vector2) -> Vector2:
	return Vector2(
		clampf(point.x, 0.0, _drawing_area.size.x),
		clampf(point.y, 0.0, _drawing_area.size.y)
	)


func _play_rejection() -> void:
	signature_rejected.emit()
	_feedback_label.text = "The mark is incomplete. Trace it again."
	_user_stroke.default_color = Color("dc4747")
	if is_instance_valid(_feedback_tween):
		_feedback_tween.kill()
	_feedback_flash.self_modulate = Color("a91f2c")
	_feedback_flash.modulate.a = 0.0
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(_feedback_flash, ^"modulate:a", 0.32, 0.08)
	_feedback_tween.tween_property(_panel, ^"position:x", _panel_rest_position.x - 10.0, 0.04)
	_feedback_tween.tween_property(_panel, ^"position:x", _panel_rest_position.x + 8.0, 0.04)
	_feedback_tween.tween_property(_panel, ^"position:x", _panel_rest_position.x, 0.05)
	_feedback_tween.tween_property(_feedback_flash, ^"modulate:a", 0.0, 0.18)


func _play_acceptance() -> void:
	_accepted = true
	_feedback_label.text = "Service signed."
	_user_stroke.default_color = Color("9be5a1")
	if is_instance_valid(_feedback_tween):
		_feedback_tween.kill()
	_feedback_flash.self_modulate = Color("f5d982")
	_feedback_flash.modulate.a = 0.0
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(_feedback_flash, ^"modulate:a", 0.3, 0.1)
	_feedback_tween.parallel().tween_property(_panel, ^"scale", Vector2(1.025, 1.025), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(_feedback_flash, ^"modulate:a", 0.0, 0.18)
	_feedback_tween.parallel().tween_property(_panel, ^"scale", Vector2.ONE, 0.16)
	_feedback_tween.tween_property(
		_panel,
		^"position:y",
		_panel_rest_position.y + success_drop_distance,
		success_drop_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_feedback_tween.parallel().tween_property(
		_panel,
		^"modulate:a",
		0.0,
		success_drop_duration * 0.72
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_feedback_tween.tween_callback(_begin_station_transition)


func _begin_station_transition() -> void:
	_transition_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_transition_tween = create_tween()
	_transition_tween.tween_property(
		_transition_fade,
		^"modulate:a",
		1.0,
		fade_to_black_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await _transition_tween.finished
	if not is_inside_tree():
		return
	# Main starts the existing station cutscene while this scene-authored cover
	# is fully opaque. Revealing it afterward makes the new cutscene fade in.
	service_signed.emit()
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_transition_tween = create_tween()
	_transition_tween.tween_property(
		_transition_fade,
		^"modulate:a",
		0.0,
		fade_from_black_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await _transition_tween.finished
	if not is_inside_tree():
		return
	_transition_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key_event := event as InputEventKey
	if key_event != null and key_event.echo:
		return
	if event.is_action_pressed(&"service_action"):
		request_close()
		get_viewport().set_input_as_handled()
