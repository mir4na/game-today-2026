extends SceneTree
## Verifies the level-by-level distraction schedule and its first-time hints.

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

	var expected: Array[Dictionary] = [
		{"day": 1, "blocked": false, "clean": false},
		{"day": 2, "blocked": true, "clean": false},
		{"day": 3, "blocked": false, "clean": true},
		{"day": 4, "blocked": true, "clean": true},
		{"day": 5, "blocked": true, "clean": true},
	]
	for row: Dictionary in expected:
		game.day_number = int(row.day)
		_check(
			game._blocked_aisle_enabled_for_level() == bool(row.blocked),
			"Blocked aisle schedule is wrong for level %d." % game.day_number
		)
		_check(
			game._clean_seat_enabled_for_level() == bool(row.clean),
			"Clean-seat schedule is wrong for level %d." % game.day_number
		)
		game._blocked_aisle_timer.stop()
		game._dirty_seat_timer.stop()
		game._schedule_maintenance_events()
		_check(
			(not game._blocked_aisle_timer.is_stopped()) == bool(row.blocked),
			"Blocked aisle timer does not match level %d." % game.day_number
		)
		_check(
			(not game._dirty_seat_timer.is_stopped()) == bool(row.clean),
			"Clean-seat timer does not match level %d." % game.day_number
		)

	game.day_number = 2
	game._active_modal = null
	_check(game._show_level_start_hint_if_needed(), "Level 2 must present the blocked-aisle hint.")
	_check(game._hint_ui.visible, "The level 2 hint should be visible.")
	_check(game._hint_ui.get_node("%BlockedAisle").visible, "Level 2 must show the blocked-aisle panel.")
	game._active_modal = null
	game._hint_ui.hide()

	game.day_number = 3
	_check(game._show_level_start_hint_if_needed(), "Level 3 must present the clean-seat hint.")
	_check(game._hint_ui.visible, "The level 3 hint should be visible.")
	_check(game._hint_ui.get_node("%CleanTheSeat").visible, "Level 3 must show the clean-seat panel.")
	game._active_modal = null
	game._hint_ui.hide()

	for day: int in [1, 4, 5]:
		game.day_number = day
		_check(not game._show_level_start_hint_if_needed(), "Only levels 2 and 3 should show onboarding hints.")

	game.free()
	if _failures == 0:
		print("PASS: maintenance progression and level hints.")
	quit(1 if _failures > 0 else 0)
