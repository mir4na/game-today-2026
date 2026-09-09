extends SceneTree
## Verifies the temporary HUD shortcut builds the complete Night Shift roster.

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
	var game := MainScene.instantiate() as AfterTheEndGame
	root.add_child(game)
	await process_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game._active_modal = null
	game.state = AfterTheEndGame.GameState.DAY
	game._hud.set_day_hud_visible(true)

	var expected_night_roster: int = 0
	for data: PassengerData in game._daily_manifest:
		if data.is_dead:
			expected_night_roster += 1
	var shortcut := game._hud.get_node("%DebugNightButton") as Button
	_check(shortcut.visible, "The temporary Night Shift button must be visible during daylight gameplay.")
	shortcut.pressed.emit()

	_check(game.state == AfterTheEndGame.GameState.NIGHT, "The shortcut must enter Night Shift immediately.")
	_check(game._get_dead_passenger_data().size() == expected_night_roster, "The shortcut must include every scheduled anomaly in the night roster.")
	_check(game._active_passenger_count() == expected_night_roster, "Living daylight passengers must not remain active at night.")
	_check(game._runtime_puzzle != null, "The shortcut must initialize the runtime constellation puzzle.")
	_check(not shortcut.visible, "The temporary shortcut must hide after Night Shift begins.")

	game.free()
	if _failures == 0:
		print("PASS: temporary Night Shift shortcut and complete anomaly roster.")
	quit(1 if _failures > 0 else 0)
