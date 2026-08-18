extends SceneTree
## Verifies menu construction, settings navigation, and Start -> gameplay boot.

const TestFlowHelpers = preload("res://tests/test_flow_helpers.gd")

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var packed := load("res://scenes/menu/main_menu.tscn") as PackedScene
	var menu := packed.instantiate() as MainMenu
	root.add_child(menu)
	current_scene = menu
	await process_frame

	var start_button := menu.get("_start_button") as Button
	var settings_button := menu.get("_settings_button") as Button
	var quit_button := menu.get("_quit_button") as Button
	assert(start_button != null and settings_button != null and quit_button != null, "Main menu needs Start, Settings, and Quit")
	assert(MainMenu.DEFAULT_FULLSCREEN, "Fullscreen should be the first-run display default")
	assert(int(ProjectSettings.get_setting("display/window/size/mode")) == DisplayServer.WINDOW_MODE_FULLSCREEN, "The project should launch fullscreen before the menu loads")
	menu.call("_show_settings")
	assert((menu.get("_settings_panel") as Control).visible, "Settings panel should open")
	assert(not (menu.get("_menu_panel") as Control).visible, "Main buttons should hide behind settings")
	menu.call("_save_and_close_settings")
	assert((menu.get("_menu_panel") as Control).visible, "Settings should return to main buttons")

	menu.call("_start_game")
	await create_timer(0.55).timeout
	assert(current_scene is AfterTheEndGame, "Start should transition into gameplay")
	var gameplay := current_scene as AfterTheEndGame
	TestFlowHelpers.finish_opening(gameplay)
	assert(gameplay.call("_active_passenger_count") == 10, "Gameplay should begin with ten active passengers")
	print("MENU_FLOW_TEST: PASS")
	gameplay.queue_free()
	await process_frame
	quit()
