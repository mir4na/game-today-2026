extends SceneTree
## Verifies the Soul Record wrong-guess crack overlay: 1 -> 2 -> shatter close.


func _initialize() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)


func _run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/"):
		push_error("Use an isolated /tmp XDG_DATA_HOME for this test.")
		quit(1)
		return
	var record := load("res://scenes/ui/night_soul_record_ui.tscn").instantiate() as NightSoulRecordUI
	root.add_child(record)
	await process_frame
	var overlay := record.get_node_or_null("%CrackOverlay") as ColorRect
	_check(overlay != null, "Record UI must expose the crack overlay.")
	if overlay == null:
		quit(1)
		return
	var material := overlay.material as ShaderMaterial
	_check(material != null, "Crack overlay must own a ShaderMaterial.")
	record.set_identity_miss_streak(1, true)
	_check(record._crack_level == 1, "First wrong guess must set crack level 1.")
	_check(
		float(material.get_shader_parameter(&"line_alpha")) > 0.0,
		"A wrong guess must make the crack visible."
	)
	record.set_identity_miss_streak(2, true)
	_check(record._crack_level == 2, "Second wrong guess must deepen the crack.")
	record.set_identity_miss_streak(3, true)
	_check(record._crack_level == 3, "Third wrong guess must fully shatter.")
	_check(
		float(material.get_shader_parameter(&"line_alpha")) > 0.0,
		"A shattered record must still render its crack lines."
	)
	record.show()
	record.play_shatter_and_close()
	await create_timer(0.6).timeout
	_check(not record.visible, "Shattering must close the Soul Record so the soul can flee.")
	record.free()
	await process_frame
	print("PASS: soul record wrong-guess cracks crack, deepen, and shatter.")
	quit(0)
