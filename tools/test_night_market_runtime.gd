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
		"audit_slips": 1,
		"radar_charges": 2,
		"speed_level": 0,
		"speed_max_level": 3,
		"audit_slip_cost": 3,
		"radar_charge_cost": 4,
		"speed_upgrade_cost": 6,
	}
	market.open_market(snapshot, {"earned": 120, "dropoff_reward": 180, "penalty_deduction": 60})
	await create_timer(0.3).timeout
	assert(market.visible, "Night market must open.")
	assert(market.get_node("LightRig").get_child_count() == 7, "Night market requires all seven light layers.")
	assert(not market.get_node("MarketActors/AuditEntrance/AuditFloat/AuditButton").disabled, "Audit must use its existing purchasable backend.")
	market.call(&"_set_item_highlight", 1, true)
	await create_timer(0.25).timeout
	var radar_highlight := market.get_node("MarketActors/RadarEntrance/RadarFloat/RadarHighlight") as Sprite2D
	assert(radar_highlight.modulate.a > 0.7, "Focused items must reveal ItemHighlight.png.")
	if DisplayServer.get_name() != "headless":
		await process_frame
		root.get_texture().get_image().save_png("res://.godot/night_market_preview.png")

	var signal_state: Dictionary = {"requested_tool": &"", "continued": false}
	market.purchase_requested.connect(func(tool_id: StringName) -> void: signal_state["requested_tool"] = tool_id)
	market.get_node("MarketActors/RadarEntrance/RadarFloat/RadarButton").pressed.emit()
	assert(signal_state["requested_tool"] == &"radar_charge", "Radar art must retain the radar purchase action.")

	market.continue_requested.connect(func() -> void: signal_state["continued"] = true)
	market.get_node("HeaderRoot/ContinueButton").pressed.emit()
	await create_timer(2.0).timeout
	assert(bool(signal_state["continued"]), "Continue must emit only after the exit and gate-close animation.")
	var left_door := market.get_node("GateLayer/GateMotion/LeftDoor") as Sprite2D
	var right_door := market.get_node("GateLayer/GateMotion/RightDoor") as Sprite2D
	assert(is_equal_approx(left_door.position.x, 470.0) and is_equal_approx(right_door.position.x, 810.0), "Mirrored doors must meet at the center.")
	if DisplayServer.get_name() != "headless":
		await process_frame
		root.get_texture().get_image().save_png("res://.godot/night_market_gate_preview.png")
	print("PASS: animated Night Market assets, selection highlight, purchase, and gate exit.")
	quit()
