extends SceneTree
## Focused ending smoke test. Set WHERE_DO_YOU_BELONG_TEST_SAVE to an isolated path.

const Progress = preload("res://scripts/systems/shift_progress.gd")
const MainScene = preload("res://scenes/main/main.tscn")
const CreditsScene = preload("res://scenes/menu/credits.tscn")

var _failures: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _run() -> void:
	var isolated_save_path: String = OS.get_environment(Progress.TEST_SAVE_PATH_ENV).replace("\\", "/")
	if "where-do-you-belong-tests" not in isolated_save_path:
		push_error("Set WHERE_DO_YOU_BELONG_TEST_SAVE to an isolated where-do-you-belong-tests path.")
		quit(1)
		return
	Progress.start_new_run()
	var game: AfterTheEndGame = MainScene.instantiate()
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var music_manager := root.get_node_or_null("MusicManager")
	_check(music_manager != null, "The scene-authored MusicManager autoload must exist.")
	if music_manager != null:
		_check(is_equal_approx(float(music_manager.get("music_volume")), 0.35), "Music must play at the scene-authored 35 percent volume.")
		_check(music_manager.get("gameplay_day_stream") != null, "Day gameplay music must be assigned in MusicManager.tscn.")
		_check(music_manager.get("heaven_outro_stream") != null, "Heaven outro must be assigned in MusicManager.tscn.")
		_check(music_manager.get("bad_ending_outro_stream") != null, "Bad-ending outro must be assigned in MusicManager.tscn.")
	_check(game.get_node("EndingLayer").layer > game.get_node("BloomLayer").layer, "Ending art and UI must render above gameplay bloom.")
	_check(game.get_node("PauseLayer").layer > game.get_node("BloomLayer").layer, "Pause UI must render above gameplay bloom.")

	game.state = AfterTheEndGame.GameState.SHIFT_REPORT
	game._day_blessing_award = {"passed": false, "net_earnings": 80, "pass_target": 300}
	game._on_shift_report_continue()
	_check(game.state == AfterTheEndGame.GameState.HELL_ENDING, "Failed daylight paychecks must enter Hell.")
	_check(game._hell_ending_ui.visible and not game._pause_ui.visible, "Hell must replace normal modal and Pause UI presentation.")
	_check("80 / 300" in game._hell_ending_ui.get_node("%Reason").text, "Hell must explain the failed paycheck quota.")
	if music_manager != null:
		_check(music_manager.get("_current_track") == &"ending_bad", "Hell must start the scene-authored bad-ending outro.")

	game._hell_ending_ui.hide()
	game.day_number = 5
	game._day_blessing_award = {"earned": 500}
	game._night_blessing_award = {"earned": 750, "correct_night_dropoffs": 5}
	game._show_heaven_ending()
	_check(game.state == AfterTheEndGame.GameState.HEAVEN_ENDING, "Day 5 success must enter Heaven.")
	_check(game._heaven_ending_ui.visible and not game._pause_ui.visible, "Heaven must remain separate from Pause UI.")
	_check("DAYS COMPLETED     5 / 5" in game._heaven_ending_ui.get_node("%Summary").text, "The final paycheck must summarize all five days.")
	if music_manager != null:
		_check(music_manager.get("_current_track") == &"ending_good", "Heaven must start the scene-authored Heaven outro.")

	var credits: GameCredits = CreditsScene.instantiate()
	root.add_child(credits)
	_check(credits.get_node("CreditsBlock/Panel/Margin/Content/Programmers").text == "Ame  •  Ammar", "Programmer credits must list Ame and Ammar.")
	_check(credits.get_node("CreditsBlock/Panel/Margin/Content/Artists").text == "Yasmin  •  Mahi  •  Rheina", "Artist credits must list Yasmin, Mahi, and Rheina.")

	credits.free()
	game.free()
	DirAccess.remove_absolute(isolated_save_path)
	if _failures > 0:
		quit(1)
		return
	print("PASS: Heaven, Hell, final paycheck, credits, and bloom-safe UI layers.")
	quit()
