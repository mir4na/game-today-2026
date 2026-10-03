extends SceneTree
## Verifies the single campaign day's display label and both obstacle lessons.

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
	game._day_intro_ui.hide()
	game._active_modal = null
	game.state = AfterTheEndGame.GameState.DAY
	_check(game.day_number == 2, "The campaign must retain the second-shift content.")
	_check(game._display_day_number() == 1, "The single campaign shift must display Day 1.")
	game._day_intro_ui.play_intro(game._display_day_number())
	_check(game._day_intro_ui._day_label.text == "DAY 1", "The opening chapter card must read DAY 1.")
	game._day_intro_ui.hide()
	game._refresh_day_blessing_hud()
	_check(game._hud._day_label.text == "Day 1", "The gameplay HUD must read Day 1.")
	_check(game._blocked_aisle_enabled_for_level(), "Luggage must be enabled in the campaign.")
	_check(game._clean_seat_enabled_for_level(), "Dirty seats must be enabled in the campaign.")

	game._blocked_aisle_timer.stop()
	game._dirty_seat_timer.stop()
	game._schedule_maintenance_events()
	_check(
		absf(game._blocked_aisle_timer.time_left - game.level_two_blocked_first_delay_seconds) < 0.5,
		"Luggage should be scheduled first."
	)
	_check(
		absf(game._dirty_seat_timer.time_left - game.level_three_clean_first_delay_seconds) < 0.5
		and game._dirty_seat_timer.time_left > game._blocked_aisle_timer.time_left,
		"Dirty seats should be scheduled after luggage."
	)
	game._blocked_aisle_timer.stop()
	game._dirty_seat_timer.stop()

	_check(game._show_level_start_hint_if_needed(), "The campaign must show obstacle guidance.")
	_check(game._active_modal == game._hint_ui, "Guidance must hold player control.")
	_check(game._hint_ui.get_node("%BlockedAisle").visible, "Luggage guidance must appear first.")
	_check(not game._hint_ui.get_node("%CleanTheSeat").visible, "Seat guidance must wait for the first click.")
	await create_timer(0.55).timeout
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	game._hint_ui.call(&"_input", click)
	await create_timer(0.3).timeout
	_check(game._active_modal == game._hint_ui, "The first click must keep guidance active.")
	_check(game._hint_ui.get_node("%CleanTheSeat").visible, "The first click must show seat guidance.")
	_check(not game._hint_ui.get_node("%BlockedAisle").visible, "Luggage guidance must close before seat guidance.")
	await create_timer(0.55).timeout
	game._hint_ui.call(&"_input", click)
	await create_timer(0.3).timeout
	_check(not game._hint_ui.visible, "The second click must close guidance.")
	_check(game._active_modal == null, "The second click must release player control.")
	_check(not game._blocked_aisle_timer.is_stopped(), "Luggage events must start after both hints.")
	_check(not game._dirty_seat_timer.is_stopped(), "Dirty-seat events must start after both hints.")

	game.free()
	if _failures == 0:
		print("PASS: Day 1 label and sequential luggage/seat guidance.")
	quit(1 if _failures > 0 else 0)