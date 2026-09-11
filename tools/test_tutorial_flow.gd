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
	game.state = AfterTheEndGame.GameState.DAY
	game._active_modal = null
	game._hud.set_day_hud_visible(true)
	_check(game.get_node_or_null("%TutorialDirector") != null, "Main scene must include TutorialDirector.")
	_check(game._start_tutorial_if_needed(), "TutorialDirector must start on request.")
	var tutorial := game.get_node("%TutorialDirector") as TutorialDirector
	_check(tutorial.visible, "TutorialDirector must become visible after starting.")
	_check(game._tutorial_route_time_paused, "Tutorial onboarding must pause route time.")
	_check(not game._player.movement_enabled and not game._player.interaction_enabled, "Tutorial intro must lock player controls.")
	tutorial._advance_from_continue()
	_check(game._player.movement_enabled and not game._player.interaction_enabled, "Movement step must allow walking while keeping interaction locked.")
	tutorial.finish_tutorial()
	_check(not game._tutorial_route_time_paused, "Tutorial finish must release route time.")
	game.free()

	if _failures == 0:
		print("PASS: tutorial launch plumbing and first onboarding gates.")
	quit(1 if _failures > 0 else 0)
