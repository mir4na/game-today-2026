extends SceneTree
## Run with an isolated XDG_DATA_HOME so checks never replace a player's save.
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
	if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/"):
		push_error("Use an isolated /tmp XDG_DATA_HOME for this test.")
		quit(1)
		return
	var market: MarketToolState = MarketScene.instantiate()
	root.add_child(market)
	var initial: Dictionary = {"blessings": 500, "audit_slips": 2, "radar_charges": 3, "speed_level": 1}
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
	current_scene = menu
	menu.get_node("%ContinueButton").pressed.emit()
	var game: AfterTheEndGame = await _wait_for_game()
	_check(game.day_number == 2 and game._daily_seed == checkpoint.seed, "Continue restores the saved day and roster seed.")
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
	game._correct_drop_offs = 6
	game._wrong_drop_offs = 1
	game._finalize_day_shift()
	_check(game._day_blessing_award.net_earnings == 120 and game._day_blessing_award.passed, "Main paycheck passes at the Day 2 threshold.")
	game._on_shift_report_continue()
	_check(game.state == AfterTheEndGame.GameState.MARKET, "Passing unlocks the market.")
	game._market_tool_state.call("purchase", &"radar_charge")
	game._restart_game()
	await process_frame
	await process_frame
	game = current_scene as AfterTheEndGame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_check(_roster(game) == names and game.day_number == 2, "Restart must keep the day and manifest.")
	_check(game._market_tool_state.get("blessings") == 500 and game._market_tool_state.get("radar_charges") == 3, "Restart must not keep payout or purchases from the previous attempt.")
	game._finalize_day_shift()
	_check(not game._day_blessing_award.passed, "A zero-earnings attempt must fail despite savings.")
	game._on_shift_report_continue()
	await process_frame
	await process_frame
	game = current_scene as AfterTheEndGame
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
	game._on_departures_confirmed(game._get_departure_puzzle().correct_passenger_by_station)
	game._sequence_ui._show_complete()
	_check(Progress.load_checkpoint().day == 3, "Finishing the night checkpoints the next day.")
	game._on_journey_continue()
	await process_frame
	await process_frame
	game = current_scene as AfterTheEndGame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_check(game.day_number == 3, "Continue after the night enters the next day.")
	game.day_number = 5
	game._enter_night()
	game._on_departures_confirmed(game._get_departure_puzzle().correct_passenger_by_station)
	game._sequence_ui._show_complete()
	_check(Progress.load_checkpoint().completed and Progress.load_checkpoint().day == 5, "Day 5 ends the campaign; no Day 6.")
	game.free()
	current_scene = null
	menu = MenuScene.instantiate()
	root.add_child(menu)
	_check(menu.get_node("%ContinueButton").disabled, "A completed run has no pending day to continue.")
	menu.free()
	var invalid := ConfigFile.new()
	invalid.set_value("progress", "version", 1)
	invalid.set_value("progress", "checkpoint", {"day": "broken"})
	invalid.save(Progress.SAVE_PATH)
	_check(Progress.load_checkpoint().is_empty(), "Invalid save data must be rejected safely.")
	menu = MenuScene.instantiate()
	root.add_child(menu)
	_check(menu.get_node("%ContinueButton").disabled, "Invalid saves must not enable Continue.")
	current_scene = menu
	menu.get_node("%StartButton").pressed.emit()
	game = await _wait_for_game()
	_check(game.day_number == 1 and game._market_tool_state.get("blessings") == 0, "New Game starts Day 1 with fresh inventory through the loading screen.")
	game.free()
	current_scene = null
	DirAccess.remove_absolute(Progress.SAVE_PATH)
	await process_frame
	await process_frame
	if _failures > 0:
		quit(1)
		return
	print("PASS: paycheck arithmetic, pass boundary, payout idempotence, seed/inventory persistence, retry rollback, anomaly deduplication, menu Continue, day advancement, five-day completion, corrupt-save handling.")
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

func _roster(game: AfterTheEndGame) -> PackedStringArray:
	var names := PackedStringArray()
	for data: PassengerData in game._daily_manifest:
		names.append("%s|%s|%s|%s" % [data.passenger_name, data.anomaly_type, data.origin_station, data.destination_station])
	return names
