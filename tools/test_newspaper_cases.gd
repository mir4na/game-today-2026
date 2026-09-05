extends SceneTree
## XDG_DATA_HOME=/tmp/newspaper-cases godot --headless --path . --script tools/test_newspaper_cases.gd
var _failures: int = 0

func _initialize() -> void:
	call_deferred(&"_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/"):
		push_error("Use an isolated /tmp XDG_DATA_HOME.")
		quit(1)
		return
	for death_case: bool in [false, true]:
		var game: AfterTheEndGame = load("res://scenes/main/main.tscn").instantiate()
		game.debug_print_anomaly_roster = false
		game.newspaper_edition_mode = AfterTheEndGame.NewspaperEditionMode.FORCE_DEATH if death_case else AfterTheEndGame.NewspaperEditionMode.FORCE_NON_DEATH
		root.add_child(game)
		game.set_process(false)
		game._day_intro_ui.set_process(false)
		game._day_intro_ui.hide()
		var overlay: DocumentOverlayUI = game._document_overlay
		var reader: NewspaperReader = overlay.get_node("%NewspaperReader")
		_check(reader.get_variant_count() == 2, "Both newspaper layouts remain available.")
		var saved_document: String = game._newspaper_document
		var subject: PassengerData = game._find_newspaper_subject(game._daily_rng)
		if death_case:
			_check(subject != null, "A death report has a generated anomaly subject.")
			if subject != null:
				_check(subject.is_dead and subject.initially_on_train, "The reported passenger is an anomaly aboard from the start.")
				_check(game._newspaper_subject_name == subject.passenger_name, "The report identifies its actual passenger.")
				_check(saved_document.contains(subject.passenger_name.to_upper()), "The article prints the matching name.")
				_check(reader._portrait_texture == subject.id_photo, "The death report photo matches its passenger.")
				var aboard: bool = false
				for passenger: Passenger in game._passengers:
					aboard = aboard or passenger.data == subject
				_check(aboard, "The reported anomaly was successfully spawned aboard.")
		else:
			_check(subject == null, "Ordinary news does not generate an unsupported newspaper-death anomaly.")
			_check(not game._get_generated_passenger_names().has(game._newspaper_subject_name), "Ordinary news uses a non-passenger subject.")
		for variant: int in 2:
			reader.set_variant(variant)
			overlay.show_newspaper(saved_document)
			_check(overlay._newspaper_primary_body in saved_document, "Both layouts display the selected case.")
			overlay.request_close()
			await create_timer(0.1).timeout
			overlay.show_newspaper(saved_document)
			_check(game._newspaper_document == saved_document, "Reopening never rerolls the case or subject.")
			overlay.request_close()
			await create_timer(0.1).timeout
		# Sample generated manifests across seeds for both cases.
		for sample_seed: int in range(40):
			var rng := RandomNumberGenerator.new()
			rng.seed = sample_seed
			var manifest: Array[PassengerData] = DailyManifestGenerator.generate(game.passenger_identity_profiles, game.day_route, game.manifest_config, rng, death_case)
			_check(not manifest.is_empty(), "Both cases generate a valid manifest.")
			var reported_anomalies: int = 0
			for data: PassengerData in manifest:
				if data.anomaly_type == String(game.manifest_config.newspaper_anomaly_type):
					reported_anomalies += 1
					_check(data.is_dead and data.initially_on_train, "Every newspaper-death anomaly is available in the opening roster.")
			_check(reported_anomalies == (1 if death_case else 0), "Only the death case reserves a newspaper anomaly.")
		game.manifest_config = game.manifest_config.duplicate()
		game.manifest_config.non_death_news_weight = 0.0 if death_case else 1.0
		game.manifest_config.matching_death_news_weight = 1.0 if death_case else 0.0
		for roll: int in 30:
			var selected: AfterTheEndGame.NewspaperCase = game._roll_random_newspaper_case()
			_check(selected == (AfterTheEndGame.NewspaperCase.MATCHING_PASSENGER_DEATH if death_case else AfterTheEndGame.NewspaperCase.NON_DEATH_NEWS), "Weights select only the two supported cases.")
		game.queue_free()
		await process_frame
		await process_frame
	if _failures == 0:
		print("PASS: two cases in both layouts, matching anomaly aboard, ordinary news, stable rereads, 80 seeded manifests and case weights.")
	quit(1 if _failures else 0)
