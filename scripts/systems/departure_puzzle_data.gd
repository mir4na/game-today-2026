class_name DeparturePuzzleData
extends Resource
## Content for the night station path and its Soul Records. The UI scene owns
## the graph layout; this resource builds a matching, solvable nightly case.

@export_category("Station Path")
@export var night_stations: PackedStringArray = PackedStringArray()
@export var station_path_layout_scenes: Array[PackedScene] = []
@export_multiline var clockwise_statement_template: String
@export_multiline var hub_statement_template: String
@export_multiline var endpoint_statement_template: String
@export_multiline var distance_statement_template: String
@export_multiline var single_passenger_statement: String
@export_multiline var veil_note_statement_template: String = "%s and %s belong at stations joined by one line."
@export_multiline var veil_note_distance_statement_template: String = "%s and %s are separated by %s."
@export_multiline var veil_note_direct_statement_template: String = "%s belongs at %s."
@export_multiline var veil_note_shared_station_template: String = "%s and %s share %s."

@export_category("Five-Level Progression")
@export_multiline var direct_station_statement_template: String = "%s belongs at %s."
@export_multiline var between_statement_template: String = "%s rests between %s and %s, with one line reaching each."
@export_multiline var outside_loop_statement_template: String = "%s rests beyond the only closed loop."
@export_multiline var linked_pair_statement_template: String = "%s shares one line with both %s and %s."
@export_multiline var path_through_statement_template: String = "The shortest path from %s to %s passes through %s."
@export_multiline var highest_mark_statement_template: String = "%s rests at the highest station mark."
@export_multiline var lowest_mark_statement_template: String = "%s rests at the lowest station mark."
@export_multiline var opposite_mark_statement_template: String = "%s rests opposite %s on the station path."
@export_multiline var same_station_statement_template: String = "%s and %s rest at the same station."
@export_multiline var shared_station_link_statement_template: String = "The station shared by %s and %s is joined directly to %s."
@export_multiline var shared_station_counterclockwise_statement_template: String = "The station shared by %s and %s is one mark counterclockwise from %s."

@export_category("Anomaly Language")
@export var anomaly_descriptor_by_type: Dictionary = {}
@export var anomaly_label_by_type: Dictionary = {}
@export var fallback_descriptor_template: String = "the %s"
@export var fallback_anomaly_label: String = "UNRESOLVED ANOMALY"
@export var duplicate_descriptor_template: String = "%s who worked as the %s"
@export var occupation_descriptor_template: String = "the %s"
@export var duplicate_occupation_descriptor_template: String = "%s, the %s"

