class_name DailyManifestGenerator
extends RefCounted
## Builds a fresh runtime manifest from immutable passenger profile resources.

static func generate(
	identity_profiles: Array[PassengerIdentityProfile],
	route: PackedStringArray,
	config: DailyManifestConfig,
	rng: RandomNumberGenerator,
	include_matching_newspaper_case: bool
) -> Array[PassengerData]:
	var generated_manifest: Array[PassengerData] = []
	if config == null or route.size() < 2:
		push_error("Daily manifest generation requires a config and at least two day stations.")
		return generated_manifest

	var passengers: Array[PassengerData] = _create_runtime_passengers(identity_profiles, config, rng)
	_shuffle_passengers(passengers, rng)

	var intermediate_stop_count: int = maxi(0, route.size() - 2)
	var scheduled_count: int = config.total_passenger_count
	if scheduled_count < config.initial_passenger_count:
		push_error("Total passenger count cannot be lower than the initial onboard count.")
		return generated_manifest
	if intermediate_stop_count == 0 and scheduled_count != config.initial_passenger_count:
		push_error("A route without intermediate stations cannot schedule later boarders.")
		return generated_manifest
	var boarding_counts: PackedInt32Array = _distribute_intermediate_boarders(
		scheduled_count - config.initial_passenger_count,
		intermediate_stop_count
	)
	if passengers.size() < scheduled_count:
		push_error("Daily manifest needs %d passenger profiles but only %d are configured." % [scheduled_count, passengers.size()])
		return generated_manifest
	if config.deceased_passenger_count > scheduled_count:
		push_error("Deceased passenger count cannot exceed the generated day roster.")
		return generated_manifest

	_reset_runtime_fields(passengers, route, config, rng)
	_assign_boarding_schedule(passengers, route, config, boarding_counts)
	if config.balance_boarding_groups_across_carriages:
		_assign_balanced_boarding_carriages(passengers, scheduled_count, route, config, rng)
	var deceased: Array[PassengerData] = _select_deceased(passengers, scheduled_count, config, rng)
	_assign_living_destinations(passengers, scheduled_count, route, boarding_counts, rng)
	if not _assign_deceased_anomalies(
		deceased,
		passengers,
		scheduled_count,
		route,
		config,
		rng,
		include_matching_newspaper_case
	):
		return generated_manifest
	if not _assign_wrong_train_boarders(passengers, scheduled_count, route, config, rng):
		return generated_manifest
	if not _validate_distinct_origins_and_destinations(passengers, scheduled_count):
		return generated_manifest
	_assign_ticket_numbers(passengers, scheduled_count, config)

	for index: int in range(scheduled_count):
		generated_manifest.append(passengers[index])
	return generated_manifest

static func _create_runtime_passengers(
	identity_profiles: Array[PassengerIdentityProfile],
	config: DailyManifestConfig,
	rng: RandomNumberGenerator
) -> Array[PassengerData]:
	var passengers: Array[PassengerData] = []
	var combined_names: PackedStringArray = config.get_all_passenger_names()
	if combined_names.size() < config.minimum_unique_name_count:
		push_error(
			"Passenger name pool needs at least %d unique names; configured %d."
			% [config.minimum_unique_name_count, combined_names.size()]
		)
		return passengers
	var used_names: Dictionary = {}
	var female_names: PackedStringArray = _prepare_name_pool(config.female_passenger_names, used_names)
	var male_names: PackedStringArray = _prepare_name_pool(config.male_passenger_names, used_names)
	_shuffle_strings(female_names, rng)
	_shuffle_strings(male_names, rng)
	var female_profile_count: int = 0
	var male_profile_count: int = 0
	for profile: PassengerIdentityProfile in identity_profiles:
		if profile == null:
			continue
		if profile.gender == PassengerIdentityProfile.Gender.FEMALE:
			female_profile_count += 1
		else:
			male_profile_count += 1
	if female_names.size() < female_profile_count or male_names.size() < male_profile_count:
		push_error(
			"Passenger name pools need %d female and %d male unique names; configured %d and %d."
			% [female_profile_count, male_profile_count, female_names.size(), male_names.size()]
		)
		return passengers
	var female_name_index: int = 0
	var male_name_index: int = 0
	for profile: PassengerIdentityProfile in identity_profiles:
		if profile == null or not profile.is_valid_identity():
			push_warning("Daily manifest skipped an invalid passenger identity profile.")
			continue
		var runtime_data: PassengerData = PassengerData.create_from_identity(profile)
		if runtime_data == null:
			continue
		var assigned_name: String
		if profile.gender == PassengerIdentityProfile.Gender.FEMALE:
			assigned_name = female_names[female_name_index]
			female_name_index += 1
		else:
			assigned_name = male_names[male_name_index]
			male_name_index += 1
		runtime_data.passenger_name = assigned_name
		runtime_data.short_name = assigned_name
		passengers.append(runtime_data)
	return passengers


