extends SceneTree
## Checks validation retries, retained investigation progress, and the final paycheck.

const MainScene = preload("res://scenes/main/main.tscn")

var _failures: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failures += 1


func _run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/"):
		push_error("Use an isolated /tmp XDG_DATA_HOME for this test.")
		quit(1)
		return
	var game := MainScene.instantiate() as AfterTheEndGame
	root.add_child(game)
	await process_frame
	game._active_modal = null
	game.state = AfterTheEndGame.GameState.DAY
	game._jump_directly_to_debug_night()
	var puzzle: DeparturePuzzleData = game._get_departure_puzzle()
	for data: PassengerData in game._get_dead_passenger_data():
		game._collected_departure_statements[data.short_name] = puzzle.get_statement_for_passenger(data.short_name)
	game._open_night_puzzle()
	await process_frame

	var board := game._night_puzzle_ui as NightPuzzleUI
	board.focus_transition_seconds = 0.01
	board.light_travel_seconds = 0.01
	board.station_hold_seconds = 0.0
	board.result_hold_seconds = 0.01
	board.paycheck_handoff_seconds = 0.01
	for target: NightStationTarget in board._station_targets:
		target.pointer_pop_seconds = 0.01
		target.pointer_shrink_seconds = 0.01
		target.star_pulse_seconds = 0.01
		target.failure_burst_seconds = 0.01

	game._night_service_elapsed_seconds = 75.0
	var correct_names: Array = puzzle.correct_station_by_passenger.keys()
	for passenger_value: Variant in correct_names:
		var passenger_name: String = str(passenger_value)
		board._assign_passenger_to_station(
			str(puzzle.correct_station_by_passenger[passenger_value]),
			passenger_name
		)
	var first_name: String = str(correct_names[0])
	var correct_station: String = str(puzzle.correct_station_by_passenger[first_name])
	var wrong_station: String = puzzle.night_stations[0]
	if wrong_station == correct_station:
		wrong_station = puzzle.night_stations[1]
	board._assign_passenger_to_station(wrong_station, first_name)
	board._confirm()
	var failed_result: Array = await board.validation_finished
	_check(not bool(failed_result[0]), "Any wrong station must reject the whole night attempt.")
	_check(int(failed_result[1]) == 1, "The first rejected submission must count as attempt one.")
	_check(game.state == AfterTheEndGame.GameState.NIGHT_PUZZLE, "A rejected station path must keep the ledger open for a retry decision.")
	_check(board.visible, "The ledger must stay open behind its retry panel.")
	_check((board.get_node("%FailPanel") as Control).visible, "A rejected route must offer retry and day-restart choices.")
	_check(
		game._collected_departure_statements.size() == puzzle.get_assignment_count(),
		"A rejected route must preserve every Soul Record already found."
	)
	_check(game._night_service_elapsed_seconds >= 75.0, "A rejected route must never reset the five-minute timer.")
	_check(board._assigned_passenger_count() == 0, "A failed submission may clear its board placements for another try.")

	(board.get_node("%RetryNightButton") as Button).pressed.emit()
	await process_frame
	_check(not (board.get_node("%FailPanel") as Control).visible, "Retrying must dismiss the fail panel.")
	_check(not board.visible, "Retrying must close the ledger for the cutscene replay.")
	_check(game.state == AfterTheEndGame.GameState.NIGHT_TRANSITION, "Retrying must replay the night-entry cutscene.")
	_check(not game._night_world_prepared, "Retrying must rebuild the night world before the replay.")
	_check(game._runtime_puzzle == null, "Retrying must drop the failed puzzle before the replay.")
	var floor_test := MarketToolState.new()
	floor_test.blessings_per_correct_night_dropoff = 100
	floor_test.blessings_per_night_statement = 50
	var partial_award: Dictionary = floor_test.award_night_blessings(2, 1, 3, ["Mira"])
	_check(int(partial_award.get("earned", -1)) == 250, "Two assignments and one record must award 250 Blessings.")
	_check(not bool(partial_award.get("assignment_succeeded", true)), "A partial assignment must be reported as incomplete.")

	game.free()
	if _failures == 0:
		print("PASS: night validation preserves time and records, then restarts from the night-entry cutscene.")
	quit(1 if _failures > 0 else 0)