@export_category("Soul Record Biography")
@export var biography_opening_by_occupation: Dictionary = {}
@export var anomaly_record_by_type: Dictionary = {}
@export var resonance_medium_by_occupation: Dictionary = {}
@export var generic_biography_opening: PackedStringArray = PackedStringArray()
@export var generic_anomaly_record: PackedStringArray = PackedStringArray()
@export var generic_resonance_medium: String
@export var resonance_closing_sentence: String
@export var biography_opening_support: PackedStringArray = PackedStringArray()
@export var biography_evidence_support: PackedStringArray = PackedStringArray()
@export var biography_veil_support: PackedStringArray = PackedStringArray()
@export var hidden_statement_context_by_paragraph: PackedStringArray = PackedStringArray([
	"An old note in {name}'s files reads: {statement}.",
	"Beside the copied evidence, {name} wrote: {statement}.",
	"Beyond the veil, {name}'s faded page reveals: {statement}.",
])
@export var hidden_statement_context_variants_by_paragraph: Array[PackedStringArray] = [
	PackedStringArray([
		"Among {name}'s surviving work notes is a line claiming that {statement}.",
		"A margin beside {name}'s unfinished work preserves the conclusion that {statement}.",
		"One detail recurs throughout {name}'s private records: {statement}.",
	]),
	PackedStringArray([
		"A pencilled conclusion beside {name}'s evidence insists that {statement}.",
		"The final annotation attached to {name}'s record suggests that {statement}.",
		"Pressed faintly beneath the official report is the claim that {statement}.",
	]),
	PackedStringArray([
		"As the carriage crosses the veil, the marks around {name}'s belongings settle around one certainty: {statement}.",
		"Under the night carriage lights, {name}'s unfinished pattern resolves and shows that {statement}.",
		"For a moment, the traces left with {name} align around the idea that {statement}.",
	]),
]
@export var hidden_statement_unique_contexts: PackedStringArray = PackedStringArray([
	"A loose timetable tucked into {name}'s belongings folds open on the words that {statement}.",
	"The underside of {name}'s oldest receipt carries a faint route note: {statement}.",
	"A torn corner from {name}'s case file darkens until it says that {statement}.",
	"A dry pencil line along {name}'s final page stops beside one sentence: {statement}.",
	"The last map scrap kept with {name} creases into a warning that {statement}.",
	"A lesson diagram in {name}'s recovered papers quietly resolves into the fact that {statement}.",
	"The ink around {name}'s ticket stamp gathers into a plain answer: {statement}.",
	"A narrow label sewn into {name}'s sleeve turns over by itself and shows that {statement}.",
	"The back of {name}'s platform token warms, then leaves the sentence: {statement}.",
	"A smudged station mark beside {name}'s name clears just long enough to show that {statement}.",
	"The pressed edge of {name}'s record book reveals one remaining instruction: {statement}.",
	"A cracked fold in {name}'s evidence sheet catches the carriage glow and states that {statement}.",
	"The final blank margin near {name}'s name fills with the conclusion that {statement}.",
	"A sealed note found under {name}'s seat opens to a single route fact: {statement}.",
	"The dust on {name}'s recovered parcel settles into a line saying that {statement}.",
	"A brass corner on {name}'s file turns cold and exposes the message that {statement}.",
	"The route pinholes around {name}'s papers connect into the sentence that {statement}.",
	"A water-stained annotation near {name}'s record becomes readable: {statement}.",
	"The final crease in {name}'s page points to the answer that {statement}.",
	"A hidden carbon copy beneath {name}'s form repeats one fact: {statement}.",
	"The station wax on {name}'s document splits and leaves behind the words that {statement}.",
	"A pale line inside {name}'s record frame writes itself as: {statement}.",
	"The last unchecked box in {name}'s ledger opens into the clue that {statement}.",
	"A torn route seal attached to {name}'s page settles around the phrase that {statement}.",
	"The recovered tag tied to {name}'s belongings twists until it reads that {statement}.",
])

## Populated only on a duplicated runtime puzzle.
var statement_by_passenger: Dictionary = {}
var correct_passenger_by_station: Dictionary = {}
var correct_station_by_passenger: Dictionary = {}
var biography_by_passenger: Dictionary = {}
var context_slot_by_passenger: Dictionary = {}
var clue_blocked_passengers_by_holder: Dictionary = {}
var veil_note_statement: String = ""
var service_level: int = 1


func get_statement_for_passenger(passenger_name: String) -> String:
	return str(_case_insensitive_lookup(statement_by_passenger, passenger_name, "")).strip_edges()


func get_biography_for_passenger(passenger_name: String) -> Array:
	var record: Variant = _case_insensitive_lookup(biography_by_passenger, passenger_name, [])
	return (record as Array).duplicate(true) if record is Array else []


func get_veil_note_statement() -> String:
	return veil_note_statement.strip_edges()


func get_anomaly_label(anomaly_type: String) -> String:
	return str(anomaly_label_by_type.get(anomaly_type, fallback_anomaly_label)).strip_edges()


func get_expected_passengers_for_station(station_name: String) -> Array[String]:
	var result: Array[String] = []
	for passenger_value: Variant in correct_station_by_passenger:
		var passenger_name: String = str(passenger_value)
		if str(correct_station_by_passenger[passenger_value]) == station_name:
			result.append(passenger_name)
	return result


