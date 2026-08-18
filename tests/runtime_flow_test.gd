extends SceneTree
## Headless integration smoke test for the complete playable state flow.

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

	var passengers: Array = game.get("_passengers")
	assert(passengers.size() == 10, "Expected ten initial passenger nodes")
	assert(game.call("_active_passenger_count") == 10, "The daytime train must respect its ten-passenger capacity")
	var player := game.get("_player") as ConductorPlayer
	var desk := game.get("_desk") as ConductorDeskInteractable
	var furnace := game.get("_furnace") as FurnaceInteractable
	var player_scale_anchor := player.get_node("CharacterScale") as Node2D
	var passenger_scale_anchor := (passengers[0] as Passenger).get_node("CharacterScale") as Node2D
	var cutscene_actor := (game.get("_station_stop_ui") as StationStopCutsceneUI).get_node("%Actor0") as Node2D
	var cutscene_actor_visual := cutscene_actor.get_node("TintedVisual") as Node2D
	assert(player_scale_anchor.scale.y >= 1.6, "The conductor visual should be approximately half the carriage interior height")
	assert(passenger_scale_anchor.scale.y >= 1.5, "Adult passenger visuals should be at least half the carriage interior height")
	assert(cutscene_actor_visual.scale.y >= 3.5, "Boarding cutscene people should match the enlarged gameplay proportions")
	assert(player.global_position.x > 0.0 and player.global_position.x < 960.0, "The player must first spawn inside the front driver and conductor cab")
	assert(desk.global_position.x < furnace.global_position.x, "The front crew cab must be far left and the coal car far right")
	assert(desk.global_position.x > 600.0 and desk.global_position.x < 960.0, "The route ledger must sit in the conductor half of the front crew cab")
	assert(desk.has_node("AbnormalPassengerTypewriter"), "The conductor desk should visibly contain the scene-authored abnormal-passenger typewriter")

	var initial_dead_count: int = 0
	var ai_behaviors: Dictionary = {}
	var inspect_ui := game.get("_inspect_ui") as PassengerInspectUI
	for passenger: Passenger in passengers:
		initial_dead_count += 1 if passenger.data.is_dead else 0
		ai_behaviors[passenger.get_ai_behavior()] = true
		game.call("_on_passenger_inspection", passenger)
		inspect_ui.request_close()
	assert(initial_dead_count == 1, "Only Damar should begin aboard; other deceased impostors must board at later stations")
	assert(ai_behaviors.size() >= 4, "The passenger roster should contain several distinct AI behavior profiles")
	assert((game.get("_inspected_data") as Array).size() == 10, "Every initial inspection should enter the notebook")
	inspect_ui.call("_show_ticket")
	assert(not "SEAT" in (inspect_ui.get("_content") as RichTextLabel).text.to_upper(), "Passenger tickets should not assign seats")
	assert("NAIK DARI" in (inspect_ui.get("_content") as RichTextLabel).text.to_upper(), "Ticket terminology should explain the boarding station")
	game.call("_open_notebook")
	var notebook_ui := game.get("_notebook_ui") as NotebookUI
	assert(not "SEAT" in (notebook_ui.get("_content") as RichTextLabel).text.to_upper(), "Notebook passenger records should not assign seats")
	notebook_ui.request_close()

	var minimap := (game.get("_hud") as GameHUD).get("_minimap") as TrainMinimap
	var minimap_labels := PackedStringArray()
	for slot_name: String in ["Slot0", "Slot1", "Slot2", "Slot3", "Slot4", "Slot5"]:
		minimap_labels.append((minimap.get_node("%s/Label" % slot_name) as Label).text)
	assert(minimap_labels == PackedStringArray(["C", "4", "3", "2", "1", "K"]), "Minimap must show the crew cab at the far left and coal at the far right")
	var minimap_counts := minimap.get("_passenger_counts") as PackedInt32Array
	var minimap_total: int = 0
	for count: int in minimap_counts:
		minimap_total += count
	assert(minimap_total == 10, "Minimap passenger dots should represent all ten active passengers")

	var fajar := game.call("_find_active_passenger_by_name", "Fajar Noor") as Passenger
	var fajar_start_x: float = fajar.position.x
	fajar.call("_process", 20.0)
	fajar.call("_process", 1.0)
	assert(not is_equal_approx(fajar.position.x, fajar_start_x), "A wandering passenger should move after its behavior interval")
	var petra := game.call("_find_active_passenger_by_name", "Petra Voss") as Passenger
	var petra_start_x: float = petra.position.x
	petra.call("_process", 30.0)
	assert(is_equal_approx(petra.position.x, petra_start_x), "A still passenger should remain in place")
	var damar := game.call("_find_active_passenger_by_name", "Damar Vey") as Passenger
	var damar_start_carriage: int = damar.get_runtime_carriage()
	damar.call("_process", 20.0)
	damar.call("_process", 20.0)
	assert(damar.get_runtime_carriage() != damar_start_carriage, "A carriage-roamer should cross into a neighboring passenger car")
	game.call("_update_passenger_minimap")
	var moved_counts := minimap.get("_passenger_counts") as PackedInt32Array
	assert(moved_counts[5 - damar_start_carriage] < minimap_counts[5 - damar_start_carriage], "Minimap dots should leave a passenger's previous carriage")

	assert(AfterTheEndGame.STATION_TRAVEL_SECONDS == 60.0, "Travel between every pair of stations must take one gameplay minute")
	assert(AfterTheEndGame.FINAL_ARRIVAL_MINUTES - AfterTheEndGame.START_MINUTES == 4.0 * AfterTheEndGame.STATION_TRAVEL_SECONDS, "The full A-to-final route should contain four sixty-second legs")
	assert(AfterTheEndGame.DAY_ROUTE == ["Alderwick", "Brambleford", "Cinderfield", "Dunmere", "Eastmere"], "The day route order must run from Alderwick through every named station to Eastmere")

	game.call("_on_coal_added", 16.0)
	game.call("_on_newspaper_read")
	var first_newspaper_document: String = (inspect_ui.get("_content") as RichTextLabel).text
	assert((game.get("_newspaper") as NewspaperInteractable).enabled, "The newspaper must remain interactable after it is read")
	inspect_ui.request_close()
	game.call("_on_newspaper_read")
	assert(inspect_ui.visible, "The newspaper should reopen on later interactions")
	assert(game.get("_newspaper_read") == true, "Rereading must preserve the collected evidence state")
	assert((inspect_ui.get("_content") as RichTextLabel).text == first_newspaper_document, "One playthrough must keep the same randomized newspaper edition on every reread")
	inspect_ui.request_close()

	var expected_stops: Array[String] = ["Brambleford", "Cinderfield", "Dunmere", "Eastmere"]
	var expected_dead_counts: Array[int] = [2, 3, 4, 4]
	for stop_index: int in range(expected_stops.size()):
		var serviced_station: String = TestFlowHelpers.complete_next_station_correctly(game)
		assert(serviced_station == expected_stops[stop_index], "Day stops must be handled in route order")
		assert(int(game.get("_route_index")) == stop_index + 1, "Route progress should advance exactly once per station")
		var active_dead_count: int = 0
		var station_boarders: int = 0
		for passenger: Passenger in game.get("_passengers") as Array:
			if passenger.departed:
				continue
			active_dead_count += 1 if passenger.data.is_dead else 0
			if not passenger.data.initially_on_train and passenger.data.origin_station == serviced_station:
				station_boarders += 1
		assert(active_dead_count == expected_dead_counts[stop_index], "Dead impostors should enter from multiple daytime stations")
		assert(station_boarders == 2, "%s must board exactly as many passengers as it disembarks" % serviced_station)

	assert(game.state == AfterTheEndGame.GameState.DEAD_SELECTION, "Reaching Eastmere should end daytime and wait for the crew-cab manifest")
	assert(game.get("_completed_station_exchanges") == 4, "All four daytime exchanges should complete before night")
	assert(game.get("_station_mistake_count") == 0, "A correct full route should seal no station mistakes")
	assert(game.get("_penalty_points") == 0, "Station results must not expose penalties before the transition report")
	var active_dead_names := PackedStringArray()
	for dead_data: PassengerData in game.call("_get_dead_passenger_data") as Array:
		active_dead_names.append(dead_data.short_name)
	active_dead_names.sort()
	assert(active_dead_names == PackedStringArray(["Aruna", "Bima", "Citra", "Damar"]), "The four station-spanning impostors must remain aboard for night service")

	var selection_ui := TestFlowHelpers.open_manifest_typewriter(game)
	var report_entries: Array[LineEdit] = selection_ui.get("_entries") as Array[LineEdit]
	assert(report_entries.size() == 5, "The abnormal passenger tool must provide five name rows")
	report_entries[0].text = "Aruna "
	selection_ui.call("_on_name_entry_1_text_changed", report_entries[0].text)
	assert(report_entries[0].text == "Aruna" and report_entries[1].has_focus(), "Typing Space after a name should trim the delimiter and focus the next row")
	selection_ui.request_close()
	assert(game.state == AfterTheEndGame.GameState.DEAD_SELECTION and player.movement_enabled, "Closing the typewriter should return control without skipping paycheck validation")
	selection_ui = TestFlowHelpers.open_manifest_typewriter(game)
	selection_ui.set_typed_names(PackedStringArray(["Aruna Vey", "Bima Sena", "Citra Lume", "Eira Sol"]))
	selection_ui.call("_confirm")
	assert(game.state == AfterTheEndGame.GameState.DEAD_SELECTION, "A wrong typed name must reject the manifest")
	assert(game.get("_penalty_points") == 10, "A wrong identity should add penalty points")
	selection_ui.set_typed_names(PackedStringArray(["Aruna Vey", "Bima Sena", "Citra Lume", "Damar Vey"]))
	selection_ui.call("_confirm")
	assert(game.state == AfterTheEndGame.GameState.SHIFT_REPORT, "Correct typed names should open the day report")
	assert(game.get("_merit") >= AfterTheEndGame.PAYCHECK_THRESHOLD, "A well-played shift should clear the paycheck threshold")
	assert(game.get("_service_points") == 0, "A cleared paycheck should not issue an SP")
	game.call("_on_shift_report_continue")
	assert(game.state == AfterTheEndGame.GameState.NIGHT, "Continuing the shift report should enter NIGHT")

	game.call("_open_night_puzzle")
	var puzzle := game.get("puzzle_resource") as DeparturePuzzleData
	assert(puzzle.night_stations.size() == 4 and not puzzle.night_stop_clues.is_empty(), "Night drop-off data should use explicit, player-readable terminology")
	var correct_assignments: Dictionary = {
		"Mistvale": "Bima",
		"Ashmoor": "Citra",
		"Hearth": "Aruna",
		"Dawnreach": "Damar"
	}
	game.call("_on_departures_confirmed", correct_assignments)
	assert(game.state == AfterTheEndGame.GameState.COMPLETE, "Correct night stops should complete the prototype")
	print("RUNTIME_FLOW_TEST: PASS")
	game.queue_free()
	await process_frame
	quit()
