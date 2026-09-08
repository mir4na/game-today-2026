extends SceneTree
## Run with Godot --headless --path . --script tools/test_minigame_resume.gd.

var _failures: int = 0
var _cleaned_events: Array[Node] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _press(control: Control, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	event.global_position = control.global_position + point
	control._gui_input(event)


func _motion(control: Control, point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = control.global_position + point
	control._gui_input(event)


func _exit_with_interact(control: Control) -> void:
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	control._unhandled_input(event)
	_check(not control.visible, "E closes the minigame.")


func _check_escape_is_reserved_for_pause(control: Control) -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	control._unhandled_input(event)
	_check(control.visible, "Esc does not close the minigame directly.")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var first_event := Node.new()
	var next_event := Node.new()
	root.add_child(first_event)
	root.add_child(next_event)
	var cleaning: CleanSeatUI = load("res://scenes/ui/clean_seat_ui.tscn").instantiate()
	root.add_child(cleaning)
	_check(cleaning.process_mode == Node.PROCESS_MODE_PAUSABLE, "Clean Seat freezes under PauseUI.")
	cleaning.completed.connect(func(event: Node) -> void: _cleaned_events.append(event))
	await process_frame
	cleaning.open_cleaning(first_event)
	var surface: CleanSeatSurface = cleaning.get_node("%WipeSurface")
	_press(surface, surface.size * Vector2(0.5, 0.28))
	var saved_mask: PackedByteArray = surface._mask_image.get_data()
	var saved_progress: String = cleaning._progress_label.text
	_check(surface._calculate_progress() > 0.0 and surface._calculate_progress() < 0.98, "Wiping creates partial progress.")
	var cleaning_close_button := cleaning.get_node("%CloseButton") as Button
	var cleaning_close_hint := cleaning.get_node("%CloseHint") as Label
	_check(cleaning_close_button.text == "X" and cleaning_close_hint.text.contains("[E]"), "Clean Seat shows its round close button and E close hint.")
	_check_escape_is_reserved_for_pause(cleaning)
	for attempt: int in 3:
		if attempt == 0:
			cleaning_close_button.pressed.emit()
			_check(not cleaning.visible, "The Clean Seat close button exits the minigame.")
		else:
			_exit_with_interact(cleaning)
		_check(not surface._wiping and not surface._cloth.visible, "Closing releases the cloth mid-wipe.")
		cleaning.open_cleaning(first_event)
		_motion(surface, surface.size * Vector2(0.47, 0.8))
		_check(surface._mask_image.get_data() == saved_mask, "Reopening preserves cleaned pixels; hovering cannot keep wiping.")
		_check(cleaning._progress_label.text == saved_progress, "Reopening preserves the displayed percentage.")
	_press(surface, surface.size * Vector2(0.47, 0.8))
	_check(surface._mask_image.get_data() != saved_mask, "A new press resumes cleaning.")
	# Finish through actual cloth input after resuming.
	for y: int in range(0, ceili(surface.size.y) + 1, 16):
		_motion(surface, Vector2(0, y))
		_motion(surface, Vector2(surface.size.x, y))
	await create_timer(0.65).timeout
	_check(_cleaned_events == [first_event] and not cleaning.visible, "Resumed cleaning completes its event exactly once.")
	cleaning.open_cleaning(next_event)
	_check(is_zero_approx(surface._calculate_progress()), "A new dirty-seat event starts dirty.")
	_check(cleaning._progress_label.visible and cleaning._progress_label.text == cleaning.progress_template % 0, "New events restore progress feedback.")
	cleaning.free()
	var puzzle: BlockedAislePuzzleUI = load("res://scenes/ui/blocked_aisle_puzzle_ui.tscn").instantiate()
	root.add_child(puzzle)
	_check(puzzle.process_mode == Node.PROCESS_MODE_PAUSABLE, "Blocked Aisle freezes under PauseUI.")
	puzzle.open_puzzle(first_event)
	var piece: PackingPiece = puzzle._pieces[0] as PackingPiece
	_press(piece, Vector2(8, 8))
	piece.global_position = puzzle._target_board.global_position
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.global_position = puzzle._target_board.global_position + Vector2(8, 8)
	piece._gui_input(release)
	var saved_position: Vector2 = piece.position
	var saved_cells: Dictionary = puzzle._occupied_cells.duplicate()
	_check(not saved_cells.is_empty(), "Dropping luggage places it on the rack.")
	var puzzle_close_button := puzzle.get_node("%CloseButton") as Button
	var puzzle_close_hint := puzzle.get_node("%CloseHint") as Label
	_check(puzzle_close_button.text == "X" and puzzle_close_hint.text.contains("[E]"), "Blocked Aisle shows its round close button and E close hint.")
	_check_escape_is_reserved_for_pause(puzzle)
	for attempt: int in 3:
		if attempt == 0:
			puzzle_close_button.pressed.emit()
			_check(not puzzle.visible, "The Blocked Aisle close button exits the minigame.")
		else:
			_exit_with_interact(puzzle)
		puzzle.open_puzzle(first_event)
		_check(puzzle._pieces[0] == piece and piece.position == saved_position, "Reopening keeps the same luggage and placement.")
		_check(puzzle._occupied_cells == saved_cells, "Reopening preserves occupied rack cells.")
	_press(piece, Vector2(8, 8))
	_motion(piece, Vector2(-150, 100))
	_exit_with_interact(puzzle)
	puzzle.open_puzzle(first_event)
	_motion(piece, Vector2(200, 100))
	_check(not piece._dragging and piece.position == saved_position, "E mid-drag restores the last placement and ends dragging.")
	_check(puzzle._occupied_cells == saved_cells, "E mid-drag restores rack occupancy.")
	puzzle.open_puzzle(next_event)
	_check(puzzle._occupied_cells.is_empty(), "A new blocked-aisle event starts with an empty rack.")
	puzzle.free()
	first_event.free()
	next_event.free()
	if _failures == 0:
		print("PASS: E/buttons close minigames, Esc stays reserved for pause, and progress survives reopen.")
	quit(1 if _failures else 0)
