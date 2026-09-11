class_name NightTransitionCutsceneUI
extends Control
## Scene-authored passage through the veil before the nightly assignment shift.

signal veil_crossed
signal whiteout_reached
signal departure_follow_requested
signal camera_return_requested
signal camera_return_completed
signal exterior_fade_requested
signal exterior_fade_completed
signal sequence_timeline_changed(elapsed: float)
signal sequence_finished

@export var transition_animation: StringName = &"transition"
@export_range(0.0, 30.0, 0.05) var veil_crossing_time: float = 5.25
@export_category("Market Whiteout")
@export_range(0.0, 5.0, 0.05) var pre_market_white_hold_seconds: float = 1.0
@export_range(0.0, 5.0, 0.05) var white_screen_hold_seconds: float = 1.0
@export_range(0.1, 3.0, 0.05) var post_market_fade_seconds: float = 1.15
@export_range(0.0, 5.0, 0.05) var night_reveal_hold_seconds: float = 1.0
@export_range(0.0, 5.0, 0.05) var exterior_hold_after_zoom_seconds: float = 1.0
@export_range(0.1, 2.0, 0.05) var market_bar_fade_seconds: float = 0.5
@export_range(0.1, 2.0, 0.05) var closing_bar_fade_seconds: float = 0.6
@export_range(0.0, 10.0, 0.05) var skip_unlock_seconds: float = 1.5
@export_category("Station Train Motion")
@export_range(0.0, 10.0, 0.05) var departure_start_time: float = 0.45
@export_range(0.0, 10.0, 0.05) var departure_follow_time: float = 0.65
@export_range(0.0, 10.0, 0.05) var station_fade_start_time: float = 1.2
@export_range(0.0, 10.0, 0.05) var station_fade_end_time: float = 3.2
@export_range(0.0, 1.0, 0.01) var veil_departure_progress: float = 0.58
@export_range(0.0, 10.0, 0.05) var departure_end_time: float = 8.35
@export_range(0.0, 10.0, 0.05) var camera_return_time: float = 8.55

@onready var _animation_player: AnimationPlayer = %TransitionAnimation
@onready var _backdrop_tint: ColorRect = $BackdropTint
@onready var _fog_back: ColorRect = $FogBack
@onready var _fog_front: ColorRect = $FogFront
@onready var _veil_flash: ColorRect = $VeilFlash
@onready var _top_bar: ColorRect = $TopBar
@onready var _bottom_bar: ColorRect = $BottomBar

var _elapsed: float = 0.0
var _veil_crossed: bool = false
var _departure_follow_requested: bool = false
var _camera_return_requested: bool = false
var _finished: bool = false
var _market_whiteout_active: bool = false
var _whiteout_reached_emitted: bool = false
var _resuming_after_market: bool = false
var _camera_return_completed: bool = false
var _exterior_fade_completed: bool = false
var _bar_tween: Tween


func _ready() -> void:
	set_process(false)


func play_transition() -> void:
	_elapsed = 0.0
	_veil_crossed = false
	_departure_follow_requested = false
	_camera_return_requested = false
	_finished = false
	_market_whiteout_active = false
	_whiteout_reached_emitted = false
	_resuming_after_market = false
	_camera_return_completed = false
	_exterior_fade_completed = false
	if is_instance_valid(_bar_tween) and _bar_tween.is_valid():
		_bar_tween.kill()
	show()
	set_process(true)
	_animation_player.play(&"RESET")
	_animation_player.advance(0.0)
	_animation_player.play(transition_animation)
	sequence_timeline_changed.emit(_elapsed)


func _process(delta: float) -> void:
	_elapsed += delta
	sequence_timeline_changed.emit(_elapsed)
	if not _departure_follow_requested and _elapsed >= departure_follow_time:
		_emit_departure_follow_requested()
	if not _veil_crossed and _elapsed >= veil_crossing_time:
		_hold_at_market_whiteout()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _elapsed < skip_unlock_seconds:
		return
	if event.is_action_pressed(&"ui_cancel"):
		skip_sequence()
		get_viewport().set_input_as_handled()


func skip_sequence() -> void:
	if _finished or _market_whiteout_active:
		return
	_animation_player.stop()
	_elapsed = maxf(_elapsed, veil_crossing_time)
	_animation_player.seek(veil_crossing_time, true)
	sequence_timeline_changed.emit(_elapsed)
	_emit_departure_follow_requested()
	_hold_at_market_whiteout()


