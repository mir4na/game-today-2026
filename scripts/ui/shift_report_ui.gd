class_name ShiftReportUI
extends Control
## Day-end performance summary shown before the train enters night service.

signal continue_requested

@export_category("Inspector Copy")
@export var correct_drop_off_template: String
@export var correct_anomaly_template: String
@export var penalty_total_template: String
@export var blessings_earned_template: String
@export var reward_breakdown_template: String
@export var penalty_entry_template: String
@export_multiline var no_penalties_text: String

@onready var _correct_drop_off_label: Label = %CorrectDropOffValue
@onready var _correct_anomaly_label: Label = %CorrectAnomalyValue
@onready var _penalty_label: Label = %PenaltyValue
@onready var _blessings_earned_label: Label = %BlessingsEarnedValue
@onready var _reward_breakdown_label: Label = %RewardBreakdown
@onready var _breakdown: RichTextLabel = %Breakdown
@onready var _continue_button: Button = %ContinueButton
var _continue_sent: bool = false

func open_report(
	correct_drop_offs: int,
	correct_anomalies: int,
	penalty_points: int,
	penalties: PackedStringArray,
	day_award: Dictionary
) -> void:
	_continue_sent = false
	_correct_drop_off_label.text = correct_drop_off_template % correct_drop_offs
	_correct_anomaly_label.text = correct_anomaly_template % correct_anomalies
	_penalty_label.text = penalty_total_template % penalty_points
	_blessings_earned_label.text = blessings_earned_template % int(day_award.get("earned", 0))
	_reward_breakdown_label.text = reward_breakdown_template % [
		int(day_award.get("dropoff_reward", 0)),
		int(day_award.get("anomaly_reward", 0)),
		int(day_award.get("penalty_deduction", 0)),
	]
	var lines := PackedStringArray()
	for penalty: String in penalties:
		lines.append(penalty_entry_template % penalty)
	_breakdown.text = "\n".join(lines) if not lines.is_empty() else no_penalties_text
	show()
	_continue_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"interact")):
		_request_continue()
		get_viewport().set_input_as_handled()

func _on_continue_button_pressed() -> void:
	_request_continue()

func _request_continue() -> void:
	if _continue_sent:
		return
	_continue_sent = true
	continue_requested.emit()
