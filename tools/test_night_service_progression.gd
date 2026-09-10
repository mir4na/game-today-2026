extends SceneTree
## Verifies the complete five-night anomaly, clue, graph, and ledger progression.

const MainScene = preload("res://scenes/main/main.tscn")
const NightPuzzleScene = preload("res://scenes/ui/night_puzzle_ui.tscn")

const EXPECTED_ANOMALY_COUNTS := [3, 3, 4, 4, 5]
const EXPECTED_ROUTE_EDGE_COUNTS := [3, 3, 4, 5, 6]
const EXPECTED_PATH_SEGMENT_COUNTS := [6, 9, 9, 11, 20]

var _failures: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failures += 1


func _run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/"):
		push_error("Use an isolated /tmp XDG_DATA_HOME for this test.")
		quit(1)
		return

	var scene_probe := MainScene.instantiate() as AfterTheEndGame
	var authored_config: DailyManifestConfig = scene_probe.manifest_config
	var authored_puzzle := scene_probe.puzzle_resource as DeparturePuzzleData
	var level_five_passengers: Array[PassengerData] = []
	var level_five_puzzle: DeparturePuzzleData

	for service_level: int in range(1, 6):
		var daily_config: DailyManifestConfig = authored_config.create_daily_service(
			service_level,
			20260909
		)
		var manifest_rng := RandomNumberGenerator.new()
		manifest_rng.seed = 5300 + service_level
		var manifest: Array[PassengerData] = DailyManifestGenerator.generate(
			scene_probe.passenger_identity_profiles,
			scene_probe.day_route,
			daily_config,
			manifest_rng,
			service_level == 5
		)
		var deceased: Array[PassengerData] = []
		var anomaly_types: Dictionary = {}
		for data: PassengerData in manifest:
			if not data.is_dead:
				continue
			deceased.append(data)
			anomaly_types[data.anomaly_type] = true
		_check(
			deceased.size() == EXPECTED_ANOMALY_COUNTS[service_level - 1],
			"Level %d must generate %d night anomalies." % [
				service_level,
				EXPECTED_ANOMALY_COUNTS[service_level - 1],
			]
		)

		var puzzle_rng := RandomNumberGenerator.new()
		puzzle_rng.seed = 9100 + service_level
		var runtime: DeparturePuzzleData = authored_puzzle.create_runtime(
			deceased,
			puzzle_rng,
			service_level
		)
		_check(runtime.service_level == service_level, "The runtime puzzle must retain its campaign level.")
		_check(
			runtime.get_assignment_count() == deceased.size(),
			"Every deceased passenger must receive exactly one solution destination."
		)
		_check(
			runtime.night_stations.size() == 4,
			"Every Night Service level must display all four stations."
		)
		_check(
			runtime.get_route_edges().size() == EXPECTED_ROUTE_EDGE_COUNTS[service_level - 1],
			"Each Night Service level must expose its intended station connections."
		)
		_check(
			runtime.get_path_segment_count() == EXPECTED_PATH_SEGMENT_COUNTS[service_level - 1],
			"Level %d must read every station-to-mark graph segment from its scene." % service_level
		)
		_check(
			runtime.get_small_mark_count() > 0,
			"Every station path must contain functional small distance marks."
		)
		var layout := runtime.get_station_path_layout_scene().instantiate() as NightStationPathLayout
		root.add_child(layout)
		for segment: NightPathSegment in layout.get_path_segments():
			segment._sync_to_anchors()
			_check(segment.points.size() == 2, "Every route line must resolve both scene anchors.")
			if segment.points.size() == 2:
				_check(
					segment.points[0].distance_to(Vector2.ZERO) > 1.0
					and segment.points[1].distance_to(Vector2.ZERO) > 1.0,
					"Level %d route lines must never fall back to the ledger corner." % service_level
				)
		layout.free()
		for first_station: String in runtime.night_stations:
			for second_station: String in runtime.night_stations:
				if first_station == second_station:
					continue
				_check(
					runtime.get_small_mark_distance(first_station, second_station) > 0,
					"Every pair of stations must have a scene-authored route through small marks."
				)

		var hidden_paragraphs: Dictionary = {}
		for data: PassengerData in deceased:
			var statement: String = runtime.get_statement_for_passenger(data.short_name)
			var biography: Array = runtime.get_biography_for_passenger(data.short_name)
			var found_paragraph: int = _find_statement_paragraph(biography, statement)
			_check(not statement.is_empty(), "Every soul must have a hidden ledger statement.")
			_check(found_paragraph >= 0, "The saved statement must exactly match one biography sentence.")
			if found_paragraph >= 0:
				hidden_paragraphs[found_paragraph] = true
			_check(
				not str(runtime.correct_station_by_passenger.get(data.short_name, "")).is_empty(),
				"Every soul must be represented in the passenger-to-station solution map."
			)
		_check(
			hidden_paragraphs.size() == 3,
			"Hidden statements must be distributed through the opening, middle, and closing paragraphs."
		)

		var occupied_station_count: int = 0
		var largest_station_group: int = 0
		for station_name: String in runtime.night_stations:
			var station_group_size: int = runtime.get_expected_passengers_for_station(station_name).size()
			if station_group_size > 0:
				occupied_station_count += 1
			largest_station_group = maxi(largest_station_group, station_group_size)
		match service_level:
			1:
				_check(occupied_station_count == 3, "Level 1 must leave one of four stations empty.")
			2:
				_check(occupied_station_count == 3, "Level 2 must leave one of four stations empty.")
			3, 4:
				_check(occupied_station_count == 4, "Levels 3 and 4 must use every station once.")
			5:
				_check(occupied_station_count == 4, "Level 5 must use all four stations.")
				_check(largest_station_group == 2, "Level 5 must place two souls at one station.")
				_check(anomaly_types.size() == 5, "Level 5 must present all five anomaly evidence types.")
				_check(
					anomaly_types.has(String(daily_config.newspaper_anomaly_type)),
					"Level 5 must guarantee the newspaper-death evidence case."
				)
				level_five_passengers = deceased
				level_five_puzzle = runtime

	_check(level_five_puzzle != null, "The final-level puzzle must be available for the ledger test.")
	if level_five_puzzle != null:
		var board := NightPuzzleScene.instantiate() as NightPuzzleUI
		root.add_child(board)
		await process_frame
		var collected: Dictionary = {}
		board.open_puzzle(level_five_passengers, level_five_puzzle, collected)
		await process_frame
		var initially_visible_cards: int = 0
		for card: NightPassengerCard in board._passenger_cards:
			if card.visible:
				initially_visible_cards += 1
		_check(initially_visible_cards == 0, "The Night Ledger must begin without any NPC records.")
		_check(board._clue_count_label.text == "0/5 FOUND", "The empty ledger must use the concise FOUND counter.")
		_check(
			board.get_node_or_null("BoardAnchor/LedgerAnchor/LedgerHeader") == null
			and board.get_node_or_null("BoardAnchor/LedgerAnchor/LedgerTitleSmall") == null,
			"The ledger header and small service title must be removed."
		)
		var first_found: PassengerData = level_five_passengers[0]
		collected[first_found.short_name] = level_five_puzzle.get_statement_for_passenger(first_found.short_name)
		board.refresh_collected_statements(collected)
		_check(
			board._passenger_cards[0].visible
			and not board._passenger_cards[1].visible
			and board._passenger_cards[0].passenger_name == first_found.short_name,
			"A valid biography statement must reveal exactly its matching NPC record."
		)
		for data: PassengerData in level_five_passengers:
			collected[data.short_name] = level_five_puzzle.get_statement_for_passenger(data.short_name)
		board.refresh_collected_statements(collected)
		_check(board._passenger_cards[4].visible, "The final night must display a fifth scene-authored ledger card.")
		_check(
			board._passenger_cards[4].scale.is_equal_approx(Vector2.ONE * board.compact_card_scale),
			"Five ledger cards must switch to the compact layout without scrolling."
		)
		_check(board._clue_count_label.text == "5/5 FOUND", "The ledger counter must update as records are discovered.")
		var visible_final_threads: int = 0
		for child: Node in board._station_path_layout.get_children():
			if child is NightPathSegment and child.visible:
				visible_final_threads += 1
		_check(
			visible_final_threads == level_five_puzzle.get_path_segment_count(),
			"The scene-authored final path must render every gameplay connection."
		)
		board.free()

	scene_probe.free()
	if _failures == 0:
		print("PASS: Night Service levels 1-5 anomaly counts, graph progression, clues, and ledger capacity.")
	quit(1 if _failures > 0 else 0)


func _find_statement_paragraph(biography: Array, statement: String) -> int:
	for paragraph_index: int in range(biography.size()):
		var paragraph: Variant = biography[paragraph_index]
		if paragraph is PackedStringArray:
			for sentence: String in paragraph:
				if sentence == statement:
					return paragraph_index
		elif paragraph is Array:
			for sentence_value: Variant in paragraph:
				if str(sentence_value) == statement:
					return paragraph_index
	return -1
