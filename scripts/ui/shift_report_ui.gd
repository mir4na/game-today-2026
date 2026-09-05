class_name ShiftReportUI
extends Control
## Day-end receipt and a retryable evaluation; no accumulated strikes.

signal continue_requested
signal main_menu_requested

@export_category("Receipt Copy")
@export var subtitle_template: String
@export var reward_template: String
@export var deduction_template: String
@export var retained_template: String
@export var amount_template: String
@export var penalty_line_template: String
@export_multiline var no_penalties_text: String
@export_category("Passed Result")
@export var passed_result_template: String
@export var passed_result_color: Color
@export_multiline var passed_payment_template: String
@export var passed_button_text: String
@export_category("Failed Result")
@export var failed_result_template: String
@export var failed_result_color: Color
@export_multiline var failed_payment_text: String
@export var failed_button_text: String

@onready var _subtitle: Label = %Subtitle
@onready var _correct: Label = %CorrectValue
@onready var _wrong: Label = %WrongValue
@onready var _anomaly: Label = %AnomalyValue
@onready var _retained: Label = %RetainedValue
@onready var _net: Label = %NetValue
@onready var _target: Label = %TargetValue
@onready var _result: Label = %ResultLabel
@onready var _payment: Label = %PaymentLabel
@onready var _breakdown: RichTextLabel = %Breakdown
@onready var _continue_button: Button = %ContinueButton
var _continue_sent: bool = false

func open_report(day: int, retained: int, anomaly_total: int, penalties: PackedStringArray, award: Dictionary) -> void:
	_continue_sent = false
	_subtitle.text = subtitle_template % day
	_correct.text = reward_template % [award.correct_dropoffs, award.correct_rate, award.dropoff_reward]
	_wrong.text = deduction_template % [award.wrong_dropoffs, award.wrong_rate, award.wrong_deduction]
	_anomaly.text = deduction_template % [award.incorrect_anomalies, award.anomaly_rate, award.anomaly_deduction]
	_retained.text = retained_template % [retained, anomaly_total]
	_net.text = amount_template % int(award.net_earnings)
	_target.text = amount_template % int(award.pass_target)
	var passed: bool = bool(award.passed)
	var difference: int = int(award.net_earnings) - int(award.pass_target)
	_result.text = passed_result_template % difference if passed else failed_result_template % -difference
	_result.add_theme_color_override(&"font_color", passed_result_color if passed else failed_result_color)
	_payment.text = passed_payment_template % int(award.earned) if passed else failed_payment_text
	_continue_button.text = passed_button_text if passed else failed_button_text
	var lines := PackedStringArray()
	for penalty: String in penalties:
		lines.append(penalty_line_template % penalty)
	_breakdown.text = "\n".join(lines) if not lines.is_empty() else no_penalties_text
	_breakdown.scroll_to_line(0)
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

func _on_main_menu_pressed() -> void:
	if _continue_sent:
		return
	_continue_sent = true
	main_menu_requested.emit()
