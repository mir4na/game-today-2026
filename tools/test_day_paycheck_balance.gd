extends SceneTree
## Guards the single-day economy against an unreachable quota.

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
	var reward_per_correct: int = market.blessings_per_correct_dropoff
	var retained_reward: int = market.blessings_per_retained_anomaly

	_check(game.day_pass_targets.size() == 1, "The campaign must define one quota for its single day.")
	if game.day_pass_targets.size() == 1:
		var daily: DailyManifestConfig = config.create_daily_service(1, 20260912)
		var living_count: int = daily.total_passenger_count - daily.deceased_passenger_count
		# The paycheck can also bank the retained-anomaly reward for each soul
		# kept aboard for Night Service.
		var maximum_paycheck: int = (
			living_count * reward_per_correct
			+ daily.deceased_passenger_count * retained_reward
		)
		var target: int = game.day_pass_targets[0]
		_check(
			target <= maximum_paycheck,
			"The day quota %d exceeds its maximum possible paycheck %d." % [target, maximum_paycheck]
		)

	game.free()
	market.free()
	if _failures == 0:
		print("PASS: the single daylight quota stays reachable.")
	quit(1 if _failures > 0 else 0)
