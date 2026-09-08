class_name DeparturePuzzleData
extends Resource
## Content for the night constellation and its Soul Records. The UI scene owns
## the graph layout; this resource builds a matching, solvable nightly case.

@export_category("Constellation")
@export var night_stations: PackedStringArray = PackedStringArray()
@export_multiline var clockwise_statement_template: String
@export_multiline var hub_statement_template: String
@export_multiline var endpoint_statement_template: String
@export_multiline var distance_statement_template: String
@export_multiline var single_passenger_statement: String

@export_category("Anomaly Language")
@export var anomaly_descriptor_by_type: Dictionary = {}
@export var anomaly_label_by_type: Dictionary = {}
@export var fallback_descriptor_template: String = "the %s"
@export var fallback_anomaly_label: String = "UNRESOLVED ANOMALY"
@export var duplicate_descriptor_template: String = "%s who worked as the %s"

@export_category("Soul Record Biography")
@export var biography_opening_by_occupation: Dictionary = {}
@export var anomaly_record_by_type: Dictionary = {}
@export var resonance_medium_by_occupation: Dictionary = {}
@export var generic_biography_opening: PackedStringArray = PackedStringArray()
@export var generic_anomaly_record: PackedStringArray = PackedStringArray()
@export var generic_resonance_medium: String
@export var resonance_closing_sentence: String

## Populated only on a duplicated runtime puzzle.
var statement_by_passenger: Dictionary = {}
var correct_passenger_by_station: Dictionary = {}
var biography_by_passenger: Dictionary = {}


func get_statement_for_passenger(passenger_name: String) -> String:
	return str(_case_insensitive_lookup(statement_by_passenger, passenger_name, "")).strip_edges()


func get_biography_for_passenger(passenger_name: String) -> Array:
	var record: Variant = _case_insensitive_lookup(biography_by_passenger, passenger_name, [])
	return (record as Array).duplicate(true) if record is Array else []


func get_anomaly_label(anomaly_type: String) -> String:
	return str(anomaly_label_by_type.get(anomaly_type, fallback_anomaly_label)).strip_edges()


func create_runtime(passengers: Array[PassengerData], rng: RandomNumberGenerator) -> DeparturePuzzleData:
	var runtime := duplicate(true) as DeparturePuzzleData
	runtime.resource_local_to_scene = true
	runtime.statement_by_passenger = {}
	runtime.correct_passenger_by_station = {}
	runtime.biography_by_passenger = {}
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

	var descriptors: PackedStringArray = runtime._build_unique_descriptors(ordered)
	var clues := PackedStringArray()
	if station_count == 1:
		clues.append(single_passenger_statement)
	elif station_count == 4:
		# Scene order: Vesperwick, Hollowcross, Bellhaven, Morrowfield.
		# The first three form the clockwise loop, Hollowcross is the hub,
		# and Morrowfield is the single-thread endpoint.
		clues.append(clockwise_statement_template % [
			runtime._sentence_case(descriptors[2]), descriptors[0]
		])
		clues.append(hub_statement_template % runtime._sentence_case(descriptors[1]))
		clues.append(endpoint_statement_template % runtime._sentence_case(descriptors[3]))
		clues.append(distance_statement_template % [descriptors[3], descriptors[2]])
	else:
		# Keep reduced debug rosters usable even though the authored UI presents
		# the complete four-node case.
		for index: int in range(station_count):
			clues.append("%s belongs at %s." % [
				runtime._sentence_case(descriptors[index]), runtime.night_stations[index]
			])

	_shuffle_strings(clues, rng)
	var statement_holders: Array[PassengerData] = passengers.duplicate()
	_shuffle_passengers(statement_holders, rng)
	for index: int in range(station_count):
		var holder: PassengerData = statement_holders[index]
		var statement: String = clues[index]
		runtime.statement_by_passenger[holder.short_name] = statement
		runtime.biography_by_passenger[holder.short_name] = runtime._compose_biography(holder, statement)
	return runtime


func _compose_biography(data: PassengerData, statement: String) -> Array:
	var occupation_key: String = data.occupation.strip_edges().to_lower()
	var opening: Variant = biography_opening_by_occupation.get(occupation_key, generic_biography_opening)
	var anomaly_record: Variant = anomaly_record_by_type.get(data.anomaly_type, generic_anomaly_record)
	var medium_template: String = str(resonance_medium_by_occupation.get(
		occupation_key,
		generic_resonance_medium
	))
	var paragraphs: Array = []
	paragraphs.append(_format_sentence_list(opening, data))
	paragraphs.append(_format_sentence_list(anomaly_record, data))
	paragraphs.append(PackedStringArray([
		_format_biography_sentence(medium_template, data),
		statement,
		_format_biography_sentence(resonance_closing_sentence, data),
	]))
	return paragraphs


func _format_sentence_list(value: Variant, data: PassengerData) -> PackedStringArray:
	var result := PackedStringArray()
	if value is PackedStringArray:
		for sentence: String in value:
			result.append(_format_biography_sentence(sentence, data))
	elif value is Array:
		for sentence: Variant in value:
			result.append(_format_biography_sentence(str(sentence), data))
	return result


func _format_biography_sentence(template: String, data: PassengerData) -> String:
	return template \
		.replace("{name}", data.short_name) \
		.replace("{occupation}", data.occupation.to_lower()) \
		.replace("{origin}", data.origin_station) \
		.replace("{destination}", data.destination_station) \
		.replace("{ticket_date}", data.ticket_service_date) \
		.replace("{portrait_owner}", data.id_photo_owner)


func _build_unique_descriptors(passengers: Array[PassengerData]) -> PackedStringArray:
	var raw_descriptors := PackedStringArray()
	var descriptor_counts: Dictionary = {}
	for data: PassengerData in passengers:
		var descriptor: String = str(anomaly_descriptor_by_type.get(
			data.anomaly_type,
			fallback_descriptor_template % data.occupation.to_lower()
		)).strip_edges()
		raw_descriptors.append(descriptor)
		descriptor_counts[descriptor] = int(descriptor_counts.get(descriptor, 0)) + 1
	var result := PackedStringArray()
	for index: int in range(passengers.size()):
		var descriptor: String = raw_descriptors[index]
		if int(descriptor_counts.get(descriptor, 0)) > 1:
			descriptor = duplicate_descriptor_template % [descriptor, passengers[index].occupation.to_lower()]
		result.append(descriptor)
	return result


func _sentence_case(value: String) -> String:
	if value.is_empty():
		return value
	return value.left(1).to_upper() + value.substr(1)


func _case_insensitive_lookup(source: Dictionary, requested_key: String, fallback: Variant) -> Variant:
	var normalized_name: String = requested_key.strip_edges().to_lower()
	for configured_name: Variant in source:
		if str(configured_name).strip_edges().to_lower() == normalized_name:
			return source[configured_name]
	return fallback


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
