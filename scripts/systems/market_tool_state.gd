class_name MarketToolState
extends Node
## Scene-owned inventory and balancing values for tools sold in the night market.

signal inventory_changed(snapshot: Dictionary)

const TOOL_AUDIT_SLIP: StringName = &"audit_slip"
const TOOL_RADAR_CHARGE: StringName = &"radar_charge"
const TOOL_SPEED_UPGRADE: StringName = &"speed_upgrade"

@export_category("Starting Inventory")
@export_range(0, 999, 1) var starting_blessings: int = 0
@export_range(0, 20, 1) var starting_audit_slips: int = 1
@export_range(0, 20, 1) var starting_radar_charges: int = 1
@export_range(0, 8, 1) var starting_speed_level: int = 0
@export_category("Market Costs")
@export_range(1, 99, 1) var audit_slip_cost: int = 3
@export_range(1, 99, 1) var radar_charge_cost: int = 4
@export var speed_upgrade_costs: PackedInt32Array = PackedInt32Array([6, 10, 15])
@export_category("Speed Upgrade")
@export_range(0.0, 300.0, 1.0) var speed_bonus_per_level: float = 45.0
@export_category("Blessing Rewards")
@export_range(0, 100, 1) var blessings_per_correct_dropoff: int = 30
@export_range(0, 100, 1) var blessings_per_wrong_dropoff: int = 20
@export_range(0, 100, 1) var blessings_per_incorrect_anomaly: int = 40
@export_range(0, 20, 1) var blessings_per_correct_night_dropoff: int = 2

var blessings: int = 0
var audit_slips: int = 0
var radar_charges: int = 0
var speed_level: int = 0
var _day_blessings_awarded: bool = false
var _night_blessings_awarded: bool = false
var _last_day_award: Dictionary = {}
var _last_night_award: Dictionary = {}


func _ready() -> void:
	_set_starting_inventory()


func reset_inventory() -> void:
	_set_starting_inventory()
	_emit_inventory_changed()


func _set_starting_inventory() -> void:
	blessings = maxi(0, starting_blessings)
	audit_slips = maxi(0, starting_audit_slips)
	radar_charges = maxi(0, starting_radar_charges)
	speed_level = clampi(starting_speed_level, 0, speed_upgrade_costs.size())
	_day_blessings_awarded = false
	_night_blessings_awarded = false
	_last_day_award.clear()
	_last_night_award.clear()


func preview_day_blessings(correct_dropoffs: int, wrong_dropoffs: int, incorrect_anomalies: int, pass_target: int) -> Dictionary:
	var dropoff_reward: int = maxi(0, correct_dropoffs) * blessings_per_correct_dropoff
	var wrong_deduction: int = maxi(0, wrong_dropoffs) * blessings_per_wrong_dropoff
	var anomaly_deduction: int = maxi(0, incorrect_anomalies) * blessings_per_incorrect_anomaly
	var net_earnings: int = dropoff_reward - wrong_deduction - anomaly_deduction
	var passed: bool = net_earnings >= pass_target
	var earned: int = maxi(0, net_earnings) if passed else 0
	return {
		"earned": earned,
		"dropoff_reward": dropoff_reward,
		"wrong_deduction": wrong_deduction,
		"anomaly_deduction": anomaly_deduction,
		"penalty_deduction": wrong_deduction + anomaly_deduction,
		"net_earnings": net_earnings,
		"pass_target": pass_target,
		"passed": passed,
		"correct_rate": blessings_per_correct_dropoff,
		"wrong_rate": blessings_per_wrong_dropoff,
		"anomaly_rate": blessings_per_incorrect_anomaly,
		"correct_dropoffs": maxi(0, correct_dropoffs),
		"wrong_dropoffs": maxi(0, wrong_dropoffs),
		"incorrect_anomalies": maxi(0, incorrect_anomalies),
	}


func award_day_blessings(correct_dropoffs: int, wrong_dropoffs: int, incorrect_anomalies: int, pass_target: int) -> Dictionary:
	if _day_blessings_awarded:
		return _last_day_award.duplicate(true)
	_day_blessings_awarded = true
	_last_day_award = preview_day_blessings(correct_dropoffs, wrong_dropoffs, incorrect_anomalies, pass_target)
	blessings += int(_last_day_award.earned)
	_emit_inventory_changed()
	return _last_day_award.duplicate(true)


