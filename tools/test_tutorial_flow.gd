extends SceneTree
## Verifies the tutorial launch plumbing and first onboarding control gates.

const MainMenuScene = preload("res://scenes/menu/main_menu.tscn")
const MainScene = preload("res://scenes/main/main.tscn")

var _failures: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failures += 1


func _run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/"):
		push_error("Use an isolated /tmp XDG_DATA_HOME for this test.")
		quit(1)
		return

	var menu := MainMenuScene.instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	_check(menu.get_node_or_null("%TutorialButton") != null, "Main Menu must expose a Tutorial button.")
	menu.free()

	var run_context := root.get_node_or_null("RunContext")
	_check(run_context != null, "RunContext autoload must exist.")
	if run_context != null:
		run_context.call(&"request_tutorial")
		_check(bool(run_context.call(&"consume_tutorial_requested")), "RunContext must return a requested tutorial once.")
		_check(not bool(run_context.call(&"consume_tutorial_requested")), "RunContext tutorial request must be one-shot.")
		run_context.call(&"request_tutorial")

	var game := MainScene.instantiate() as AfterTheEndGame
	root.add_child(game)
	await process_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_check(game.is_tutorial_mode, "Gameplay must consume the tutorial launch flag.")
	_check(game.state == AfterTheEndGame.GameState.DAY, "Tutorial must start directly in day gameplay, without the day intro cutscene.")
	_check(game._active_modal == game._tutorial_director, "TutorialDirector should be the first tutorial modal after loading.")
	_check(not game._day_intro_ui.visible, "Tutorial must not show the day intro cutscene.")
	_check(not game._station_stop_ui.visible, "Tutorial must not show the opening station cutscene.")
	_check(game._daily_manifest.is_empty(), "Tutorial must not generate a passenger manifest.")
	_check(game._passengers.is_empty(), "Tutorial must start with no NPC passengers.")
	_check(game.get_node_or_null("%TutorialDirector") != null, "Main scene must include TutorialDirector.")
	if not game._tutorial_started:
		_check(game._start_tutorial_if_needed(), "TutorialDirector must start on request.")
	var tutorial := game.get_node("%TutorialDirector") as TutorialDirector
	_check(tutorial.get_node_or_null("%DialogueDock") != null, "TutorialDirector must expose the Angel dialogue dock.")
	_check(tutorial.get_node_or_null("%DialogueMarkers") != null, "TutorialDirector must expose scene-authored dialogue markers.")
	_check(tutorial.get_node_or_null("%DialogueMarkers/Intro") is Marker2D, "TutorialDirector must expose a marker for the Angel briefing.")
	_check(tutorial.get_node_or_null("%DialogueMarkers/NightMap") is Marker2D, "TutorialDirector must expose a marker for station path guidance.")
	var angel_portrait_frame := tutorial.get_node_or_null("%AngelPortraitFrame") as Control
	_check(angel_portrait_frame != null, "TutorialDirector must expose a circular Angel portrait frame.")
	_check(angel_portrait_frame.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED, "Angel portrait frame must circularly mask its child portrait.")
	_check(tutorial.get_node_or_null("%AngelPortrait") != null, "TutorialDirector must expose the Angel head texture.")
	_check(tutorial.get_node_or_null("DialogueDock/BubbleTail") != null, "TutorialDirector must expose a speech bubble tail aimed at the portrait.")
	_check(tutorial.visible, "TutorialDirector must become visible after starting.")
	var intro_marker := tutorial.get_node("%DialogueMarkers/Intro") as Marker2D
	var dialogue_dock := tutorial.get_node("%DialogueDock") as Control
	_check(dialogue_dock.position.is_equal_approx(intro_marker.position), "Intro dialogue must initialize at its scene marker.")
	_check(game._tutorial_route_time_paused, "Tutorial onboarding must pause route time.")
	_check(not game._player.movement_enabled and not game._player.interaction_enabled, "Tutorial intro must lock player controls.")
	tutorial._advance_from_continue()
	_check(game._player.movement_enabled and not game._player.interaction_enabled, "Movement step must allow walking while keeping interaction locked.")
	var movement_marker := tutorial.get_node("%DialogueMarkers/Movement") as Marker2D
	_check(dialogue_dock.position.is_equal_approx(movement_marker.position), "Movement guidance must move to its own scene marker.")
	tutorial._show_continue_step(TutorialDirector.Step.HUD_CLOCK, "Journey Clock", "Test", "")
	var clock_marker := tutorial.get_node("%DialogueMarkers/HudClock") as Marker2D
	_check(dialogue_dock.position.is_equal_approx(clock_marker.position), "HUD clock guidance must move to its own scene marker.")
	tutorial._advance_from_continue()
	_check(tutorial._step == TutorialDirector.Step.DAY_SERVICE, "Empty-coach tutorial must skip passenger inspection.")
	tutorial._advance_from_continue()
	_check(not game._tutorial_route_time_paused, "Tutorial finish must release route time.")
	_check(game._passengers.is_empty(), "Tutorial must remain empty after finishing onboarding.")
	game.free()

	if _failures == 0:
		print("PASS: tutorial launch plumbing and first onboarding gates.")
	quit(1 if _failures > 0 else 0)
