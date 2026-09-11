extends SceneTree
## Restart loading must cover gameplay with black before its loading content appears.


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var loading := load("res://scenes/ui/loading_screen_ui.tscn").instantiate() as LoadingScreenUI
	root.add_child(loading)
	await process_frame
	loading.minimum_display_seconds = 99.0
	loading.begin_loading("res://scenes/ui/pause_ui.tscn", 1.0, true)
	var content := loading.get_node("BottomLeft") as Control
	var cover := loading.get_node("FadeToBlack") as ColorRect
	assert(loading.visible, "Restart must show the transition layer immediately.")
	assert(not content.visible, "Loading content must stay hidden while the screen fades to black.")
	assert(cover.modulate.a < 0.1, "The restart cover must begin transparent.")
	await create_timer(0.65).timeout
	assert(
		cover.modulate.a >= 0.99,
		"The gameplay view must be fully black before loading appears (alpha %.3f)." % cover.modulate.a
	)
	assert(content.visible, "Loading content must appear only after the black cover is complete.")
	assert(content.z_index > cover.z_index, "Loading content must render above the black cover.")
	loading.queue_free()
	await process_frame
	print("PASS: restart fades fully to black before revealing the loading screen.")
	quit()
