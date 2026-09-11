extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://scenes/ui/pause_ui.tscn") as PackedScene
	assert(packed != null, "Pause menu scene must load.")
	var pause_menu := packed.instantiate() as PauseUI
	assert(pause_menu != null, "Pause menu scene must instantiate PauseUI.")
	root.add_child(pause_menu)
	await process_frame
	pause_menu.configure_service_info("505", "07 JUN 2026")
	pause_menu.open_pause()
	for frame: int in range(30):
		await process_frame
	assert(pause_menu.visible, "Pause menu must be visible after open_pause().")
	assert(pause_menu.get_node_or_null("Ticket/OptionGrid") != null, "Pause menu requires the 2x4 option grid.")
	var option_grid := pause_menu.get_node("Ticket/OptionGrid") as GridContainer
	assert(option_grid.columns == 2, "Pause menu options must use two columns and four rows.")
	assert(option_grid.get_child_count() == 8, "Pause menu must expose exactly eight options.")
	var resume_button := pause_menu.get_node("%ResumeButton") as Button
	assert(resume_button.visible and resume_button.text == "Resume", "The in-game pause menu must show a Resume text button.")
	var master_slider := pause_menu.get_node("Ticket/OptionGrid/MasterVolumeOption/Content/VolumeSlider") as Control
	assert(master_slider.visible, "Audio options must use the ticket slider control.")
	pause_menu.set_night_mode(true)
	var artwork := pause_menu.get_node("Ticket/TicketArtwork") as TextureRect
	var artwork_material := artwork.material as ShaderMaterial
	assert(is_equal_approx(float(artwork_material.get_shader_parameter(&"night_strength")), 1.0), "Night service must apply the night ticket palette.")
	var display_option := pause_menu.get_node("Ticket/OptionGrid/DisplayModeOption") as PauseOptionSelector
	var display_label := display_option.get_node("Content/OptionLabel") as Label
	assert(display_label.get_theme_color(&"font_color").is_equal_approx(Color("f4e49e")), "Night service must recolor option labels.")
	pause_menu.set_night_mode(false)
	assert(display_label.get_theme_color(&"font_color").is_equal_approx(Color("353540")), "Day service must restore the exact original asset ink color.")
	var resume_events: Array[bool] = [false]
	pause_menu.resume_requested.connect(func() -> void: resume_events[0] = true)
	resume_button.pressed.emit()
	await create_timer(pause_menu.close_duration + 0.05).timeout
	assert(resume_events[0], "Pressing the Resume text button must emit the normal resume action.")
	pause_menu.free()
	var menu := load("res://scenes/menu/main_menu.tscn").instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	assert(
		menu.get_node("BloomOverlay").get_index() < menu.get_node("UI").get_index(),
		"Menu bloom must render before every menu and settings UI element."
	)
	var menu_train_sfx := menu.get_node("%TrainSfx") as AudioStreamPlayer
	assert(menu_train_sfx.stream is AudioStreamOggVorbis and (menu_train_sfx.stream as AudioStreamOggVorbis).loop, "Main menu must loop the authored in-game train SFX.")
	assert(menu_train_sfx.bus == &"SFX" and menu_train_sfx.volume_db <= -20.0, "Main-menu train SFX must stay quietly routed through the SFX bus.")
	(menu.get_node("%SettingsButton") as Button).pressed.emit()
	await process_frame
	var menu_settings := menu.get_node("%SettingsUI") as PauseUI
	assert(menu_settings.visible, "Main menu Settings must open the shared in-game settings UI.")
	assert(menu_settings.get_node("Ticket/OptionGrid").get_child_count() == 8, "Main menu must expose the same eight options as in-game.")
	assert(not (menu_settings.get_node("%ResumeButton") as Button).visible, "Resume must stay hidden in main-menu settings mode.")
	assert(not (menu_settings.get_node("%RestartButton") as Button).visible, "Restart shift must stay hidden in main-menu settings mode.")
	assert((menu_settings.get_node("%MainMenuButton") as Button).text == "Back", "The shared action must become Back in main-menu settings mode.")
	menu_settings.resume_requested.emit()
	assert(not menu_settings.visible, "Closing shared settings must return to the main menu.")
	var gameplay := load("res://scenes/main/main.tscn").instantiate() as AfterTheEndGame
	var bloom_layer := gameplay.get_node("BloomLayer") as CanvasLayer
	var hud_layer := gameplay.get_node("HUD") as CanvasLayer
	var modal_layer := gameplay.get_node("ModalLayer") as CanvasLayer
	var pause_layer := gameplay.get_node("PauseLayer") as CanvasLayer
	assert(bloom_layer.layer < hud_layer.layer, "Gameplay bloom must render below the HUD.")
	assert(bloom_layer.layer < modal_layer.layer, "Gameplay bloom must render below all modal UI.")
	assert(bloom_layer.layer < pause_layer.layer, "Gameplay bloom must render below PauseUI.")
	gameplay.free()
	print("Pause menu runtime test passed.")
	quit()
