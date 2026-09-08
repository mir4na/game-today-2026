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
	assert(pause_menu.get_node_or_null("Ticket/Actions/ResumeButton") == null, "Pause menu must not show a resume button.")
	var master_slider := pause_menu.get_node("Ticket/OptionGrid/MasterVolumeOption/Content/VolumeSlider") as Control
	assert(master_slider.visible, "Audio options must use the ticket slider control.")
	print("Pause menu runtime test passed.")
	quit()
