class_name DailyManifestConfig
extends Resource
## Inspector-authored rules for generating one runtime passenger manifest.

@export_category("Passenger Flow")
@export_range(1, 40, 1) var total_passenger_count: int = 18
@export_range(1, 20, 1) var initial_passenger_count: int = 10
@export_range(1, 4, 1) var deceased_passenger_count: int = 4
@export_range(0, 4, 1) var minimum_initial_deceased: int = 1
@export_range(1, 8, 1) var passenger_carriage_count: int = 4
@export var balance_boarding_groups_across_carriages: bool = true

@export_category("Ticket Service")
@export var service_train_number: String
@export var alternate_train_numbers: PackedStringArray
@export var ticket_day_code: String
@export_range(0, 4, 1) var wrong_train_boarder_count: int = 1

@export_category("Anomaly Rules")
@export var anomaly_types: PackedStringArray
@export var newspaper_anomaly_type: StringName = &"newspaper_death"
@export_range(1, 4, 1) var max_passengers_per_anomaly_trait: int = 2
@export var unlisted_destination_names: PackedStringArray
@export_range(70, 150, 1) var age_mismatch_minimum_age: int = 91
@export_range(70, 150, 1) var age_mismatch_maximum_age: int = 120

@export_category("Newspaper")
@export_range(0.0, 10.0, 0.1) var non_death_news_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var external_death_news_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var matching_death_news_weight: float = 1.0

@export_category("Passenger AI")
@export var ai_behaviors: PackedStringArray
@export_range(3.0, 30.0, 1.0) var minimum_ai_interval_seconds: float = 8.0
@export_range(3.0, 30.0, 1.0) var maximum_ai_interval_seconds: float = 18.0

@export_category("Random Seed")
@export var use_random_seed: bool = true
@export var debug_seed: int = 2026
