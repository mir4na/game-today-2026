extends SceneTree
## Verifies Night Service clue copy stays unique and avoids primary self-reference.

const PuzzleResource: DeparturePuzzleData = preload("res://data/puzzles/first_departures.tres")

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var used_context_slots: Dictionary = {}
	for level: int in range(1, 6):
		var rng := RandomNumberGenerator.new()
		rng.seed = 5300 + level
		var puzzle: DeparturePuzzleData = PuzzleResource.create_runtime(
			_make_passengers_for_level(level),
			rng,
			level
		)
		_check(not puzzle.get_veil_note_statement().is_empty(), "Level %d must prepare a Veil Note clue." % level)
		for holder_value: Variant in puzzle.context_slot_by_passenger.keys():
			var holder_name: String = str(holder_value)
			var context_slot: int = int(puzzle.context_slot_by_passenger[holder_value])
			_check(
				not used_context_slots.has(context_slot),
				"Hidden statement context slot %d must not repeat across the level samples." % context_slot
			)
			used_context_slots[context_slot] = true
			var blocked: Variant = puzzle.clue_blocked_passengers_by_holder.get(holder_name, PackedStringArray())
			if blocked is PackedStringArray:
				_check(
					not (blocked as PackedStringArray).has(holder_name),
					"%s must not hold a clue whose primary target is themselves." % holder_name
				)

	var day_two_puzzle: DeparturePuzzleData = _find_day_two_dimitra_upper_case()
	_check(day_two_puzzle != null, "The Day 2 test fixture must be able to place Dimitra at the upper station.")
	if day_two_puzzle != null:
		_check(
			day_two_puzzle.get_veil_note_statement()
			== "The last lesson map leaves Dimitra closest to the upper station.",
			"Day 2 must use the approved Dimitra Veil Note wording when she is nearest the upper station."
		)

	if _failures == 0:
		print("PASS: departure statement copy uniqueness, holder assignment, and Day 2 Veil Note wording.")
	quit(0 if _failures == 0 else 1)


func _find_day_two_dimitra_upper_case() -> DeparturePuzzleData:
	var passengers: Array[PassengerData] = _make_passengers_for_level(2)
	for seed: int in range(0, 128):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var puzzle: DeparturePuzzleData = PuzzleResource.create_runtime(passengers, rng, 2)
		if str(puzzle.correct_station_by_passenger.get("Dimitra", "")) == "Vesperwick":
			return puzzle
	return null


func _make_passengers_for_level(level: int) -> Array[PassengerData]:
	match level:
		1:
			return [
				_make_passenger("Helena", "clockmaker", "time_invalid_ticket"),
				_make_passenger("Zoe", "tailor", "unlisted_destination"),
				_make_passenger("Anthea", "lamplighter", "shadowless"),
			]
		2:
			return [
				_make_passenger("Dimitra", "retired teacher", "portrait_mismatch"),
				_make_passenger("Michalis", "bookbinder", "shadowless"),
				_make_passenger("Irene", "tailor", "unlisted_destination"),
			]
		3:
			return [
				_make_passenger("Nikolas", "florist", "newspaper_death"),
				_make_passenger("Kalliope", "nurse", "portrait_mismatch"),
				_make_passenger("Elias", "student", "time_invalid_ticket"),
				_make_passenger("Panagiotis", "botanist", "shadowless"),
			]
		4:
			return [
				_make_passenger("Panagiotis", "student", "time_invalid_ticket"),
				_make_passenger("Kyriakos", "cook", "unlisted_destination"),
				_make_passenger("Lydia", "lamplighter", "shadowless"),
				_make_passenger("Dimitra", "carpenter", "portrait_mismatch"),
			]
		_:
			return [
				_make_passenger("Daphne", "shopkeeper", "newspaper_death"),
				_make_passenger("Andreas", "courier", "portrait_mismatch"),
				_make_passenger("Theo", "bookbinder", "time_invalid_ticket"),
				_make_passenger("Helena", "glassworker", "shadowless"),
				_make_passenger("Lydia", "lamplighter", "unlisted_destination"),
			]


func _make_passenger(name: String, occupation: String, anomaly_type: String) -> PassengerData:
	var data := PassengerData.new()
	data.resource_local_to_scene = true
	data.passenger_name = name
	data.short_name = name
	data.occupation = occupation
	data.origin_station = "Alderwick"
	data.destination_station = "Eastmere"
	data.ticket_service_date = "07 JUN 2026"
	data.id_photo_owner = name
	data.is_dead = true
	data.anomaly_type = anomaly_type
	return data


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
