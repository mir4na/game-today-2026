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
