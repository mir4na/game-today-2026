class_name ShiftReportUI
extends Control
## Day-end performance summary shown before the train enters night service.

signal continue_requested

@export_category("Inspector Copy")
@export var merit_value_template: String = "%d / %d"
@export var service_point_template: String = "SP %d"
@export var ledger_entry_template: String = "• %s"

@onready var _success_status: Label = %SuccessStatus
@onready var _failure_status: Label = %FailureStatus
@onready var _merit_label: Label = %MeritValue
@onready var _penalty_label: Label = %PenaltyValue
@onready var _sp_label: Label = %ServicePointValue
@onready var _breakdown: RichTextLabel = %Breakdown
@onready var _continue_button: Button = %ContinueButton

func open_report(merit: int, threshold: int, penalty_points: int, service_points: int, threshold_met: bool, entries: PackedStringArray) -> void:
	_success_status.visible = threshold_met
	_failure_status.visible = not threshold_met
	_merit_label.text = merit_value_template % [merit, threshold]
	_penalty_label.text = str(penalty_points)
	_sp_label.text = service_point_template % service_points
	var lines := PackedStringArray()
	for entry: String in entries:
		lines.append(ledger_entry_template % entry)
	_breakdown.text = "\n".join(lines)
	show()
	_continue_button.grab_focus()

func _on_continue_button_pressed() -> void:
	continue_requested.emit()
