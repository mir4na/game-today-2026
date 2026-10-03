extends SceneTree
## Guards the single playable day's quota against an unreachable paycheck.

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

	var daily: DailyManifestConfig = config.create_daily_service(game.day_number, 20260912)
	var living_count: int = daily.total_passenger_count - daily.deceased_passenger_count
	var maximum_paycheck: int = (
		living_count * reward_per_correct
		+ daily.deceased_passenger_count * retained_reward
	)
	_check(game.day_number == 2, "The playable campaign starts on Day 2.")
	_check(game._get_day_pass_target() == 300, "Day 2 requires 300 Blessings.")
	_check(
		game._get_day_pass_target() <= maximum_paycheck,
		"The Day 2 quota must be reachable from the authored passenger roster."
	)
	for sample_seed: int in range(40):
		var rng := RandomNumberGenerator.new()
		rng.seed = sample_seed
		var generated_config: DailyManifestConfig = config.create_daily_service(2, sample_seed)
		var manifest: Array[PassengerData] = DailyManifestGenerator.generate(
			game.passenger_identity_profiles,
			game.day_route,
			generated_config,
			rng,
			true
		)
		_check(manifest.size() == generated_config.total_passenger_count, "Every Day 2 seed must generate the full passenger roster.")
		var deceased_count: int = 0
		for passenger: PassengerData in manifest:
			if passenger.is_dead:
				deceased_count += 1
			else:
				_check(
					game.day_route.find(passenger.destination_station) > game.day_route.find(passenger.origin_station),
					"Living passengers must have a reachable station after boarding."
				)
		_check(deceased_count == 5, "Each Day 2 roster must contain five anomalies.")

	game.free()
	market.free()
	if _failures == 0:
		print("PASS: the Day 2 quota is 300 and 40 seeds generate valid passenger rosters.")
	quit(1 if _failures > 0 else 0)
