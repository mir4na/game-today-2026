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
	var guardian: Variant = game.get_node("%NightLedgerGuardian")
	_check(guardian != null and guardian.visible and guardian.enabled, "NPC 17 watcher must appear only when Night Service begins.")
	if guardian != null:
		guardian.interact()
		await process_frame
		_check(game.state == AfterTheEndGame.GameState.NIGHT_PUZZLE, "Interacting with the watcher must open the Night Ledger map.")
		_check(game._night_puzzle_ui.visible, "The watcher interaction must present the assignment map UI.")
		game._close_night_puzzle()
		await process_frame

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
		var portrait := reader.get_node("%Portrait") as NightCharacterPortrait
		_check(reader.visible, "Interacting with a night passenger must open the Soul Record.")
		_check(anchor.anchor_left == 1.0 and anchor.size.x > anchor.size.y, "Soul Record paper must be horizontal and anchored to the right side.")
		_check(
			portrait.get_source_artwork() == inspected.data.get_character_artwork(),
			"The Soul Record portrait must depict the NPC being inspected, even when their ID portrait is borrowed."
		)
		_check(
			portrait.texture is AtlasTexture,
			"The Soul Record portrait must crop the character artwork to an upper-body frame."
		)
		_check(biography_text.text.contains(puzzle.get_statement_for_passenger(inspected_name)), "The clickable biography must include the hidden statement.")
		_check(game._gameplay_camera.offset.x > 200.0, "Soul Record inspection must shift the gameplay camera toward the player/NPC framing.")
		_check(reader.get_node_or_null("%StatusLabel") == null, "Soul Record must not keep a recorded/rejected status sentence.")
		var correct_sentence_index: int = -1
		var incorrect_sentence_index: int = -1
		for sentence_index: int in reader._sentence_by_index:
			if reader._sentence_by_index[sentence_index] == puzzle.get_statement_for_passenger(inspected_name):
				correct_sentence_index = sentence_index
			elif incorrect_sentence_index < 0:
				incorrect_sentence_index = sentence_index
		_check(correct_sentence_index >= 0, "The embedded clue must remain a selectable sentence.")
		_check(incorrect_sentence_index >= 0, "The biography must retain selectable decoy sentences.")
		if incorrect_sentence_index >= 0:
			reader._on_sentence_clicked(incorrect_sentence_index)
			await create_timer(0.07).timeout
			_check(
				float(reader._error_flash_material.get_shader_parameter(&"strength")) > 0.0,
				"A rejected sentence must produce the red screen feedback effect."
			)
			_check(
				game._gameplay_camera.offset.distance_to(game._night_record_camera_target_offset) > 0.1,
				"A rejected sentence must shake the gameplay camera."
			)
			_check(not game._collected_departure_statements.has(inspected_name), "A rejected sentence must not enter the Night Ledger.")
			await create_timer(0.55).timeout
		if correct_sentence_index >= 0:
			reader._on_sentence_hover_started(correct_sentence_index)
			_check(
				biography_text.text.contains("[url=%d][color=#%s]" % [
					correct_sentence_index,
					reader.hovered_sentence_color.to_html(false),
				]),
				"A hovered biography sentence must turn red."
			)
			reader._on_sentence_hover_ended(correct_sentence_index)
			_check(
				not biography_text.text.contains("[url=%d][color=#%s]" % [
					correct_sentence_index,
					reader.hovered_sentence_color.to_html(false),
				]),
				"A biography sentence must restore its normal color after hover."
			)
			var camera_offset_before_success: Vector2 = game._gameplay_camera.offset
			reader._on_sentence_clicked(correct_sentence_index)
			_check(reader._correct_reveal_characters >= 0, "A correct statement must begin its typewriter reveal.")
			_check(
				biography_text.text.contains("[bgcolor=#%s][color=#%s]" % [
					reader.correct_highlight_background.to_html(false),
					reader.correct_highlight_text_color.to_html(false),
				]),
				"A correct statement must switch to a black highlight with white text."
			)
			_check(game._collected_departure_statements.has(inspected_name), "Clicking the embedded clue must record it in the Night Ledger.")
			_check(
				str(game._collected_departure_statements.get(inspected_name, ""))
				== puzzle.get_statement_for_passenger(inspected_name),
				"The Night Ledger must preserve the exact sentence clicked in the biography."
			)
			await create_timer(0.07).timeout
			_check(
				(reader._error_flash_material.get_shader_parameter(&"flash_color") as Color).is_equal_approx(
					reader.correct_flash_color
				),
				"An accepted sentence must use the green Soul Record feedback color."
			)
			_check(
				float(reader._error_flash_material.get_shader_parameter(&"strength")) > 0.0,
				"An accepted sentence must produce a visible green feedback flash."
			)
			_check(
				game._gameplay_camera.offset.distance_to(camera_offset_before_success) < 0.1,
				"An accepted sentence must not shake the gameplay camera."
			)
			await create_timer(reader.correct_typewriter_seconds + 0.1).timeout
			_check(
				biography_text.text.contains(puzzle.get_statement_for_passenger(inspected_name)),
				"The full correct statement must remain readable after the typewriter reveal."
			)
		reader.request_close()
		await create_timer(0.45).timeout
		_check(not reader.visible, "Soul Record must finish its slide-out close animation.")
		_check(game._gameplay_camera.offset.distance_to(game._night_record_camera_rest_offset) < 1.0, "Closing the record must restore the gameplay camera.")

	game.free()
	if _failures == 0:
		print("PASS: watcher entry, varied hidden statements, and visual sentence feedback.")
	quit(1 if _failures > 0 else 0)
