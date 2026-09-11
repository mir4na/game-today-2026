class_name ShiftReportUI
extends Control
## Day-end receipt and a retryable evaluation; no accumulated strikes.

signal continue_requested

@export_category("Receipt Copy")
@export var subtitle_template: String
@export var reward_template: String
@export var deduction_template: String
@export var retained_template: String
@export var amount_template: String
@export var penalty_line_template: String = "• %s"
@export_multiline var no_penalties_text: String = "No penalties issued."
@export_category("Passed Result")
@export var passed_result_template: String
@export var debug_passed_result_text: String = "PASSED  •  TRANSITION PREVIEW"
@export var passed_result_color: Color
@export_multiline var passed_payment_template: String
@export var passed_continue_text: String
@export_category("Failed Result")
@export var failed_result_template: String
@export var failed_result_color: Color
@export_multiline var failed_payment_text: String
@export var failed_continue_text: String
@export_category("Night Paycheck Copy")
@export var night_title_text: String = "PAYCHECK"
@export var night_subtitle_template: String = "NIGHT SHIFT • DAY %d"
@export var night_souls_caption: String = "CORRECT ASSIGNMENTS"
@export var night_information_caption: String = "SOUL RECORDS FOUND"
@export var night_missing_caption: String = "WRONG / MISSING"
@export var night_route_caption: String = "ASSIGNMENT RESULT"
@export var night_detail_title: String = "EARNINGS BREAKDOWN"
@export var night_net_caption: String = "NIGHT TOTAL"
@export var night_balance_caption: String = "CURRENT BALANCE"
@export var night_result_passed_text: String = "NIGHT SHIFT COMPLETE"
@export var night_result_incomplete_text: String = "NIGHT SHIFT INCOMPLETE"
@export var night_payment_template: String = "%d Blessings added from Night Service."
@export_multiline var night_earnings_breakdown_template: String = "• %d correct assignment(s) × %d = %d Blessings\n• %d Soul Record(s) × %d = %d Blessings"
@export var night_records_template: String = "Records: %s"
@export var night_no_records_text: String = "Records: none"
@export_category("Typewriter")
@export var typewriter_target_paths: Array[NodePath] = []
@export_range(20.0, 600.0, 5.0) var typewriter_characters_per_second: float = 180.0
@export_range(0.0, 0.5, 0.01) var typewriter_line_pause_seconds: float = 0.04
@export_range(0.1, 3.0, 0.05) var maximum_target_duration_seconds: float = 1.25
@export_range(0.0, 1.0, 0.05) var input_lock_seconds: float = 0.35
@export_category("Presentation")
@export_node_path("AnimationPlayer") var presentation_player_path: NodePath
@export var presentation_animation: StringName = &"present"

@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _correct_caption: Label = %CorrectCaption
@onready var _correct: Label = %CorrectValue
@onready var _wrong_caption: Label = %WrongCaption
@onready var _wrong: Label = %WrongValue
@onready var _anomaly_caption: Label = %AnomalyCaption
@onready var _anomaly: Label = %AnomalyValue
@onready var _retained_caption: Label = %RetainedCaption
@onready var _retained: Label = %RetainedValue
@onready var _detail_title: Label = %DetailTitle
@onready var _net: Label = %NetValue
@onready var _net_caption: Label = %NetCaption
@onready var _target: Label = %TargetValue
@onready var _target_caption: Label = %TargetCaption
@onready var _result: Label = %ResultLabel
@onready var _payment: Label = %PaymentLabel
@onready var _breakdown: RichTextLabel = %Breakdown
@onready var _continue_hint: Label = %ContinueHint
@onready var _hint_animation: AnimationPlayer = %HintAnimation
@onready var _presentation_player: AnimationPlayer = get_node_or_null(presentation_player_path) as AnimationPlayer

var _continue_sent: bool = false
var _typewriter_targets: Array[Control] = []
var _typewriter_index: int = 0
var _typewriter_characters: float = 0.0
var _typewriter_pause_remaining: float = 0.0
var _typewriter_running: bool = false
var _input_lock_remaining: float = 0.0
var _external_input_locked: bool = false
var _day_receipt_copy: Dictionary = {}


func _ready() -> void:
	_day_receipt_copy = {
		"title": _title.text,
		"correct_caption": _correct_caption.text,
		"wrong_caption": _wrong_caption.text,
		"anomaly_caption": _anomaly_caption.text,
		"retained_caption": _retained_caption.text,
		"detail_title": _detail_title.text,
		"net_caption": _net_caption.text,
		"target_caption": _target_caption.text,
	}
	for target_path: NodePath in typewriter_target_paths:
		var target: Control = get_node_or_null(target_path) as Control
		if target != null and (target is Label or target is RichTextLabel):
			_typewriter_targets.append(target)
	set_process(false)

