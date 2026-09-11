extends RefCounted
## A checkpoint is the start of a day, never an in-progress payout or purchase.

const SAVE_PATH: String = "user://shift_progress.cfg"
const TEST_SAVE_PATH_ENV: String = "WHERE_DO_YOU_BELONG_TEST_SAVE"
const VERSION: int = 4
const LEGACY_STARTER_RADAR_VERSION: int = 1
const AUDIT_SLIP_VERSION: int = 2
const SWIFT_STOCK_VERSION: int = 3
const DAY_COUNT: int = 5
const RADAR_CARRY_LIMIT: int = 3
const SWIFT_CARRY_LIMIT: int = 5


## Creates the only checkpoint that replaces an existing campaign from scratch.
## Continue and normal application exit never call this function.
static func start_new_run(path: String = "") -> Dictionary:
	path = _resolve_save_path(path)
	var checkpoint: Dictionary = make_checkpoint(1, {}, new_seed())
	if not save_checkpoint(checkpoint, path):
		return {}
	return checkpoint

static func load_checkpoint(path: String = "") -> Dictionary:
	path = _resolve_save_path(path)
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return {}
	var saved_version: int = int(file.get_value("progress", "version", 0))
	if saved_version not in [LEGACY_STARTER_RADAR_VERSION, AUDIT_SLIP_VERSION, SWIFT_STOCK_VERSION, VERSION]:
		return {}
	var checkpoint: Variant = file.get_value("progress", "checkpoint", {})
	if not checkpoint is Dictionary:
		return {}
	if not checkpoint.get("day", null) is int or not checkpoint.get("seed", null) is int:
		return {}
	if checkpoint.day < 1 or checkpoint.day > DAY_COUNT:
		return {}
	if not checkpoint.get("completed", null) is bool or not checkpoint.get("inventory", null) is Dictionary:
		return {}
	var inventory_keys: Array[String] = [
		"blessings",
		"radar_charges",
		"swift_charges" if saved_version == VERSION else "speed_level",
	]
	inventory_keys.append("veil_notes" if saved_version >= SWIFT_STOCK_VERSION else "audit_slips")
	for key: String in inventory_keys:
		var value: Variant = checkpoint.inventory.get(key, 0)
		if not value is int or value < 0:
			return {}
	if saved_version == LEGACY_STARTER_RADAR_VERSION:
		checkpoint = _migrate_legacy_starter_item(checkpoint)
	if saved_version in [LEGACY_STARTER_RADAR_VERSION, AUDIT_SLIP_VERSION]:
		checkpoint = _migrate_audit_slip(checkpoint)
	if saved_version < VERSION:
		checkpoint = _migrate_swift_stock(checkpoint)
		save_checkpoint(checkpoint, path)
	return checkpoint.duplicate(true)


static func _migrate_legacy_starter_item(checkpoint: Dictionary) -> Dictionary:
	var migrated: Dictionary = checkpoint.duplicate(true)
	var inventory: Dictionary = migrated.inventory
	# Version 1 granted one Radar charge and no Swiftstep. Remove only that
	# legacy free charge, preserving any additional charges the player bought.
	inventory["radar_charges"] = maxi(0, int(inventory.get("radar_charges", 0)) - 1)
	inventory["speed_level"] = maxi(1, int(inventory.get("speed_level", 0)))
	migrated.inventory = inventory
	return migrated


static func _migrate_audit_slip(checkpoint: Dictionary) -> Dictionary:
	var migrated: Dictionary = checkpoint.duplicate(true)
	var inventory: Dictionary = migrated.inventory
	inventory["veil_notes"] = clampi(int(inventory.get("audit_slips", 0)), 0, 1)
	inventory.erase("audit_slips")
	migrated.inventory = inventory
	return migrated


static func _migrate_swift_stock(checkpoint: Dictionary) -> Dictionary:
	var migrated: Dictionary = checkpoint.duplicate(true)
	var inventory: Dictionary = migrated.inventory
	# Old saves stored Swiftstep potency. The redesigned item uses the same
	# carry count, preserving the old value within the current five-slot case.
	inventory["swift_charges"] = clampi(
		int(inventory.get("speed_level", 1)),
		0,
		SWIFT_CARRY_LIMIT
	)
	inventory.erase("speed_level")
	migrated.inventory = inventory
	return migrated

static func make_checkpoint(
	day: int,
	inventory: Dictionary,
	seed_value: int,
	campaign_summary: Dictionary = {}
) -> Dictionary:
	var saved_inventory: Dictionary = {}
	for key: String in ["blessings", "radar_charges", "swift_charges"]:
		if inventory.has(key):
			var maximum: int = 999999
			if key == "radar_charges":
				maximum = RADAR_CARRY_LIMIT
			elif key == "swift_charges":
				maximum = SWIFT_CARRY_LIMIT
			saved_inventory[key] = clampi(int(inventory[key]), 0, maximum)
	# Allow an old or hand-authored snapshot while writing only the new
	# consumable Swiftstep inventory key.
	if not saved_inventory.has("swift_charges") and inventory.has("speed_level"):
		saved_inventory["swift_charges"] = clampi(
			int(inventory["speed_level"]),
			0,
			SWIFT_CARRY_LIMIT
		)
	if inventory.has("veil_notes") or inventory.has("audit_slips"):
		saved_inventory["veil_notes"] = clampi(
			int(inventory.get("veil_notes", inventory.get("audit_slips", 0))),
			0,
			1
		)
	return {
		"day": clampi(day, 1, DAY_COUNT),
		"seed": seed_value,
		"inventory": saved_inventory,
		"completed": false,
		"campaign_summary": _sanitize_campaign_summary(campaign_summary),
	}


static func _sanitize_campaign_summary(summary: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	for key: String in [
		"days_completed",
		"correct_dropoffs",
		"wrong_dropoffs",
		"anomalies_retained",
		"souls_released",
		"night_attempts",
		"blessings_earned",
		"blessing_balance",
	]:
		sanitized[key] = maxi(0, int(summary.get(key, 0)))
	return sanitized

static func new_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.seed

static func save_checkpoint(checkpoint: Dictionary, path: String = "") -> bool:
	path = _resolve_save_path(path)
	var file := ConfigFile.new()
	file.set_value("progress", "version", VERSION)
	file.set_value("progress", "checkpoint", checkpoint)
	var error: Error = file.save(path + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(path + ".tmp", path)
	if error != OK:
		push_error("Could not save shift progress: %s" % error_string(error))
	return error == OK


static func _resolve_save_path(path: String) -> String:
	if not path.is_empty():
		return path
	var test_override: String = OS.get_environment(TEST_SAVE_PATH_ENV).strip_edges()
	return test_override if not test_override.is_empty() else SAVE_PATH
