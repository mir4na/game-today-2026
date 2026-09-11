extends SceneTree
## Verifies five fixed day steps plus the fresh five-minute Night Service dial.


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var hud := load("res://scenes/ui/hud.tscn").instantiate() as GameHUD
	root.add_child(hud)
	await process_frame
	assert(hud.get_node_or_null("%DebugNextStationButton") == null, "The clock must not contain a Skip Stop button.")
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
	assert(is_equal_approx(game.night_service_duration_seconds, 300.0), "Night Service must last five minutes.")
	game._night_service_elapsed_seconds = 0.0
	assert(is_equal_approx(game._night_service_clock_progress(), 0.0), "Night Service must reset the clock to zero degrees.")
	game._night_service_elapsed_seconds = 150.0
	assert(is_equal_approx(game._night_service_clock_progress(), 0.5), "Half of Night Service must place the clock at 90 degrees.")
	game._night_service_elapsed_seconds = 300.0
	assert(is_equal_approx(game._night_service_clock_progress(), 1.0), "Night Service must finish at 180 degrees.")
	game.free()
	hud.free()
	print("PASS: day clock uses five divisions and Night Service resets for a full five-minute arc.")
	quit()
