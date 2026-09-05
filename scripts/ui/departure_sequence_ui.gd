class_name DepartureSequenceUI
extends Control

signal sequence_finished
signal journey_continue_requested

@export_category("Presentation")
@export var station_colors: Array[Color]
@export var atmosphere_lines: Array[String]
@export var completion_background: Color
@export var completion_title: String
@export var completion_passenger_text: String
@export var completion_atmosphere_text: String
@export var passenger_departure_template: String = "%s leaves the night train here."
@export var next_button_text: String = "NEXT NIGHT STOP"
@export var complete_button_text: String = "COMPLETE JOURNEY"
@export var journey_continue_button_text: String = "CONTINUE"
@export var blessing_reward_template: String = "+%d BLESSINGS\n%d CORRECT SOUL DROP-OFFS • BALANCE %d"

var _puzzle: DeparturePuzzleData
var _assignments: Dictionary
var _index: int = 0
var _complete_screen: bool = false
var _night_award: Dictionary = {}
var _blessing_balance: int = 0
@onready var _background: ColorRect = %Background
@onready var _station_label: Label = %StationLabel
@onready var _passenger_label: Label = %PassengerLabel
@onready var _atmosphere_label: Label = %AtmosphereLabel
@onready var _blessing_reward_label: Label = %BlessingRewardLabel
@onready var _continue_button: Button = %ContinueButton

func start_sequence(
	assignments: Dictionary,
	puzzle: DeparturePuzzleData,
	night_award: Dictionary = {},
	blessing_balance: int = 0
) -> void:
	_assignments = assignments.duplicate()
	_puzzle = puzzle
	_night_award = night_award.duplicate(true)
	_blessing_balance = maxi(0, blessing_balance)
	_index = 0
	_complete_screen = false
	show()
	_show_current_station()
	_continue_button.grab_focus()

func _show_current_station() -> void:
	var station: String = _puzzle.night_stations[_index]
	var passenger_name: String = _assignments[station]
	_background.color = station_colors[_index]
	_station_label.text = station.to_upper()
	_passenger_label.text = passenger_departure_template % passenger_name
	_atmosphere_label.text = atmosphere_lines[_index]
	_blessing_reward_label.hide()
	_continue_button.text = next_button_text if _index < _puzzle.night_stations.size() - 1 else complete_button_text
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)

func _advance() -> void:
	_index += 1
	if _index < _puzzle.night_stations.size():
		_show_current_station()
		return
	_show_complete()

func _show_complete() -> void:
	_background.color = completion_background
	_station_label.text = completion_title
	_passenger_label.text = completion_passenger_text
	_atmosphere_label.text = completion_atmosphere_text
	_blessing_reward_label.text = blessing_reward_template % [
		int(_night_award.get("earned", 0)),
		int(_night_award.get("correct_night_dropoffs", 0)),
		_blessing_balance,
	]
	_blessing_reward_label.show()
	_continue_button.text = journey_continue_button_text
	_complete_screen = true
	sequence_finished.emit()

func _on_continue_button_pressed() -> void:
	if _complete_screen:
		journey_continue_requested.emit()
	else:
		_advance()


func set_progress_result(day: int, day_count: int, saved: bool) -> void:
	if not saved:
		_atmosphere_label.text = "Progress could not be saved. Try again to continue."
		_continue_button.text = "RETRY SAVE"
		return
	if day >= day_count:
		_station_label.text = "JOURNEY COMPLETE"
		_atmosphere_label.text = "All %d days completed. Every shift brought them closer to home." % day_count
		_continue_button.text = "MAIN MENU"
	else:
		_station_label.text = "DAY %d COMPLETE" % day
		_continue_button.text = "BEGIN DAY %d" % (day + 1)