func restore_shift_inventory(snapshot: Dictionary) -> void:
	_set_starting_inventory()
	blessings = maxi(0, int(snapshot.get("blessings", starting_blessings)))
	audit_slips = maxi(0, int(snapshot.get("audit_slips", starting_audit_slips)))
	radar_charges = maxi(0, int(snapshot.get("radar_charges", starting_radar_charges)))
	speed_level = clampi(int(snapshot.get("speed_level", starting_speed_level)), 0, speed_upgrade_costs.size())
	_emit_inventory_changed()


func award_night_blessings(correct_night_dropoffs: int) -> Dictionary:
	if _night_blessings_awarded:
		return _last_night_award.duplicate(true)
	_night_blessings_awarded = true
	var correct_count: int = maxi(0, correct_night_dropoffs)
	var earned: int = correct_count * blessings_per_correct_night_dropoff
	blessings += earned
	_last_night_award = {
		"earned": earned,
		"correct_night_dropoffs": correct_count,
	}
	_emit_inventory_changed()
	return _last_night_award.duplicate(true)


func purchase(tool_id: StringName) -> Dictionary:
	match tool_id:
		TOOL_AUDIT_SLIP:
			return _purchase_consumable(audit_slip_cost, TOOL_AUDIT_SLIP)
		TOOL_RADAR_CHARGE:
			return _purchase_consumable(radar_charge_cost, TOOL_RADAR_CHARGE)
		TOOL_SPEED_UPGRADE:
			return _purchase_speed_upgrade()
	return {"success": false, "message": "UNKNOWN MARKET ITEM"}


func consume_audit_slip() -> bool:
	if audit_slips <= 0:
		return false
	audit_slips -= 1
	_emit_inventory_changed()
	return true


func consume_radar_charge() -> bool:
	if radar_charges <= 0:
		return false
	radar_charges -= 1
	_emit_inventory_changed()
	return true


func get_speed_bonus() -> float:
	return float(speed_level) * speed_bonus_per_level


func get_snapshot() -> Dictionary:
	return {
		"blessings": blessings,
		"audit_slips": audit_slips,
		"radar_charges": radar_charges,
		"speed_level": speed_level,
		"speed_max_level": speed_upgrade_costs.size(),
		"audit_slip_cost": audit_slip_cost,
		"radar_charge_cost": radar_charge_cost,
		"speed_upgrade_cost": _next_speed_cost(),
		"speed_bonus": get_speed_bonus()
	}


func _purchase_consumable(cost: int, tool_id: StringName) -> Dictionary:
	if not _try_spend(cost):
		return {"success": false, "message": "NOT ENOUGH BLESSINGS"}
	if tool_id == TOOL_AUDIT_SLIP:
		audit_slips += 1
		_emit_inventory_changed()
		return {"success": true, "message": "AUDIT SLIP ADDED"}
	radar_charges += 1
	_emit_inventory_changed()
	return {"success": true, "message": "RADAR CHARGE ADDED"}


func _purchase_speed_upgrade() -> Dictionary:
	var next_cost: int = _next_speed_cost()
	if next_cost < 0:
		return {"success": false, "message": "SPEED IS ALREADY AT MAXIMUM LEVEL"}
	if not _try_spend(next_cost):
		return {"success": false, "message": "NOT ENOUGH BLESSINGS"}
	speed_level += 1
	_emit_inventory_changed()
	return {"success": true, "message": "MOVEMENT SPEED UPGRADED TO LEVEL %d" % speed_level}


func _try_spend(cost: int) -> bool:
	if blessings < cost:
		return false
	blessings -= cost
	return true


func _next_speed_cost() -> int:
	if speed_level < 0 or speed_level >= speed_upgrade_costs.size():
		return -1
	return speed_upgrade_costs[speed_level]


func _emit_inventory_changed() -> void:
	inventory_changed.emit(get_snapshot())
