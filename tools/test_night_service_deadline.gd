extends SceneTree
## Verifies timeout evaluation while the Night Assignment ledger is still open.

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
	game.set_process(false)
	game._active_modal = null
	game.state = AfterTheEndGame.GameState.DAY
	game._jump_directly_to_debug_night()
	var puzzle: DeparturePuzzleData = game._get_departure_puzzle()
	var passengers: Array[PassengerData] = game._get_dead_passenger_data()
	var found_passenger: PassengerData = passengers[0]
	game._collected_departure_statements[found_passenger.short_name] = puzzle.get_statement_for_passenger(
		found_passenger.short_name
	)
	game._open_night_puzzle()
	await process_frame
	var board := game._night_puzzle_ui as NightPuzzleUI
	board._assign_passenger_to_station(
		str(puzzle.correct_station_by_passenger[found_passenger.short_name]),
		found_passenger.short_name
	)

	game._night_service_elapsed_seconds = 299.0
	game._update_night_service(1.0, true)
	await process_frame
	_check(game.state == AfterTheEndGame.GameState.COMPLETE, "Five minutes must end Night Service even while the ledger is open.")
	_check(game._shift_report_ui.visible, "The timeout must immediately present the final paycheck.")
	_check(not board.visible, "The open ledger must close when the deadline arrives.")
	_check(is_equal_approx(game._night_service_clock_progress(), 1.0), "The timeout must fill the clock to 180 degrees.")
	var award: Dictionary = game._night_blessing_award
	_check(int(award.get("correct_night_dropoffs", -1)) == 1, "The paycheck must retain a correct partial assignment.")
	_check(int(award.get("information_found", -1)) == 1, "The paycheck must count the Soul Record found before timeout.")
	_check(not bool(award.get("assignment_succeeded", true)), "An unfinished route must be reported as incomplete.")
	_check(
		(game._shift_report_ui.get_node("%RetainedValue") as Label).text == "INCOMPLETE",
		"The paycheck must clearly label an unfinished assignment."
	)
	_check(
		(game._shift_report_ui.get_node("%Breakdown") as RichTextLabel).text.contains(found_passenger.short_name),
		"The paycheck must list which passenger information was obtained."
	)

	game.free()
	if _failures == 0:
		print("PASS: Night Service deadline evaluates partial assignments and Soul Records.")
	quit(1 if _failures > 0 else 0)
