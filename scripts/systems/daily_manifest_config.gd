class_name DailyManifestConfig
extends Resource
## Inspector-authored rules for generating one runtime passenger manifest.

@export_category("Passenger Flow")
@export_range(1, 40, 1) var total_passenger_count: int = 17
@export_range(1, 20, 1) var initial_passenger_count: int = 10
@export_range(1, 4, 1) var deceased_passenger_count: int = 4
@export_range(0, 4, 1) var minimum_initial_deceased: int = 1
@export_range(1, 8, 1) var passenger_carriage_count: int = 4
@export var balance_boarding_groups_across_carriages: bool = true

@export_category("Passenger Name Pools")
@export_range(1, 100, 1) var minimum_unique_name_count: int = 30
@export var female_passenger_names: PackedStringArray
@export var male_passenger_names: PackedStringArray

@export_category("Ticket Service")
@export var service_train_number: String
@export var alternate_train_numbers: PackedStringArray
@export var service_date_text: String
@export var ticket_day_code: String
@export var invalid_service_dates_by_day_code: Dictionary = {}
@export_range(0, 4, 1) var wrong_train_boarder_count: int = 1

@export_category("Anomaly Rules")
@export var anomaly_types: PackedStringArray
@export var newspaper_anomaly_type: StringName = &"newspaper_death"
@export_range(1, 4, 1) var max_passengers_per_anomaly_trait: int = 2
@export var unlisted_destination_names: PackedStringArray

@export_category("Newspaper")
@export_range(0.0, 10.0, 0.1) var non_death_news_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var matching_death_news_weight: float = 1.0

@export_category("Passenger AI")
@export var ai_behaviors: PackedStringArray
@export_range(3.0, 30.0, 1.0) var minimum_ai_interval_seconds: float = 8.0
@export_range(3.0, 30.0, 1.0) var maximum_ai_interval_seconds: float = 18.0

@export_category("Random Seed")
@export var use_random_seed: bool = true
@export var debug_seed: int = 2026


func create_daily_service(day: int, shift_seed: int) -> DailyManifestConfig:
	var daily := duplicate(true) as DailyManifestConfig
	var service_rng := RandomNumberGenerator.new()
	service_rng.seed = ("train:%d:day:%d" % [shift_seed, day]).hash()
	var numbers := PackedStringArray()
	for number: int in range(100, 1000):
		var candidate: String = str(number)
		if not alternate_train_numbers.has(candidate):
			numbers.append(candidate)
	daily.service_train_number = numbers[service_rng.randi_range(0, numbers.size() - 1)]
	return daily


func get_all_passenger_names() -> PackedStringArray:
	var combined_names := PackedStringArray()
	var used_names: Dictionary = {}
	for name_pool: PackedStringArray in [female_passenger_names, male_passenger_names]:
		for configured_name: String in name_pool:
			var cleaned_name: String = configured_name.strip_edges()
			var normalized_name: String = cleaned_name.to_lower()
			if cleaned_name.is_empty() or used_names.has(normalized_name):
				continue
			used_names[normalized_name] = true
			combined_names.append(cleaned_name)
	return combined_names
