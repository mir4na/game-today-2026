extends SceneTree
## Runtime coverage for the asset-driven market, selection, and gate exit.


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var market := load("res://scenes/ui/night_market_ui.tscn").instantiate() as NightMarketUI
	root.add_child(market)
	await process_frame
	var snapshot: Dictionary = {
		"blessings": 100,
		"veil_notes": 0,
		"radar_charges": 2,
		"speed_level": 0,
		"speed_max_level": 3,
		"veil_note_cost": 3,
		"radar_charge_cost": 4,
		"speed_upgrade_cost": 6,
	}
	market.open_market(snapshot, {"earned": 120, "dropoff_reward": 180, "penalty_deduction": 60})
	await create_timer(0.3).timeout
	assert(market.visible, "Night market must open.")
	assert(market.get_node("LightRig").get_child_count() == 7, "Night market requires all seven light layers.")
	var veil_note_button := market.get_node("MarketActors/VeilNoteEntrance/VeilNoteFloat/VeilNoteButton") as Button
	var angel_entrance := market.get_node("MarketActors/AngelEntrance") as Node2D
	var left_door := market.get_node("GateLayer/GateMotion/LeftDoor") as Sprite2D
	var right_door := market.get_node("GateLayer/GateMotion/RightDoor") as Sprite2D
	var gate_layer := market.get_node("GateLayer") as Control
	var entrance_fog := market.get_node("TransitionFog/FogFront") as ColorRect
	assert(veil_note_button.disabled, "Purchases must remain locked while the entrance cinematic plays.")
	assert(angel_entrance.modulate.a < 0.01, "The angel must wait until the fog and gate opening finish.")
	assert(is_equal_approx(left_door.position.x, 470.0) and is_equal_approx(right_door.position.x, 810.0), "The market gate must begin closed behind the incoming fog.")
	assert(gate_layer.modulate.a < 0.01, "The closed gate must stay concealed until the entrance fog is dense.")
	assert(entrance_fog.self_modulate.a > 0.05, "Fog must arrive before the market gate opens.")
	await create_timer(2.9).timeout
	assert(not veil_note_button.disabled, "The market must unlock after fog, gate, angel, and item entrances finish.")
	assert(angel_entrance.modulate.a > 0.99, "The angel must enter after the gate is open.")
	assert(gate_layer.modulate.a > 0.99, "The gate must be revealed only after fog conceals the set change.")
	assert(is_equal_approx(left_door.position.x, 170.0) and is_equal_approx(right_door.position.x, 1110.0), "The gate must finish opening before purchases unlock.")
	market.call(&"_set_item_highlight", 1, true)
	await create_timer(0.25).timeout
	var radar_highlight := market.get_node("MarketActors/RadarEntrance/RadarFloat/RadarHighlight") as Sprite2D
	assert(radar_highlight.modulate.a > 0.7, "Focused items must reveal ItemHighlight.png.")
	if DisplayServer.get_name() != "headless":
		await process_frame
		root.get_texture().get_image().save_png("res://.godot/night_market_preview.png")

	var signal_state: Dictionary = {"requested_tool": &"", "continued": false}
	market.purchase_requested.connect(func(tool_id: StringName) -> void: signal_state["requested_tool"] = tool_id)
	veil_note_button.pressed.emit()
	assert(signal_state["requested_tool"] == &"veil_note", "Veil Note art must request the redesigned clue item.")
	market.set_snapshot(snapshot.merged({"veil_notes": 1}, true))
	assert(veil_note_button.disabled, "A second Veil Note cannot be bought while one is owned.")
	market.get_node("MarketActors/RadarEntrance/RadarFloat/RadarButton").pressed.emit()
	assert(signal_state["requested_tool"] == &"radar_charge", "Radar art must retain the radar purchase action.")

	market.continue_requested.connect(func() -> void: signal_state["continued"] = true)
	market.get_node("HeaderRoot/ContinueButton").pressed.emit()
	await create_timer(3.5).timeout
	assert(bool(signal_state["continued"]), "Continue must emit only after the exit and gate-close animation.")
	assert(is_equal_approx(left_door.position.x, 470.0) and is_equal_approx(right_door.position.x, 810.0), "Mirrored doors must meet at the center.")
	var transition_fog := market.get_node("TransitionFog/FogFront") as ColorRect
	assert(transition_fog.self_modulate.a > 0.95, "Dense fog must cover the market only after its exit and gate animations finish.")
	if DisplayServer.get_name() != "headless":
		await process_frame
		root.get_texture().get_image().save_png("res://.godot/night_market_gate_preview.png")
	market.release_transition_fog()
	await create_timer(1.2).timeout
	assert(not market.visible, "Transition fog must release into Night Service and then hide the market.")
	print("PASS: fog-first Night Market entrance, gate reveal, selection, purchase, and fog-covered exit.")
	quit()