func open_report(day: int, retained: int, anomaly_total: int, penalties: PackedStringArray, award: Dictionary) -> void:
	GameSFX.play(&"paper_rustle", -7.0, 0.98, 0.02, 0.1)
	_continue_sent = false
	_restore_day_receipt_copy()
	_subtitle.text = subtitle_template % day
	_correct.text = reward_template % int(award.dropoff_reward)
	_wrong.text = deduction_template % int(award.wrong_deduction)
	_anomaly.text = deduction_template % int(award.anomaly_deduction)
	_retained.text = retained_template % [retained, anomaly_total]
	_net.text = amount_template % int(award.net_earnings)
	_target.text = amount_template % int(award.pass_target)
	var passed: bool = bool(award.passed)
	var difference: int = int(award.net_earnings) - int(award.pass_target)
	if bool(award.get("debug_pass_override", false)):
		_result.text = debug_passed_result_text
	else:
		_result.text = passed_result_template % difference if passed else failed_result_template % -difference
	_result.add_theme_color_override(&"font_color", passed_result_color if passed else failed_result_color)
	_payment.text = passed_payment_template % int(award.earned) if passed else failed_payment_text
	_continue_hint.text = passed_continue_text if passed else failed_continue_text
	var lines := PackedStringArray()
	for penalty: String in penalties:
		lines.append(penalty_line_template % penalty)
	_breakdown.text = "\n".join(lines) if not lines.is_empty() else no_penalties_text
	_breakdown.scroll_to_line(0)
	show()
	_present()
	_start_typewriter()


func open_night_report(day: int, soul_total: int, award: Dictionary, balance: int) -> void:
	_continue_sent = false
	_title.text = night_title_text
	_subtitle.text = night_subtitle_template % day
	var correct_count: int = int(award.get("correct_night_dropoffs", 0))
	var information_count: int = int(award.get("information_found", 0))
	var missing_count: int = maxi(
		int(award.get("incorrect_or_missing_assignments", soul_total)),
		soul_total - information_count
	)
	var assignment_succeeded: bool = bool(award.get("assignment_succeeded", false))
	var paycheck_passed: bool = bool(award.get("passed", assignment_succeeded))
	_correct_caption.text = "%s  (%d/%d)" % [night_souls_caption, correct_count, soul_total]
	_correct.text = reward_template % int(award.get("assignment_reward", 0))
	_wrong_caption.text = night_information_caption
	_wrong.text = reward_template % int(award.get("information_reward", 0))
	_anomaly_caption.text = night_missing_caption
	_anomaly.text = str(missing_count)
	_anomaly.add_theme_color_override(&"font_color", Color("333340"))
	_retained_caption.text = night_route_caption
	_retained.text = "ALIGNED" if assignment_succeeded else "INCOMPLETE"
	_detail_title.text = night_detail_title
	var information_names: Array = award.get("information_names", []) as Array
	var records_line: String = (
		night_records_template % ", ".join(PackedStringArray(information_names))
		if not information_names.is_empty()
		else night_no_records_text
	)
	_breakdown.text = night_earnings_breakdown_template % [
		correct_count,
		int(award.get("correct_rate", 0)),
		int(award.get("assignment_reward", 0)),
		information_count,
		int(award.get("information_rate", 0)),
		int(award.get("information_reward", 0)),
	]
	_breakdown.text += "\n" + records_line
	_breakdown.scroll_to_line(0)
	_net_caption.text = night_net_caption
	_net.text = amount_template % int(award.get("earned", 0))
	_target_caption.text = "REQUIRED TO PASS"
	_target.text = amount_template % int(award.get("pass_target", maxi(0, balance)))
	_result.text = night_result_passed_text if paycheck_passed else night_result_incomplete_text
	_result.add_theme_color_override(&"font_color", passed_result_color if paycheck_passed else failed_result_color)
	_payment.text = night_payment_template % int(award.get("earned", 0))
	_continue_hint.text = passed_continue_text if paycheck_passed else failed_continue_text
	show()
	_present()
	_start_typewriter()


func _restore_day_receipt_copy() -> void:
	_title.text = str(_day_receipt_copy.get("title", "PAYCHECK"))
	_correct_caption.text = str(_day_receipt_copy.get("correct_caption", "CORRECT DROP-OFFS"))
	_wrong_caption.text = str(_day_receipt_copy.get("wrong_caption", "WRONG DROP-OFFS"))
	_anomaly_caption.text = str(_day_receipt_copy.get("anomaly_caption", "ANOMALY STAMPS"))
	_retained_caption.text = str(_day_receipt_copy.get("retained_caption", "ANOMALIES RETAINED"))
	_detail_title.text = str(_day_receipt_copy.get("detail_title", "PENALTY DETAILS"))
	_net_caption.text = str(_day_receipt_copy.get("net_caption", "NET TOTAL"))
	_target_caption.text = str(_day_receipt_copy.get("target_caption", "REQUIRED TO PASS"))
	_anomaly.add_theme_color_override(&"font_color", failed_result_color)


