class_name ShiftReportUI
extends Control
## Day-end receipt and a retryable evaluation; no accumulated strikes.

signal continue_requested
signal main_menu_requested

@onready var _title: Label = %Title
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
	_title.text = "DAY %d — PAYCHECK" % day
	_correct.text = "%d × %d     +%d" % [award.correct_dropoffs, award.correct_rate, award.dropoff_reward]
	_wrong.text = "%d × %d     −%d" % [award.wrong_dropoffs, award.wrong_rate, award.wrong_deduction]
	_anomaly.text = "%d × %d     −%d" % [award.incorrect_anomalies, award.anomaly_rate, award.anomaly_deduction]
	_retained.text = "%d / %d   •   NO BONUS OR PENALTY" % [retained, anomaly_total]
	_net.text = "%d BLESSINGS" % int(award.net_earnings)
	_target.text = "%d BLESSINGS" % int(award.pass_target)
	var passed: bool = bool(award.passed)
	var difference: int = int(award.net_earnings) - int(award.pass_target)
	_result.text = "PASSED  •  %d above target" % difference if passed else "FAILED  •  %d below target" % -difference
	_result.modulate = Color("9ed8ae") if passed else Color("ee9d91")
	_payment.text = "%d Blessings added to your balance." % int(award.earned) if passed else "Restart this shift with your starting balance and supplies restored."
	_continue_button.text = "CONTINUE TO NIGHT MARKET" if passed else "RESTART SHIFT"
	var lines := PackedStringArray()
	for penalty: String in penalties:
		lines.append("• %s" % penalty)
	_breakdown.text = "\n".join(lines) if not lines.is_empty() else "No penalties issued."
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
