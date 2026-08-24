class_name DeparturePuzzleData
extends Resource
## Inspector-authored night route and generic clue language; runtime mappings are generated per shift.

@export var night_stations: PackedStringArray = PackedStringArray()
@export_category("Runtime Clue Language")
@export var anomaly_descriptor_by_type: Dictionary = {}
@export var fallback_descriptor_template: String = "the %s"
@export var duplicate_descriptor_template: String = "%s who worked as the %s"
@export_multiline var immediately_before_template: String
@export_multiline var before_template: String
@export_multiline var single_passenger_statement: String

## Populated only on a duplicated runtime puzzle.
@export var statement_by_passenger: Dictionary = {}
@export var correct_passenger_by_station: Dictionary = {}

func get_statement_for_passenger(passenger_name: String) -> String:
	var normalized_name: String = passenger_name.strip_edges().to_lower()
	for configured_name: Variant in statement_by_passenger:
		if str(configured_name).strip_edges().to_lower() == normalized_name:
			return str(statement_by_passenger[configured_name]).strip_edges()
	return ""

func create_runtime(passengers: Array[PassengerData], rng: RandomNumberGenerator) -> DeparturePuzzleData:
	var runtime := duplicate(true) as DeparturePuzzleData
	runtime.resource_local_to_scene = true
	runtime.statement_by_passenger = {}
	runtime.correct_passenger_by_station = {}
	var station_count: int = mini(passengers.size(), night_stations.size())
	var runtime_stations := PackedStringArray()
	for index: int in range(station_count):
		runtime_stations.append(night_stations[index])
	runtime.night_stations = runtime_stations
	if station_count == 0:
		return runtime

	var ordered: Array[PassengerData] = passengers.duplicate()
	_shuffle_passengers(ordered, rng)
	for index: int in range(station_count):
		runtime.correct_passenger_by_station[runtime.night_stations[index]] = ordered[index].short_name

	var descriptors: PackedStringArray = _build_unique_descriptors(ordered)
	var clues := PackedStringArray()
	if station_count == 1:
		clues.append(single_passenger_statement)
	else:
		for index: int in range(station_count - 1):
			clues.append(immediately_before_template % [descriptors[index], descriptors[index + 1]])
		while clues.size() < station_count:
			clues.append(before_template % [descriptors[0], descriptors[station_count - 1]])
	_shuffle_strings(clues, rng)
	var statement_holders: Array[PassengerData] = passengers.duplicate()
	_shuffle_passengers(statement_holders, rng)
	for index: int in range(station_count):
		runtime.statement_by_passenger[statement_holders[index].short_name] = clues[index]
	return runtime

func _build_unique_descriptors(passengers: Array[PassengerData]) -> PackedStringArray:
	var raw_descriptors := PackedStringArray()
	var descriptor_counts: Dictionary = {}
	for data: PassengerData in passengers:
		var descriptor: String = str(anomaly_descriptor_by_type.get(data.anomaly_type, fallback_descriptor_template % data.occupation.to_lower()))
		raw_descriptors.append(descriptor)
		descriptor_counts[descriptor] = int(descriptor_counts.get(descriptor, 0)) + 1
	var result := PackedStringArray()
	for index: int in range(passengers.size()):
		var descriptor: String = raw_descriptors[index]
		if int(descriptor_counts.get(descriptor, 0)) > 1:
			descriptor = duplicate_descriptor_template % [descriptor, passengers[index].occupation.to_lower()]
		result.append(descriptor)
	return result

func _shuffle_passengers(values: Array[PassengerData], rng: RandomNumberGenerator) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var held: PassengerData = values[index]
		values[index] = values[swap_index]
		values[swap_index] = held

func _shuffle_strings(values: PackedStringArray, rng: RandomNumberGenerator) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var held: String = values[index]
		values[index] = values[swap_index]
		values[swap_index] = held
