class_name NightMarketUI
extends Control
## Market shown between the daylight paycheck and night service.

signal purchase_requested(tool_id: StringName)
signal continue_requested

@export_category("Inspector Copy")
@export var merit_template: String = "MERIT MARKS  %d"
@export var audit_stock_template: String = "INVENTORY: %d SLIP(S)"
@export var radar_stock_template: String = "INVENTORY: %d CHARGE(S)"
@export var speed_level_template: String = "CURRENT LEVEL: %d / %d   (+%d SPEED)"
@export var purchase_button_template: String = "BUY  •  %d MARKS"
@export var speed_button_template: String = "UPGRADE  •  %d MARKS"
@export var maximum_speed_text: String = "MAXIMUM LEVEL REACHED"

@onready var _merit_label: Label = %MeritLabel
@onready var _audit_stock_label: Label = %AuditStockLabel
@onready var _radar_stock_label: Label = %RadarStockLabel
@onready var _speed_level_label: Label = %SpeedLevelLabel
@onready var _audit_button: Button = %AuditButton
@onready var _radar_button: Button = %RadarButton
@onready var _speed_button: Button = %SpeedButton
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _continue_button: Button = %ContinueButton

var _snapshot: Dictionary = {}
var _continue_sent: bool = false


func open_market(snapshot: Dictionary, earned_merit: int) -> void:
	_continue_sent = false
	show()
	set_snapshot(snapshot)
	_feedback_label.modulate = Color("9ed8ae")
	_feedback_label.text = "+%d MERIT MARKS EARNED FROM DAYLIGHT SERVICE" % earned_merit
	_focus_first_available_action()


func set_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	var merit: int = int(_snapshot.get("merit_marks", 0))
	var audit_cost: int = int(_snapshot.get("audit_slip_cost", 0))
	var radar_cost: int = int(_snapshot.get("radar_charge_cost", 0))
	var speed_cost: int = int(_snapshot.get("speed_upgrade_cost", -1))
	var speed_level: int = int(_snapshot.get("speed_level", 0))
	var speed_maximum: int = int(_snapshot.get("speed_max_level", 0))
	_merit_label.text = merit_template % merit
	_audit_stock_label.text = audit_stock_template % int(_snapshot.get("audit_slips", 0))
	_radar_stock_label.text = radar_stock_template % int(_snapshot.get("radar_charges", 0))
	_speed_level_label.text = speed_level_template % [
		speed_level,
		speed_maximum,
		int(round(float(_snapshot.get("speed_bonus", 0.0))))
	]
	_audit_button.text = purchase_button_template % audit_cost
	_radar_button.text = purchase_button_template % radar_cost
	_speed_button.text = maximum_speed_text if speed_cost < 0 else speed_button_template % speed_cost
	_audit_button.disabled = merit < audit_cost
	_radar_button.disabled = merit < radar_cost
	_speed_button.disabled = speed_cost < 0 or merit < speed_cost


func show_purchase_result(result: Dictionary, snapshot: Dictionary) -> void:
	set_snapshot(snapshot)
	var success: bool = bool(result.get("success", false))
	_feedback_label.modulate = Color("9ed8ae") if success else Color("ee9a93")
	_feedback_label.text = str(result.get("message", ""))
	_focus_first_available_action()


func _focus_first_available_action() -> void:
	for button: Button in [_audit_button, _radar_button, _speed_button]:
		if not button.disabled:
			button.grab_focus()
			return
	_continue_button.grab_focus()


func _on_audit_button_pressed() -> void:
	purchase_requested.emit(&"audit_slip")


func _on_radar_button_pressed() -> void:
	purchase_requested.emit(&"radar_charge")


func _on_speed_button_pressed() -> void:
	purchase_requested.emit(&"speed_upgrade")


func _on_continue_button_pressed() -> void:
	if _continue_sent:
		return
	_continue_sent = true
	continue_requested.emit()
