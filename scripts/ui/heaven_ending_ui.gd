class_name HeavenEndingUI
extends Control
## Five-day finale. The authored layers remain independent so rays, fog and MC
## can move without baking animation into the illustration.

signal credits_requested

@export_category("Music")
@export var music_track: StringName = &"ending_good"
@export var music_loops: bool = false
@export_range(0.1, 4.0, 0.05) var fade_in_seconds: float = 0.8
@export_range(0.5, 8.0, 0.05) var ascent_seconds: float = 4.2
@export_range(0.0, 8.0, 0.05) var paycheck_delay_seconds: float = 3.0
@export_range(0.1, 3.0, 0.05) var paycheck_reveal_seconds: float = 0.65
@export_range(0.1, 3.0, 0.05) var fade_out_seconds: float = 0.9

@onready var _scene_root: Control = %SceneRoot
@onready var _character_flight: Control = %CharacterFlight
@onready var _character_bob: Control = %CharacterBob
@onready var _paycheck_panel: PanelContainer = %PaycheckPanel
@onready var _summary: Label = %Summary
@onready var _continue_button: Button = %ContinueButton
@onready var _fade: ColorRect = %Fade

var _motion_time: float = 0.0
var _playing: bool = false
var _can_continue: bool = false
var _sequence_id: int = 0
var _flight_origin := Vector2.ZERO
var _panel_origin := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_flight_origin = _character_flight.position
	_panel_origin = _paycheck_panel.position
	hide()
	set_process(false)


func play_ending(summary: Dictionary) -> void:
	_play_scene_music()
	_sequence_id += 1
	var sequence: int = _sequence_id
	_motion_time = 0.0
	_playing = true
	_can_continue = false
	_continue_button.disabled = true
	_summary.text = _format_summary(summary)
	show()
	_scene_root.modulate.a = 0.0
	_fade.color.a = 1.0
	_character_flight.position = Vector2(0.0, 215.0)
	_character_bob.position = Vector2.ZERO
	_character_bob.modulate.a = 0.0
	_paycheck_panel.position = _panel_origin + Vector2(430.0, 0.0)
	_paycheck_panel.modulate.a = 0.0
	set_process(true)

	var entrance := create_tween().set_parallel(true)
	entrance.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	entrance.tween_property(_fade, ^"color:a", 0.0, fade_in_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	entrance.tween_property(_scene_root, ^"modulate:a", 1.0, fade_in_seconds)
	entrance.tween_property(_character_bob, ^"modulate:a", 1.0, fade_in_seconds * 0.8)
	entrance.tween_property(_character_flight, ^"position", _flight_origin, ascent_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(paycheck_delay_seconds, true, false, true).timeout
	if sequence != _sequence_id or not visible:
		return
	var receipt := create_tween().set_parallel(true)
	receipt.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	receipt.tween_property(_paycheck_panel, ^"position", _panel_origin, paycheck_reveal_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	receipt.tween_property(_paycheck_panel, ^"modulate:a", 1.0, paycheck_reveal_seconds * 0.65)
	await receipt.finished
	if sequence != _sequence_id:
		return
	_can_continue = true
	_continue_button.disabled = false
	_continue_button.grab_focus()


func _play_scene_music() -> void:
	var music_manager := get_node_or_null("/root/MusicManager")
	if music_manager != null and music_manager.has_method(&"play"):
		music_manager.call(&"play", music_track, music_loops)


func _process(delta: float) -> void:
	if not _playing:
		return
	_motion_time += delta
	_character_bob.position = Vector2(
		sin(_motion_time * 0.73) * 4.0,
		sin(_motion_time * 1.14) * 7.0
	)
	_character_bob.rotation = deg_to_rad(sin(_motion_time * 0.62) * 1.2)


func _on_continue_pressed() -> void:
	if not _can_continue:
		return
	_can_continue = false
	_continue_button.disabled = true
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade, ^"color:a", 1.0, fade_out_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_playing = false
	credits_requested.emit()


func _format_summary(summary: Dictionary) -> String:
	return "DAYS COMPLETED     %d / 5\nSOULS DELIVERED    %d\nSOULS MISROUTED    %d\nANOMALIES HELD     %d\nNIGHT SOULS FREED  %d\n\nBLESSINGS EARNED   %d\nFINAL BALANCE      %d" % [
		int(summary.get("days_completed", 5)),
		int(summary.get("correct_dropoffs", 0)),
		int(summary.get("wrong_dropoffs", 0)),
		int(summary.get("anomalies_retained", 0)),
		int(summary.get("souls_released", 0)),
		int(summary.get("blessings_earned", 0)),
		int(summary.get("blessing_balance", 0)),
	]
