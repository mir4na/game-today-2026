class_name MarketToolState
extends Node
## Scene-owned inventory and balancing values for tools sold in the night market.

signal inventory_changed(snapshot: Dictionary)

const TOOL_VEIL_NOTE: StringName = &"veil_note"
const TOOL_RADAR_CHARGE: StringName = &"radar_charge"
const TOOL_SWIFTSTEP: StringName = &"swiftstep"

@export_category("Starting Inventory")
@export_range(0, 999, 1) var starting_blessings: int = 0
@export_range(0, 1, 1) var starting_veil_notes: int = 1
@export_range(0, 3, 1) var starting_radar_charges: int = 0
@export_range(0, 5, 1) var starting_swift_charges: int = 1
@export_category("Carry Limits")
@export_range(1, 3, 1) var maximum_radar_charges: int = 3
@export_range(1, 5, 1) var maximum_swift_charges: int = 5
@export_category("Market Costs")
@export_range(1, 999, 1) var veil_note_cost: int = 200
@export_range(1, 999, 1) var radar_charge_cost: int = 150
@export_range(1, 999, 1) var swift_charge_cost: int = 75
@export_category("Blessing Rewards")
@export_range(0, 100, 1) var blessings_per_correct_dropoff: int = 30
@export_range(0, 100, 1) var blessings_per_wrong_dropoff: int = 20
@export_range(0, 100, 1) var blessings_per_incorrect_anomaly: int = 40
@export_range(0, 500, 1) var blessings_per_correct_night_dropoff: int = 100
@export_range(0, 500, 1) var blessings_per_night_statement: int = 50

var blessings: int = 0
var veil_notes: int = 0
var radar_charges: int = 0
var swift_charges: int = 0
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
	veil_notes = clampi(starting_veil_notes, 0, 1)
	radar_charges = clampi(starting_radar_charges, 0, maximum_radar_charges)
	swift_charges = clampi(starting_swift_charges, 0, maximum_swift_charges)
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
	# Version 2 saves used the old Audit Slip name. Keep those runs playable,
	# then clamp the redesigned Veil Note to its one-item capacity.
	veil_notes = clampi(
		int(snapshot.get("veil_notes", snapshot.get("audit_slips", starting_veil_notes))),
		0,
		1
	)
	radar_charges = clampi(
		int(snapshot.get("radar_charges", starting_radar_charges)),
		0,
		maximum_radar_charges
	)
	# Version 3 stored a Swiftstep potency level. It now represents the number
	# of ten-second speed boosts carried, clamped to the current five-item case.
	swift_charges = clampi(
		int(snapshot.get("swift_charges", snapshot.get("speed_level", starting_swift_charges))),
		0,
		maximum_swift_charges
	)
	_emit_inventory_changed()


func award_night_blessings(
	correct_night_dropoffs: int,
	information_found: int,
	total_souls: int,
	information_names: Array[String] = []
) -> Dictionary:
	if _night_blessings_awarded:
		return _last_night_award.duplicate(true)
	_night_blessings_awarded = true
	var safe_total: int = maxi(0, total_souls)
	var correct_count: int = clampi(correct_night_dropoffs, 0, safe_total)
	var found_count: int = clampi(information_found, 0, safe_total)
	var assignment_reward: int = correct_count * blessings_per_correct_night_dropoff
	var information_reward: int = found_count * blessings_per_night_statement
	var earned: int = assignment_reward + information_reward
	blessings += earned
	_last_night_award = {
		"earned": earned,
		"base_reward": earned,
		"assignment_reward": assignment_reward,
		"information_reward": information_reward,
		"correct_rate": blessings_per_correct_night_dropoff,
		"information_rate": blessings_per_night_statement,
		"correct_night_dropoffs": correct_count,
		"information_found": found_count,
		"information_names": information_names.duplicate(),
		"total_souls": safe_total,
		"incorrect_or_missing_assignments": safe_total - correct_count,
		"assignment_succeeded": safe_total > 0 and correct_count == safe_total,
	}
	_emit_inventory_changed()
	return _last_night_award.duplicate(true)


func purchase(tool_id: StringName) -> Dictionary:
	match tool_id:
		TOOL_VEIL_NOTE:
			return _purchase_veil_note()
		TOOL_RADAR_CHARGE:
			return _purchase_radar_charge()
		TOOL_SWIFTSTEP:
			return _purchase_swift_charge()
	return {"success": false, "message": "UNKNOWN MARKET ITEM"}


func consume_veil_note() -> bool:
	if veil_notes <= 0:
		return false
	veil_notes -= 1
	_emit_inventory_changed()
	return true


func consume_radar_charge() -> bool:
	if radar_charges <= 0:
		return false
	radar_charges -= 1
	_emit_inventory_changed()
	return true


func consume_swift_charge() -> bool:
	if swift_charges <= 0:
		return false
	swift_charges -= 1
	_emit_inventory_changed()
	return true


func get_snapshot() -> Dictionary:
	return {
		"blessings": blessings,
		"veil_notes": veil_notes,
		"radar_charges": radar_charges,
		"radar_max_charges": maximum_radar_charges,
		"swift_charges": swift_charges,
		"swift_max_charges": maximum_swift_charges,
		"veil_note_cost": veil_note_cost,
		"radar_charge_cost": radar_charge_cost,
		"swift_charge_cost": swift_charge_cost,
	}


func _purchase_veil_note() -> Dictionary:
	if veil_notes >= 1:
		return {"success": false, "message": "ONLY ONE VEIL NOTE MAY BE CARRIED"}
	if not _try_spend(veil_note_cost):
		return {"success": false, "message": "NOT ENOUGH BLESSINGS"}
	veil_notes = 1
	_emit_inventory_changed()
	return {"success": true, "message": "VEIL NOTE ADDED"}


func _purchase_radar_charge() -> Dictionary:
	if radar_charges >= maximum_radar_charges:
		return {"success": false, "message": "RADAR CASE IS FULL"}
	if not _try_spend(radar_charge_cost):
		return {"success": false, "message": "NOT ENOUGH BLESSINGS"}
	radar_charges += 1
	_emit_inventory_changed()
	return {"success": true, "message": "RADAR CHARGE ADDED"}


func _purchase_swift_charge() -> Dictionary:
	if swift_charges >= maximum_swift_charges:
		return {"success": false, "message": "SWIFTSTEP CASE IS FULL"}
	if not _try_spend(swift_charge_cost):
		return {"success": false, "message": "NOT ENOUGH BLESSINGS"}
	swift_charges += 1
	_emit_inventory_changed()
	return {"success": true, "message": "SWIFTSTEP CHARGE ADDED"}


func _try_spend(cost: int) -> bool:
	if blessings < cost:
		return false
	blessings -= cost
	return true


func _emit_inventory_changed() -> void:
	inventory_changed.emit(get_snapshot())
