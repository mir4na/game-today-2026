extends SceneTree
## Set WHERE_DO_YOU_BELONG_TEST_SAVE to an isolated path so checks never
## replace a player's save on Linux or Windows.
const Progress = preload("res://scripts/systems/shift_progress.gd")
const MarketScene = preload("res://scenes/systems/market_tool_state.tscn")
const MenuScene = preload("res://scenes/menu/main_menu.tscn")
var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failures += 1

func _run() -> void:
	var isolated_save_path: String = OS.get_environment(Progress.TEST_SAVE_PATH_ENV).replace("\\", "/")
	if "where-do-you-belong-tests" not in isolated_save_path:
		push_error("Set WHERE_DO_YOU_BELONG_TEST_SAVE to an isolated where-do-you-belong-tests path.")
		quit(1)
		return
	var market: MarketToolState = MarketScene.instantiate()
	root.add_child(market)
	var initial: Dictionary = {"blessings": 500, "veil_notes": 1, "radar_charges": 3, "swift_charges": 1}
	market.restore_shift_inventory(initial)
	var award: Dictionary = market.award_day_blessings(6, 1, 1, 100)
	_check(award.net_earnings == 120 and award.passed and market.blessings == 620, "Receipt must use +30/-20/-40 independently of the starting balance.")
	market.award_day_blessings(6, 1, 1, 100)
	_check(market.blessings == 620, "Opening the report twice must not duplicate payment.")
	market.restore_shift_inventory(initial)
	award = market.award_day_blessings(4, 1, 0, 100)
	_check(award.passed and award.net_earnings == 100, "Exactly meeting the target passes.")
	market.restore_shift_inventory(initial)
	award = market.award_day_blessings(0, 2, 1, 100)
	_check(not award.passed and award.net_earnings == -80 and award.earned == 0 and market.blessings == 500, "A negative paycheck fails without taking old savings.")
	market.purchase(&"radar_charge")
	market.restore_shift_inventory(initial)
	_check(market.blessings == 500 and market.radar_charges == 3, "Retry restores pre-shift purchases and balance.")
	market.free()

	var checkpoint: Dictionary = Progress.make_checkpoint(2, initial, -5937024214972579229)
	_check(Progress.save_checkpoint(checkpoint), "Checkpoint must save.")
	_check(Progress.load_checkpoint() == checkpoint, "Save/load must retain the exact 64-bit seed and inventory.")
	var menu: MainMenu = MenuScene.instantiate()
	root.add_child(menu)
	_check(not menu.get_node("%ContinueButton").disabled and "DAY 2" in menu.get_node("%ContinueButton").text, "Menu must offer the saved day.")
	menu.free()
	menu = MenuScene.instantiate()
	root.add_child(menu)
	_check(Progress.load_checkpoint() == checkpoint, "Closing and reopening the application menu must not replace the saved run.")
	_check(not menu.get_node("%ContinueButton").disabled and "DAY 2" in menu.get_node("%ContinueButton").text, "Continue must remain available after a relaunch.")
	var continue_button := menu.get_node("%ContinueButton") as Button
	continue_button.grab_focus()
	_check(
		continue_button.get_theme_color(&"font_focus_color").is_equal_approx(Color(0.06, 0.045, 0.06, 1.0)),
		"The focused Continue button must keep its authored black text."
	)
	var settings_button := menu.get_node("%SettingsButton") as Button
	settings_button.grab_focus()
	_check(
		settings_button.get_theme_color(&"font_focus_color").is_equal_approx(Color(0.06, 0.045, 0.06, 1.0)),
		"The focused Settings button must keep its authored black text."
	)
	current_scene = menu
	menu.get_node("%ContinueButton").pressed.emit()
	var game: AfterTheEndGame = await _wait_for_game()
	_check(game.day_number == 2 and game._daily_seed == checkpoint.seed, "Continue restores the saved day and roster seed.")
	var expected_day_targets := PackedInt32Array([280, 290, 300, 310, 320])
	for sample_day: int in range(1, 6):
		game.day_number = sample_day
		_check(
			game._get_day_pass_target() == expected_day_targets[sample_day - 1],
			"Day %d must use its authored Blessings threshold." % sample_day
		)
	game.day_number = 2
	var service_number: String = game.manifest_config.service_train_number
	var scene_probe: AfterTheEndGame = load("res://scenes/main/main.tscn").instantiate()
	var authored_config: DailyManifestConfig = scene_probe.manifest_config
	var authored_number: String = authored_config.service_train_number
	_check(authored_config.create_daily_service(2, checkpoint.seed).service_train_number == service_number, "Continue restores the daily service number from its checkpoint seed.")
	var generated_numbers: Dictionary = {}
	var expected_night_counts := PackedInt32Array([3, 3, 4, 4, 5])
	var previous_day_target: int = 0
	var correct_dropoff_rate: int = int(game._market_tool_state.get("blessings_per_correct_dropoff"))
	for sample_day: int in range(1, 6):
		var daily_config: DailyManifestConfig = authored_config.create_daily_service(sample_day, checkpoint.seed)
		var day_target: int = expected_day_targets[sample_day - 1]
		var living_passenger_count: int = daily_config.total_passenger_count - daily_config.deceased_passenger_count
		var maximum_day_paycheck: int = living_passenger_count * correct_dropoff_rate
		generated_numbers[daily_config.service_train_number] = true
		_check(daily_config.service_train_number == authored_config.create_daily_service(sample_day, checkpoint.seed).service_train_number, "Daily service generation is repeatable.")
		_check(daily_config.service_train_codes.has(daily_config.service_train_number), "Service number must come from the authored train code pool.")
		_check(
			daily_config.deceased_passenger_count == expected_night_counts[sample_day - 1],
			"Night Service must follow the authored 3, 3, 4, 4, 5 anomaly progression."
		)
		_check(day_target > previous_day_target, "Daylight paycheck targets must increase every day.")
		_check(
			day_target <= maximum_day_paycheck,
			"Day %d target must be reachable from its %d living passengers." % [sample_day, living_passenger_count]
		)
		previous_day_target = day_target
	_check(generated_numbers.size() > 1 and authored_config.service_train_number == authored_number, "Daily randomization varies without modifying the authored config.")
	scene_probe.free()
	_check(game._market_tool_state.get("blessings") == 500, "Continue restores the day-start inventory.")
	var names: PackedStringArray = _roster(game)
	var anomaly: Passenger = null
	for passenger: Passenger in game._passengers:
		if passenger.data.is_dead:
			anomaly = passenger
			break
	_check(anomaly != null, "Test roster requires an anomaly.")
	game.state = AfterTheEndGame.GameState.DAY
	game._on_station_assignment_toggled(anomaly.data.passenger_name, true)
	game._on_station_assignment_toggled(anomaly.data.passenger_name, false)
	game._on_station_assignment_toggled(anomaly.data.passenger_name, true)
	_check(game._incorrectly_stamped_anomalies.size() == 1 and game._penalty_log.size() == 1, "Repeated anomaly stamps charge once per shift, even after removing the stamp.")
	game._correct_drop_offs = 12
	game._wrong_drop_offs = 1
	game._finalize_day_shift()
	_check(game._day_blessing_award.net_earnings == 300 and game._day_blessing_award.passed, "A reachable Day 2 paycheck must pass without a debug override.")
	game._on_shift_report_continue()
	_check(game.state == AfterTheEndGame.GameState.NIGHT_TRANSITION, "Passing starts the terminal-to-night transition after the paycheck.")
	_check(game._night_transition_ui.visible, "The veil transition appears before the Night Market.")
	game._night_transition_ui.pre_market_white_hold_seconds = 0.0
	game._night_transition_ui.skip_sequence()
	_check(game.state == AfterTheEndGame.GameState.MARKET, "Completing the transition opens the Night Market.")
	_check(game._night_market_ui.visible, "The Night Market opens after the train crosses the veil.")
	game._night_market_ui.content_exit_duration = 0.01
	game._night_market_ui.gate_close_duration = 0.01
	game._night_market_ui.transition_fog_rise_duration = 0.01
	game._night_market_ui.transition_fog_hold_seconds = 0.0
	game._night_market_ui.transition_fog_release_duration = 0.01
	game._night_transition_ui.white_screen_hold_seconds = 0.01
	game._night_transition_ui.post_market_fade_seconds = 0.01
	game._night_transition_ui.night_reveal_hold_seconds = 0.0
	game._night_transition_ui.exterior_hold_after_zoom_seconds = 0.0
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	game._on_night_market_continue()
	_check(game.state == AfterTheEndGame.GameState.NIGHT_TRANSITION, "Leaving the market must return to the white transition first.")
	await create_timer(2.0).timeout
	_check(game.state == AfterTheEndGame.GameState.NIGHT, "The whiteout must reveal night gameplay after the market closes.")
	_check(not game._night_market_ui.visible, "The market must clear before night gameplay begins.")
	game._market_tool_state.call("purchase", &"radar_charge")
	var previous_game: AfterTheEndGame = game
	game._restart_game()
	game = await _wait_for_reloaded_game(previous_game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_check(_roster(game) == names and game.day_number == 2, "Restart must keep the day and manifest.")
	_check(game.manifest_config.service_train_number == service_number, "Restart keeps the same service number.")
	_check(game._market_tool_state.get("blessings") == 500 and game._market_tool_state.get("radar_charges") == 3, "Restart must not keep payout or purchases from the previous attempt.")
	game._finalize_day_shift()
	_check(not game._day_blessing_award.passed, "A zero-earnings attempt must fail despite savings.")
	game._on_shift_report_continue()
	_check(
		game.state == AfterTheEndGame.GameState.HELL_ENDING and game._hell_ending_ui.visible,
		"A failed daylight paycheck must enter the Hell cutscene before offering retry."
	)
	previous_game = game
	game._on_hell_retry_requested()
	game = await _wait_for_reloaded_game(previous_game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_check(game.day_number == 2 and game._correct_drop_offs == 0, "Failure retries the same day without strikes or advancement.")
	game.state = AfterTheEndGame.GameState.DAY
	game._route_index = game.day_route.size() - 2
	game._station_arrival_announced = true
	var living_count: int = 0
	for passenger: Passenger in game._passengers:
		if not passenger.data.is_dead:
			living_count += 1
			passenger.data.required_dropoff_station = game.day_route[0]
			passenger.data.destination_station = game.day_route[0]
	game._process_station_arrival()
	_check(game._wrong_drop_offs == living_count and game._correct_drop_offs == 0, "Wrong terminal drop-offs count each living passenger once regardless of station distance.")
	game._finalize_day_shift()
	_check(game._day_blessing_award.wrong_deduction == 20 * living_count, "Station settlement applies a flat 20 Blessings per wrong drop-off.")
	game._enter_night()
	_check(game._hud._next_stop_label.text == "THE END", "Night Service changes the clock sign destination to The End.")
	game.state = AfterTheEndGame.GameState.NIGHT_PUZZLE
	game._complete_night_service(_complete_night_fixture(game))
	_check(Progress.load_checkpoint().day == 3, "Finishing the night checkpoints the next day.")
	previous_game = game
	game._continue_after_night_paycheck()
	game = await _wait_for_reloaded_game(previous_game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_check(game.day_number == 3, "Continue after the night enters the next day.")
	game._enter_night()
	game.state = AfterTheEndGame.GameState.NIGHT_PUZZLE
	game._complete_night_service({})
	_check(
		game._night_paycheck_failed and Progress.load_checkpoint().day == 3,
		"An incomplete Night Service paycheck must not advance the saved day."
	)
	game._on_shift_report_continue()
	_check(
		game.state == AfterTheEndGame.GameState.HELL_ENDING,
		"An under-quota Night Service paycheck must enter the Hell cutscene."
	)
	previous_game = game
	game._on_hell_retry_requested()
	game = await _wait_for_reloaded_game(previous_game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_check(game.day_number == 3, "Retrying from Hell must restore the current day checkpoint.")
	game.day_number = 5
	game._enter_night()
	game.state = AfterTheEndGame.GameState.NIGHT_PUZZLE
	game._complete_night_service(_complete_night_fixture(game))
	_check(Progress.load_checkpoint().completed and Progress.load_checkpoint().day == 5, "Day 5 ends the campaign; no Day 6.")
	_check(
		game.state == AfterTheEndGame.GameState.HEAVEN_ENDING and game._heaven_ending_ui.visible,
		"A successful Day 5 must enter Heaven before the credits."
	)
	_check(
		int(Progress.load_checkpoint().campaign_summary.get("days_completed", 0)) == 5,
		"The completed checkpoint must retain the five-day final-paycheck summary."
	)
	game.free()
	current_scene = null
	menu = MenuScene.instantiate()
	root.add_child(menu)
	_check(menu.get_node("%ContinueButton").disabled, "A completed run has no pending day to continue.")
	menu.free()
	var invalid := ConfigFile.new()
	invalid.set_value("progress", "version", 1)
	invalid.set_value("progress", "checkpoint", {"day": "broken"})
	invalid.save(isolated_save_path)
	_check(Progress.load_checkpoint().is_empty(), "Invalid save data must be rejected safely.")
	menu = MenuScene.instantiate()
	root.add_child(menu)
	_check(menu.get_node("%ContinueButton").disabled, "Invalid saves must not enable Continue.")
	current_scene = menu
	menu.get_node("%StartButton").pressed.emit()
	var intro: IntroCutscene = await _wait_for_intro()
	intro.closing_fade_duration = 0.01
	intro._finish_intro()
	game = await _wait_for_game()
	_check(game.is_tutorial_mode, "New Game must continue from the story intro into the tutorial.")
	var tutorial_game := game
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game._tutorial_director.call(&"_start_day_one")
	game = await _wait_for_reloaded_game(tutorial_game)
	_check(not game.is_tutorial_mode, "Skipping the tutorial must reload a clean standard Day 1 run.")
	_check(
		game.day_number == 1
		and game._market_tool_state.get("blessings") == 0
		and game._market_tool_state.get("veil_notes") == 1,
		"New Game starts Day 1 with its scene-authored Veil Note through the loading screen."
	)
	game.state = AfterTheEndGame.GameState.DAY
	game._active_modal = null
	game._route_index = 0
	game._station_arrival_announced = false
	game._station_exchange_processed = false
	game._day_minutes = game._next_arrival_minutes()
	game._update_day_route_presentation()
	game._announce_next_station()
	_check(
		game._station_arrival_announced
		and is_equal_approx(game._day_minutes, game._next_arrival_minutes())
		and game._active_modal == game._station_stop_ui,
		"Debug next-station action must enter the complete normal station-arrival flow."
	)
	game.free()
	current_scene = null
	DirAccess.remove_absolute(isolated_save_path)
	await process_frame
	await process_frame
	if _failures > 0:
		quit(1)
		return
	print("PASS: shift progression, Night Market routing, debug station skip, persistence, payout, retry, anomaly, and campaign boundaries.")
	quit()

func _wait_for_game() -> AfterTheEndGame:
	for attempt: int in 200:
		await create_timer(0.05).timeout
		if current_scene is AfterTheEndGame:
			var game := current_scene as AfterTheEndGame
			game.process_mode = Node.PROCESS_MODE_DISABLED
			return game
	_check(false, "Menu/loading transition did not reach the game within 10 seconds.")
	return null


func _wait_for_reloaded_game(previous_game: AfterTheEndGame) -> AfterTheEndGame:
	for attempt: int in 200:
		await create_timer(0.05).timeout
		if current_scene is AfterTheEndGame and current_scene != previous_game:
			var game := current_scene as AfterTheEndGame
			game.process_mode = Node.PROCESS_MODE_DISABLED
			return game
	_check(false, "Loading transition did not reload the game within 10 seconds.")
	return null


func _wait_for_intro() -> IntroCutscene:
	for attempt: int in 200:
		await create_timer(0.05).timeout
		if current_scene is IntroCutscene:
			return current_scene as IntroCutscene
	_check(false, "Menu/loading transition did not reach the intro within 10 seconds.")
	return null

func _roster(game: AfterTheEndGame) -> PackedStringArray:
	var names := PackedStringArray()
	for data: PassengerData in game._daily_manifest:
		names.append("%s|%s|%s|%s" % [data.passenger_name, data.anomaly_type, data.origin_station, data.destination_station])
	return names


func _complete_night_fixture(game: AfterTheEndGame) -> Dictionary:
	var puzzle: DeparturePuzzleData = game._get_departure_puzzle()
	var assignments: Dictionary = {}
	for station: String in puzzle.night_stations:
		assignments[station] = puzzle.get_expected_passengers_for_station(station)
	for data: PassengerData in game._get_dead_passenger_data():
		game._collected_departure_statements[data.short_name] = "Recovered test record"
	return assignments
