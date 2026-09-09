extends SceneTree
## Checks clue placement variety and the split camera/vertical paper presentation.

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
	var puzzle: DeparturePuzzleData = game._runtime_puzzle
	_check(puzzle != null, "Night shortcut must create a Soul Record puzzle.")

	var occupied_paragraphs: Dictionary = {}
	for passenger_name: String in puzzle.statement_by_passenger:
		var statement: String = puzzle.get_statement_for_passenger(passenger_name)
		var biography: Array = puzzle.get_biography_for_passenger(passenger_name)
		for paragraph_index: int in range(biography.size()):
			var sentences := biography[paragraph_index] as PackedStringArray
			if sentences.has(statement):
				occupied_paragraphs[paragraph_index] = true
	_check(occupied_paragraphs.has(0), "At least one hidden statement must appear in the opening paragraph.")
	_check(occupied_paragraphs.has(1), "At least one hidden statement must appear in the evidence paragraph.")
	_check(occupied_paragraphs.has(2), "At least one hidden statement must appear in the closing paragraph.")

	var inspected_name: String = str(puzzle.statement_by_passenger.keys()[0])
	var inspected: Passenger = game._find_active_passenger_by_name(inspected_name)
	_check(inspected != null, "A statement holder must remain available for inspection.")
	if inspected != null:
		game._on_night_passenger_interacted(inspected)
		await create_timer(0.45).timeout
		var reader := game._night_soul_record_ui as NightSoulRecordUI
		var anchor := reader.get_node("%RecordAnchor") as Control
		var biography_text := reader.get_node("%BiographyText") as RichTextLabel
		_check(reader.visible, "Interacting with a night passenger must open the Soul Record.")
		_check(anchor.anchor_left == 1.0 and anchor.size.y > anchor.size.x, "Soul Record paper must be vertical and anchored to the right side.")
		_check(biography_text.text.contains(puzzle.get_statement_for_passenger(inspected_name)), "The clickable biography must include the hidden statement.")
		_check(game._gameplay_camera.offset.x > 200.0, "Soul Record inspection must shift the gameplay camera toward the player/NPC framing.")
		var correct_sentence_index: int = -1
		for sentence_index: int in reader._sentence_by_index:
			if reader._sentence_by_index[sentence_index] == puzzle.get_statement_for_passenger(inspected_name):
				correct_sentence_index = sentence_index
				break
		_check(correct_sentence_index >= 0, "The embedded clue must remain a selectable sentence.")
		if correct_sentence_index >= 0:
			reader._on_sentence_clicked(correct_sentence_index)
			_check(game._collected_departure_statements.has(inspected_name), "Clicking the embedded clue must record it in the Night Ledger.")
			_check(
				str(game._collected_departure_statements.get(inspected_name, ""))
				== puzzle.get_statement_for_passenger(inspected_name),
				"The Night Ledger must preserve the exact sentence clicked in the biography."
			)
		reader.request_close()
		await create_timer(0.45).timeout
		_check(not reader.visible, "Soul Record must finish its slide-out close animation.")
		_check(game._gameplay_camera.offset.distance_to(game._night_record_camera_rest_offset) < 1.0, "Closing the record must restore the gameplay camera.")

	game.free()
	if _failures == 0:
		print("PASS: varied hidden statements, vertical Soul Record, and camera shift.")
	quit(1 if _failures > 0 else 0)
