extends SceneTree
## Verifies both designer-forced branches of the production 50/50 newspaper roll.

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var game := packed.instantiate() as AfterTheEndGame
	assert(game.newspaper_edition_mode == AfterTheEndGame.NewspaperEditionMode.RANDOM, "The Main scene should use the random newspaper mode")
	assert(is_equal_approx(game.newspaper_relevant_chance, 0.5), "The relevant-passenger newspaper chance must be 50 percent")
	game.newspaper_edition_mode = AfterTheEndGame.NewspaperEditionMode.FORCE_RELEVANT
	root.add_child(game)
	await process_frame

	var inspect_ui := game.get("_inspect_ui") as PassengerInspectUI
	game.call("_on_newspaper_read")
	var relevant_document: String = (inspect_ui.get("_content") as RichTextLabel).text
	assert(game.get("_newspaper_has_relevant_name") == true, "The relevant edition should report a deceased train passenger")
	assert("Damar Vey" in relevant_document, "The relevant edition should expose the newspaper-death passenger")
	inspect_ui.request_close()
	game.call("_on_newspaper_read")
	assert((inspect_ui.get("_content") as RichTextLabel).text == relevant_document, "Rereading must not reroll the newspaper")
	inspect_ui.request_close()

	game.newspaper_edition_mode = AfterTheEndGame.NewspaperEditionMode.FORCE_UNRELATED
	game.call("_prepare_newspaper_edition")
	game.call("_on_newspaper_read")
	var unrelated_document: String = (inspect_ui.get("_content") as RichTextLabel).text
	assert(game.get("_newspaper_has_relevant_name") == false, "The unrelated edition should contain no relevant train name")
	for resource: Resource in game.passenger_resources:
		var data := resource as PassengerData
		assert(data == null or not data.passenger_name in unrelated_document, "The unrelated article must not name any passenger in this train's roster")

	print("NEWSPAPER_RANDOMIZATION_TEST: PASS")
	game.queue_free()
	await process_frame
	quit()
