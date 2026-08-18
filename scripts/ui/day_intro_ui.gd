class_name DayIntroUI
extends Control
## Full-black chapter card shown before the opening station vignette.

signal intro_finished

const INTRO_DURATION: float = 3.25
const FADE_IN_END: float = 0.85
const FADE_OUT_START: float = 2.25

@export_category("Scene Copy")
@export var day_title_template: String = "DAY %d"

var _elapsed: float = 0.0
var _day_number: int = 1
var _station_name: String = "Alderwick"
var _finished: bool = false

@onready var _content: VBoxContainer = %Content
@onready var _day_label: Label = %DayLabel
@onready var _station_label: Label = %StationLabel

func play_intro(day_number: int, station_name: String) -> void:
	_day_number = maxi(1, day_number)
	_station_name = station_name
	_elapsed = 0.0
	_finished = false
	_day_label.text = day_title_template % _day_number
	_station_label.text = _station_name.to_upper()
	show()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_fade()

func skip_intro() -> void:
	if visible:
		_finish_intro()

func _process(delta: float) -> void:
	_elapsed += delta
	_apply_fade()
	if _elapsed >= INTRO_DURATION:
		_finish_intro()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _elapsed < 0.5:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
		skip_intro()
		get_viewport().set_input_as_handled()

func _finish_intro() -> void:
	if _finished:
		return
	_finished = true
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()
	intro_finished.emit()

func _apply_fade() -> void:
	_content.modulate.a = _text_alpha()

func _text_alpha() -> float:
	if _elapsed < FADE_IN_END:
		return _ease_in_out(clampf(_elapsed / FADE_IN_END, 0.0, 1.0))
	if _elapsed > FADE_OUT_START:
		return _ease_in_out(clampf((INTRO_DURATION - _elapsed) / (INTRO_DURATION - FADE_OUT_START), 0.0, 1.0))
	return 1.0

func _ease_in_out(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)
