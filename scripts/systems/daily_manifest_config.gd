class_name DailyManifestConfig
extends Resource
## Inspector-authored rules for generating one runtime passenger manifest.

@export_category("Passenger Flow")
@export_range(1, 40, 1) var total_passenger_count: int = 17
@export_range(1, 20, 1) var initial_passenger_count: int = 8
@export_range(1, 40, 1) var maximum_onboard_passenger_count: int = 12
@export var maximum_onboard_passenger_count_by_day: PackedInt32Array = PackedInt32Array([14, 15, 15, 16, 16])
@export_range(1, 5, 1) var deceased_passenger_count: int = 3
@export_range(0, 5, 1) var minimum_initial_deceased: int = 1
@export_range(1, 8, 1) var passenger_carriage_count: int = 4
@export var balance_boarding_groups_across_carriages: bool = true

@export_category("Night Service Progression")
@export var night_anomaly_count_by_level: PackedInt32Array = PackedInt32Array([3, 3, 4, 4, 5])
@export_range(0, 5, 1) var guaranteed_newspaper_anomaly_level: int = 5

@export_category("Passenger Name Pools")
@export_range(1, 100, 1) var minimum_unique_name_count: int = 30
@export var female_passenger_names: PackedStringArray
@export var male_passenger_names: PackedStringArray

@export_category("Ticket Service")
@export var service_train_number: String
@export var service_train_codes: PackedStringArray = PackedStringArray([
	"ATE-101", "ATE-202", "ATE-303", "ATE-404", "ATE-505",
])
@export var service_date_text: String
@export var ticket_day_code: String
@export var invalid_service_dates_by_day_code: Dictionary = {}

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

const SERVICE_DATE_YEAR: int = 2026
const SERVICE_DATE_LAST_MONTH: int = 12
const SERVICE_DATE_LAST_DAY: int = 27
const MONTH_ABBREVIATIONS: Array[String] = [
	"JAN", "FEB", "MAR", "APR", "MAY", "JUN",
	"JUL", "AUG", "SEP", "OCT", "NOV", "DEC",
]


func create_daily_service(day: int, shift_seed: int) -> DailyManifestConfig:
	var daily := duplicate(true) as DailyManifestConfig
	daily.deceased_passenger_count = get_night_anomaly_count(day)
	var service_rng := RandomNumberGenerator.new()
	service_rng.seed = ("train:%d:day:%d" % [shift_seed, day]).hash()
	var codes: PackedStringArray = service_train_codes.duplicate()
	if codes.is_empty():
		codes.append(service_train_number.strip_edges())
	var picked_code: String = codes[service_rng.randi_range(0, codes.size() - 1)].strip_edges()
	daily.service_train_number = picked_code if not picked_code.is_empty() else "ATE-000"
	daily.randomize_service_date(shift_seed)
	return daily


## Picks the campaign service date deterministically from the shift seed, so
## every New Game lands on a different 2026 date while Continue restores the
## same one. The ticket day code (YYMMDD) always matches the picked date.
func randomize_service_date(shift_seed: int) -> void:
	var date_rng := RandomNumberGenerator.new()
	date_rng.seed = ("service-date:%d" % shift_seed).hash()
	var noon := {"hour": 12, "minute": 0, "second": 0}
	var first_day: Dictionary = {"year": SERVICE_DATE_YEAR, "month": 1, "day": 1}
	first_day.merge(noon)
	var last_day: Dictionary = {
		"year": SERVICE_DATE_YEAR, "month": SERVICE_DATE_LAST_MONTH, "day": SERVICE_DATE_LAST_DAY
	}
	last_day.merge(noon)
	var first_unix: float = Time.get_unix_time_from_datetime_dict(first_day)
	var last_unix: float = Time.get_unix_time_from_datetime_dict(last_day)
	var span_days: int = maxi(0, int((last_unix - first_unix) / 86400.0))
	var picked: Dictionary = Time.get_datetime_dict_from_unix_time(
		first_unix + float(date_rng.randi_range(0, span_days)) * 86400.0
	)
	service_date_text = format_service_date(int(picked["day"]), int(picked["month"]), int(picked["year"]))
	ticket_day_code = format_day_code(int(picked["day"]), int(picked["month"]), int(picked["year"]))


static func format_service_date(day: int, month: int, year: int) -> String:
	var month_name: String = MONTH_ABBREVIATIONS[clampi(month - 1, 0, 11)]
	return "%02d %s %04d" % [day, month_name, year]


static func format_day_code(day: int, month: int, year: int) -> String:
	return "%02d%02d%02d" % [year % 100, month, day]


static func parse_service_date(date_text: String) -> Dictionary:
	var parts: PackedStringArray = date_text.strip_edges().split(" ", false)
	if parts.size() != 3:
		return {}
	var month: int = MONTH_ABBREVIATIONS.find(parts[1].strip_edges().to_upper()) + 1
	if month <= 0 or not parts[0].is_valid_int() or not parts[2].is_valid_int():
		return {}
	return {"year": parts[2].to_int(), "month": month, "day": parts[0].to_int()}


## Neighboring wrong dates for the time-invalid-ticket anomaly: the day
## before, the day after, and the same date next year. Codes stay consistent
## with their printed dates.
func get_invalid_service_date_candidates() -> Array[Dictionary]:
	var active: Dictionary = parse_service_date(service_date_text)
	if active.is_empty():
		return []
	var noon := {"hour": 12, "minute": 0, "second": 0}
	var active_noon: Dictionary = active.duplicate()
	active_noon.merge(noon)
	var active_unix: float = Time.get_unix_time_from_datetime_dict(active_noon)
	var neighbors: Array[Dictionary] = [
		Time.get_datetime_dict_from_unix_time(active_unix - 86400.0),
		Time.get_datetime_dict_from_unix_time(active_unix + 86400.0),
		{"year": int(active["year"]) + 1, "month": int(active["month"]), "day": int(active["day"])},
	]
	var candidates: Array[Dictionary] = []
	for neighbor: Dictionary in neighbors:
		var day: int = int(neighbor.get("day", 0))
		var month: int = int(neighbor.get("month", 0))
		var year: int = int(neighbor.get("year", 0))
		if day <= 0 or month <= 0 or year <= 0:
			continue
		var day_code: String = format_day_code(day, month, year)
		var printed_date: String = format_service_date(day, month, year)
		if day_code == ticket_day_code.strip_edges():
			continue
		if printed_date.to_lower() == service_date_text.strip_edges().to_lower():
			continue
		candidates.append({"day_code": day_code, "printed_date": printed_date})
	return candidates


func get_night_anomaly_count(level: int) -> int:
	if night_anomaly_count_by_level.is_empty():
		return clampi(deceased_passenger_count, 1, 5)
	return clampi(
		night_anomaly_count_by_level[clampi(level - 1, 0, night_anomaly_count_by_level.size() - 1)],
		1,
		5
	)


func should_guarantee_newspaper_anomaly(level: int) -> bool:
	return guaranteed_newspaper_anomaly_level > 0 and level >= guaranteed_newspaper_anomaly_level


func get_maximum_onboard_passenger_count(day_number: int) -> int:
	if maximum_onboard_passenger_count_by_day.is_empty():
		return maximum_onboard_passenger_count
	return maxi(
		maximum_onboard_passenger_count_by_day[clampi(day_number - 1, 0, maximum_onboard_passenger_count_by_day.size() - 1)],
		initial_passenger_count
	)


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
