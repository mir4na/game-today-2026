extends SceneTree
## Isolate saves: XDG_DATA_HOME=/tmp/npc-test godot --headless --path . --script tools/test_npc_stops_and_overlay_motion.gd

var _failures: int = 0

func _initialize() -> void:
	call_deferred(&"_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/"):
		push_error("Run this integration test with an isolated /tmp XDG_DATA_HOME.")
		quit(1)
		return
	var game: AfterTheEndGame = load("res://scenes/main/main.tscn").instantiate()
	game.debug_print_anomaly_roster = false
	game.manifest_config = game.manifest_config.duplicate()
	game.manifest_config.initial_passenger_count = 12
	root.add_child(game)
	game.set_process(false)
	game._day_intro_ui.set_process(false)
	game._day_intro_ui.hide()
	game._station_stop_ui.hide()
	game._active_modal = null
	game.state = AfterTheEndGame.GameState.DAY
	game._station_arrival_announced = false
	game.day_number = 2
	game._blocked_aisle_timer.stop()
	game._dirty_seat_timer.stop()
	await physics_frame
	game._finish_staged_boarding()
	_check(game._passengers.size() == 12, "Strict seat spacing must still accommodate twelve passengers.")
	for passenger: Passenger in game._passengers:
		passenger.set_process(false)
		passenger.set_ai_enabled(true)
		_check(not Passenger.is_stop_reserved_for_interaction(self, game._passenger_container.to_global(passenger.get_reserved_seat_position())), "Reserved seats keep the newspaper clear.")
	# Accelerate several minutes of mixed wandering without advancing station timers.
	for step: int in 3600:
		for passenger: Passenger in game._passengers:
			passenger._process(0.1)
		if step % 20 == 0:
			_check_idle_layout(game._passengers)
	# Direct regression: a still NPC found at the rack must walk to a safe stop.
	var npc: Passenger = game._passengers.back()
	npc.position = game._passenger_container.to_local(game._newspaper.global_position)
	npc.runtime_carriage = npc._carriage_from_world_x(npc.position.x)
	npc._ai_walking = false
	npc.data.ai_behavior = "still"
	npc._process(0.1)
	_check(npc._ai_walking, "Even a still NPC must leave the newspaper's standing clearance.")
	_check(not Passenger.is_stop_reserved_for_interaction(self, game._passenger_container.to_global(npc._ai_target_position)), "The replacement destination is outside newspaper clearance.")
	# Crossing remains permitted: this is a stop restriction, not a solid wall.
	npc.position = game._passenger_container.to_local(game._newspaper.global_position) + Vector2(-200, 0)
	npc._ai_target_position = npc.position + Vector2(400, 0)
	npc._ai_walking = true
	for step: int in 45:
		npc._advance_ai_movement(0.1)
	_check(npc.position.distance_to(npc._ai_target_position) < 1.0, "NPCs may walk through the newspaper area.")
	# Night must not freeze a walking ghost at the rack.
	npc.data.is_dead = true
	npc.position = game._passenger_container.to_local(game._newspaper.global_position)
	npc._ai_walking = false
	npc.set_night_mode(true)
	_check(npc._settling_for_night, "Night transition sends an obstructing ghost to a safe stop.")
	for step: int in 600:
		npc._process(0.1)
	_check(not npc._ai_walking and not Passenger.is_stop_reserved_for_interaction(self, npc.global_position), "The ghost settles clear of the rack.")
	game._travel_foreground._on_pole_timer_timeout()
	game._on_dirty_seat_cleaning_requested(game._dirty_seat_events[0])
	await _check_motion(game, "clean seat")
	game._clean_seat_ui.request_close()
	game._on_blocked_aisle_puzzle_requested(game._blocked_aisle_events[0])
	await _check_motion(game, "blocked aisle")
	game._blocked_aisle_ui.request_close()
	game._active_modal = game._guidebook_ui
	await _check_motion(game, "guidebook")
	game._active_modal = game._pause_ui
	game._update_travel_foreground()
	_check(not game._travel_foreground._traveling, "The pause menu still pauses scenery.")
	game._active_modal = game._clean_seat_ui
	game._station_arrival_announced = true
	game._update_travel_foreground()
	_check(not game._travel_foreground._traveling, "An overlay cannot restart the train at a station.")
	game._station_stop_ui.show()
	game._station_cutscene_motion_strength = 0.35
	game._update_travel_foreground()
	_check(is_equal_approx(game._travel_foreground._motion_strength, 0.35), "Station cinematics retain control of motion.")
	game.queue_free()
	await process_frame
	await process_frame
	_check_crossing_and_arrival()
	if _failures == 0:
		print("PASS: twelve-passenger spacing, six minutes of roaming, newspaper clearance/crossing, night settling, overlay scenery and station/pause rules.")
	quit(1 if _failures else 0)

func _check_crossing_and_arrival() -> void:
	var container := Node2D.new()
	root.add_child(container)
	var walker: Passenger = load("res://scenes/passengers/passenger.tscn").instantiate()
	var standing: Passenger = load("res://scenes/passengers/passenger.tscn").instantiate()
	for passenger: Passenger in [walker, standing]:
		passenger.data = PassengerData.new()
		container.add_child(passenger)
		passenger.set_process(false)
	walker.configure_seat_navigation(Vector2.ZERO, PackedVector2Array([Vector2(240, 0)]), {1: Vector2(0, 960)})
	standing.position = Vector2(120, 0)
	standing.configure_seat_navigation(Vector2(480, 0), PackedVector2Array(), {1: Vector2(0, 960)})
	walker._ai_target_position = Vector2(240, 0)
	walker._ai_walking = true
	walker._advance_ai_movement(120.0 / Passenger.PASSENGER_WALK_SPEED)
	_check(walker.position == standing.position and walker._ai_walking, "Walking through another NPC remains allowed.")
	standing.position = Vector2(240, 0)
	walker._update_day_ai(2.0)
	_check(walker._ai_walking and walker._ai_target_position != standing.position, "An occupied destination is rechecked on arrival.")
	walker._update_day_ai(3.0)
	_check(not walker._ai_walking and walker.position == Vector2.ZERO, "The arriving NPC finds a separate idle position.")
	container.free()

func _check_idle_layout(passengers: Array[Passenger]) -> void:
	for index: int in passengers.size():
		var passenger: Passenger = passengers[index]
		if passenger._ai_walking or not passenger.visible:
			continue
		_check(not Passenger.is_stop_reserved_for_interaction(self, passenger.global_position), "Idle NPC blocks the newspaper.")
		for other_index: int in range(index + 1, passengers.size()):
			var other: Passenger = passengers[other_index]
			if not other._ai_walking and other.visible:
				_check(not passenger._stop_shapes_overlap(passenger.position, other, other.position), "Stationary NPCs overlap.")

func _check_motion(game: AfterTheEndGame, label: String) -> void:
	game._update_travel_foreground()
	var foreground: TravelForeground = game._travel_foreground
	foreground._on_cable_timer_timeout()
	foreground._on_pole_timer_timeout()
	await process_frame
	var layer: Node2D = game._travel_background._period_root.get_child(0)
	var cable_x: float = foreground._passing_cables.position.x
	var pole_x: float = foreground._passing_pole.position.x
	var layer_x: float = layer.position.x
	await create_timer(0.15).timeout
	_check(not is_equal_approx(cable_x, foreground._passing_cables.position.x), "Cables move during %s." % label)
	_check(not is_equal_approx(pole_x, foreground._passing_pole.position.x), "Poles move during %s." % label)
	_check(not is_equal_approx(layer_x, layer.position.x), "Background moves during %s." % label)
