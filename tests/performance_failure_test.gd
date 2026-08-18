extends SceneTree
## Verifies low daytime performance issues SP and penalties only at transition.

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

	# Handle the route correctly but skip optional inspections and furnace duty.
	for expected_station: String in ["Brambleford", "Cinderfield", "Dunmere", "Eastmere"]:
		assert(TestFlowHelpers.complete_next_station_correctly(game) == expected_station)
	game.set("_coal", 20.0)
	assert(game.get("_penalty_points") == 0, "Daytime penalties must remain hidden until the transition report")
	assert(game.state == AfterTheEndGame.GameState.DEAD_SELECTION)
	var selection_ui := TestFlowHelpers.open_manifest_typewriter(game)
	selection_ui.set_typed_names(PackedStringArray(["Aruna", "Bima", "Citra", "Damar"]))
	selection_ui.call("_confirm")

	assert(game.state == AfterTheEndGame.GameState.SHIFT_REPORT, "A valid manifest should reach the report even after poor duties")
	assert(game.get("_merit") < AfterTheEndGame.PAYCHECK_THRESHOLD, "Skipped optional duties should miss the multi-stop paycheck threshold")
	assert(game.get("_penalty_points") == AfterTheEndGame.LOW_COAL_POINTS, "Low coal should be revealed as a transition penalty")
	assert(game.get("_service_points") == 1, "Missing the daily threshold should issue SP 1")
	print("PERFORMANCE_FAILURE_TEST: PASS")
	game.queue_free()
	await process_frame
	quit()
