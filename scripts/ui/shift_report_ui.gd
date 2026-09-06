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
@onready var _receipt_stack: Control = %ReceiptStack
@onready var _shade: ColorRect = %Shade
var _continue_sent: bool = false
var _open_tween: Tween

func open_report(day: int, retained: int, anomaly_total: int, penalties: PackedStringArray, award: Dictionary) -> void:
	_continue_sent = false
	_title.text = "SHIFT %d  /  PASSENGER SERVICE" % day
	_correct.text = "%d × %d     +%d" % [award.correct_dropoffs, award.correct_rate, award.dropoff_reward]
	_wrong.text = "%d × %d     -%d" % [award.wrong_dropoffs, award.wrong_rate, award.wrong_deduction]
	_anomaly.text = "%d × %d     -%d" % [award.incorrect_anomalies, award.anomaly_rate, award.anomaly_deduction]
	_retained.text = "%d / %d" % [retained, anomaly_total]
	_net.text = "%d BLESSINGS" % int(award.net_earnings)
	_target.text = "%d BLESSINGS" % int(award.pass_target)
	var passed: bool = bool(award.passed)
	var difference: int = int(award.net_earnings) - int(award.pass_target)
	_result.text = "SHIFT APPROVED  •  +%d" % difference if passed else "PAYCHECK DECLINED  •  -%d" % -difference
	_result.modulate = Color("638463") if passed else Color("b84c4c")
	_payment.text = "Target %d  •  %d Blessings deposited." % [int(award.pass_target), int(award.earned)] if passed else "Target %d missed — this shift must be repeated." % int(award.pass_target)
	_continue_button.text = "CONTINUE TO NIGHT MARKET" if passed else "RESTART SHIFT"
	var lines := PackedStringArray()
	for penalty: String in penalties:
		lines.append("• %s" % penalty)
	_breakdown.text = "\n".join(lines) if not lines.is_empty() else "No penalties issued. Record is clean."
	_breakdown.scroll_to_line(0)
	show()
	_continue_button.grab_focus()
	_play_open_animation()

func _play_open_animation() -> void:
	if _open_tween and _open_tween.is_valid():
		_open_tween.kill()
	await get_tree().process_frame
	_receipt_stack.pivot_offset = _receipt_stack.size * 0.5
	_receipt_stack.scale = Vector2(0.88, 0.88)
	_receipt_stack.rotation = deg_to_rad(-2.2)
	_receipt_stack.modulate.a = 0.0
	_shade.modulate.a = 0.0
	_open_tween = create_tween().set_parallel(true)
	_open_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(_receipt_stack, "scale", Vector2.ONE, 0.38)
	_open_tween.tween_property(_receipt_stack, "rotation", 0.0, 0.42)
	_open_tween.tween_property(_receipt_stack, "modulate:a", 1.0, 0.18)
	_open_tween.tween_property(_shade, "modulate:a", 1.0, 0.22)

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
