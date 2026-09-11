extends SceneTree
## Verifies per-soul miss tracking and the third-miss flight response.

const MainScene = preload("res://scenes/main/main.tscn")
const Progress = preload("res://scripts/systems/shift_progress.gd")

var _failures: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failures += 1


func _run() -> void:
	var isolated_save_path: String = OS.get_environment(Progress.TEST_SAVE_PATH_ENV).replace("\\", "/")
	if "where-do-you-belong-tests" not in isolated_save_path:
		push_error("Set WHERE_DO_YOU_BELONG_TEST_SAVE to an isolated where-do-you-belong-tests path.")
		quit(1)
		return
	var game := MainScene.instantiate() as AfterTheEndGame
	root.add_child(game)
	await process_frame
	game._active_modal = null
	game.state = AfterTheEndGame.GameState.DAY
	game._jump_directly_to_debug_night()

	var puzzle: DeparturePuzzleData = game._runtime_puzzle
	_check(puzzle != null, "Night mode must create a Soul Record puzzle.")
	var passenger_name: String = str(puzzle.statement_by_passenger.keys()[0])
	var passenger: Passenger = game._find_active_passenger_by_name(passenger_name)
	_check(passenger != null, "The selected Soul Record holder must exist in the train.")
	if passenger == null:
		game.free()
		quit(1)
		return

	game._on_night_passenger_interacted(passenger)
	await process_frame
	var reader := game._night_soul_record_ui as NightSoulRecordUI
	var incorrect_sentence_index: int = -1
	var correct_sentence_index: int = -1
	for sentence_index: int in reader._sentence_by_index:
		if reader._sentence_by_index[sentence_index] == puzzle.get_statement_for_passenger(passenger_name):
			correct_sentence_index = sentence_index
		elif incorrect_sentence_index < 0:
			incorrect_sentence_index = sentence_index
	_check(incorrect_sentence_index >= 0, "The Soul Record must contain a decoy sentence.")
	_check(correct_sentence_index >= 0, "The Soul Record must contain its correct sentence.")

	var initial_carriage: int = passenger.get_runtime_carriage()
	passenger.night_repel_duration_seconds = 0.12
	for attempt: int in 3:
		reader._on_sentence_clicked(incorrect_sentence_index)
		if attempt < 2:
			_check(
				not game._night_soul_record_repulsed.has(passenger_name),
				"The soul must not fly away before its third wrong guess."
			)
	_check(reader._closing, "The third wrong guess must force the Soul Record to close.")
	await create_timer(0.3).timeout

	_check(
		int(game._night_soul_record_misses.get(passenger_name, 0)) == 3,
		"Three wrong guesses must be counted separately for the inspected soul."
	)
	_check(
		game._night_soul_record_repulsed.has(passenger_name),
		"The third wrong guess must trigger the soul's flight response."
	)
	_check(not reader.visible and not game._night_statement_active, "The Soul Record must be fully dismissed after repulsion.")
	_check(
		passenger.get_runtime_carriage() != initial_carriage,
		"The repulsed soul must reappear in a different random carriage."
	)
	var minimum_train_x: float = INF
	var maximum_train_x: float = -INF
	for carriage_value: Variant in passenger._carriage_ranges.values():
		var carriage_range: Vector2 = carriage_value
		minimum_train_x = minf(minimum_train_x, minf(carriage_range.x, carriage_range.y))
		maximum_train_x = maxf(maximum_train_x, maxf(carriage_range.x, carriage_range.y))
	_check(
		passenger.position.x >= minimum_train_x + passenger.night_repel_edge_margin - 0.1
		and passenger.position.x <= maximum_train_x - passenger.night_repel_edge_margin + 0.1,
		"The soul must land inside the train's authored interior bounds."
	)

	var first_landing_position: Vector2 = passenger.position
	game._on_night_passenger_interacted(passenger)
	await process_frame
	_check(reader.visible, "The relocated soul's record must require a new interaction.")
	reader._on_sentence_clicked(incorrect_sentence_index)
	await create_timer(0.16).timeout
	_check(
		passenger.position.is_equal_approx(first_landing_position),
		"A soul may only be repulsed once even if the player keeps guessing incorrectly."
	)
	reader._on_sentence_clicked(correct_sentence_index)
	_check(
		int(game._night_soul_record_misses.get(passenger_name, 0)) == 4,
		"A correct guess must not increase the soul's accumulated miss count."
	)
	_check(
		game._collected_departure_statements.has(passenger_name),
		"The correct guess must still record the statement after the soul moved."
	)

	game.free()
	DirAccess.remove_absolute(isolated_save_path)
	if _failures == 0:
		print("PASS: forced close, cross-carriage fade relocation, per-soul misses, and post-flight success.")
	quit(1 if _failures > 0 else 0)