func get_assignment_count() -> int:
	return correct_station_by_passenger.size()


func get_assignment_instruction() -> String:
	return "Drag each soul to a station."


func get_service_label() -> String:
	return "NIGHT SERVICE  •  LEVEL %d" % service_level


func get_route_edges() -> Array[Vector2i]:
	if service_level == 1:
		# The introductory path is a four-station chain with one empty
		# destination: Vesperwick - Hollowcross - Bellhaven - Morrowfield.
		return [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3)]
	var edges: Array[Vector2i] = [
		Vector2i(0, 1), # Vesperwick - Hollowcross
		Vector2i(1, 3), # Hollowcross - Morrowfield
		Vector2i(1, 2), # Hollowcross - Bellhaven
	]
	if service_level >= 3:
		edges.append(Vector2i(0, 2)) # Opens the first loop.
	if service_level >= 4:
		edges.append(Vector2i(2, 3)) # Opens a second loop.
	if service_level >= 5:
		edges.append(Vector2i(0, 3)) # Completes the interlinked final path.
	return edges


func get_station_path_layout_scene(level: int = service_level) -> PackedScene:
	if station_path_layout_scenes.is_empty():
		return null
	return station_path_layout_scenes[clampi(level - 1, 0, station_path_layout_scenes.size() - 1)]


func get_small_mark_distance(first_station: String, second_station: String) -> int:
	var layout: NightStationPathLayout = _instantiate_path_layout()
	if layout == null:
		return -1
	var distance: int = layout.get_small_mark_distance(first_station, second_station)
	layout.free()
	return distance


func get_path_segment_count() -> int:
	var layout: NightStationPathLayout = _instantiate_path_layout()
	if layout == null:
		return 0
	var count: int = layout.get_path_segments().size()
	layout.free()
	return count


func get_small_mark_count() -> int:
	var layout: NightStationPathLayout = _instantiate_path_layout()
	if layout == null:
		return 0
	var count: int = layout.get_path_markers().size()
	layout.free()
	return count


func _instantiate_path_layout() -> NightStationPathLayout:
	var layout_scene: PackedScene = get_station_path_layout_scene()
	if layout_scene == null:
		return null
	return layout_scene.instantiate() as NightStationPathLayout