func _present() -> void:
	if not is_instance_valid(_presentation_player):
		push_warning("Shift Report UI has no Inspector-configured presentation AnimationPlayer.")
		return
	if not _presentation_player.has_animation(presentation_animation):
		push_warning("Shift Report UI presentation animation '%s' was not found." % presentation_animation)
		return
	_presentation_player.stop()
	_presentation_player.play(presentation_animation)
	_presentation_player.advance(0.0)


func _process(delta: float) -> void:
	_input_lock_remaining = maxf(0.0, _input_lock_remaining - delta)
	if not _typewriter_running:
		if _input_lock_remaining <= 0.0:
			set_process(false)
		return
	if _typewriter_pause_remaining > 0.0:
		_typewriter_pause_remaining = maxf(0.0, _typewriter_pause_remaining - delta)
		return
	if _typewriter_index >= _typewriter_targets.size():
		_finish_typewriter()
		return
	var target: Control = _typewriter_targets[_typewriter_index]
	var total_characters: int = _get_total_characters(target)
	if total_characters <= 0:
		_advance_typewriter_target()
		return
	var effective_speed: float = maxf(
		typewriter_characters_per_second,
		float(total_characters) / maxf(maximum_target_duration_seconds, 0.1)
	)
	_typewriter_characters = minf(float(total_characters), _typewriter_characters + effective_speed * delta)
	_set_visible_characters(target, floori(_typewriter_characters))
	if _typewriter_characters >= float(total_characters):
		_advance_typewriter_target()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _external_input_locked or not _is_continue_input(event):
		return
	get_viewport().set_input_as_handled()
	if _input_lock_remaining > 0.0:
		return
	if _typewriter_running:
		_finish_typewriter()
		return
	_request_continue()


func set_external_input_locked(value: bool) -> void:
	_external_input_locked = value

func _request_continue() -> void:
	if _continue_sent or _typewriter_running:
		return
	_continue_sent = true
	GameSFX.stop_loop(&"shift_report_typewriter")
	continue_requested.emit()


func _start_typewriter() -> void:
	_typewriter_index = 0
	_typewriter_characters = 0.0
	_typewriter_pause_remaining = 0.0
	_typewriter_running = not _typewriter_targets.is_empty()
	_input_lock_remaining = input_lock_seconds
	_continue_hint.hide()
	_hint_animation.stop()
	for target: Control in _typewriter_targets:
		_set_visible_characters(target, 0)
	if not _typewriter_running:
		_finish_typewriter()
	else:
		GameSFX.start_loop(&"shift_report_typewriter", &"typewriter", -16.0, 1.0)
		set_process(true)


func _advance_typewriter_target() -> void:
	if _typewriter_index < _typewriter_targets.size():
		_set_visible_characters(_typewriter_targets[_typewriter_index], -1)
	_typewriter_index += 1
	_typewriter_characters = 0.0
	_typewriter_pause_remaining = typewriter_line_pause_seconds
	if _typewriter_index >= _typewriter_targets.size():
		_finish_typewriter()


func _finish_typewriter() -> void:
	GameSFX.stop_loop(&"shift_report_typewriter")
	for target: Control in _typewriter_targets:
		_set_visible_characters(target, -1)
	_typewriter_index = _typewriter_targets.size()
	_typewriter_running = false
	_typewriter_pause_remaining = 0.0
	_continue_hint.show()
	_hint_animation.play(&"blink")
	set_process(_input_lock_remaining > 0.0)


func _exit_tree() -> void:
	GameSFX.stop_loop(&"shift_report_typewriter")


func _get_total_characters(target: Control) -> int:
	if target is Label:
		return (target as Label).get_total_character_count()
	if target is RichTextLabel:
		return (target as RichTextLabel).get_total_character_count()
	return 0


func _set_visible_characters(target: Control, count: int) -> void:
	if target is Label:
		(target as Label).visible_characters = count
	elif target is RichTextLabel:
		(target as RichTextLabel).visible_characters = count


func _is_continue_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index in [
			MOUSE_BUTTON_WHEEL_UP,
			MOUSE_BUTTON_WHEEL_DOWN,
			MOUSE_BUTTON_WHEEL_LEFT,
			MOUSE_BUTTON_WHEEL_RIGHT,
		]:
			return false
		return mouse_event.pressed
	return false
