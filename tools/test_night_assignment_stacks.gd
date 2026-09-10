extends SceneTree
## Verifies exact ledger copy, character drag previews, and multi-soul stations.

const MainScene = preload("res://scenes/main/main.tscn")

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
	var game := MainScene.instantiate() as AfterTheEndGame
	root.add_child(game)
	await process_frame
	game._active_modal = null
	game.state = AfterTheEndGame.GameState.DAY
	game._jump_directly_to_debug_night()
	var puzzle: DeparturePuzzleData = game._get_departure_puzzle()
	var passengers: Array[PassengerData] = game._get_dead_passenger_data()
	var statements: Dictionary = {}
	for data: PassengerData in passengers:
		statements[data.short_name] = puzzle.get_statement_for_passenger(data.short_name)
	game._night_puzzle_ui.open_puzzle(passengers, puzzle, statements)
	await process_frame

	var board := game._night_puzzle_ui as NightPuzzleUI
	for card: NightPassengerCard in board._passenger_cards:
		var record_strip := card.get_node("%CardPaper") as TextureRect
		_check(
			record_strip.texture != null
			and record_strip.texture.resource_path == "res://assets/NightShift/Frame 28.png",
			"Every ledger NPC card must use the scene-authored Frame 28 record strip."
		)
	var first_card := board._passenger_cards[0] as NightPassengerCard
	var card_paper := first_card.get_node("%CardPaper") as TextureRect
	var first_card_portrait := first_card.get_node("%Portrait") as NightCharacterPortrait
	_check(card_paper.stretch_mode == TextureRect.STRETCH_SCALE, "The record strip must align its portrait well to the card bounds.")
	_check(
		first_card_portrait.get_source_artwork() == passengers[0].get_character_artwork(),
		"A ledger portrait must retain the same real character identity shown in the carriage."
	)
	_check(first_card_portrait.texture is AtlasTexture, "Ledger portrait boxes must show an upper-body crop.")
	var portrait_crop := first_card_portrait.texture as AtlasTexture
	_check(
		absf(portrait_crop.region.size.x - portrait_crop.region.size.y) < 4.0,
		"The ledger portrait crop must match its square frame without letterboxing."
	)
	_check(
		(first_card.get_node("%PortraitName") as Label).text == passengers[0].short_name.to_upper(),
		"The caption below a ledger portrait must show that NPC's name."
	)
	var first_station: String = puzzle.night_stations[0]
	var first_name: String = passengers[0].short_name
	var second_name: String = passengers[1].short_name
	var first_target := board._station_targets[0] as NightStationTarget
	var assignment_pins := first_target.get_node("%AssignmentPins") as Control
	var star_material := (first_target.get_node("%Star") as TextureRect).material as ShaderMaterial
	_check(
		board._station_path_anchor.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and board._station_path_layout_host.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and board._station_path_layout.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Transparent station-path layers must not intercept drags that begin on ledger cards."
	)
	_check(not assignment_pins.visible, "An empty station must not show a red passenger pin.")
	_check(star_material != null, "Every scene-authored station star must carry its shimmer material.")
	var drag_payload: Dictionary = {
		"kind": &"night_soul_card",
		"passenger_name": first_name,
	}
	_check(first_target._can_drop_data(Vector2.ZERO, drag_payload), "A station must accept a dragged soul card.")
	if star_material != null:
		_check(
			is_equal_approx(float(star_material.get_shader_parameter(&"outline_strength")), 1.0),
			"A valid drag hover must enable the station star's white outline."
		)
	first_target._set_drop_highlight(false)
	board._assign_passenger_to_station(first_station, first_name)
	board._assign_passenger_to_station(first_station, second_name)
	var stacked: Array = board._passengers_assigned_to(first_station)
	_check(stacked.size() == 2, "A station must retain more than one assigned soul.")
	_check(stacked.has(first_name) and stacked.has(second_name), "Stacked station assignments must retain both passenger names.")
	_check(assignment_pins.get_child_count() == 2, "A stacked station must render one pin per assigned NPC.")
	_check(assignment_pins.visible, "A station must reveal its red passenger pins after souls are assigned.")
	for pin: Node in assignment_pins.get_children():
		var character_placeholder := pin.get_node_or_null("%CharacterPlaceholder") as NightCharacterPortrait
		_check(
			character_placeholder != null,
			"Every assignment pin must expose an editable character placeholder."
		)
		if character_placeholder != null:
			_check(
				character_placeholder.material is ShaderMaterial,
				"Pin portraits must be clipped to the pin's circular head."
			)
			_check(
				is_equal_approx(character_placeholder.crop_height_ratio, 0.43),
				"Pin portraits must use the same upper-body crop as ledger portraits."
			)

	_check(first_card.get_node("%StatementLabel").text == statements[first_name], "The ledger card must show the exact biography sentence.")
	_check((first_card.get_node("%AssignedOverlay") as ColorRect).visible, "An assigned ledger portrait must show its gray overlay.")
	# Scene linkage is the invariant that keeps the visual preview editable.
	_check(first_card.drag_preview_scene != null, "The passenger drag preview must be supplied by a scene resource.")
	_check(first_target.assignment_pin_scene != null, "Station pins must be supplied by a scene resource.")
	if first_card.drag_preview_scene != null:
		for profile: PassengerIdentityProfile in game.passenger_identity_profiles:
			var preview_data := PassengerData.create_from_identity(profile)
			var preview := first_card.drag_preview_scene.instantiate() as NightPassengerDragPreview
			preview.configure(preview_data)
			var preview_sprite := preview.get_node("%CharacterSprite") as AnimatedSprite2D
			_check(
				preview.position == -preview.preview_center
				and preview_sprite.position == preview.preview_center,
				"The drag preview cursor hotspot must be centered on the walk-cycle sprite."
			)
			_check(
				preview_sprite.sprite_frames != null
				and preview_sprite.animation == &"walk"
				and preview_sprite.sprite_frames.get_frame_count(&"walk") > 1
				and preview_sprite.is_playing(),
				"Dragging %s must play the walk SpriteFrames from that NPC's scene." % profile.short_name
			)
			_check(
				preview.get_node_or_null("%PassengerName") == null,
				"The walk-cycle drag preview must not render a separate name plate."
			)
			preview.free()
	var expected_passengers: Array[String] = puzzle.get_expected_passengers_for_station(
		puzzle.night_stations[0]
	)
	var expected_name: String = expected_passengers[0] if not expected_passengers.is_empty() else ""
	_check(
		game._night_assignment_contains(
			{puzzle.night_stations[0]: [expected_name, "another soul"]},
			puzzle.night_stations[0],
			expected_name
		),
		"A correct soul must still score when its station holds multiple assignments."
	)

	game.free()
	if _failures == 0:
		print("PASS: exact ledger statements and stacked night assignments.")
	quit(1 if _failures > 0 else 0)