func create_runtime(
	passengers: Array[PassengerData],
	rng: RandomNumberGenerator,
	requested_level: int = 0
) -> DeparturePuzzleData:
	var runtime := duplicate(true) as DeparturePuzzleData
	runtime.resource_local_to_scene = true
	runtime.statement_by_passenger = {}
	runtime.correct_passenger_by_station = {}
	runtime.correct_station_by_passenger = {}
	runtime.biography_by_passenger = {}
	runtime.context_slot_by_passenger = {}
	runtime.clue_blocked_passengers_by_holder = {}
	runtime.veil_note_statement = ""
	runtime.service_level = runtime._resolve_service_level(requested_level, passengers.size())
	runtime.night_stations = runtime._stations_for_level(runtime.service_level)
	if passengers.is_empty() or runtime.night_stations.is_empty():
		return runtime

	var ordered: Array[PassengerData] = passengers.duplicate()
	_shuffle_passengers(ordered, rng)
	var assignment_stations: PackedStringArray = runtime._assignment_stations_for_level(
		runtime.service_level,
		ordered.size()
	)
	for index: int in range(ordered.size()):
		var passenger_name: String = ordered[index].short_name
		var station_name: String = assignment_stations[index]
		runtime.correct_station_by_passenger[passenger_name] = station_name
		# Preserve the original one-passenger lookup for old content and tools. New
		# validation uses correct_station_by_passenger so Level 5 can stack souls.
		if not runtime.correct_passenger_by_station.has(station_name):
			runtime.correct_passenger_by_station[station_name] = passenger_name
	var descriptors: PackedStringArray = runtime._build_unique_descriptors(ordered)
	runtime.veil_note_statement = runtime._build_veil_note_statement(ordered, descriptors, rng)
	var clue_records: Array = runtime._build_progression_clue_records(descriptors, assignment_stations)

	runtime._shuffle_clue_records(clue_records, rng)
	var holder_assignments: PackedInt32Array = runtime._assign_statement_holders(clue_records, ordered.size())
	var paragraph_placements := PackedInt32Array()
	for index: int in range(ordered.size()):
		paragraph_placements.append(index % 3)
	_shuffle_ints(paragraph_placements, rng)
	for index: int in range(clue_records.size()):
		var clue_record: Dictionary = clue_records[index]
		var holder_index: int = holder_assignments[index] if index < holder_assignments.size() else index
		var holder: PassengerData = ordered[clampi(holder_index, 0, ordered.size() - 1)]
		var clue_statement: String = str(clue_record.get("statement", ""))
		var context_slot: int = int(clue_record.get("context_slot", index))
		var blocked_passengers := PackedStringArray()
		var blocked_indices: Variant = clue_record.get("blocked_holders", PackedInt32Array())
		if blocked_indices is PackedInt32Array:
			for blocked_index: int in blocked_indices:
				if blocked_index >= 0 and blocked_index < ordered.size():
					blocked_passengers.append(ordered[blocked_index].short_name)
		var biography: Array = runtime._compose_biography(
			holder,
			clue_statement,
			paragraph_placements[index],
			rng,
			context_slot
		)
		var hidden_statement: String = runtime._find_hidden_statement(biography, clue_statement)
		runtime.statement_by_passenger[holder.short_name] = hidden_statement
		runtime.biography_by_passenger[holder.short_name] = biography
		runtime.context_slot_by_passenger[holder.short_name] = context_slot
		runtime.clue_blocked_passengers_by_holder[holder.short_name] = blocked_passengers
	return runtime


func _resolve_service_level(requested_level: int, passenger_count: int) -> int:
	if requested_level > 0:
		return clampi(requested_level, 1, 5)
	if passenger_count >= 5:
		return 5
	if passenger_count >= 4:
		return 3
	return 1


func _stations_for_level(_level: int) -> PackedStringArray:
	# Station paths always expose all four authored destinations. Early levels
	# reduce the soul count instead, leaving one station visibly unoccupied.
	return night_stations.duplicate()


func _assignment_stations_for_level(level: int, passenger_count: int) -> PackedStringArray:
	var result := PackedStringArray()
	if passenger_count <= 0 or night_stations.is_empty():
		return result
	var authored_indices: PackedInt32Array
	match level:
		1:
			authored_indices = PackedInt32Array([0, 1, 2])
		2:
			authored_indices = PackedInt32Array([0, 1, 3])
		_:
			authored_indices = PackedInt32Array([0, 1, 2, 3, 1])
	for index: int in range(passenger_count):
		var authored_index: int = authored_indices[index] if index < authored_indices.size() else 1
		result.append(night_stations[clampi(authored_index, 0, night_stations.size() - 1)])
	return result


func _build_progression_clues(
	descriptors: PackedStringArray,
	assignment_stations: PackedStringArray
) -> PackedStringArray:
	var records: Array = _build_progression_clue_records(descriptors, assignment_stations)
	var clues := PackedStringArray()
	for record: Dictionary in records:
		clues.append(str(record.get("statement", "")))
	return clues


