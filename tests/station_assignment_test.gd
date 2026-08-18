extends SceneTree
## Verifies a wrong stop is sealed during day and reviewed only after the full route.

const TestFlowHelpers = preload("res://tests/test_flow_helpers.gd")

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var game := packed.instantiate() as AfterTheEndGame
	root.add_child(game)
	current_scene = game
	await process_frame
	TestFlowHelpers.finish_opening(game)

	var inspect_ui := game.get("_inspect_ui") as PassengerInspectUI
	# Eira is scheduled for Brambleford; Petra is a deliberately wrong assignment.
	for passenger_name: String in ["Eira Sol", "Petra Voss"]:
		var passenger := game.call("_find_active_passenger_by_name", passenger_name) as Passenger
		game.call("_on_passenger_inspection", passenger)
		inspect_ui.call("_toggle_station_assignment")
		inspect_ui.request_close()
	assert((game.get("_station_assignment") as PackedStringArray).size() == 2, "Passenger interaction should create the first-stop assignments")
	var petra := game.call("_find_active_passenger_by_name", "Petra Voss") as Passenger
	game.call("_on_passenger_inspection", petra)
	assert((inspect_ui.get("_assignment_button") as Button).text == "CANCEL DISEMBARK", "An assigned passenger must expose an explicit cancel action")
	inspect_ui.call("_toggle_station_assignment")
	assert((game.get("_station_assignment") as PackedStringArray).size() == 1, "Cancel should remove the passenger from the pending disembark list")
	assert((inspect_ui.get("_assignment_button") as Button).text == inspect_ui.assign_button_text, "A canceled passenger must be assignable again")
	inspect_ui.request_close()
	TestFlowHelpers.announce_next_station(game)
	game.call("_on_station_door_activated")
	assert(game.get("_station_exchange_processed") == false, "The station door must wait until exactly two disembarks are selected")
	game.call("_on_passenger_inspection", petra)
	inspect_ui.call("_toggle_station_assignment")
	inspect_ui.request_close()
	game.call("_on_station_door_activated")
	assert(game.get("_station_mistake_count") == 1, "Replacing one scheduled passenger with a wrong one should count as one station mistake")
	assert(game.get("_penalty_points") == 0, "A station mistake must not reveal or apply points during daytime")
	assert(game.call("_active_passenger_count") == 10, "Wrong assignments must still preserve the ten-passenger capacity")
	var gita := game.call("_find_active_passenger_by_name", "Gita Pranata") as Passenger
	assert(gita != null and not gita.departed, "A passenger missed at their destination must remain aboard until explicitly disembarked")
	(game.get("_station_stop_ui") as StationStopCutsceneUI).skip_sequence()

	for expected_station: String in ["Cinderfield", "Dunmere", "Eastmere"]:
		assert(TestFlowHelpers.complete_next_station_correctly(game) == expected_station)
	assert(game.state == AfterTheEndGame.GameState.DEAD_SELECTION, "The manifest tool should activate only after reaching the final daytime station")
	assert(game.get("_penalty_points") == 0, "The sealed Brambleford result must remain hidden until the report")

	var selection_ui := TestFlowHelpers.open_manifest_typewriter(game)
	selection_ui.set_typed_names(PackedStringArray(["Aruna", "Bima", "Citra", "Damar"]))
	selection_ui.call("_confirm")
	assert(game.state == AfterTheEndGame.GameState.SHIFT_REPORT, "The transition should reveal the sealed station result")
	assert(game.get("_penalty_points") == AfterTheEndGame.MISSED_STOP_POINTS * 4, "A wrong drop plus a passenger carried three stops past their destination should add four distance units")
	assert(game.get("_station_mistake_count") == 4, "Penalty units must increase with the distance from the passenger's ticket destination")
	print("STATION_ASSIGNMENT_TEST: PASS")
	game.queue_free()
	await process_frame
	quit()
