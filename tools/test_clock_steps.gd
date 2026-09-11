extends SceneTree
## Verifies one full dial sweep per day leg (two minutes) and per Night Service
## (ten minutes).


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var hud := load("res://scenes/ui/hud.tscn").instantiate() as GameHUD
	root.add_child(hud)
	await process_frame
	assert(hud.get_node_or_null("%DebugNextStationButton") == null, "The clock must not contain a Skip Stop button.")
	for step: int in range(5):
		var progress: float = float(step) / 4.0
		hud.set_clock_progress(progress)
		var expected_degrees: float = hud.clock_pointer_start_degrees + 180.0 * progress
		assert(
			is_equal_approx(rad_to_deg(hud._clock_pointer_pivot.rotation), expected_degrees),
			"Clock pointer must sweep the full 180-degree dial exactly once per leg."
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
	var leg_count: int = maxi(game.day_route.size() - 1, 1)
	assert(is_equal_approx(game._get_station_travel_seconds(0), 120.0), "Each day leg must last two minutes.")
	game._route_index = 0
	game._day_minutes = AfterTheEndGame.START_MINUTES
	assert(is_equal_approx(game._day_leg_clock_progress(), 0.0), "A leg must start the dial at zero.")
	game._day_minutes = AfterTheEndGame.START_MINUTES + 60.0
	assert(is_equal_approx(game._day_leg_clock_progress(), 0.5), "Half a leg must place the dial halfway.")
	game._day_minutes = AfterTheEndGame.START_MINUTES + 120.0
	assert(is_equal_approx(game._day_leg_clock_progress(), 1.0), "Arrival must complete the dial sweep.")
	game._route_index = 1
	assert(is_equal_approx(game._day_leg_clock_progress(), 0.0), "The next leg must restart the dial.")
	assert(leg_count >= 1, "The route must contain at least one leg.")
	assert(is_equal_approx(game.night_service_duration_seconds, 600.0), "Night Service must last ten minutes.")
	game._night_service_elapsed_seconds = 0.0
	assert(is_equal_approx(game._night_service_clock_progress(), 0.0), "Night Service must reset the clock to zero degrees.")
	game._night_service_elapsed_seconds = 300.0
	assert(is_equal_approx(game._night_service_clock_progress(), 0.5), "Half of Night Service must place the clock at 90 degrees.")
	game._night_service_elapsed_seconds = 600.0
	assert(is_equal_approx(game._night_service_clock_progress(), 1.0), "Night Service must finish at 180 degrees.")
	game.free()
	hud.free()
	print("PASS: each day leg and Night Service sweep the full dial exactly once.")
	quit()
