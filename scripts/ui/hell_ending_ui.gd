class_name HellEndingUI
extends Control
## Failed-paycheck ending. Choices appear only after the fall and scene dimming.

signal retry_requested
signal main_menu_requested

@export_category("Music")
@export var music_track: StringName = &"ending_bad"
@export var music_loops: bool = false
@export_range(0.1, 4.0, 0.05) var fade_in_seconds: float = 0.65
@export_range(0.5, 8.0, 0.05) var fall_seconds: float = 2.8
@export_range(0.0, 8.0, 0.05) var choice_delay_seconds: float = 2.4
@export_range(0.1, 3.0, 0.05) var fade_out_seconds: float = 0.75

@onready var _scene_root: Control = %SceneRoot
@onready var _character_fall: Control = %CharacterFall
@onready var _character_bob: Control = %CharacterBob
@onready var _front_fire: TextureRect = %FrontFire
@onready var _back_fire: TextureRect = %BackFire
@onready var _darkness: ColorRect = %Darkness
@onready var _choice_panel: PanelContainer = %ChoicePanel
@onready var _reason: Label = %Reason
@onready var _retry_button: Button = %RetryButton
@onready var _menu_button: Button = %MenuButton
@onready var _fade: ColorRect = %Fade

var _motion_time: float = 0.0
var _playing: bool = false
var _can_choose: bool = false
var _sequence_id: int = 0
var _fall_origin := Vector2.ZERO
var _panel_origin := Vector2.ZERO
var _front_fire_origin := Vector2.ZERO
var _back_fire_origin := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fall_origin = _character_fall.position
	_panel_origin = _choice_panel.position
	_front_fire_origin = _front_fire.position
	_back_fire_origin = _back_fire.position
	hide()
	set_process(false)


func play_ending(reason: String, paycheck: int = 0, required: int = 0) -> void:
	_play_scene_music()
	_sequence_id += 1
	var sequence: int = _sequence_id
	_motion_time = 0.0
	_playing = true
	_can_choose = false
	_retry_button.disabled = true
	_menu_button.disabled = true
	_reason.text = _format_reason(reason, paycheck, required)
	show()
	_scene_root.modulate.a = 0.0
	_fade.color.a = 1.0
	_darkness.color.a = 0.0
	_character_fall.position = _fall_origin + Vector2(0.0, -290.0)
	_character_fall.rotation = deg_to_rad(-14.0)
	_character_bob.position = Vector2.ZERO
	_choice_panel.position = _panel_origin + Vector2(0.0, 210.0)
	_choice_panel.modulate.a = 0.0
	set_process(true)

	var entrance := create_tween().set_parallel(true)
	entrance.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	entrance.tween_property(_fade, ^"color:a", 0.0, fade_in_seconds)
	entrance.tween_property(_scene_root, ^"modulate:a", 1.0, fade_in_seconds)
	entrance.tween_property(_character_fall, ^"position", _fall_origin, fall_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	entrance.tween_property(_character_fall, ^"rotation", 0.0, fall_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(choice_delay_seconds, true, false, true).timeout
	if sequence != _sequence_id or not visible:
		return
	var reveal := create_tween().set_parallel(true)
	reveal.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal.tween_property(_darkness, ^"color:a", 0.46, 0.7)
	reveal.tween_property(_choice_panel, ^"position", _panel_origin, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(_choice_panel, ^"modulate:a", 1.0, 0.45)
	await reveal.finished
	if sequence != _sequence_id:
		return
	_can_choose = true
	_retry_button.disabled = false
	_menu_button.disabled = false
	_retry_button.grab_focus()


func _play_scene_music() -> void:
	var music_manager := get_node_or_null("/root/MusicManager")
	if music_manager != null and music_manager.has_method(&"play"):
		music_manager.call(&"play", music_track, music_loops)


func _process(delta: float) -> void:
	if not _playing:
		return
	_motion_time += delta
	_character_bob.position = Vector2(
		sin(_motion_time * 0.82) * 8.0,
		sin(_motion_time * 1.27) * 10.0
	)
	_character_bob.rotation = deg_to_rad(sin(_motion_time * 0.68) * 2.2)
	_front_fire.position = _front_fire_origin + Vector2(sin(_motion_time * 0.9) * 4.0, sin(_motion_time * 1.8) * 3.0)
	_back_fire.position = _back_fire_origin + Vector2(sin(_motion_time * 0.72 + 1.1) * 3.0, sin(_motion_time * 1.35) * 2.0)


func _on_retry_pressed() -> void:
	_choose(true)


func _on_menu_pressed() -> void:
	_choose(false)


func _choose(retry: bool) -> void:
	if not _can_choose:
		return
	_can_choose = false
	_retry_button.disabled = true
	_menu_button.disabled = true
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade, ^"color:a", 1.0, fade_out_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_playing = false
	if retry:
		retry_requested.emit()
	else:
		main_menu_requested.emit()


func _format_reason(reason: String, paycheck: int, required: int) -> String:
	var details: String = reason
	if required > 0:
		details += "\nPAYCHECK  %d / %d BLESSINGS" % [paycheck, required]
	return details
