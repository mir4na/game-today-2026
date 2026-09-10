extends SceneTree
## Covers the daytime watcher, scene-authored trace patterns, and station skip.

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
	var watcher: Variant = game.get_node("%NightLedgerGuardian")
	var signature: Variant = game.get_node("%ServiceSignatureUI")
	var pause_ui := game.get_node("%PauseUI") as PauseUI
	watcher.set_shift_active(true, false)
	_check(watcher.visible and watcher.enabled, "The watcher must be available during daytime gameplay.")
	_check(watcher.get_prompt().contains("Report completed service"), "The daytime watcher must explain its sign-off interaction.")
	_check((watcher.get_node("%WatcherVisual") as CanvasGroup).modulate.a < 0.8, "The daytime watcher must remain visibly translucent.")
	_check((pause_ui.get_node("%ResumeButton") as Button).text == "Resume", "The pause menu must expose a Resume text button.")

	watcher.interact()
	await process_frame
	_check(signature.visible, "Consulting the watcher during daylight must open service sign-off.")
	_check(game._active_modal == signature, "Service sign-off must own gameplay input while open.")
	var close_button := signature.get_node("%CloseButton") as Button
	close_button.pressed.emit()
	await process_frame
	_check(not signature.visible, "The service sign-off close button must close the UI.")
	_check(game._active_modal == null, "Closing service sign-off must restore modal ownership.")
	watcher.interact()
	await process_frame
	_check(signature.visible, "The daytime watcher can reopen service sign-off after closing it.")
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
	_check(not watcher.visible and not watcher.enabled, "The watcher must hide during a station cutscene.")

	game.free()
	if _failures == 0:
		print("PASS: daytime watcher, Resume button, service trace, and station fast-forward.")
	quit(1 if _failures > 0 else 0)
