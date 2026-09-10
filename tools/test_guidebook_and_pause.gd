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
	_check((guide.get_node("%TodayLayout") as Control).visible, "Today's Service uses its scene-authored layout.")
	_check(not (guide.get_node("%Content") as RichTextLabel).visible, "The visible guidebook page is not the raw RichText document.")
	_check((guide.get_node("%TodayRouteLabel") as Label).text.contains(game.manifest_config.service_train_number), "The scene-authored service page shows the generated service number.")
	_check((guide.get_node("%PassShiftBody") as Label).text.contains("Blessings"), "The scene-authored service page shows the paycheck target.")
	var original_day: int = game.day_number
	for day: int in range(1, 6):
		game.day_number = day
		game._open_guidebook()
		_check(guide._content.text.contains("[b]Required[/b]  %d Blessings" % game._get_day_pass_target()), "Today's Service shows the paycheck target for day %d." % day)
	game.day_number = original_day
	game._open_guidebook()
	_check(not game._day_intro_ui.has_node("Center/Content/TargetLabel"), "The opening chapter card does not display the paycheck target.")
	var starting_balance: int = game._market_tool_state.blessings
	var initial_count: int = game._active_passenger_count()
	_check(guide._content.text.contains("[b]Currently aboard[/b]  %d" % initial_count), "Today shows the actual opening passenger count.")
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
	_check(guide._content.text.contains("[b]Earned today[/b]  30 Blessings"), "Live earnings use +30/-20/-40 scoring.")
	_check(guide._content.text.contains("[b]Still needed[/b]  %d Blessings" % maxi(0, game._get_day_pass_target() - 30)), "The remaining target reflects net earnings.")
	_check(guide._content.text.contains("[b]Stops completed[/b]  1 / %d" % (game.day_route.size() - 1)), "Route progress excludes the departure station.")
	_check(guide._content.text.contains("[b]Currently aboard[/b]  %d" % (initial_count - 1)), "Departed passengers disappear from the live count.")
	_check(guide._boarded_today == initial_count, "Departures do not reduce the cumulative boarding total.")
	_check(guide._stamped_aboard == 0, "A departed stamped passenger is excluded even before assignments are cleared.")
	game._station_assignment.clear()
	guide._show_procedure()
	game._correct_drop_offs = 0
	game._process(0.01)
	_check(guide._page_title.text == "Rules", "Live updates preserve the selected section.")
	_check((guide.get_node("%RulesLayout") as Control).visible, "Rules uses its scene-authored layout.")
	_check(not ((guide.get_node("Center/BookStage/Page/RulesLayout/RulesRightText") as Label).text.contains("TAB")), "Rules page avoids raw keyboard-control lists.")
	guide._show_today()
	_check(guide._content.text.contains("[b]Earned today[/b]  -60 Blessings"), "Negative earnings are shown without hiding penalties.")
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
	_check(guide._anomaly_list.visible, "Anomaly section uses its scene-authored page.")
	_check((guide.get_node("%AnomalyIntroLabel") as Label).text.contains("Keep suspicious"), "Anomaly page has a short player-facing instruction.")
	var entries: Node = guide._anomaly_list.get_node("Entries")
	var left_entries: Node = entries.get_node("LeftPageEntries")
	var right_entries: Node = entries.get_node("RightPageEntries")
	_check(not (left_entries is Container) and not (right_entries is Container), "Anomaly page columns allow free-positioned sections.")
	var anomaly_entries: Array[Node] = []
	for child: Node in left_entries.get_children():
		anomaly_entries.append(child)
	for child: Node in right_entries.get_children():
		anomaly_entries.append(child)
	var entries_by_name: Dictionary = {}
	for child: Node in anomaly_entries:
		entries_by_name[child.name] = child
	_check(anomaly_entries.size() == 5, "Only passenger anomalies appear in the anomaly guidebook page.")
	_check(not entries_by_name.has("BlockedConnector"), "Blocked connectors are not listed as passenger anomalies.")
	for expected_entry: String in ["Shadowless", "UnlistedDestination", "PortraitMismatch", "TimeInvalidTicket", "NewspaperDeath"]:
		_check(entries_by_name.has(expected_entry), "The guidebook includes %s." % expected_entry)
	var expected_photos: Dictionary = {
		"Shadowless": "res://assets/ui/guidebook/shadowless.png",
		"UnlistedDestination": "res://assets/ui/guidebook/unlisted_destination.png",
		"PortraitMismatch": "res://assets/ui/id_card.png",
		"TimeInvalidTicket": "res://assets/ui/passenger_ticket.png",
		"NewspaperDeath": "res://assets/ui/guidebook/newspaper.png",
	}
	var expected_photo_sides: Dictionary = {
		"Shadowless": 0,
		"UnlistedDestination": 0,
		"PortraitMismatch": 1,
		"TimeInvalidTicket": 1,
		"NewspaperDeath": 0,
	}
	for entry: Node in anomaly_entries:
		_check(entry.get("photo_side") != null, "%s exposes its scene-authored photo-side control." % entry.name)
		_check(entry.get("photo_offset") != null, "%s exposes scene-authored crop positioning." % entry.name)
		_check(entry.get("photo_scale") != null, "%s exposes scene-authored crop scaling." % entry.name)
		_check(entry.get("allow_manual_photo_content") != null, "%s supports manually authored photo content like the newspaper picture." % entry.name)
		var photo: Sprite2D = entry.get_node("PhotoFrame/PhotoClip/PhotoContent/Photo") as Sprite2D
		var placeholder: Label = entry.get_node("PhotoFrame/PhotoClip/Placeholder") as Label
		_check(photo.texture != null and photo.texture.resource_path == expected_photos[entry.name], "%s uses its scene-authored reference photo." % entry.name)
		_check(not placeholder.visible, "%s hides its placeholder when a photo is available." % entry.name)
		var photo_side: int = int(entry.get("photo_side"))
		_check(photo_side == expected_photo_sides[entry.name], "%s keeps its authored photo side." % entry.name)
		var expected_first_child: String = "Text" if photo_side == 1 else "PhotoFrame"
		_check(entry.get_child(0).name == expected_first_child, "%s applies the authored left/right photo position." % entry.name)
		var sample := GradientTexture2D.new()
		entry.set("photo", sample)
		_check(photo.texture == sample and not placeholder.visible, "Assigning a photo replaces its placeholder.")
		entry.set("photo", null)
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
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	game._clean_seat_ui.show()
	game._active_modal = game._clean_seat_ui
	game._player.movement_enabled = false
	game._player.interaction_enabled = false
	game._unhandled_input(esc)
	_check(paused and game._active_modal == game._pause_ui, "Esc opens Pause over an active minigame.")
	_check(game._clean_seat_ui.visible, "Pausing keeps the current minigame open underneath.")
	game._pause_ui._unhandled_input(esc)
	await create_timer(game._pause_ui.close_duration + 0.05).timeout
	_check(not paused and game._active_modal == game._clean_seat_ui, "Resume restores the active minigame.")
	_check(not game._player.movement_enabled and not game._player.interaction_enabled, "Resume does not enable gameplay controls behind a minigame.")
	game._clean_seat_ui.hide()
	game._active_modal = null
	game._open_pause()
	_check(paused, "Pause pauses the scene tree.")
	before = game._day_minutes
	var npc_position: Vector2 = game._passengers[0].position
	var sway_before: float = game._train._sway_time
	await create_timer(0.2).timeout
	game._process(0.2)
	_check(game._day_minutes == before and game._passengers[0].position == npc_position, "Pause freezes shift time and NPC movement.")
	_check(game._train._sway_time == sway_before, "Pause freezes train animation processing.")
	game._pause_ui._unhandled_input(esc)
	await create_timer(game._pause_ui.close_duration + 0.05).timeout
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
