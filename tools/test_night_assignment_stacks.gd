extends SceneTree
## Verifies exact ledger copy, character drag previews, and multi-soul stations.

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
	game._on_debug_night_requested()
	var puzzle: DeparturePuzzleData = game._get_departure_puzzle()
	var passengers: Array[PassengerData] = game._get_dead_passenger_data()
	var statements: Dictionary = {}
	for data: PassengerData in passengers:
		statements[data.short_name] = puzzle.get_statement_for_passenger(data.short_name)
	game._night_puzzle_ui.open_puzzle(passengers, puzzle, statements)
	await process_frame

	var board := game._night_puzzle_ui as NightPuzzleUI
	var first_station: String = puzzle.night_stations[0]
	var first_name: String = passengers[0].short_name
	var second_name: String = passengers[1].short_name
	board._assign_passenger_to_station(first_station, first_name)
	board._assign_passenger_to_station(first_station, second_name)
	var stacked: Array = board._passengers_assigned_to(first_station)
	_check(stacked.size() == 2, "A station must retain more than one assigned soul.")
	_check(stacked.has(first_name) and stacked.has(second_name), "Stacked station assignments must retain both passenger names.")
	var first_target := board._station_targets[0] as NightStationTarget
	_check(first_target.get_node("%AssignmentFaces").get_child_count() == 2, "A stacked station must render one face token per assigned NPC.")

	var first_card := board._passenger_cards[0] as NightPassengerCard
	_check(first_card.get_node("%StatementLabel").text == statements[first_name], "The ledger card must show the exact biography sentence.")
	# Scene linkage is the invariant that keeps the visual preview editable.
	_check(first_card.drag_preview_scene != null, "The passenger drag preview must be supplied by a scene resource.")
	_check(first_target.face_token_scene != null, "Station face tokens must be supplied by a scene resource.")
	if first_card.drag_preview_scene != null:
		var preview := first_card.drag_preview_scene.instantiate() as NightPassengerDragPreview
		preview.configure(passengers[0])
		var preview_sprite := preview.get_node("%CharacterSprite") as TextureRect
		_check(preview_sprite.texture == passengers[0].get_character_artwork(), "Dragging must use the NPC character artwork.")
		preview.free()
	var expected_name: String = str(puzzle.correct_passenger_by_station.get(
		puzzle.night_stations[0], ""
	))
	_check(
		game._night_assignment_contains(
			{puzzle.night_stations[0]: [expected_name, "another soul"]},
			puzzle.night_stations[0],
			expected_name
		),
		"A correct soul must still score when its station holds multiple assignments."
	)

	game.free()
	if _failures == 0:
		print("PASS: exact ledger statements and stacked night assignments.")
	quit(1 if _failures > 0 else 0)