static func _prepare_name_pool(configured_names: PackedStringArray, used_names: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for configured_name: String in configured_names:
		var cleaned_name: String = configured_name.strip_edges()
		var normalized_name: String = cleaned_name.to_lower()
		if cleaned_name.is_empty() or used_names.has(normalized_name):
			continue
		used_names[normalized_name] = true
		result.append(cleaned_name)
	return result

static func _reset_runtime_fields(passengers: Array[PassengerData], route: PackedStringArray, config: DailyManifestConfig, rng: RandomNumberGenerator) -> void:
	for data: PassengerData in passengers:
		data.age = data.identity_profile.age
		data.id_photo = data.identity_profile.id_photo
		data.id_photo_owner = data.passenger_name
		data.origin_station = route[-1]
		data.destination_station = route[-1]
		data.ticket_owner = data.short_name
		data.ticket_number = ""
		data.ticket_train_number = config.service_train_number.strip_edges()
		data.ticket_service_date = config.service_date_text.strip_edges()
		data.ticket_day_code = config.ticket_day_code.strip_edges()
		data.ticket_issue_type = PassengerData.TICKET_ISSUE_NONE
		data.required_dropoff_station = ""
		data.is_dead = false
		data.anomaly_type = "none"
		data.current_carriage = rng.randi_range(1, config.passenger_carriage_count)
		data.initially_on_train = false
		data.ai_behavior = _pick_string(config.ai_behaviors, rng, "still")
		data.ai_interval_seconds = rng.randf_range(
			minf(config.minimum_ai_interval_seconds, config.maximum_ai_interval_seconds),
			maxf(config.minimum_ai_interval_seconds, config.maximum_ai_interval_seconds)
		)

static func _assign_boarding_schedule(
	passengers: Array[PassengerData],
	route: PackedStringArray,
	config: DailyManifestConfig,
	boarding_counts: PackedInt32Array
) -> void:
	for index: int in range(config.initial_passenger_count):
		passengers[index].origin_station = route[0]
		passengers[index].initially_on_train = true
	var cursor: int = config.initial_passenger_count
	for station_index: int in range(1, route.size() - 1):
		var station_boarder_count: int = boarding_counts[station_index - 1]
		for _boarder: int in range(station_boarder_count):
			passengers[cursor].origin_station = route[station_index]
			cursor += 1


static func _assign_balanced_boarding_carriages(
	passengers: Array[PassengerData],
	scheduled_count: int,
	route: PackedStringArray,
	config: DailyManifestConfig,
	rng: RandomNumberGenerator
) -> void:
	var carriage_count: int = maxi(config.passenger_carriage_count, 1)
	for station_index: int in range(route.size() - 1):
		var boarding_group: Array[PassengerData] = []
		for passenger_index: int in range(scheduled_count):
			var data: PassengerData = passengers[passenger_index]
			if data.origin_station == route[station_index]:
				boarding_group.append(data)
		if boarding_group.is_empty():
			continue
		var carriage_order: Array[int] = []
		for carriage: int in range(1, carriage_count + 1):
			carriage_order.append(carriage)
		for group_index: int in range(boarding_group.size()):
			if group_index % carriage_count == 0:
				_shuffle_ints(carriage_order, rng)
			boarding_group[group_index].current_carriage = carriage_order[group_index % carriage_count]

static func _select_deceased(
	passengers: Array[PassengerData],
	scheduled_count: int,
	config: DailyManifestConfig,
	rng: RandomNumberGenerator
) -> Array[PassengerData]:
	var selected_indices: Array[int] = []
	var initial_indices: Array[int] = []
	for index: int in range(config.initial_passenger_count):
		initial_indices.append(index)
	_shuffle_ints(initial_indices, rng)
	var guaranteed_initial_count: int = mini(
		config.deceased_passenger_count,
		mini(config.minimum_initial_deceased, initial_indices.size())
	)
	for index: int in range(guaranteed_initial_count):
		selected_indices.append(initial_indices[index])

	var remaining_indices: Array[int] = []
	for index: int in range(scheduled_count):
		if not selected_indices.has(index):
			remaining_indices.append(index)
	_shuffle_ints(remaining_indices, rng)
	while selected_indices.size() < config.deceased_passenger_count and not remaining_indices.is_empty():
		selected_indices.append(remaining_indices.pop_back())

	var deceased: Array[PassengerData] = []
	for index: int in selected_indices:
		passengers[index].is_dead = true
		deceased.append(passengers[index])
	_shuffle_passengers(deceased, rng)
	return deceased

static func _assign_living_destinations(
	passengers: Array[PassengerData],
	scheduled_count: int,
	route: PackedStringArray,
	boarding_counts: PackedInt32Array,
	rng: RandomNumberGenerator
) -> void:
	var assigned: Dictionary = {}
	for destination_index: int in range(1, route.size() - 1):
		var station_dropoff_count: int = boarding_counts[destination_index - 1]
		var eligible: Array[PassengerData] = []
		for index: int in range(scheduled_count):
			var data: PassengerData = passengers[index]
			if data.is_dead or assigned.has(data):
				continue
			var origin_index: int = route.find(data.origin_station)
			if origin_index >= 0 and origin_index < destination_index:
				eligible.append(data)
		_shuffle_passengers(eligible, rng)
		if eligible.size() < station_dropoff_count:
			push_error("Not enough living passengers can be assigned to %s." % route[destination_index])
			continue
		for assignment_index: int in range(station_dropoff_count):
			var assigned_data: PassengerData = eligible[assignment_index]
			assigned_data.destination_station = route[destination_index]
			assigned[assigned_data] = true

	for index: int in range(scheduled_count):
		var data: PassengerData = passengers[index]
		if not data.is_dead and not assigned.has(data):
			data.destination_station = route[-1]

static func _distribute_intermediate_boarders(total_boarders: int, intermediate_stop_count: int) -> PackedInt32Array:
	var boarding_counts := PackedInt32Array()
	if intermediate_stop_count <= 0:
		return boarding_counts
	var even_count: int = floori(float(total_boarders) / float(intermediate_stop_count))
	var remainder: int = total_boarders % intermediate_stop_count
	for station_offset: int in range(intermediate_stop_count):
		boarding_counts.append(even_count + (1 if station_offset < remainder else 0))
	return boarding_counts

static func _assign_wrong_train_boarders(
	passengers: Array[PassengerData],
	scheduled_count: int,
	route: PackedStringArray,
	config: DailyManifestConfig,
	rng: RandomNumberGenerator
) -> bool:
	if config.wrong_train_boarder_count <= 0:
		return true
	var service_train_number: String = config.service_train_number.strip_edges()
	if service_train_number.is_empty():
		push_error("Daily Manifest Config/Service Train Number cannot be empty.")
		return false
	var alternate_numbers := PackedStringArray()
	for configured_number: String in config.alternate_train_numbers:
		var cleaned_number: String = configured_number.strip_edges()
		if not cleaned_number.is_empty() and cleaned_number != service_train_number and not alternate_numbers.has(cleaned_number):
			alternate_numbers.append(cleaned_number)
	if alternate_numbers.is_empty():
		push_error("Wrong-train boarders require at least one alternate train number different from the active service.")
		return false

	var reserved_passengers: Dictionary = {}
	for _case_index: int in range(config.wrong_train_boarder_count):
		var candidates: Array[PassengerData] = []
		for index: int in range(scheduled_count):
			var candidate: PassengerData = passengers[index]
			if candidate.is_dead or reserved_passengers.has(candidate):
				continue
			var origin_index: int = route.find(candidate.origin_station)
			var destination_index: int = route.find(candidate.destination_station)
			if origin_index < 0 or origin_index + 1 >= route.size() or destination_index <= origin_index + 1:
				continue
			var immediate_station: String = route[origin_index + 1]
			if _find_dropoff_swap_candidate(passengers, scheduled_count, candidate, immediate_station, reserved_passengers) != null:
				candidates.append(candidate)
		if candidates.is_empty():
			push_error("The manifest cannot place %d wrong-train boarder case(s) without breaking station exchange counts." % config.wrong_train_boarder_count)
			return false
		_shuffle_passengers(candidates, rng)
		var wrong_train_data: PassengerData = candidates[0]
		var wrong_origin_index: int = route.find(wrong_train_data.origin_station)
		var required_station: String = route[wrong_origin_index + 1]
		var swap_candidate: PassengerData = _find_dropoff_swap_candidate(
			passengers,
			scheduled_count,
			wrong_train_data,
			required_station,
			reserved_passengers
		)
		if swap_candidate == null:
			push_error("Wrong-train boarder generation lost its station-exchange swap candidate.")
			return false
		swap_candidate.destination_station = wrong_train_data.destination_station
		wrong_train_data.ticket_issue_type = PassengerData.TICKET_ISSUE_WRONG_TRAIN_BOARDER
		wrong_train_data.ticket_train_number = alternate_numbers[rng.randi_range(0, alternate_numbers.size() - 1)]
		wrong_train_data.required_dropoff_station = required_station
		reserved_passengers[wrong_train_data] = true
		reserved_passengers[swap_candidate] = true
	return true

static func _find_dropoff_swap_candidate(
	passengers: Array[PassengerData],
	scheduled_count: int,
	wrong_train_candidate: PassengerData,
	required_station: String,
	reserved_passengers: Dictionary
) -> PassengerData:
	for index: int in range(scheduled_count):
		var candidate: PassengerData = passengers[index]
		if candidate == wrong_train_candidate or candidate.is_dead or reserved_passengers.has(candidate):
			continue
		if candidate.destination_station == required_station:
			return candidate
	return null

static func _assign_ticket_numbers(passengers: Array[PassengerData], scheduled_count: int, config: DailyManifestConfig) -> void:
	for index: int in range(scheduled_count):
		var data: PassengerData = passengers[index]
		var day_code: String = data.ticket_day_code.strip_edges()
		if day_code.is_empty():
			day_code = config.ticket_day_code.strip_edges()
		if day_code.is_empty():
			day_code = "000000"
		data.ticket_number = "%s-%s-%04d" % [day_code, data.ticket_train_number, index + 1]

static func _assign_deceased_anomalies(
	deceased: Array[PassengerData],
	passengers: Array[PassengerData],
	scheduled_count: int,
	route: PackedStringArray,
	config: DailyManifestConfig,
	rng: RandomNumberGenerator,
	include_matching_newspaper_case: bool
) -> bool:
	var selected_anomalies: PackedStringArray = _select_anomaly_types(config, deceased.size(), rng, include_matching_newspaper_case)
	if selected_anomalies.size() < deceased.size():
		push_error("The anomaly pool cannot provide evidence for every deceased passenger.")
		return false
	if include_matching_newspaper_case:
		var newspaper_type: String = String(config.newspaper_anomaly_type)
		var newspaper_index: int = selected_anomalies.find(newspaper_type)
		var initial_deceased_index: int = -1
		for index: int in range(deceased.size()):
			if deceased[index].initially_on_train:
				initial_deceased_index = index
				break
		if newspaper_index >= 0 and initial_deceased_index >= 0 and newspaper_index != initial_deceased_index:
			var held_anomaly: String = selected_anomalies[initial_deceased_index]
			selected_anomalies[initial_deceased_index] = selected_anomalies[newspaper_index]
			selected_anomalies[newspaper_index] = held_anomaly
	if not _make_impossible_tickets_route_compatible(
		selected_anomalies,
		deceased,
		route,
		config,
		rng,
		include_matching_newspaper_case
	):
		return false
	for index: int in range(deceased.size()):
		var data: PassengerData = deceased[index]
		var origin_index: int = maxi(0, route.find(data.origin_station))
		data.destination_station = route[rng.randi_range(mini(origin_index + 1, route.size() - 1), route.size() - 1)]
		data.anomaly_type = selected_anomalies[index]
		match data.anomaly_type:
			"impossible_ticket":
				if origin_index <= 0:
					push_error("Impossible-ticket anomalies require a boarding station after the first route stop.")
					return false
				data.destination_station = route[rng.randi_range(0, origin_index - 1)]
			"unlisted_destination":
				data.destination_station = _pick_unlisted_destination(config.unlisted_destination_names, route, rng)
			"portrait_mismatch":
				if not _assign_mismatched_portrait(data, passengers, scheduled_count, rng):
					return false
			"time_invalid_ticket":
				if not _assign_invalid_ticket_date(data, config, rng):
					return false
	return true


static func _assign_mismatched_portrait(
	data: PassengerData,
	passengers: Array[PassengerData],
	scheduled_count: int,
	rng: RandomNumberGenerator
) -> bool:
	var candidates: Array[PassengerData] = []
	for index: int in range(scheduled_count):
		var candidate: PassengerData = passengers[index]
		if candidate == data or candidate.identity_profile == null:
			continue
		var candidate_photo: Texture2D = candidate.identity_profile.id_photo
		if candidate_photo == null or candidate_photo == data.identity_profile.id_photo:
			continue
		candidates.append(candidate)
	if candidates.is_empty():
		push_error("Portrait-mismatch anomalies require another passenger with a distinct ID photo.")
		return false
	var portrait_owner: PassengerData = candidates[rng.randi_range(0, candidates.size() - 1)]
	data.id_photo = portrait_owner.identity_profile.id_photo
	data.id_photo_owner = portrait_owner.passenger_name
	return true


static func _assign_invalid_ticket_date(
	data: PassengerData,
	config: DailyManifestConfig,
	rng: RandomNumberGenerator
) -> bool:
	var candidates: Array[Dictionary] = []
	var active_code: String = config.ticket_day_code.strip_edges()
	var active_date: String = config.service_date_text.strip_edges()
	for configured_code: Variant in config.invalid_service_dates_by_day_code.keys():
		var day_code: String = str(configured_code).strip_edges()
		var printed_date: String = str(config.invalid_service_dates_by_day_code[configured_code]).strip_edges()
		if day_code.is_empty() or printed_date.is_empty():
			continue
		if day_code == active_code or printed_date.to_lower() == active_date.to_lower():
			continue
		candidates.append({"day_code": day_code, "printed_date": printed_date})
	if candidates.is_empty():
		push_error("Time-invalid-ticket anomalies require at least one alternate service date and day code.")
		return false
	var selected: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	data.ticket_day_code = str(selected["day_code"])
	data.ticket_service_date = str(selected["printed_date"])
	return true


static func _make_impossible_tickets_route_compatible(
	selected_anomalies: PackedStringArray,
	deceased: Array[PassengerData],
	route: PackedStringArray,
	config: DailyManifestConfig,
	rng: RandomNumberGenerator,
	include_matching_newspaper_case: bool
) -> bool:
	for anomaly_index: int in range(selected_anomalies.size()):
		if selected_anomalies[anomaly_index] != "impossible_ticket":
			continue
		if route.find(deceased[anomaly_index].origin_station) > 0:
			continue
		var swap_index: int = -1
		for candidate_index: int in range(selected_anomalies.size()):
			if selected_anomalies[candidate_index] == "impossible_ticket":
				continue
			if route.find(deceased[candidate_index].origin_station) > 0:
				swap_index = candidate_index
				break
		if swap_index >= 0:
			var held_anomaly: String = selected_anomalies[anomaly_index]
			selected_anomalies[anomaly_index] = selected_anomalies[swap_index]
			selected_anomalies[swap_index] = held_anomaly
			continue
		var replacement: String = _pick_compatible_anomaly_replacement(
			selected_anomalies,
			config,
			rng,
			include_matching_newspaper_case
		)
		if replacement.is_empty():
			push_error("No compatible anomaly trait is available to replace an impossible ticket at the first station.")
			return false
		selected_anomalies[anomaly_index] = replacement
	return true


static func _pick_compatible_anomaly_replacement(
	selected_anomalies: PackedStringArray,
	config: DailyManifestConfig,
	rng: RandomNumberGenerator,
	include_matching_newspaper_case: bool
) -> String:
	var trait_counts: Dictionary = {}
	for selected: String in selected_anomalies:
		trait_counts[selected] = int(trait_counts.get(selected, 0)) + 1
	# The incompatible impossible-ticket slot is about to be replaced.
	trait_counts["impossible_ticket"] = maxi(0, int(trait_counts.get("impossible_ticket", 0)) - 1)
	var candidates := PackedStringArray()
	for anomaly_type: String in config.anomaly_types:
		if anomaly_type == "impossible_ticket" or anomaly_type == String(config.newspaper_anomaly_type):
			continue
		if int(trait_counts.get(anomaly_type, 0)) >= config.max_passengers_per_anomaly_trait:
			continue
		candidates.append(anomaly_type)
	if candidates.is_empty() and include_matching_newspaper_case:
		var newspaper_type: String = String(config.newspaper_anomaly_type)
		if int(trait_counts.get(newspaper_type, 0)) < config.max_passengers_per_anomaly_trait:
			candidates.append(newspaper_type)
	if candidates.is_empty():
		return ""
	return candidates[rng.randi_range(0, candidates.size() - 1)]


static func _validate_distinct_origins_and_destinations(
	passengers: Array[PassengerData],
	scheduled_count: int
) -> bool:
	for index: int in range(scheduled_count):
		var data: PassengerData = passengers[index]
		if data.origin_station == data.destination_station:
			push_error(
				"Passenger %s cannot board and have a destination at the same station (%s)."
				% [data.passenger_name, data.origin_station]
			)
			return false
	return true

static func _select_anomaly_types(
	config: DailyManifestConfig,
	count: int,
	rng: RandomNumberGenerator,
	include_matching_newspaper_case: bool
) -> PackedStringArray:
	var pool := PackedStringArray()
	var newspaper_type: String = String(config.newspaper_anomaly_type)
	for anomaly_type: String in config.anomaly_types:
		if anomaly_type == newspaper_type:
			continue
		if not pool.has(anomaly_type):
			pool.append(anomaly_type)
	_shuffle_strings(pool, rng)
	var selected := PackedStringArray()
	if include_matching_newspaper_case and config.anomaly_types.has(newspaper_type) and count > 0:
		selected.append(newspaper_type)
	while selected.size() < count and not pool.is_empty():
		selected.append(pool[0])
		pool.remove_at(0)
	var reusable: PackedStringArray = config.anomaly_types.duplicate()
	if not include_matching_newspaper_case and reusable.has(newspaper_type):
		reusable.remove_at(reusable.find(newspaper_type))
	_shuffle_strings(reusable, rng)
	var trait_counts: Dictionary = {}
	for anomaly_type: String in selected:
		trait_counts[anomaly_type] = int(trait_counts.get(anomaly_type, 0)) + 1
	for anomaly_type: String in reusable:
		if selected.size() >= count:
			break
		if int(trait_counts.get(anomaly_type, 0)) >= config.max_passengers_per_anomaly_trait:
			continue
		selected.append(anomaly_type)
		trait_counts[anomaly_type] = int(trait_counts.get(anomaly_type, 0)) + 1
	_shuffle_strings(selected, rng)
	return selected

static func _pick_unlisted_destination(names: PackedStringArray, route: PackedStringArray, rng: RandomNumberGenerator) -> String:
	var candidates := PackedStringArray()
	for destination_name: String in names:
		if not destination_name.is_empty() and not route.has(destination_name):
			candidates.append(destination_name)
	if candidates.is_empty():
		push_error("Daily manifest config needs at least one destination outside the day route.")
		return route[-1]
	return candidates[rng.randi_range(0, candidates.size() - 1)]

static func _pick_string(values: PackedStringArray, rng: RandomNumberGenerator, fallback: String) -> String:
	if values.is_empty():
		return fallback
	return values[rng.randi_range(0, values.size() - 1)]

static func _shuffle_passengers(values: Array[PassengerData], rng: RandomNumberGenerator) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var held: PassengerData = values[index]
		values[index] = values[swap_index]
		values[swap_index] = held

static func _shuffle_ints(values: Array[int], rng: RandomNumberGenerator) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var held: int = values[index]
		values[index] = values[swap_index]
		values[swap_index] = held

static func _shuffle_strings(values: PackedStringArray, rng: RandomNumberGenerator) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var held: String = values[index]
		values[index] = values[swap_index]
		values[swap_index] = held