func _build_progression_clue_records(
	descriptors: PackedStringArray,
	assignment_stations: PackedStringArray
) -> Array:
	var records: Array = []
	if descriptors.size() == 1:
		records.append(_clue_record(single_passenger_statement, PackedInt32Array([0]), 0))
		return records
	var slot_base: int = maxi(0, service_level - 1) * 5
	if service_level == 1 and descriptors.size() >= 3:
		records.append(_clue_record(
			direct_station_statement_template % [_sentence_case(descriptors[0]), assignment_stations[0]],
			PackedInt32Array([0]),
			slot_base
		))
		records.append(_clue_record(
			between_statement_template % [_sentence_case(descriptors[1]), descriptors[0], descriptors[2]],
			PackedInt32Array([1]),
			slot_base + 1
		))
		records.append(_clue_record(
			_build_distance_statement(descriptors[2], descriptors[0], assignment_stations[2], assignment_stations[0]),
			PackedInt32Array([2, 0]),
			slot_base + 2
		))
	elif service_level == 2 and descriptors.size() >= 3:
		records.append(_clue_record(
			highest_mark_statement_template % _sentence_case(descriptors[0]),
			PackedInt32Array([0]),
			slot_base
		))
		records.append(_clue_record(
			_build_distance_statement(descriptors[1], descriptors[0], assignment_stations[1], assignment_stations[0]),
			PackedInt32Array([1, 0]),
			slot_base + 1
		))
		records.append(_clue_record(
			lowest_mark_statement_template % _sentence_case(descriptors[2]),
			PackedInt32Array([2]),
			slot_base + 2
		))
	elif service_level == 3 and descriptors.size() >= 4:
		records.append(_clue_record(
			clockwise_statement_template % [_sentence_case(descriptors[2]), descriptors[0]],
			PackedInt32Array([2]),
			slot_base
		))
		records.append(_clue_record(
			hub_statement_template % _sentence_case(descriptors[1]),
			PackedInt32Array([1]),
			slot_base + 1
		))
		records.append(_clue_record(
			endpoint_statement_template % _sentence_case(descriptors[3]),
			PackedInt32Array([3]),
			slot_base + 2
		))
		records.append(_clue_record(
			_build_distance_statement(descriptors[3], descriptors[2], assignment_stations[3], assignment_stations[2]),
			PackedInt32Array([3, 2]),
			slot_base + 3
		))
	elif service_level == 4 and descriptors.size() >= 4:
		records.append(_clue_record(
			highest_mark_statement_template % _sentence_case(descriptors[0]),
			PackedInt32Array([0]),
			slot_base
		))
		records.append(_clue_record(
			clockwise_statement_template % [_sentence_case(descriptors[2]), descriptors[0]],
			PackedInt32Array([2]),
			slot_base + 1
		))
		records.append(_clue_record(
			linked_pair_statement_template % [_sentence_case(descriptors[1]), descriptors[0], descriptors[3]],
			PackedInt32Array([1]),
			slot_base + 2
		))
		records.append(_clue_record(
			opposite_mark_statement_template % [_sentence_case(descriptors[3]), descriptors[0]],
			PackedInt32Array([3]),
			slot_base + 3
		))
	elif service_level >= 5 and descriptors.size() >= 5:
		records.append(_clue_record(
			highest_mark_statement_template % _sentence_case(descriptors[0]),
			PackedInt32Array([0]),
			slot_base
		))
		records.append(_clue_record(
			clockwise_statement_template % [_sentence_case(descriptors[2]), descriptors[0]],
			PackedInt32Array([2]),
			slot_base + 1
		))
		records.append(_clue_record(
			opposite_mark_statement_template % [_sentence_case(descriptors[3]), descriptors[0]],
			PackedInt32Array([3]),
			slot_base + 2
		))
		records.append(_clue_record(
			same_station_statement_template % [_sentence_case(descriptors[1]), descriptors[4]],
			PackedInt32Array([1, 4]),
			slot_base + 3
		))
		records.append(_clue_record(
			shared_station_counterclockwise_statement_template % [descriptors[1], descriptors[4], descriptors[0]],
			PackedInt32Array([1, 4]),
			slot_base + 4
		))
	# Direct station lines keep editor/debug rosters playable if their size does
	# not match the campaign's authored 3/3/4/4/5 progression.
	while records.size() < descriptors.size():
		var index: int = records.size()
		records.append(_clue_record(
			direct_station_statement_template % [_sentence_case(descriptors[index]), assignment_stations[index]],
			PackedInt32Array([index]),
			slot_base + index
		))
	if records.size() > descriptors.size():
		records.resize(descriptors.size())
	return records