func resume_after_market() -> void:
	if _finished or not _market_whiteout_active or _resuming_after_market:
		return
	_resuming_after_market = true
	_exterior_fade_completed = false
	# The second cutscene plays with cinematic bars again. They fade in over
	# the white screen, so the market-to-cutscene handoff stays seamless.
	_fade_bars(1.0, market_bar_fade_seconds)
	if white_screen_hold_seconds > 0.0:
		await get_tree().create_timer(white_screen_hold_seconds).timeout
	if _finished or not is_inside_tree():
		return
	var reveal := create_tween().set_parallel(true)
	reveal.tween_property(_veil_flash, ^"self_modulate:a", 0.0, post_market_fade_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal.tween_property(_fog_back, ^"self_modulate:a", 0.0, post_market_fade_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal.tween_property(_fog_front, ^"self_modulate:a", 0.0, post_market_fade_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal.tween_property(_backdrop_tint, ^"self_modulate:a", 0.0, post_market_fade_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await reveal.finished
	# Let the night carriage settle in its normal framing before the camera moves
	# toward the player. The exterior remains onscreen for the full handoff.
	if night_reveal_hold_seconds > 0.0:
		await get_tree().create_timer(night_reveal_hold_seconds).timeout
	if _finished or not is_inside_tree():
		return
	_emit_camera_return_requested()
	# The exterior fades during the final camera push-in, so it is fully
	# gone the moment gameplay takes over. No extra beat is added.
	exterior_fade_requested.emit()
	if not _camera_return_completed:
		await camera_return_completed
	if not _exterior_fade_completed:
		await exterior_fade_completed
	if _finished or not is_inside_tree():
		return
	if exterior_hold_after_zoom_seconds > 0.0:
		await get_tree().create_timer(exterior_hold_after_zoom_seconds).timeout
	if _finished or not is_inside_tree():
		return
	# Cutscene-style ending: the bars ease out last. The UI hides only
	# after they are fully gone, so nothing pops.
	_fade_bars(0.0, closing_bar_fade_seconds)
	if is_instance_valid(_bar_tween) and _bar_tween.is_valid():
		await _bar_tween.finished
	if _finished or not is_inside_tree():
		return
	_elapsed = maxf(_elapsed, departure_end_time)
	sequence_timeline_changed.emit(_elapsed)
	_finish_sequence()


func notify_camera_return_completed() -> void:
	if _camera_return_completed:
		return
	_camera_return_completed = true
	camera_return_completed.emit()


func notify_exterior_fade_finished() -> void:
	if _exterior_fade_completed:
		return
	_exterior_fade_completed = true
	exterior_fade_completed.emit()


func _fade_bars(target_alpha: float, duration: float) -> void:
	if is_instance_valid(_bar_tween) and _bar_tween.is_valid():
		_bar_tween.kill()
	_bar_tween = create_tween().set_parallel(true)
	_bar_tween.tween_property(
		_top_bar, ^"self_modulate:a", clampf(target_alpha, 0.0, 1.0), maxf(duration, 0.05)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bar_tween.tween_property(
		_bottom_bar, ^"self_modulate:a", clampf(target_alpha, 0.0, 1.0), maxf(duration, 0.05)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_transition_animation_finished(animation_name: StringName) -> void:
	if animation_name == transition_animation:
		_finish_sequence()


func _emit_veil_crossed() -> void:
	if _veil_crossed:
		return
	_veil_crossed = true
	veil_crossed.emit()


func _hold_at_market_whiteout() -> void:
	if _market_whiteout_active:
		return
	_market_whiteout_active = true
	_elapsed = maxf(_elapsed, veil_crossing_time)
	_animation_player.pause()
	# The market sits behind a true full-screen whiteout. The cinematic bars
	# ease out instead of snapping away, like a cutscene ending.
	_fade_bars(0.0, market_bar_fade_seconds)
	set_process(false)
	_emit_veil_crossed()
	_emit_whiteout_reached_after_hold()


func _emit_whiteout_reached_after_hold() -> void:
	if _whiteout_reached_emitted:
		return
	_whiteout_reached_emitted = true
	if pre_market_white_hold_seconds > 0.0:
		await get_tree().create_timer(pre_market_white_hold_seconds).timeout
	if _finished or not _market_whiteout_active or not is_inside_tree():
		return
	whiteout_reached.emit()


func _emit_departure_follow_requested() -> void:
	if _departure_follow_requested:
		return
	_departure_follow_requested = true
	departure_follow_requested.emit()


func _emit_camera_return_requested() -> void:
	if _camera_return_requested:
		return
	_camera_return_requested = true
	camera_return_requested.emit()


func get_station_departure_progress() -> float:
	var crossing_time: float = maxf(veil_crossing_time, departure_start_time + 0.01)
	var finish_time: float = maxf(departure_end_time, crossing_time + 0.01)
	if _elapsed <= departure_start_time:
		return 0.0
	if _elapsed <= crossing_time:
		var approach: float = clampf(
			inverse_lerp(departure_start_time, crossing_time, _elapsed),
			0.0,
			1.0
		)
		return _ease_in_out_sine(approach) * veil_departure_progress
	var exit_progress: float = clampf(
		inverse_lerp(crossing_time, finish_time, _elapsed),
		0.0,
		1.0
	)
	return lerpf(
		veil_departure_progress,
		1.0,
		_ease_in_out_sine(exit_progress)
	)


func get_station_environment_alpha() -> float:
	var fade_start: float = minf(station_fade_start_time, station_fade_end_time)
	var fade_end: float = maxf(station_fade_start_time, station_fade_end_time)
	if _elapsed <= fade_start:
		return 1.0
	if _elapsed >= fade_end:
		return 0.0
	var progress: float = inverse_lerp(fade_start, maxf(fade_end, fade_start + 0.001), _elapsed)
	return 1.0 - _ease_in_out_sine(progress)


func _finish_sequence() -> void:
	if _finished:
		return
	_finished = true
	_elapsed = maxf(_elapsed, departure_end_time)
	sequence_timeline_changed.emit(_elapsed)
	_emit_departure_follow_requested()
	_emit_veil_crossed()
	_emit_camera_return_requested()
	set_process(false)
	hide()
	sequence_finished.emit()


func _ease_in_out_sine(value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	return -(cos(PI * clamped) - 1.0) * 0.5
