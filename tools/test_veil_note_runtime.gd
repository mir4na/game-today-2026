extends SceneTree
## Covers one-item capacity, night-only activation, reveal, and ledger storage.

const MainScene = preload("res://scenes/main/main.tscn")
const MarketScene = preload("res://scenes/systems/market_tool_state.tscn")
const ShiftProgress = preload("res://scripts/systems/shift_progress.gd")

var _failures: bool = false


func _initialize() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failures = true


func _run() -> void:
	var market := MarketScene.instantiate() as MarketToolState
	root.add_child(market)
	market.restore_shift_inventory({
		"blessings": 10,
		"veil_notes": 1,
		"radar_charges": 0,
		"speed_level": 1,
	})
	var result: Dictionary = market.purchase(&"veil_note")
	_check(not bool(result.success) and market.blessings == 10, "An owned Veil Note must block purchase before spending Blessings.")
	_check(market.consume_veil_note() and market.veil_notes == 0, "Opening the Veil Note must consume its single stock.")
	result = market.purchase(&"veil_note")
	_check(bool(result.success) and market.veil_notes == 1 and market.blessings == 7, "An empty slot may buy exactly one Veil Note.")
	result = market.purchase(&"veil_note")
	_check(not bool(result.success) and market.blessings == 7, "Repeated purchases must remain blocked at capacity one.")
	market.restore_shift_inventory({"blessings": 0, "audit_slips": 8})
	_check(market.veil_notes == 1, "Legacy Audit Slip saves must migrate into one Veil Note.")
	market.free()
	var legacy_save_path: String = "user://veil_note_legacy_save.cfg"
	var legacy_save := ConfigFile.new()
	legacy_save.set_value("progress", "version", ShiftProgress.AUDIT_SLIP_VERSION)
	legacy_save.set_value("progress", "checkpoint", {
		"day": 2,
		"seed": 90210,
		"inventory": {
			"blessings": 12,
			"audit_slips": 5,
			"radar_charges": 0,
			"speed_level": 1,
		},
		"completed": false,
	})
	_check(legacy_save.save(legacy_save_path) == OK, "The migration fixture must save.")
	var migrated_checkpoint: Dictionary = ShiftProgress.load_checkpoint(legacy_save_path)
	_check(
		int(migrated_checkpoint.inventory.get("veil_notes", -1)) == 1
		and not migrated_checkpoint.inventory.has("audit_slips"),
		"Version 2 progress must migrate to a single Veil Note."
	)

	var game := MainScene.instantiate() as AfterTheEndGame
	root.add_child(game)
	await process_frame
	game._active_modal = null
	game.state = AfterTheEndGame.GameState.DAY
	game._market_tool_state.restore_shift_inventory({
		"blessings": 0,
		"veil_notes": 1,
		"radar_charges": 0,
		"speed_level": 1,
	})
	game._on_market_tool_requested(&"veil_note")
	_check(game._market_tool_state.veil_notes == 1, "Veil Note activation must be rejected during Day Shift.")

	game._jump_directly_to_debug_night()
	var puzzle: DeparturePuzzleData = game._get_departure_puzzle()
	_check(puzzle != null and not puzzle.get_veil_note_statement().is_empty(), "Every generated night case must prepare an additional statement.")
	var reveal := game._veil_note_reveal_ui as VeilNoteRevealUI
	reveal.rise_seconds = 0.01
	reveal.shake_steps = 1
	reveal.shake_step_seconds = 0.01
	reveal.flash_seconds = 0.01
	reveal.typewriter_characters_per_second = 10000.0
	reveal.statement_hold_seconds = 0.0
	reveal.particle_flight_seconds = 0.01
	game._on_market_tool_requested(&"veil_note")
	_check(game._market_tool_state.veil_notes == 0, "Night activation must consume the Veil Note.")
	_check(game._collected_veil_note_statement == puzzle.get_veil_note_statement(), "The generated extra statement must be recorded exactly.")
	_check(reveal.visible and game._active_modal == reveal, "The scene-authored reveal must own input while it plays.")
	await create_timer(0.9).timeout
	_check(not reveal.visible and game._active_modal == null, "The reveal must return control after its particle flight.")

	game._open_night_puzzle()
	await process_frame
	var board := game._night_puzzle_ui as NightPuzzleUI
	var shade := board.get_node("Shade") as ColorRect
	var map_paper := board.get_node("BoardAnchor/StationPathAnchor/MapPaper") as TextureRect
	_check(
		shade.z_index < map_paper.z_index,
		"The station-path paper must render above the dark screen shade."
	)
	_check((board.get_node("%VeilNotePanel") as Control).visible, "The extra statement must appear inside the Night Ledger.")
	_check((board.get_node("%VeilNoteStatement") as Label).text == puzzle.get_veil_note_statement(), "Night Ledger text must match the revealed statement.")
	game._on_night_validation_finished(false, 1)
	_check(not game._collected_veil_note_statement.is_empty(), "A consumed Veil Note must remain recorded after a failed assignment attempt.")

	game.free()
	if not _failures:
		print("PASS: Veil Note capacity, night restriction, reveal, and Night Ledger clue storage.")
	quit(1 if _failures else 0)