func _clue_record(statement: String, blocked_holder_indices: PackedInt32Array, context_slot: int) -> Dictionary:
	return {
		"statement": statement.strip_edges(),
		"blocked_holders": blocked_holder_indices.duplicate(),
		"context_slot": context_slot,
	}


func _build_distance_statement(
	first_descriptor: String,
	second_descriptor: String,
	first_station: String,
	second_station: String
) -> String:
	var distance: int = maxi(0, get_small_mark_distance(first_station, second_station))
	return distance_statement_template % [
		first_descriptor,
		second_descriptor,
		_small_mark_phrase(distance),
	]


func _small_mark_phrase(count: int) -> String:
	return "%d small %s" % [count, "mark" if count == 1 else "marks"]


func _build_veil_note_statement(
	ordered_passengers: Array[PassengerData],
	descriptors: PackedStringArray,
	rng: RandomNumberGenerator
) -> String:
	if ordered_passengers.is_empty():
		return ""
	if ordered_passengers.size() == 1:
		return single_passenger_statement.strip_edges()
	if service_level == 1:
		return _build_direct_veil_statement(ordered_passengers, descriptors, rng)
	if service_level == 2:
		var upper_note: String = _build_upper_station_veil_statement(ordered_passengers)
		if not upper_note.is_empty():
			return upper_note
	if service_level >= 5:
		var shared_statement: String = _build_shared_station_veil_statement(
			ordered_passengers,
			descriptors
		)
		if not shared_statement.is_empty():
			return shared_statement
	var available_pairs: Array[Dictionary] = []
	for first_index: int in range(ordered_passengers.size()):
		var first_name: String = ordered_passengers[first_index].short_name
		var first_station: String = str(correct_station_by_passenger.get(first_name, ""))
		for second_index: int in range(first_index + 1, ordered_passengers.size()):
			var second_name: String = ordered_passengers[second_index].short_name
			var second_station: String = str(correct_station_by_passenger.get(second_name, ""))
			if first_station == second_station:
				continue
			var distance: int = get_small_mark_distance(first_station, second_station)
			var shares_route: bool = _stations_share_line(first_station, second_station)
			if distance >= 0 and (service_level != 3 or shares_route):
				available_pairs.append({
					"first": first_index,
					"second": second_index,
					"distance": distance,
				})
	if available_pairs.is_empty():
		return _build_direct_veil_statement(ordered_passengers, descriptors, rng)
	var selected_pair: Dictionary = available_pairs[rng.randi_range(0, available_pairs.size() - 1)]
	var first_descriptor: String = _sentence_case(descriptors[int(selected_pair["first"])])
	var second_descriptor: String = descriptors[int(selected_pair["second"])]
	if service_level == 3:
		return (veil_note_statement_template % [
			first_descriptor,
			second_descriptor,
		]).strip_edges()
	return (veil_note_distance_statement_template % [
		first_descriptor,
		second_descriptor,
		_small_mark_phrase(int(selected_pair["distance"])),
	]).strip_edges()


func _build_direct_veil_statement(
	ordered_passengers: Array[PassengerData],
	descriptors: PackedStringArray,
	rng: RandomNumberGenerator
) -> String:
	var selectable_count: int = mini(ordered_passengers.size(), descriptors.size())
	if selectable_count <= 0:
		return single_passenger_statement.strip_edges()
	var selected_index: int = rng.randi_range(0, selectable_count - 1)
	var passenger_name: String = ordered_passengers[selected_index].short_name
	var station_name: String = str(correct_station_by_passenger.get(passenger_name, ""))
	return (veil_note_direct_statement_template % [
		_sentence_case(descriptors[selected_index]),
		station_name,
	]).strip_edges()


