extends SceneTree
## Smoke test for the permanent drag-and-drop station stamp flow.

var _failures: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var overlay: DocumentOverlayUI = load("res://scenes/ui/document_overlay_ui.tscn").instantiate()
	root.add_child(overlay)
	await process_frame

	var data := PassengerData.new()
	data.passenger_name = "Stamp Test"
	data.short_name = data.passenger_name
	data.ticket_owner = data.passenger_name
	data.origin_station = "Alderwick"
	data.destination_station = "Dunmere"
	data.ticket_service_date = "07 JUN 2026"
	data.ticket_train_number = "505"
	data.ticket_number = "260607-505-9999"
	overlay.station_stamp_applied.connect(
		func(_passenger_name: String, station_name: String, ticket_position: Vector2) -> void:
			data.stamped_station = station_name
			data.stamp_ticket_position = ticket_position
	)
	overlay.show_passenger(data)
	await process_frame
	var documents: PassengerDocuments = overlay.get_node("PassengerDocumentCenter/PassengerDocumentAnchor/PassengerDocuments")
	var tray: StampTrayUI = overlay.get_node("StampTrayUI")
	_check(not tray.visible, "Stamp tray must remain hidden while the ID card is active.")
	documents.show_ticket()
	await create_timer(0.75).timeout
	_check(tray.visible, "Stamp tray must appear when the ticket finishes turning face-up.")
	_check(is_equal_approx(tray._tray.position.x, tray.collapsed_x), "The tray must initially expose only its STAMP tab.")

	tray._dragging = true
	tray._set_expanded(true)
	await create_timer(tray.drawer_duration + 0.05).timeout
	_check(is_equal_approx(tray._tray.position.x, tray.expanded_x), "Hover expansion must reveal the full stamp drawer.")
	tray._dragging = false
	var choice := tray.get_node("Tray/StampChoices/Alderwick") as Control
	_check(choice.self_modulate.a > 0.95 and choice.scale.distance_to(Vector2.ONE) < 0.08, "Station stamps must animate into their tray slots.")
	tray._begin_drag("Alderwick", choice)
	tray._finish_drag(false)
	await create_timer(tray.return_duration + 0.08).timeout
	_check(not tray._drag_preview.visible and is_equal_approx(choice.self_modulate.a, 1.0), "A released stamp must return to its authored slot.")

	overlay._on_stamp_dropped("Dunmere", Vector2(310.0, 158.0))
	_check(data.stamped_station == "Dunmere", "Dropping a stamp must persist its station on the passenger.")
	_check(data.stamp_ticket_position.is_equal_approx(Vector2(310.0, 158.0)), "Dropping a stamp must persist its exact ticket position.")
	var ticket: PassengerTicketDocument = documents.get_node("PassengerTicket")
	var result := ticket.get_node("TicketSurface/ValidationStamp") as TextureRect
	_check(result.visible and result.texture == PassengerTicketDocument.get_stamp_result_texture("Dunmere"), "The ticket must show the matching station result asset.")
	_check(result.self_modulate.a > 0.0 and result.self_modulate.a < 1.0, "Stamp ink must remain translucent.")
	tray.mark_committed()
	await create_timer(tray.drawer_duration + 0.08).timeout
	_check(not tray.visible, "A committed ticket must slide the entire stamp drawer off-screen.")

	documents.set_passenger(data)
	await process_frame
	_check(result.visible, "A permanent stamp must reappear after reopening the same passenger ticket.")
	_check(result.position.is_equal_approx(Vector2(249.0, 97.0)), "The permanent result must return to the saved drop position.")
	overlay.queue_free()
	await process_frame
	if _failures == 0:
		print("STAMP TRAY RUNTIME TESTS PASSED")
	quit(_failures)
