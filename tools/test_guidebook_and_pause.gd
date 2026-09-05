extends SceneTree
## Run with XDG_DATA_HOME=/tmp/guide-test to protect player saves.
var _failures: int = 0
func _initialize() -> void:
	call_deferred(&"_run")
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
func _run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/"):
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var game: AfterTheEndGame = load("res://scenes/main/main.tscn").instantiate()
	game.debug_print_anomaly_roster = false
	root.add_child(game)
	game.set_process(false)
	game._day_intro_ui.set_process(false)
	game._day_intro_ui.hide()
	game._active_modal = null
	game.state = AfterTheEndGame.GameState.DAY
	game._station_arrival_announced = false
	game._blocked_aisle_timer.stop()
	game._dirty_seat_timer.stop()
	game._finish_staged_boarding()
	game._open_guidebook()
	var guide: GuidebookUI = game._guidebook_ui
	var original_day: int = game.day_number
	for day: int in range(1, 6):
		game.day_number = day
		game._open_guidebook()
		_check(guide._content.text.contains("PASS TARGET: %d BLESSINGS" % game._get_day_pass_target()), "Today's Service shows the paycheck target for day %d." % day)
	game.day_number = original_day
	game._open_guidebook()
	_check(not game._day_intro_ui.has_node("Center/Content/TargetLabel"), "The opening chapter card does not display the paycheck target.")
	var starting_balance: int = game._market_tool_state.blessings
	var initial_count: int = game._active_passenger_count()
	_check(guide._content.text.contains("[b]Passengers aboard[/b]  %d" % initial_count), "Today shows the actual opening passenger count.")
	_check(guide._content.text.contains("[b]Boarded today[/b]  %d" % initial_count), "Opening passengers count toward the cumulative total.")
	_check(guide._content.text.contains("[b]Train number[/b]  %s" % game.manifest_config.service_train_number), "Guidebook displays the generated service number.")
	var stamp_subject: Passenger = game._passengers[0]
	game._on_station_assignment_toggled(stamp_subject.data.passenger_name, true)
	game._refresh_guidebook_progress()
	_check(guide._content.text.contains("[b]Stamped aboard[/b]  1"), "Applying a stamp updates the onboard stamp count.")
	game._on_station_assignment_toggled(stamp_subject.data.passenger_name, false)
	game._refresh_guidebook_progress()
	_check(guide._content.text.contains("[b]Stamped aboard[/b]  0"), "Removing a stamp decreases the onboard stamp count.")
	game._incorrectly_stamped_anomalies.clear()
	var boarder: Passenger
	for data: PassengerData in game._daily_manifest:
		if data.initially_on_train:
			continue
		var seat: Marker2D = game._find_available_seat(data.current_carriage)
		if seat != null:
			boarder = game._spawn_passenger(data, seat)
			if boarder != null:
				break
	_check(boarder != null, "The test can spawn a later boarder.")
	if boarder != null:
		game._stage_passenger_for_boarding(boarder, 0)
		game._refresh_guidebook_progress()
		_check(guide._boarded_today == initial_count, "A staged passenger is not counted before boarding.")
		game._finish_staged_boarding()
		game._refresh_guidebook_progress()
		initial_count += 1
		_check(guide._boarded_today == initial_count and guide._passenger_count == initial_count, "Finishing boarding increases both counts.")
	game._station_assignment.append(game._passengers.back().data.passenger_name)
	game._correct_drop_offs = 3
	game._wrong_drop_offs = 1
	game._incorrectly_stamped_anomalies["Test anomaly"] = true
	game._route_index = 1
	game._passengers.back().depart_train()
	game._process(0.01)
	_check(guide._content.text.contains("[b]Net earnings so far[/b]  30 Blessings"), "Live earnings use +30/-20/-40 scoring.")
	_check(guide._content.text.contains("[b]Still needed[/b]  %d Blessings" % maxi(0, game._get_day_pass_target() - 30)), "The remaining target reflects net earnings.")
	_check(guide._content.text.contains("[b]Scheduled stops completed[/b]  1 / %d" % (game.day_route.size() - 1)), "Route progress excludes the departure station.")
	_check(guide._content.text.contains("[b]Passengers aboard[/b]  %d" % (initial_count - 1)), "Departed passengers disappear from the live count.")
	_check(guide._boarded_today == initial_count, "Departures do not reduce the cumulative boarding total.")
	_check(guide._stamped_aboard == 0, "A departed stamped passenger is excluded even before assignments are cleared.")
	game._station_assignment.clear()
	guide._show_procedure()
	game._correct_drop_offs = 0
	game._process(0.01)
	_check(guide._page_title.text == "RULES", "Live updates preserve the selected section.")
	guide._show_today()
	_check(guide._content.text.contains("[b]Net earnings so far[/b]  -60 Blessings"), "Negative earnings are shown without hiding penalties.")
	game._correct_drop_offs = 20
	game._process(0.01)
	_check(guide._content.text.contains("[b]Still needed[/b]  0 Blessings"), "Exceeding the target leaves zero still needed.")
	_check(game._market_tool_state.blessings == starting_balance and not game._market_tool_state._day_blessings_awarded, "Viewing progress never pays out or finalizes the shift.")
	game._correct_drop_offs = 0
	game._wrong_drop_offs = 0
	game._incorrectly_stamped_anomalies.clear()
	game._route_index = 0
	game._refresh_guidebook_progress()
	_check(guide._section_buttons().size() == 3, "Guidebook has exactly three sections.")
	var before: float = game._day_minutes
	game._process(1.0)
	_check(game._day_minutes > before, "Guidebook does not pause the shift clock.")
	_check(game._passengers[0].ai_enabled, "NPC activity continues while guidebook is open.")
	guide._show_procedure()
	_check(guide._content.text.contains("30 Blessings") and guide._content.text.contains("40 Blessings"), "Rules include the current paycheck scoring.")
	guide._show_anomalies()
	var entries: Node = guide._anomaly_list.get_node("Entries")
	_check(entries.get_child_count() == 6, "Every anomaly has a photo entry.")
	for entry: Node in entries.get_children():
		_check(entry.get_node("PhotoFrame/Placeholder").visible, "An empty entry displays its photo placeholder.")
		var sample := GradientTexture2D.new()
		entry.photo = sample
		_check(entry.get_node("PhotoFrame/Photo").texture == sample and not entry.get_node("PhotoFrame/Placeholder").visible, "Assigning a photo replaces its placeholder.")
		entry.photo = null
	await create_timer(0.1).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/guidebook-anomalies.png")
	guide.request_close()
	game._on_newspaper_read()
	before = game._day_minutes
	game._process(1.0)
	_check(game._day_minutes > before, "Newspaper does not pause the shift clock.")
	game._document_overlay.request_close()
	await create_timer(1.0).timeout
	game._open_pause()
	_check(paused, "Pause pauses the scene tree.")
	before = game._day_minutes
	var npc_position: Vector2 = game._passengers[0].position
	var sway_before: float = game._train._sway_time
	await create_timer(0.2).timeout
	game._process(0.2)
	_check(game._day_minutes == before and game._passengers[0].position == npc_position, "Pause freezes shift time and NPC movement.")
	_check(game._train._sway_time == sway_before, "Pause freezes train animation processing.")
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	game._pause_ui._unhandled_input(esc)
	_check(not paused and game._active_modal == null, "Esc resumes from Pause while the scene tree is paused.")
	# A delayed newspaper dismissal must not release the new station modal.
	game._on_newspaper_read()
	await create_timer(0.1).timeout
	game._document_overlay.request_close()
	game._active_modal = game._station_stop_ui
	await create_timer(0.3).timeout
	_check(game._active_modal == game._station_stop_ui, "Newspaper dismissal preserves station modal ownership.")
	game.queue_free()
	await process_frame
	await process_frame
	if _failures == 0:
		print("PASS: guidebook sections/photos, live gameplay behind documents, full pause/resume, station modal ownership.")
	quit(1 if _failures else 0)