func _build_upper_station_veil_statement(ordered_passengers: Array[PassengerData]) -> String:
	if night_stations.is_empty():
		return ""
	var upper_station: String = night_stations[0]
	for data: PassengerData in ordered_passengers:
		if data == null:
			continue
		if str(correct_station_by_passenger.get(data.short_name, "")) != upper_station:
			continue
		if data.occupation.strip_edges().to_lower() == "retired teacher":
			return "The last lesson map leaves %s closest to the upper station." % data.short_name
	for data: PassengerData in ordered_passengers:
		if data == null:
			continue
		if str(correct_station_by_passenger.get(data.short_name, "")) == upper_station:
			return "The oldest route map leaves %s closest to the upper station." % data.short_name
	return ""


func _build_shared_station_veil_statement(
	ordered_passengers: Array[PassengerData],
	descriptors: PackedStringArray
) -> String:
	for first_index: int in range(ordered_passengers.size()):
		var first_name: String = ordered_passengers[first_index].short_name
		var station_name: String = str(correct_station_by_passenger.get(first_name, ""))
		for second_index: int in range(first_index + 1, ordered_passengers.size()):
			var second_name: String = ordered_passengers[second_index].short_name
			if str(correct_station_by_passenger.get(second_name, "")) != station_name:
				continue
			return (veil_note_shared_station_template % [
				_sentence_case(descriptors[first_index]),
				descriptors[second_index],
				station_name,
			]).strip_edges()
	return ""


func _stations_share_line(first_station: String, second_station: String) -> bool:
	var layout: NightStationPathLayout = _instantiate_path_layout()
	if layout == null:
		return false
	var shares_route: bool = layout.stations_share_direct_route(first_station, second_station)
	layout.free()
	return shares_route


func _compose_biography(
	data: PassengerData,
	statement: String,
	paragraph_index: int,
	rng: RandomNumberGenerator,
	context_slot: int = -1
) -> Array:
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
		_format_biography_sentence(resonance_closing_sentence, data),
	]))
	var opening_sentences := paragraphs[0] as PackedStringArray
	var evidence_sentences := paragraphs[1] as PackedStringArray
	var veil_sentences := paragraphs[2] as PackedStringArray
	opening_sentences.append_array(_format_sentence_list(biography_opening_support, data))
	evidence_sentences.append_array(_format_sentence_list(biography_evidence_support, data))
	veil_sentences.append_array(_format_sentence_list(biography_veil_support, data))
	paragraphs[0] = opening_sentences
	paragraphs[1] = evidence_sentences
	paragraphs[2] = veil_sentences
	var target_paragraph: int = clampi(paragraph_index, 0, paragraphs.size() - 1)
	var hidden_statement: String = _contextualize_hidden_statement(
		data,
		statement,
		target_paragraph,
		rng,
		context_slot
	)
	var target_sentences := paragraphs[target_paragraph] as PackedStringArray
	var insertion_index: int = rng.randi_range(0, target_sentences.size())
	target_sentences.insert(insertion_index, hidden_statement)
	paragraphs[target_paragraph] = target_sentences
	return paragraphs


func _contextualize_hidden_statement(
	data: PassengerData,
	statement: String,
	paragraph_index: int,
	rng: RandomNumberGenerator,
	context_slot: int = -1
) -> String:
	var context_template: String = "{statement}"
	if context_slot >= 0 and not hidden_statement_unique_contexts.is_empty():
		context_template = hidden_statement_unique_contexts[
			clampi(context_slot, 0, hidden_statement_unique_contexts.size() - 1)
		]
	elif paragraph_index < hidden_statement_context_variants_by_paragraph.size():
		var variants: PackedStringArray = hidden_statement_context_variants_by_paragraph[paragraph_index]
		if not variants.is_empty():
			context_template = variants[rng.randi_range(0, variants.size() - 1)]
	elif not hidden_statement_context_by_paragraph.is_empty():
		context_template = hidden_statement_context_by_paragraph[
			clampi(paragraph_index, 0, hidden_statement_context_by_paragraph.size() - 1)
		]
	var clause: String = statement.strip_edges()
	clause = clause.trim_suffix(".").strip_edges()
	if not clause.is_empty():
		clause = clause.left(1).to_lower() + clause.substr(1)
	return _format_biography_sentence(context_template, data) \
		.replace("{statement}", clause) \
		.strip_edges()


