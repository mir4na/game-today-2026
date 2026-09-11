extends SceneTree
## Verifies page order, click progression, and the shared bottom-right hint slot.


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var intro := load("res://scenes/ui/intro_cutscene.tscn").instantiate() as IntroCutscene
	intro.opening_fade_duration = 0.1
	intro.page_fade_duration = 0.1
	intro.preload_gameplay_during_intro = false
	root.add_child(intro)
	await process_frame
	assert(intro.INTRO_PAGES.size() == 10, "The intro must contain exactly ten ordered story pages.")
	assert(intro._page_index == 0, "The intro must begin on Intro1.")
	assert(intro._current_page.texture == intro.INTRO_PAGES[0], "Intro1 must be the first visible page.")
	assert(intro._background.texture != null, "Introbackground must remain behind the illustrated pages.")

	intro._handle_pointer_hold(true)
	assert(intro._hold_ring.visible, "Holding must show the radial skip indicator.")
	assert(intro._prompt_label.text == "Hold to skip", "Hold copy must not display a seconds countdown.")
	intro._handle_pointer_hold(false)
	await create_timer(intro.page_fade_duration * 2.0 + 0.08).timeout
	assert(intro._page_index == 1, "A short click must advance from Intro1 to Intro2.")
	assert(intro._current_page.texture == intro.INTRO_PAGES[1], "Intro2 must follow Intro1.")

	intro._idle_elapsed = intro.continue_hint_delay_seconds
	intro._process(0.01)
	assert(not intro._hold_ring.visible, "The hold ring must hide while Click to continue is shown.")
	assert(intro._prompt_label.text == "Click to continue", "The idle hint must use the shared prompt slot.")
	intro._handle_pointer_hold(true)
	assert(intro._hold_ring.visible, "Starting a hold must replace the idle hint with the ring.")
	assert(intro._prompt_label.text == "Hold to skip", "Hold and click prompts must never appear together.")

	intro.queue_free()
	print("PASS: intro pages, click progression, fades, and exclusive prompts are configured.")
	quit()
