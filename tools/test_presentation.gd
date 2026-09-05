extends SceneTree
var _closed_count: int = 0
var _failures: int = 0
func _initialize() -> void:
	call_deferred("_run")
func _check(value: bool, message: String) -> void:
	if not value:
		_failures += 1
		push_error(message)
func _run() -> void:
	var overlay: DocumentOverlayUI = load("res://scenes/ui/document_overlay_ui.tscn").instantiate()
	root.add_child(overlay)
	overlay.closed.connect(func() -> void: _closed_count += 1)
	var reader: NewspaperReader = overlay.get_node("%NewspaperReader")
	var player: AnimationPlayer = reader.get_node("PresentationAnimation")
	for variant: int in 2:
		reader.set_variant(variant)
		overlay.show_newspaper("")
		await create_timer(0.95).timeout
		overlay.request_close()
		overlay.request_close()
		_check(overlay.visible and overlay._closing, "Newspaper stays modal during dismissal.")
		await create_timer(0.45).timeout
		_check(reader.get_node("Type%d" % (variant + 1)).position.y > 100, "Newspaper must descend before it disappears.")
		await create_timer(0.5).timeout
		_check(not overlay.visible and _closed_count == variant + 1, "Each edition dismisses once after reverse playback.")
	overlay.show_newspaper("")
	await create_timer(0.2).timeout
	var lift_position: float = player.current_animation_position
	var y_before: float = reader.get_node("Type2").position.y
	overlay.request_close()
	_check(is_equal_approx(lift_position, player.current_animation_position), "Early Esc reverses from the current animation time.")
	_check(is_equal_approx(y_before, reader.get_node("Type2").position.y), "Early dismissal must not jump to the fully raised pose.")
	await create_timer(0.35).timeout
	_check(not overlay.visible and _closed_count == 3, "Early close completes without waiting for a full lift.")
	overlay.show_newspaper("")
	await create_timer(0.2).timeout
	overlay.request_close()
	overlay.show_newspaper("")
	await create_timer(0.95).timeout
	_check(overlay.visible and _closed_count == 3, "An older close request must not hide a newly opened newspaper.")
	overlay.request_close()
	await create_timer(0.95).timeout
	_check(not overlay.visible and _closed_count == 4, "Reopening restores normal dismissal.")
	overlay._show_reader("Title", "Body")
	overlay.request_close()
	_check(not overlay.visible and _closed_count == 5, "Non-newspaper documents still close immediately.")
	overlay.free()
	var puzzle: BlockedAislePuzzleUI = load("res://scenes/ui/blocked_aisle_puzzle_ui.tscn").instantiate()
	root.add_child(puzzle)
	var event := Node.new()
	root.add_child(event)
	puzzle.open_puzzle(event)
	_check(puzzle.get_node("Shade").color.a >= 0.6, "Blocked aisle has a dark backdrop.")
	_check(not puzzle.has_node("PuzzleWindow/Hint") and not puzzle.has_node("PuzzleWindow/Instruction"), "Control instructions are removed.")
	_check(not puzzle.has_method("reset_puzzle"), "There is no player reset mechanism.")
	var piece: Control = puzzle._pieces[0]
	piece.position += Vector2(12, 8)
	var placed_position: Vector2 = piece.position
	var reset_key := InputEventKey.new()
	reset_key.physical_keycode = KEY_R
	reset_key.pressed = true
	puzzle._unhandled_input(reset_key)
	_check(piece.position == placed_position, "R does not move or reset luggage.")
	puzzle.request_close()
	puzzle.open_puzzle(event)
	_check(piece.position == placed_position, "Closing and reopening preserves the puzzle.")
	puzzle.free()
	event.free()
	if _failures == 0:
		print("PASS: both newspaper editions, reverse close, repeated/early close, reopen race, instant document close, blocked aisle dim/no hints/no reset.")
	quit(1 if _failures else 0)
