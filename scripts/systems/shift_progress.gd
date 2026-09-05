extends RefCounted
## A checkpoint is the start of a day, never an in-progress payout or purchase.

const SAVE_PATH: String = "user://shift_progress.cfg"
const VERSION: int = 1
const DAY_COUNT: int = 5

static func load_checkpoint(path: String = SAVE_PATH) -> Dictionary:
	var file := ConfigFile.new()
	if file.load(path) != OK or file.get_value("progress", "version", 0) != VERSION:
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
	for key: String in ["blessings", "audit_slips", "radar_charges", "speed_level"]:
		var value: Variant = checkpoint.inventory.get(key, 0)
		if not value is int or value < 0:
			return {}
	return checkpoint.duplicate(true)

static func make_checkpoint(day: int, inventory: Dictionary, seed_value: int) -> Dictionary:
	var saved_inventory: Dictionary = {}
	for key: String in ["blessings", "audit_slips", "radar_charges", "speed_level"]:
		if inventory.has(key):
			saved_inventory[key] = maxi(0, int(inventory[key]))
	return {"day": clampi(day, 1, DAY_COUNT), "seed": seed_value, "inventory": saved_inventory, "completed": false}

static func new_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.seed

static func save_checkpoint(checkpoint: Dictionary, path: String = SAVE_PATH) -> bool:
	var file := ConfigFile.new()
	file.set_value("progress", "version", VERSION)
	file.set_value("progress", "checkpoint", checkpoint)
	var error: Error = file.save(path + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(path + ".tmp", path)
	if error != OK:
		push_error("Could not save shift progress: %s" % error_string(error))
	return error == OK
