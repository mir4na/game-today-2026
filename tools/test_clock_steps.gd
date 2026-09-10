extends SceneTree
## Verifies five fixed 36-degree clock steps: four day arrivals and Night Service.


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var hud := load("res://scenes/ui/hud.tscn").instantiate() as GameHUD
	root.add_child(hud)
	await process_frame
	var debug_state: Dictionary = {"requested": false}
	hud.debug_next_station_requested.connect(func() -> void: debug_state["requested"] = true)
	hud.set_debug_next_station_available(true)
	var debug_button := hud.get_node("%DebugNextStationButton") as Button
	assert(debug_button.visible == OS.is_debug_build(), "Next-station button must only appear in debug builds.")
	assert(debug_button.get_parent() == hud._clock_sign_assembly, "The debug skip button must stay attached to the Next Stop sign.")
	var debug_sign := debug_button.get_node("Sign") as TextureRect
	var main_sign := hud._clock_sign_assembly.get_node("ClockSign") as TextureRect
	assert(debug_sign.texture == main_sign.texture, "The debug skip button must reuse the Clock Sign artwork.")
	assert(debug_button.size.x < main_sign.size.x, "The attached debug sign must remain smaller than the destination sign.")
	debug_button.pressed.emit()
	assert(bool(debug_state.requested) == OS.is_debug_build(), "Debug next-station button must emit only in debug builds.")
	hud.set_clock_route_stop_count(5)
	for step: int in range(6):
		var progress: float = float(step) / 5.0
		hud.set_clock_progress(progress)
		var expected_degrees: float = hud.clock_pointer_start_degrees + 36.0 * float(step)
		assert(
			is_equal_approx(rad_to_deg(hud._clock_pointer_pivot.rotation), expected_degrees),
			"Clock pointer must advance exactly 36 degrees per service step."
		)
		var fill_material := hud._clock_fill.material as ShaderMaterial
		assert(
			is_equal_approx(float(fill_material.get_shader_parameter(&"progress")), progress),
			"Clock fill must remain locked to the pointer angle."
		)

	assert(hud._day_symbol.visible and not hud._night_symbol.visible, "The journey clock must begin with its day symbol.")
	hud.set_clock_night_mode(true, true)
	await create_timer(hud.clock_symbol_flip_duration * 0.38).timeout
	assert(hud._day_symbol.visible, "The day face must remain visible during the slow opening spins.")
	await create_timer(hud.clock_symbol_flip_duration * 0.18).timeout
	assert(hud._night_symbol.visible and not hud._day_symbol.visible, "The coin must reveal the night face at its fastest midpoint.")
	await create_timer(hud.clock_symbol_flip_duration * 0.5).timeout
	assert(hud._clock_symbol_pivot.scale.is_equal_approx(Vector2.ONE), "The clock coin must finish at its full authored scale.")
	assert(is_zero_approx(hud._clock_symbol_pivot.rotation), "The clock coin must settle without a residual tilt.")

	var game := load("res://scenes/main/main.tscn").instantiate() as AfterTheEndGame
	assert(game.day_route.size() == 5, "The configured route must contain five daylight stations.")
	for station_index: int in range(game.day_route.size()):
		game._route_index = station_index
		assert(
			is_equal_approx(game._day_station_clock_progress(), float(station_index) / 5.0),
			"Each daylight arrival must consume one of the first four clock steps."
		)
	assert(
		is_equal_approx(game._day_travel_clock_progress(1.0), 0.8),
		"Day travel must stop at 144 degrees and reserve 36 degrees for Night Service."
	)
	assert(is_equal_approx(game.night_service_duration_seconds, 180.0), "Night Service must last three minutes.")
	game._night_service_elapsed_seconds = 0.0
	assert(is_equal_approx(game._night_service_clock_progress(), 0.8), "Night Service must begin at 144 degrees.")
	game._night_service_elapsed_seconds = 90.0
	assert(is_equal_approx(game._night_service_clock_progress(), 0.9), "Half of Night Service must place the clock at 162 degrees.")
	game._night_service_elapsed_seconds = 180.0
	assert(is_equal_approx(game._night_service_clock_progress(), 1.0), "Night Service must finish at 180 degrees.")
	game.free()
	hud.free()
	print("PASS: clock advances 36 degrees per station, reserves Night Service, and completes the day-to-night coin spin.")
	quit()
