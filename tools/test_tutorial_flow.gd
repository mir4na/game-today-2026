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
	# Pin the clean-coach path: the production scene runs the full Goat flow.
	tutorial.use_empty_coach_flow = true
	_check(tutorial.get_node_or_null("%DialogueDock") != null, "TutorialDirector must expose the Angel dialogue dock.")
	_check(tutorial.get_node_or_null("%DialogueMarkers") != null, "TutorialDirector must expose scene-authored dialogue markers.")
	_check(tutorial.get_node_or_null("%DialogueMarkers/Intro") is Marker2D, "TutorialDirector must expose a marker for the Angel briefing.")
	_check(tutorial.get_node_or_null("%DialogueMarkers/PassengerIntro") is Marker2D, "TutorialDirector must expose a marker for the passenger introduction.")
	_check(tutorial.get_node_or_null("%DialogueMarkers/PassengerPrompt") is Marker2D, "TutorialDirector must expose a marker for the passenger inspect prompt.")
	_check(tutorial.get_node_or_null("WorldPointerSettings/PassengerOffset") is Marker2D, "TutorialDirector must expose a scene-authored passenger pointer offset.")
	_check(tutorial.get_node_or_null("%DialogueMarkers/NightMap") is Marker2D, "TutorialDirector must expose a marker for station path guidance.")
	var angel_portrait_frame := tutorial.get_node_or_null("%AngelPortraitFrame") as Control
	_check(angel_portrait_frame != null, "TutorialDirector must expose a circular Angel portrait frame.")
	_check(angel_portrait_frame.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED, "Angel portrait frame must circularly mask its child portrait.")
	_check(tutorial.get_node_or_null("%AngelPortrait") != null, "TutorialDirector must expose the Angel head texture.")
	_check(tutorial.get_node_or_null("%AngelPortraitContent") is Node2D, "Angel portrait crop content must use a scene-authored Node2D transform.")
	_check(not tutorial.get_node_or_null("%AngelPortraitContent") is CanvasGroup, "Angel portrait crop must avoid CanvasGroup clipping artifacts.")
	_check(tutorial.get_node_or_null("DialogueDock/BubbleTail") != null, "TutorialDirector must expose a speech bubble tail aimed at the portrait.")
	_check(tutorial.visible, "TutorialDirector must become visible after starting.")
	_check(not tutorial._hud.visible, "Tutorial intro must hide the gameplay HUD.")
	_check(not (tutorial.get_node("%Panel") as Control).visible, "Intro search must keep the dialogue bubble hidden.")
	_check(not (tutorial.get_node("%BubbleTail") as Control).visible, "Intro search must keep the bubble tail hidden with the dialogue.")
	# The spotlight search plus the angel circle reveal and its hold beat
	# play before the intro bubble.
	await create_timer(3.6).timeout
	var intro_marker := tutorial.get_node("%DialogueMarkers/Intro") as Marker2D
	var dialogue_dock := tutorial.get_node("%DialogueDock") as Control
	var intro_frame := tutorial.get_node("%DialogueFrames/Intro") as Control
	var intro_portrait_spot := intro_frame.get_node("PortraitSpot") as Control
	var intro_tail_spot := intro_frame.get_node("TailSpot") as Control
	var bubble_tail := tutorial.get_node("%BubbleTail") as Control
	_check(dialogue_dock.position.is_equal_approx(intro_marker.position), "Intro dialogue must initialize at its scene marker.")
	_check(dialogue_dock.scale.is_equal_approx(intro_frame.scale), "Bubble animation must not alter the DialogueFrames-authored dock scale.")
	_check(
		angel_portrait_frame.scale.is_equal_approx(tutorial._portrait_base_scale * intro_portrait_spot.scale),
		"Intro reveal must preserve the portrait scale authored in DialogueFrames/Intro/PortraitSpot."
	)
	_check(tutorial._spotlight_control == null, "Intro spotlight must return to the player after revealing the Inspector.")
	_check(is_equal_approx(tutorial._shade_alpha, tutorial.continue_step_dim_alpha), "Intro briefing must keep the game screen dimmed.")
	_check(bubble_tail.position.is_equal_approx(intro_tail_spot.position), "Runtime bubble tail position must match the Intro TailSpot.")
	_check(bubble_tail.size.is_equal_approx(intro_tail_spot.size), "Runtime bubble tail size must match the Intro TailSpot.")
	_check(bubble_tail.scale.is_equal_approx(intro_tail_spot.scale), "Runtime bubble tail scale must match the Intro TailSpot without an extra flip.")
	_check(is_equal_approx(bubble_tail.rotation, intro_tail_spot.rotation), "Runtime bubble tail rotation must match the Intro TailSpot.")
	_check(game._tutorial_route_time_paused, "Tutorial onboarding must pause route time.")
	_check(not game._player.movement_enabled and not game._player.interaction_enabled, "Tutorial intro must lock player controls.")
	_check(tutorial.intro_dialogue_pages.size() == 4, "Inspector briefing must be split into four short dialogue pages.")
	for page: String in tutorial.intro_dialogue_pages:
		var sentence_count: int = page.count(".") + page.count("!") + page.count("?")
		_check(sentence_count <= 2, "Each Inspector intro bubble must contain at most two sentences.")
	_check((tutorial.get_node("%SpeakerLabel") as Label).text == "The Inspector", "Intro speaker must identify the character as the Inspector.")
	_check((tutorial.get_node("%BodyLabel") as Label).text == tutorial.intro_dialogue_pages[0], "Intro must begin with the short Inspector greeting.")
	for page_index: int in range(1, tutorial.intro_dialogue_pages.size()):
		tutorial._complete_typewriter()
		tutorial._advance_from_continue()
		_check((tutorial.get_node("%BodyLabel") as Label).text == tutorial.intro_dialogue_pages[page_index], "Intro Continue must reveal dialogue page %d." % (page_index + 1))
	tutorial._complete_typewriter()
	tutorial._advance_from_continue()
	_check(tutorial._step == TutorialDirector.Step.MOVEMENT_INTRO, "Intro must lead into a short movement briefing.")
	_check(not game._player.movement_enabled, "Movement briefing must wait for Continue before enabling movement.")
	_check((tutorial.get_node("%BodyLabel") as Label).text == tutorial.movement_intro_prompt, "Movement briefing must use its scene-configured copy.")
	tutorial._complete_typewriter()
	tutorial._advance_from_continue()
	_check(game._player.movement_enabled and not game._player.interaction_enabled, "Movement step must allow walking while keeping interaction locked.")
	_check(not tutorial._hud.visible, "A/D movement training must keep the gameplay HUD hidden.")
	_check(dialogue_dock.visible, "Movement instruction bubble stays readable while walking.")
	_check((tutorial.get_node("%BodyLabel") as Label).text.contains("Keep moving"), "Walk bubble must carry the movement instruction.")
	tutorial._walk_time = tutorial.movement_required_seconds
	tutorial._process(0.0)
	_check(tutorial._step == TutorialDirector.Step.MOVEMENT_SUCCESS, "Completing movement must show the Inspector's success response.")
	_check((tutorial.get_node("%BodyLabel") as Label).text == tutorial.movement_success_prompt, "Movement success must use its scene-configured copy.")
	_check(not tutorial._hud.visible, "Movement success response must keep the gameplay HUD hidden.")
	tutorial._complete_typewriter()
	tutorial._advance_from_continue()
	_check(tutorial._step == TutorialDirector.Step.HUD_INTRO, "Movement success must lead into the HUD introduction.")
	_check(not tutorial._hud.visible, "HUD introduction must keep the HUD hidden until its reveal beat.")
	_check((tutorial.get_node("%BodyLabel") as Label).text == "Now, let me explain the tools you will use on this train.", "HUD introduction must announce the feature explanation.")
	tutorial.hud_intro_hold_seconds = 0.05
	tutorial.minimap_reveal_hold_seconds = 0.05
	tutorial.minimap_spotlight_zoom_seconds = 0.1
	tutorial.hud_feature_hold_seconds = 0.05
	tutorial.hud_feature_spotlight_zoom_seconds = 0.1
	tutorial._complete_typewriter()
	tutorial._advance_from_continue()
	_check(not dialogue_dock.visible, "Staged minimap reveal must clear the dialogue before its first hold.")
	await create_timer(0.08).timeout
	_check(tutorial._hud.visible, "Minimap must appear after the HUD intro hold.")
	_check(tutorial._hud._minimap_anchor.visible, "Staged HUD reveal must expose the minimap.")
	for hud_child: Node in tutorial._hud._root.get_children():
		if hud_child is CanvasItem and hud_child != tutorial._hud._minimap_anchor:
			_check(not (hud_child as CanvasItem).visible, "Only the minimap may be visible during its isolated reveal.")
	await create_timer(0.2).timeout
	_check(tutorial._step == TutorialDirector.Step.HUD_MINIMAP, "Spotlight zoom must finish on minimap guidance.")
	_check(tutorial._spotlight_control == tutorial._hud.get_tutorial_minimap_focus_control(), "Spotlight must settle on the minimap.")
	_check(not (tutorial.get_node("%HintLabel") as Label).visible, "Tutorial dialogue must not display a secondary hint row.")
	tutorial._complete_typewriter()
	tutorial._advance_from_continue()
	_check(not dialogue_dock.visible, "Clock reveal must hide dialogue during its 0.75 second hold.")
	await create_timer(0.2).timeout
	_check(tutorial._step == TutorialDirector.Step.HUD_CLOCK, "Clock must receive its own staged reveal before its explanation.")
	_check(tutorial._hud._clock_panel.visible, "Clock must become visible after its reveal hold.")
	_check(tutorial._spotlight_control == tutorial._hud.get_tutorial_clock_focus_control(), "Spotlight must settle on the clock.")
	_check((tutorial.get_node("%BodyLabel") as Label).text.contains("one full turn"), "Clock dialogue must explain the route time limit.")
	var clock_marker := tutorial.get_node("%DialogueMarkers/HudClock") as Marker2D
	_check(dialogue_dock.position.is_equal_approx(clock_marker.position), "HUD clock guidance must move to its own scene marker.")
	tutorial._complete_typewriter()
	tutorial._advance_from_continue()
	await create_timer(0.2).timeout
	_check(tutorial._step == TutorialDirector.Step.BLESSINGS, "Clock guidance must continue into day Blessings scoring.")
	_check(tutorial._hud._blessing_summary.visible, "Blessings summary must become visible after its reveal hold.")
	_check(tutorial._spotlight_control == tutorial._hud.get_tutorial_blessings_focus_control(), "Spotlight must settle on the Blessings summary.")
	_check((tutorial.get_node("%BodyLabel") as Label).text.contains("left number"), "Blessings dialogue must explain earned Blessings and the target.")
	tutorial.passenger_spawn_hold_seconds = 0.05
	tutorial.passenger_camera_move_seconds = 0.1
	tutorial.passenger_spawn_animation_seconds = 0.1
	game.process_mode = Node.PROCESS_MODE_INHERIT
	tutorial._complete_typewriter()
	tutorial._advance_from_continue()
	_check(tutorial._step == TutorialDirector.Step.PASSENGER_REVEAL, "Blessings must lead into the staged passenger reveal.")
	_check(not dialogue_dock.visible, "Passenger reveal hold must clear the previous dialogue.")
	await create_timer(0.3).timeout
	_check(tutorial._step == TutorialDirector.Step.PASSENGER_INTRO, "NPC 12 must receive an introduction after its spawn animation.")
	_check(game._passengers.size() == 1, "Tutorial must spawn exactly one passenger after the clean opening.")
	var tutorial_passenger: Passenger = game._passengers[0] if not game._passengers.is_empty() else null
	_check(is_instance_valid(tutorial_passenger), "Tutorial passenger must be a valid Passenger instance.")
	if is_instance_valid(tutorial_passenger):
		_check(tutorial_passenger.data.identity_profile == tutorial.tutorial_passenger_profile, "Tutorial must use the NPC 12 identity profile configured in the scene.")
		_check(tutorial_passenger.get_runtime_carriage() == 2, "Tutorial passenger must spawn in the second carriage.")
		_check(tutorial_passenger.visible and tutorial_passenger.enabled, "Tutorial passenger must become visible and interactable after landing.")
	_check(game._gameplay_camera.zoom.is_equal_approx(tutorial.passenger_camera_zoom), "Passenger reveal must zoom the gameplay camera to its scene-configured value.")
	_check((tutorial.get_node("%BodyLabel") as Label).text.contains("seen this person"), "Passenger introduction must mention the Inspector's sense of recognition.")
	var passenger_intro_marker := tutorial.get_node("%DialogueMarkers/PassengerIntro") as Marker2D
	_check(dialogue_dock.position.is_equal_approx(passenger_intro_marker.position), "Passenger introduction must use its scene-authored marker.")
	tutorial._complete_typewriter()
	tutorial._advance_from_continue()
	_check(tutorial._step == TutorialDirector.Step.PASSENGER_PROMPT, "Passenger introduction must lead into the inspect instruction.")
	_check((tutorial.get_node("%BodyLabel") as Label).text.contains("press E"), "Passenger prompt must explain how to inspect the NPC.")
	_check((tutorial.get_node("%ArrowLabel") as Label).visible, "Inspect pointer must appear with the passenger instruction.")
	tutorial._complete_typewriter()
	tutorial._advance_from_continue()
	_check(tutorial._step == TutorialDirector.Step.PASSENGER, "Closing the inspect instruction must begin the passenger task.")
	_check(not dialogue_dock.visible, "Passenger inspection task must hide the dialogue bubble.")
	_check(not bubble_tail.visible, "Passenger inspection task must hide the dialogue tail.")
	_check((tutorial.get_node("%ArrowLabel") as Label).visible, "Passenger inspection task must keep a pointer aimed at NPC 12.")
	await create_timer(0.15).timeout
	_check(game._player.movement_enabled and game._player.interaction_enabled, "Player must regain movement and interaction after the camera returns.")
	_check(game._gameplay_camera.zoom.is_equal_approx(game._tutorial_camera_rest_zoom), "Passenger task must restore the gameplay camera zoom before player control returns.")
	if is_instance_valid(tutorial_passenger):
		game._on_interaction_pressed(tutorial_passenger)
		await process_frame
	_check(tutorial._step == TutorialDirector.Step.DOCUMENTS, "Inspecting NPC 12 must advance to the document lesson.")
	_check(game._document_overlay.visible, "NPC 12 interaction must open the actual passenger document UI.")
	_check(not (tutorial.get_node("%ArrowLabel") as Label).visible, "Inspect pointer must disappear once the passenger documents open.")
	game.free()

	if _failures == 0:
		print("PASS: tutorial launch plumbing and first onboarding gates.")
	quit(1 if _failures > 0 else 0)