func _find_hidden_statement(paragraphs: Array, source_statement: String) -> String:
	var source_clause: String = source_statement.strip_edges().trim_suffix(".").to_lower()
	for paragraph_value: Variant in paragraphs:
		if not paragraph_value is PackedStringArray:
			continue
		var sentences := paragraph_value as PackedStringArray
		for sentence: String in sentences:
			if source_clause in sentence.to_lower():
				return sentence
	return source_statement


func _assign_statement_holders(clue_records: Array, passenger_count: int) -> PackedInt32Array:
	var assignments := PackedInt32Array()
	for _index: int in range(clue_records.size()):
		assignments.append(-1)
	var used := PackedInt32Array()
	for _index: int in range(passenger_count):
		used.append(0)
	if _assign_statement_holders_recursive(clue_records, assignments, used, 0, false):
		return assignments
	for index: int in range(assignments.size()):
		assignments[index] = -1
	for index: int in range(used.size()):
		used[index] = 0
	if _assign_statement_holders_recursive(clue_records, assignments, used, 0, true):
		return assignments
	for index: int in range(clue_records.size()):
		assignments[index] = index % maxi(1, passenger_count)
	return assignments


func _assign_statement_holders_recursive(
	clue_records: Array,
	assignments: PackedInt32Array,
	used: PackedInt32Array,
	clue_index: int,
	allow_blocked_holders: bool
) -> bool:
	if clue_index >= clue_records.size():
		return true
	var preferred_indices := PackedInt32Array()
	for holder_index: int in range(used.size()):
		if used[holder_index] != 0:
			continue
		if _clue_blocks_holder(clue_records[clue_index] as Dictionary, holder_index):
			if not allow_blocked_holders:
				continue
		preferred_indices.append(holder_index)
	for holder_index: int in preferred_indices:
		assignments[clue_index] = holder_index
		used[holder_index] = 1
		if _assign_statement_holders_recursive(
			clue_records,
			assignments,
			used,
			clue_index + 1,
			allow_blocked_holders
		):
			return true
		assignments[clue_index] = -1
		used[holder_index] = 0
	return false


func _clue_blocks_holder(clue_record: Dictionary, holder_index: int) -> bool:
	var blocked: Variant = clue_record.get("blocked_holders", PackedInt32Array())
	if blocked is PackedInt32Array:
		return (blocked as PackedInt32Array).has(holder_index)
	if blocked is Array:
		return (blocked as Array).has(holder_index)
	return false


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
	var occupation_counts: Dictionary = {}
	for data: PassengerData in passengers:
		var occupation: String = data.occupation.strip_edges().to_lower()
		if occupation.is_empty():
			occupation = "traveler"
		var descriptor: String = occupation_descriptor_template % occupation
		raw_descriptors.append(descriptor)
		occupation_counts[occupation] = int(occupation_counts.get(occupation, 0)) + 1
	var result := PackedStringArray()
	for index: int in range(passengers.size()):
		var descriptor: String = raw_descriptors[index]
		var occupation: String = passengers[index].occupation.strip_edges().to_lower()
		if occupation.is_empty():
			occupation = "traveler"
		if int(occupation_counts.get(occupation, 0)) > 1:
			descriptor = duplicate_occupation_descriptor_template % [
				passengers[index].short_name,
				occupation,
			]
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


func _shuffle_clue_records(values: Array, rng: RandomNumberGenerator) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var held: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = held


func _shuffle_ints(values: PackedInt32Array, rng: RandomNumberGenerator) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var held: int = values[index]
		values[index] = values[swap_index]
		values[swap_index] = held
