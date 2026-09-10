extends SceneTree
## Verifies the temporary HUD shortcut previews the complete terminal-to-night flow.

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
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game._active_modal = null
	game.state = AfterTheEndGame.GameState.DAY
	game._hud.set_day_hud_visible(true)

	var expected_night_roster: int = 0
	for data: PassengerData in game._daily_manifest:
		if data.is_dead:
			expected_night_roster += 1
	var shortcut := game._hud.get_node("%DebugNightButton") as Button
	_check(shortcut.visible, "The temporary Night Shift button must be visible during daylight gameplay.")
	shortcut.pressed.emit()

	_check(game.state == AfterTheEndGame.GameState.DAY, "The shortcut must remain in daylight while the terminal cutscene plays.")
	_check(game._station_cutscene_context == &"terminal_exchange", "The shortcut must begin the real final-station cutscene.")
	_check(game._station_stop_ui.visible, "The final-station cutscene UI must be visible after using the shortcut.")
	_check(game._get_dead_passenger_data().size() == expected_night_roster, "The shortcut must include every scheduled anomaly in the night roster.")
	_check(game._active_passenger_count() == expected_night_roster, "Living passengers must leave during the terminal exchange.")
	_check(not shortcut.visible, "The temporary shortcut must hide while the terminal cutscene plays.")

	# Resolve the terminal sequence without waiting for authored animation timings.
	game._station_stop_ui.hide()
	game._on_station_stop_finished()
	_check(game.state == AfterTheEndGame.GameState.SHIFT_REPORT, "The terminal cutscene must lead to the day paycheck.")
	_check(bool(game._day_blessing_award.get("passed", false)), "The transition preview paycheck must pass below the normal threshold.")
	_check(bool(game._day_blessing_award.get("debug_pass_override", false)), "The forced pass must remain scoped to the debug preview.")

	var wheel_event := InputEventMouseButton.new()
	wheel_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_event.pressed = true
	_check(not game._shift_report_ui._is_continue_input(wheel_event), "Mouse-wheel scrolling must not continue the paycheck.")
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	_check(game._shift_report_ui._is_continue_input(click_event), "A normal mouse click must still continue the paycheck.")

	game._on_shift_report_continue()
	_check(game.state == AfterTheEndGame.GameState.NIGHT_TRANSITION, "Continuing the paycheck must begin the veil transition.")
	_check(game._night_transition_ui.visible, "The terminal-to-night transition UI must play after the paycheck.")
	_check(not game._debug_day_pass_override, "The debug pass override must clear once the transition begins.")

	var transition := game._night_transition_ui as NightTransitionCutsceneUI
	_check(transition.get_node_or_null("NightTitle") == null, "The veil transition must not show a Night Service title.")
	_check(transition.get_node_or_null("VeilSymbol") == null, "The veil transition must not show the old diamond logo.")
	_check(
		transition.station_fade_end_time <= transition.departure_start_time + 3.0,
		"The terminal station must clear before fog starts three seconds after departure."
	)
	var transition_animation := transition.get_node("%TransitionAnimation") as AnimationPlayer
	transition_animation.seek(transition.departure_start_time + 3.0 - 0.01, true)
	_check(
		(transition.get_node("FogBack") as ColorRect).self_modulate.a < 0.01
		and (transition.get_node("FogFront") as ColorRect).self_modulate.a < 0.01,
		"Fog must remain absent during the first three seconds of train departure."
	)
	transition_animation.seek(transition.departure_start_time + 3.5, true)
	_check(
		(transition.get_node("FogBack") as ColorRect).self_modulate.a > 0.05
		and (transition.get_node("FogFront") as ColorRect).self_modulate.a > 0.05,
		"Both fog layers must arrive after the train has left the station."
	)

	transition._process(transition.departure_follow_time + 0.01)
	_check(game._station_cinematic_view._departure_following, "The wide camera must begin following the departing train before the veil appears.")
	var wide_zoom: Vector2 = game._station_cinematic_view._station_camera.zoom
	game._station_cinematic_view._update_departure_follow(1.0)
	_check(
		game._station_cinematic_view._station_camera.zoom.is_equal_approx(wide_zoom),
		"Following the departing train must preserve the station shot's wide zoom."
	)
	transition._process(transition.camera_return_time - transition._elapsed + 0.01)
	_check(game._station_cinematic_view._returning, "The camera must begin its player return only after the fog clears.")
	_check(
		game._station_cinematic_view._return_start_center.distance_to(
			game._station_cinematic_view._handoff_target_position()
		) < 1.0,
		"The final player zoom must begin from the already-following camera position without a spatial jump."
	)

	game.free()
	if _failures == 0:
		print("PASS: terminal Night Shift preview, delayed veil, seamless camera handoff, forced paycheck pass, and scroll exclusion.")
	quit(1 if _failures > 0 else 0)
