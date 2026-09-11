extends SceneTree
## Guards the five-day economy against unreachable or non-progressive quotas.

const MainScene = preload("res://scenes/main/main.tscn")
const MarketScene = preload("res://scenes/systems/market_tool_state.tscn")

var _failures: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _run() -> void:
	var game := MainScene.instantiate() as AfterTheEndGame
	var market := MarketScene.instantiate() as MarketToolState
	var config: DailyManifestConfig = game.manifest_config
	var previous_target: int = 0
	var reward_per_correct: int = market.blessings_per_correct_dropoff

	_check(game.day_pass_targets.size() == 5, "The campaign must define one quota for each of its five days.")
	for day: int in range(1, 6):
		var daily: DailyManifestConfig = config.create_daily_service(day, 20260912)
		var living_count: int = daily.total_passenger_count - daily.deceased_passenger_count
		var maximum_paycheck: int = living_count * reward_per_correct
		var target: int = game.day_pass_targets[day - 1]
		_check(target > previous_target, "Day %d quota must be higher than the previous day." % day)
		_check(
			target <= maximum_paycheck,
			"Day %d quota %d exceeds its maximum possible paycheck %d." % [day, target, maximum_paycheck]
		)
		previous_target = target

	game.free()
	market.free()
	if _failures == 0:
		print("PASS: all five daylight quotas increase and remain reachable.")
	quit(1 if _failures > 0 else 0)
