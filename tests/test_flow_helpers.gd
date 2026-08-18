class_name TestFlowHelpers
extends RefCounted
## Shared transition helper for gameplay tests that start after the mandatory opening.

static func finish_opening(game: AfterTheEndGame) -> void:
	assert(game.state == AfterTheEndGame.GameState.OPENING, "Gameplay should begin with the DAY 1 opening state")
	var intro := game.get("_day_intro_ui") as DayIntroUI
	assert(intro.visible, "The full-screen DAY 1 card should appear before gameplay")
	intro.set("_elapsed", 0.0)
	assert(is_zero_approx(float(intro.call("_text_alpha"))), "DAY 1 should begin fully faded out")
	intro.set("_elapsed", DayIntroUI.FADE_IN_END)
	assert(is_equal_approx(float(intro.call("_text_alpha")), 1.0), "DAY 1 should fade to full opacity")
	var start_minutes: float = game.get("_day_minutes")
	intro.set("_elapsed", DayIntroUI.INTRO_DURATION)
	assert(is_zero_approx(float(intro.call("_text_alpha"))), "DAY 1 should fade fully out before the station cutscene")
	intro.call("_process", 0.01)
	var station_cutscene := game.get("_station_stop_ui") as StationStopCutsceneUI
	assert(station_cutscene.visible, "The Alderwick boarding cutscene should follow the day card")
	var train := game.get("_train") as TrainWorld
	assert(train.is_exterior_body_visible(), "The train body layer should cover the interior without changing gameplay cameras")
	assert(not (station_cutscene.get("_door_screen_positions") as PackedVector2Array).is_empty(), "Cutscene passengers need doors projected through the gameplay camera")
	assert(station_cutscene.get("_opening_mode") == true, "The first station vignette should use opening mode")
	var boarding_actors := station_cutscene.get("_boarding_actors") as Array
	assert(boarding_actors.size() == 10, "All ten starting passengers should visibly board at Alderwick")
	var carriages: Dictionary = {}
	for actor: Dictionary in boarding_actors:
		carriages[int(actor.get("carriage", 0))] = true
	assert(carriages.size() >= 3, "Opening passengers should enter through multiple carriages")
	station_cutscene.call("_process", StationStopCutsceneUI.OPENING_DURATION)
	assert(game.state == AfterTheEndGame.GameState.DAY, "Interior gameplay should begin after the train departs")
	assert(not train.is_exterior_body_visible(), "The body layer should reveal the interior when gameplay begins")
	assert(is_equal_approx(float(game.get("_day_minutes")), start_minutes), "The one-minute station clock must not run during the opening")
	assert(game.call("_current_day_station") == "Alderwick", "Day gameplay must begin at Alderwick")
	assert(game.call("_next_day_station") == "Brambleford", "Brambleford must be the first daytime destination")

static func announce_next_station(game: AfterTheEndGame) -> String:
	var station_name: String = game.call("_next_day_station")
	game.set("_day_minutes", float(game.call("_next_arrival_minutes")))
	game.call("_process", 0.0)
	assert(game.get("_station_arrival_announced") == true, "%s should announce after a sixty-second leg" % station_name)
	return station_name

static func assign_expected_for_next_station(game: AfterTheEndGame) -> PackedStringArray:
	var station_name: String = game.call("_next_day_station")
	var names := PackedStringArray()
	var inspect_ui := game.get("_inspect_ui") as PassengerInspectUI
	for passenger: Passenger in game.get("_passengers") as Array:
		if not passenger.departed and not passenger.data.is_dead and passenger.data.destination_station == station_name:
			names.append(passenger.data.passenger_name)
			game.call("_on_passenger_inspection", passenger)
			assert((inspect_ui.get("_assignment_panel") as PanelContainer).visible, "Expected passenger assignment UI for %s" % station_name)
			inspect_ui.call("_toggle_station_assignment")
			inspect_ui.request_close()
	assert(names.size() == AfterTheEndGame.STATION_BOARDING_COUNT, "%s should schedule exactly two living passengers" % station_name)
	return names

static func complete_next_station_correctly(game: AfterTheEndGame) -> String:
	var station_name: String = game.call("_next_day_station")
	var assigned_names: PackedStringArray = assign_expected_for_next_station(game)
	assert(assigned_names.size() == AfterTheEndGame.STATION_BOARDING_COUNT)
	announce_next_station(game)
	var stopped_clock: float = game.get("_day_minutes")
	game.call("_process", 1.0)
	assert(is_equal_approx(float(game.get("_day_minutes")), stopped_clock), "The route clock should pause while station duties are waiting")
	game.call("_on_station_door_activated")
	var stop_ui := game.get("_station_stop_ui") as StationStopCutsceneUI
	assert(stop_ui.visible, "%s should begin an exterior exchange cutscene" % station_name)
	assert((game.get("_train") as TrainWorld).is_exterior_body_visible(), "%s exchange should cover the interior with the exterior train body" % station_name)
	assert((stop_ui.get("_departing_actors") as Array).size() == AfterTheEndGame.STATION_BOARDING_COUNT, "%s should show two passengers getting off" % station_name)
	assert((stop_ui.get("_boarding_actors") as Array).size() == AfterTheEndGame.STATION_BOARDING_COUNT, "%s should show an equal number boarding" % station_name)
	stop_ui.skip_sequence()
	assert(not (game.get("_train") as TrainWorld).is_exterior_body_visible(), "Interior gameplay should return after departing %s" % station_name)
	assert(game.call("_active_passenger_count") == AfterTheEndGame.MAX_ACTIVE_PASSENGERS, "%s exchange must restore the ten-passenger capacity" % station_name)
	return station_name

static func open_manifest_typewriter(game: AfterTheEndGame) -> DeadSelectionUI:
	assert(game.state == AfterTheEndGame.GameState.DEAD_SELECTION, "The day route should wait for the abnormal passenger report")
	var selection_ui := game.get("_dead_selection_ui") as DeadSelectionUI
	var desk := game.get("_desk") as ConductorDeskInteractable
	var player := game.get("_player") as ConductorPlayer
	assert(not selection_ui.visible, "The manifest must not open automatically at the final station")
	assert(player.movement_enabled and player.interaction_enabled, "The player must be able to walk back to the front crew cab")
	assert(desk.prompt_text == desk.manifest_prompt, "The crew-cab tool should advertise the abnormal passenger report before paycheck review")
	player.global_position = desk.global_position + Vector2(-80.0, 0.0)
	player.call("_physics_process", 0.0)
	assert(player.get("_nearest") == desk, "Walking near the typewriter should select it as the contextual interaction")
	game.call("_on_interaction_pressed", desk)
	assert(selection_ui.visible, "Interacting with the crew-cab typewriter should open the typed manifest")
	assert(not player.movement_enabled and not player.interaction_enabled, "Typing at the manifest tool should pause world control")
	return selection_ui
