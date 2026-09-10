extends SceneTree
## Ensures the two daytime maintenance events never select overlapping bounds.

const MainScene = preload("res://scenes/main/main.tscn")

var _failures: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/"):
		push_error("Use an isolated /tmp XDG_DATA_HOME for this test.")
		quit(1)
		return
	var game := MainScene.instantiate() as AfterTheEndGame
	game.debug_print_anomaly_roster = false
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._blocked_aisle_timer.stop()
	game._dirty_seat_timer.stop()
	game._day_intro_ui.hide()
	game._station_stop_ui.hide()
	game._active_modal = null
	game.state = AfterTheEndGame.GameState.DAY

	_check(not game._blocked_aisle_events.is_empty(), "The train must expose blocked-connector events.")
	_check(not game._dirty_seat_events.is_empty(), "The train must expose dirty-seat events.")
	if game._blocked_aisle_events.is_empty() or game._dirty_seat_events.is_empty():
		game.free()
		quit(1)
		return

	var blocked_event: Node = game._blocked_aisle_events[0]
	blocked_event.call(&"set_event_active", true, game._player.global_position.x)
	game._active_blocked_aisle_event = blocked_event
	game._blocked_aisle_activated = true
	var overlapping_dirty_seats: int = 0
	for dirty_event: Node in game._dirty_seat_events:
		if game._maintenance_events_overlap(dirty_event, blocked_event):
			overlapping_dirty_seats += 1
	_check(overlapping_dirty_seats > 0, "The fixture must include edge seats close enough to reproduce the overlap regression.")

	game._dirty_seat_activated = false
	game._on_dirty_seat_timer_timeout()
	var selected_dirty: Node = game._active_dirty_seat_event
	_check(is_instance_valid(selected_dirty), "A safe dirty seat must remain available.")
	if is_instance_valid(selected_dirty):
		_check(
			not game._maintenance_events_overlap(selected_dirty, blocked_event),
			"Dirty-seat selection must reject bounds occupied by active luggage."
		)
		selected_dirty.call(&"set_event_active", false)
	game._active_dirty_seat_event = null

	blocked_event.call(&"set_event_active", false)
	game._active_blocked_aisle_event = null
	game._blocked_aisle_activated = false
	var overlapping_dirty: Node
	for dirty_event: Node in game._dirty_seat_events:
		if game._maintenance_events_overlap(blocked_event, dirty_event, game._player.global_position.x):
			overlapping_dirty = dirty_event
			break
	_check(is_instance_valid(overlapping_dirty), "The fixture must expose a dirty seat beside the connector.")
	if is_instance_valid(overlapping_dirty):
		overlapping_dirty.call(&"set_event_active", true)
		game._active_dirty_seat_event = overlapping_dirty
		game._dirty_seat_activated = true
		game._on_blocked_aisle_timer_timeout()
		var selected_blocked: Node = game._active_blocked_aisle_event
		_check(is_instance_valid(selected_blocked), "A safe connector must remain available.")
		if is_instance_valid(selected_blocked):
			_check(
				not game._maintenance_events_overlap(selected_blocked, overlapping_dirty, game._player.global_position.x),
				"Blocked-connector selection must reject bounds occupied by an active dirty seat."
			)

	game.free()
	if _failures == 0:
		print("PASS: blocked connector and dirty seat maintain scene-authored spatial clearance.")
	quit(1 if _failures > 0 else 0)
