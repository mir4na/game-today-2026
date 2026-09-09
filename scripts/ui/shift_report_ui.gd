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
@export var penalty_line_template: String
@export_multiline var no_penalties_text: String
@export_category("Passed Result")
@export var passed_result_template: String
@export var passed_result_color: Color
@export_multiline var passed_payment_template: String
@export var passed_continue_text: String
@export_category("Failed Result")
@export var failed_result_template: String
@export var failed_result_color: Color
@export_multiline var failed_payment_text: String
@export var failed_continue_text: String
@export_category("Night Paycheck Copy")
@export var night_title_text: String = "NIGHT PAYCHECK"
@export var night_subtitle_template: String = "NIGHT SHIFT • DAY %d"
@export var night_souls_caption: String = "SOULS RELEASED"
@export var night_failed_attempts_caption: String = "FAILED ATTEMPTS"
@export var night_attempts_caption: String = "TOTAL ATTEMPTS"
@export var night_route_caption: String = "STATION PATH"
@export var night_detail_title: String = "ATTEMPT DEDUCTION"
@export var night_net_caption: String = "NIGHT TOTAL"
@export var night_balance_caption: String = "CURRENT BALANCE"
@export var night_result_text: String = "NIGHT SHIFT COMPLETE"
@export var night_payment_template: String = "%d Blessings added after attempt deductions."
@export_multiline var night_first_attempt_text: String = "No deduction — the station path aligned on the first attempt."
@export_multiline var night_attempt_breakdown_template: String = "• %d failed attempt(s) × %d Blessings\n• Reward reduced by %d Blessings."
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
	_continue_sent = false
	_restore_day_receipt_copy()
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
	_correct_caption.text = night_souls_caption
	_correct.text = reward_template % [
		soul_total,
		int(award.get("correct_rate", 0)),
		int(award.get("base_reward", 0)),
	]
	_wrong_caption.text = night_failed_attempts_caption
	_wrong.text = deduction_template % [
		int(award.get("failed_attempts", 0)),
		int(award.get("attempt_rate", 0)),
		int(award.get("attempt_deduction", 0)),
	]
	_anomaly_caption.text = night_attempts_caption
	_anomaly.text = str(int(award.get("attempt_count", 1)))
	_anomaly.add_theme_color_override(&"font_color", Color("333340"))
	_retained_caption.text = night_route_caption
	_retained.text = "ALIGNED"
	_detail_title.text = night_detail_title
	var failed_attempts: int = int(award.get("failed_attempts", 0))
	_breakdown.text = night_first_attempt_text if failed_attempts == 0 else \
		night_attempt_breakdown_template % [
			failed_attempts,
			int(award.get("attempt_rate", 0)),
			int(award.get("attempt_deduction", 0)),
		]
	_breakdown.scroll_to_line(0)
	_net_caption.text = night_net_caption
	_net.text = amount_template % int(award.get("earned", 0))
	_target_caption.text = night_balance_caption
	_target.text = amount_template % maxi(0, balance)
	_result.text = night_result_text
	_result.add_theme_color_override(&"font_color", passed_result_color)
	_payment.text = night_payment_template % int(award.get("earned", 0))
	_continue_hint.text = passed_continue_text
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
	if not visible or not _is_continue_input(event):
		return
	get_viewport().set_input_as_handled()
	if _input_lock_remaining > 0.0:
		return
	if _typewriter_running:
		_finish_typewriter()
		return
	_request_continue()

func _request_continue() -> void:
	if _continue_sent or _typewriter_running:
		return
	_continue_sent = true
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
	for target: Control in _typewriter_targets:
		_set_visible_characters(target, -1)
	_typewriter_index = _typewriter_targets.size()
	_typewriter_running = false
	_typewriter_pause_remaining = 0.0
	_continue_hint.show()
	_hint_animation.play(&"blink")
	set_process(_input_lock_remaining > 0.0)


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
		return event.pressed
	return false
