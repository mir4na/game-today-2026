extends SceneTree
## Covers the daytime service button, scene-authored trace patterns, and station skip.

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
	var service_button := game._hud.get_node("%ServiceActionButton") as Button
	var guidebook_button := game._hud.get_node("%GuidebookButton") as Button
	var signature: Variant = game.get_node("%ServiceSignatureUI")
	var pause_ui := game.get_node("%PauseUI") as PauseUI
	game._hud.set_day_hud_visible(true)
	_check(game.get_node_or_null("%NightLedgerGuardian") == null, "The in-world watcher must be removed from gameplay.")
	_check(service_button.visible and not service_button.disabled, "The service button must be available during daytime gameplay.")
	_check(service_button.tooltip_text.is_empty(), "The service button must not show a long hover caption over gameplay.")
	_check(service_button.icon != null and service_button.icon.resource_path.ends_with("Group 176.png"), "The service button must use the Group 176 ledger asset.")
	_check(service_button.position.y < guidebook_button.position.y, "The service button must sit above the Guidebook button.")
	_check((pause_ui.get_node("%ResumeButton") as Button).text == "Resume", "The pause menu must expose a Resume text button.")
	_check(
		not game._station_stop_ui.show_terminal_title
		and game._station_stop_ui.terminal_heading_text.is_empty(),
		"The terminal cutscene must not place terminal copy in the middle of the screen."
	)

	service_button.pressed.emit()
	await process_frame
	_check(signature.visible, "Pressing the daytime service button must open service sign-off.")
	_check(game._active_modal == signature, "Service sign-off must own gameplay input while open.")
	var close_button := signature.get_node("%CloseButton") as Button
	close_button.pressed.emit()
	await process_frame
	_check(not signature.visible, "The service sign-off close button must close the UI.")
	_check(game._active_modal == null, "Closing service sign-off must restore modal ownership.")
	service_button.pressed.emit()
	await process_frame
	_check(signature.visible, "The daytime service button can reopen service sign-off after closing it.")
	signature._on_confirm_pressed()
	_check(signature._signature_stage.visible, "Confirming completion must reveal the trace stage.")
	var drawing_center: Vector2 = signature._drawing_area.size * 0.5
	for pattern: Line2D in [signature._pulse_pattern, signature._loop_pattern]:
		var min_point: Vector2 = pattern.points[0]
		var max_point: Vector2 = pattern.points[0]
		for point: Vector2 in pattern.points:
			min_point = min_point.min(point)
			max_point = max_point.max(point)
		var pattern_center: Vector2 = (min_point + max_point) * 0.5
		_check(
			pattern_center.distance_to(drawing_center) <= 2.0,
			"The scene-authored service sign-off mark must be centered in the drawing area."
		)
	_check(
		signature._trace_matches_pattern(signature._active_pattern.points, signature._active_pattern.points),
		"Tracing a scene-authored mark exactly must be accepted."
	)
	_check(
		not signature._trace_matches_pattern(PackedVector2Array([Vector2.ZERO, Vector2.ONE]), signature._active_pattern.points),
		"An incomplete scribble must be rejected."
	)
	signature._play_rejection()
	_check(
		is_instance_valid(game._night_record_camera_shake_tween) and game._night_record_camera_shake_tween.is_valid(),
		"A rejected signature must start a gameplay-camera shake tween."
	)

	var arrival_minutes: float = game._next_arrival_minutes()
	var fade_alpha_when_signed: Array[float] = [-1.0]
	signature.service_signed.connect(func() -> void: fade_alpha_when_signed[0] = signature._transition_fade.modulate.a)
	signature._user_stroke.points = signature._active_pattern.points
	signature._drawing = true
	signature._finish_stroke()
	await create_timer(1.65).timeout
	_check(not signature.visible, "An accepted service signature must close its UI.")
	_check(fade_alpha_when_signed[0] >= 0.99, "The station cutscene must begin only after the transition cover reaches black.")
	_check(signature._transition_fade.modulate.a <= 0.01, "The transition cover must fade back out to reveal the cutscene.")
	_check(game._day_minutes == arrival_minutes, "An accepted signature must fast-forward route time to the next arrival.")
	_check(game._station_arrival_announced, "An accepted signature must begin the normal next-station sequence.")
	_check(game._active_modal == game._station_stop_ui, "Fast-forward must enter the existing station cutscene flow.")
	_check(not (game._hud.get_node("%Root") as Control).visible, "The service button must hide with the HUD during a station cutscene.")

	game.free()
	if _failures == 0:
		print("PASS: daytime service button, Resume button, trace, and station fast-forward.")
	quit(1 if _failures > 0 else 0)
