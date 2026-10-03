extends SceneTree
## Verifies the merged single-day distraction schedule and its onboarding hint.

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
	game.day_number = 1

	_check(game._blocked_aisle_enabled_for_level(), "The single day must enable blocked aisles.")
	_check(game._clean_seat_enabled_for_level(), "The single day must enable clean seats.")

	game._blocked_aisle_timer.stop()
	game._dirty_seat_timer.stop()
	game._blocked_aisle_activated = false
	game._dirty_seat_activated = false
	game._schedule_maintenance_events()
	_check(not game._blocked_aisle_timer.is_stopped(), "The blocked-aisle timer must arm on the single day.")
	_check(not game._dirty_seat_timer.is_stopped(), "The clean-seat timer must arm on the single day.")

	game._blocked_aisle_spawn_count = 0
	for sample_index: int in range(12):
		var blocked_delay: float = game._next_blocked_aisle_delay()
		_check(
			blocked_delay >= game.blocked_aisle_delay_range_seconds.x
			and blocked_delay <= game.blocked_aisle_delay_range_seconds.y,
			"The single day uses the random blocked-aisle delay (sample %d)." % sample_index
		)

	game._route_index = 0
	game._dirty_seat_spawns_this_route = 0
	_check(
		is_equal_approx(game._next_dirty_seat_delay(), game.level_three_clean_first_delay_seconds),
		"The single day's first clean seat must keep the guided 10-second delay."
	)
	game._dirty_seat_spawns_this_route = 1
	_check(
		is_equal_approx(game._next_dirty_seat_delay(), game.level_three_clean_second_delay_seconds),
		"The single day's second clean seat must keep the guided 60-second delay."
	)
	game._dirty_seat_spawns_this_route = 2
	_check(game._next_dirty_seat_delay() < 0.0, "The first route must stop after two clean seats.")

	game._route_index = 1
	game._dirty_seat_spawns_this_route = 0
	var route_duration: float = game._get_station_travel_seconds(1)
	var clearance: float = minf(
		game.clean_seat_route_edge_clearance_seconds,
		maxf(route_duration * 0.5 - 0.1, 0.1)
	)
	for sample_index: int in range(12):
		var randomized_delay: float = game._next_dirty_seat_delay()
		_check(
			randomized_delay >= clearance and randomized_delay <= route_duration - clearance,
			"The next-route clean seat must avoid both route edges (sample %d)." % sample_index
		)
	game._dirty_seat_spawns_this_route = 1
	_check(game._next_dirty_seat_delay() < 0.0, "The next route may spawn only one clean seat.")
	game._route_index = 2
	game._dirty_seat_spawns_this_route = 0
	_check(
		game._next_dirty_seat_delay() < 0.0,
		"The single day must not schedule another clean seat after the next route."
	)

	game.day_number = 1
	game._active_modal = null
	_check(game._show_level_start_hint_if_needed(), "The single day must present an onboarding hint.")
	_check(game._hint_ui.visible, "The onboarding hint should be visible.")
	_check(
		game._hint_ui.get_node("%CleanTheSeat").visible,
		"The merged single day must show the clean-seat hint."
	)
	game._active_modal = null
	game._hint_ui.hide()

	game.free()
	if _failures == 0:
		print("PASS: merged single-day maintenance schedule and hint.")
	quit(1 if _failures > 0 else 0)
