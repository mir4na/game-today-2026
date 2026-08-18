extends SceneTree
## Manual visual-regression capture for the three newly expanded gameplay screens.

const TestFlowHelpers = preload("res://tests/test_flow_helpers.gd")

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("VISUAL_CAPTURE_TEST: SKIP (requires a display renderer)")
		quit()
		return
	root.size = Vector2i(1280, 720)
	var menu_packed := load("res://scenes/menu/main_menu.tscn") as PackedScene
	var menu := menu_packed.instantiate() as MainMenu
	root.add_child(menu)
	current_scene = menu
	await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(1280, 720)
	await process_frame
	_capture("/tmp/where_do_you_belong_main_menu.png")
	menu.call("_show_settings")
	await process_frame
	_capture("/tmp/where_do_you_belong_settings.png")
	menu.queue_free()
	await process_frame

	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var game := packed.instantiate() as AfterTheEndGame
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	var day_intro := game.get("_day_intro_ui") as DayIntroUI
	day_intro.set("_elapsed", 1.1)
	await process_frame
	_capture("/tmp/where_do_you_belong_day_1.png")
	day_intro.skip_intro()
	var opening_cutscene := game.get("_station_stop_ui") as StationStopCutsceneUI
	opening_cutscene.set("_elapsed", 2.45)
	(game.get("_train") as TrainWorld).set_exterior_sequence_elapsed(2.45)
	await process_frame
	_capture("/tmp/where_do_you_belong_alderwick_boarding.png")
	opening_cutscene.set("_elapsed", 5.65)
	(game.get("_train") as TrainWorld).set_exterior_sequence_elapsed(5.65)
	await process_frame
	_capture("/tmp/where_do_you_belong_alderwick_departure.png")
	opening_cutscene.skip_sequence()
	await process_frame
	var player := game.get("_player") as ConductorPlayer
	var camera := player.get_node("Camera2D") as Camera2D
	var hud := game.get("_hud") as GameHUD
	hud.set_cutscene_hidden(true)
	player.global_position = Vector2(470.0, 520.0)
	camera.reset_smoothing()
	await process_frame
	_capture("/tmp/where_do_you_belong_front_crew_cab.png")
	var front_train := game.get("_train") as TrainWorld
	front_train.show_exterior_body(StationStopCutsceneUI.STOP_DURATION, StationStopCutsceneUI.STOP_ARRIVAL_END, StationStopCutsceneUI.STOP_DEPARTURE_START)
	front_train.set_exterior_sequence_elapsed(StationStopCutsceneUI.STOP_ARRIVAL_END)
	await process_frame
	_capture("/tmp/where_do_you_belong_front_crew_cab_exterior.png")
	front_train.hide_exterior_body()
	player.global_position = Vector2(3010.0, 520.0)
	camera.reset_smoothing()
	hud.set_cutscene_hidden(false)
	await process_frame
	_capture("/tmp/where_do_you_belong_day.png")
	game.call("_open_notebook")
	var notebook_ui := game.get("_notebook_ui") as NotebookUI
	notebook_ui.call("_show_route")
	await process_frame
	_capture("/tmp/where_do_you_belong_day_route.png")
	notebook_ui.request_close()

	var eira := game.call("_find_active_passenger_by_name", "Eira Sol") as Passenger
	game.call("_on_passenger_inspection", eira)
	await process_frame
	_capture("/tmp/where_do_you_belong_passenger_assignment.png")
	var inspect_ui := game.get("_inspect_ui") as PassengerInspectUI
	inspect_ui.call("_toggle_station_assignment")
	inspect_ui.request_close()
	var gita := game.call("_find_active_passenger_by_name", "Gita Pranata") as Passenger
	game.call("_on_passenger_inspection", gita)
	inspect_ui.call("_toggle_station_assignment")
	inspect_ui.request_close()
	TestFlowHelpers.announce_next_station(game)
	game.call("_on_station_door_activated")
	var exterior_cutscene := game.get("_station_stop_ui") as StationStopCutsceneUI
	var train := game.get("_train") as TrainWorld
	exterior_cutscene.set("_elapsed", 2.9)
	train.set_exterior_sequence_elapsed(2.9)
	await process_frame
	_capture("/tmp/where_do_you_belong_station_exterior.png")
	exterior_cutscene.skip_sequence()
	for expected_station: String in ["Cinderfield", "Dunmere", "Eastmere"]:
		assert(TestFlowHelpers.complete_next_station_correctly(game) == expected_station)
	assert(game.state == AfterTheEndGame.GameState.DEAD_SELECTION)
	TestFlowHelpers.open_manifest_typewriter(game)
	await process_frame
	_capture("/tmp/where_do_you_belong_manifest.png")

	var selection_ui := game.get("_dead_selection_ui") as DeadSelectionUI
	selection_ui.set_typed_names(PackedStringArray(["Aruna", "Bima", "Citra", "Damar"]))
	selection_ui.call("_confirm")
	await process_frame
	_capture("/tmp/where_do_you_belong_report.png")
	game.call("_on_shift_report_continue")
	game.call("_open_night_puzzle")
	await process_frame
	_capture("/tmp/where_do_you_belong_night_drop_off.png")

	print("VISUAL_CAPTURE_TEST: PASS")
	game.queue_free()
	await process_frame
	await process_frame
	quit()

func _capture(path: String) -> void:
	RenderingServer.force_draw(true, 0.0)
	var error := root.get_texture().get_image().save_png(path)
	assert(error == OK, "Could not save visual capture: %s" % path)
