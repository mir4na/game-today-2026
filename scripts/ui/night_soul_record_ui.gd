class_name NightSoulRecordUI
extends Control
## Vertical biography reader used during the night walk. Every sentence is
## clickable, but only the naturally embedded station-path clue is recorded.

signal closed
signal closing
signal statement_recorded(passenger_name: String, statement: String)
signal statement_feedback_requested(succeeded: bool)

@export_category("Inspector Copy")
@export var record_title: String = "SOUL RECORD"
@export var instruction_text: String = "Read carefully. Some words may belong to the Night Ledger."
@export var empty_record_text: String = "No Soul Record could be recovered."
@export_category("Sentence Colors")
@export var sentence_color: Color = Color("3f3734")
@export var hovered_sentence_color: Color = Color("c33f3a")
@export var correct_highlight_background: Color = Color("211d1c")
@export var correct_highlight_text_color: Color = Color("fff8ed")
@export var correct_flash_color: Color = Color("45d47a")
@export var incorrect_flash_color: Color = Color("e6090c")
@export_category("Feedback Timing")
@export_range(0.1, 1.5, 0.05) var correct_flash_seconds: float = 0.5
@export_range(0.1, 1.5, 0.05) var incorrect_flash_seconds: float = 0.55
@export_category("Statement Extraction")
@export_range(0.15, 2.0, 0.05) var statement_extract_seconds: float = 0.85
@export_range(0.0, 0.08, 0.005) var letter_stagger_seconds: float = 0.012
@export_range(0.0, 80.0, 1.0) var letter_source_spread: float = 48.0
@export_range(8, 28, 1) var extracted_letter_font_size: int = 15
@export var extracted_letter_color: Color = Color("000000")

var _passenger_name: String = ""
var _correct_statement: String = ""
var _sentence_by_index: Dictionary = {}
var _sentence_indices_by_paragraph: Array[PackedInt32Array] = []
var _hovered_sentence_index: int = -1
var _recorded: bool = false
var _correct_reveal_characters: int = -1
var _extracted_sentence_index: int = -1
var _statement_target_position: Vector2 = Vector2.ZERO
var _flying_letters: Array[Label] = []
var _correct_feedback_tween: Tween
var _error_flash_tween: Tween
var _error_flash_material: ShaderMaterial
var _presentation_tween: Tween
var _record_rest_position: Vector2
var _closing: bool = false

@onready var _shade: ColorRect = %Shade
@onready var _error_flash: ColorRect = %ErrorFlash
@onready var _record_anchor: Control = %RecordAnchor
@onready var _title_label: Label = %RecordTitle
@onready var _portrait: NightCharacterPortrait = %Portrait
@onready var _name_label: Label = %PassengerName
@onready var _details_label: Label = %PassengerDetails
@onready var _instruction_label: Label = %InstructionLabel
@onready var _biography_label: RichTextLabel = %BiographyText


func _ready() -> void:
	_title_label.text = record_title
	_instruction_label.text = instruction_text
	_biography_label.meta_clicked.connect(_on_sentence_clicked)
	_biography_label.meta_hover_started.connect(_on_sentence_hover_started)
	_biography_label.meta_hover_ended.connect(_on_sentence_hover_ended)
	_error_flash_material = _error_flash.material as ShaderMaterial
	if is_instance_valid(_error_flash_material):
		_error_flash_material = _error_flash_material.duplicate() as ShaderMaterial
		_error_flash_material.resource_local_to_scene = true
		_error_flash.material = _error_flash_material
		_set_error_flash_strength(0.0)
	_record_rest_position = _record_anchor.position
	resized.connect(_refresh_record_scale)
	_refresh_record_scale()
	hide()


func open_record(data: PassengerData, puzzle: DeparturePuzzleData, already_recorded: bool, statement_target_position: Vector2 = Vector2.ZERO) -> void:
	if data == null or puzzle == null:
		return
	_passenger_name = data.short_name
	_correct_statement = puzzle.get_statement_for_passenger(_passenger_name)
	_recorded = already_recorded
	_statement_target_position = statement_target_position
	# A Borrowed Portrait changes the daytime ID photo. The Soul Record depicts
	# the soul being inspected, so it always uses that NPC's real character art.
	_portrait.set_passenger(data)
	_name_label.text = data.short_name.to_upper()
	_details_label.text = "%s  •  %s" % [
		data.occupation.to_upper(),
		puzzle.get_anomaly_label(data.anomaly_type),
	]
	_closing = false
	_correct_reveal_characters = -1
	_extracted_sentence_index = -1
	_clear_flying_letters()
	_set_error_flash_strength(0.0)
	_build_biography(puzzle.get_biography_for_passenger(_passenger_name))
	show()
	_present_record()


func request_close() -> void:
	if not visible or _closing:
		return
	_closing = true
	closing.emit()
	_kill_presentation_tween()
	_presentation_tween = create_tween().set_parallel(true)
	_presentation_tween.tween_property(
		_record_anchor,
		^"position",
		_record_rest_position + Vector2(220.0, 0.0),
		0.24
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_presentation_tween.tween_property(_record_anchor, ^"modulate:a", 0.0, 0.18)
	_presentation_tween.tween_property(_shade, ^"modulate:a", 0.0, 0.22)
	_presentation_tween.chain().tween_callback(_finish_close)


func _build_biography(paragraphs: Array) -> void:
	_sentence_by_index.clear()
	_sentence_indices_by_paragraph.clear()
	_hovered_sentence_index = -1
	_extracted_sentence_index = -1
	var sentence_index: int = 0
	for sentences: Variant in paragraphs:
		var paragraph_indices := PackedInt32Array()
		for sentence_value: Variant in sentences:
			var sentence: String = str(sentence_value).strip_edges()
			if sentence.is_empty():
				continue
			_sentence_by_index[sentence_index] = sentence
			paragraph_indices.append(sentence_index)
			sentence_index += 1
		if not paragraph_indices.is_empty():
			_sentence_indices_by_paragraph.append(paragraph_indices)
	_render_biography()


func _render_biography() -> void:
	var rendered_paragraphs := PackedStringArray()
	for paragraph_indices: PackedInt32Array in _sentence_indices_by_paragraph:
		var rendered := PackedStringArray()
		for sentence_index: int in paragraph_indices:
			var sentence: String = str(_sentence_by_index.get(sentence_index, ""))
			if _recorded and sentence == _correct_statement:
				rendered.append("[url=%d][color=#%s]%s[/color][/url]" % [
					sentence_index,
					Color(1.0, 1.0, 1.0, 0.0).to_html(false),
					_blank_statement_text(sentence),
				])
				continue
			var color: Color = sentence_color
			if sentence_index == _hovered_sentence_index:
				color = hovered_sentence_color
			rendered.append("[url=%d][color=#%s]%s[/color][/url]" % [
				sentence_index,
				color.to_html(false),
				sentence,
			])
		if not rendered.is_empty():
			rendered_paragraphs.append(" ".join(rendered))
	_biography_label.text = "\n\n".join(rendered_paragraphs) if not rendered_paragraphs.is_empty() else empty_record_text


func _on_sentence_hover_started(meta: Variant) -> void:
	var index: int = int(str(meta))
	if not _sentence_by_index.has(index) or _hovered_sentence_index == index:
		return
	_hovered_sentence_index = index
	_render_biography()


func _on_sentence_hover_ended(meta: Variant) -> void:
	var index: int = int(str(meta))
	if _hovered_sentence_index != index:
		return
	_hovered_sentence_index = -1
	_render_biography()


func _on_sentence_clicked(meta: Variant) -> void:
	var index: int = int(str(meta))
	if not _sentence_by_index.has(index):
		return
	var selected_sentence: String = str(_sentence_by_index[index])
	if selected_sentence != _correct_statement:
		statement_feedback_requested.emit(false)
		_play_incorrect_feedback()
		return
	if _recorded:
		return
	_recorded = true
	_extracted_sentence_index = index
	_hovered_sentence_index = -1
	statement_feedback_requested.emit(true)
	statement_recorded.emit(_passenger_name, _correct_statement)
	_play_correct_statement_feedback(index)


func _play_correct_statement_feedback(sentence_index: int) -> void:
	if is_instance_valid(_correct_feedback_tween):
		_correct_feedback_tween.kill()
	_play_feedback_flash(correct_flash_color, correct_flash_seconds)
	_correct_reveal_characters = 0
	var source_rect: Rect2 = _estimate_sentence_source_rect(sentence_index)
	_render_biography()
	_animate_statement_extraction(source_rect)
	_correct_feedback_tween = create_tween()
	_correct_feedback_tween.tween_interval(statement_extract_seconds + letter_stagger_seconds * float(_correct_statement.length()))
	_correct_feedback_tween.tween_callback(_finish_correct_statement_feedback)


func _set_correct_reveal_characters(value: float) -> void:
	_correct_reveal_characters = clampi(int(value), 0, _correct_statement.length())


func _finish_correct_statement_feedback() -> void:
	_correct_reveal_characters = -1
	_extracted_sentence_index = -1
	_render_biography()


func _blank_statement_text(statement: String) -> String:
	var blank := PackedStringArray()
	for character: String in statement:
		if character == " ":
			blank.append(" ")
		else:
			blank.append(" ")
	return "".join(blank)


func _estimate_sentence_source_rect(sentence_index: int) -> Rect2:
	var text_rect: Rect2 = _biography_label.get_global_rect()
	var paragraph_index: int = 0
	var sentence_index_in_paragraph: int = 0
	for paragraph_indices: PackedInt32Array in _sentence_indices_by_paragraph:
		var local_index: int = paragraph_indices.find(sentence_index)
		if local_index >= 0:
			sentence_index_in_paragraph = local_index
			break
		paragraph_index += 1
	var row_height: float = minf(82.0, maxf(44.0, text_rect.size.y / maxf(1.0, float(_sentence_indices_by_paragraph.size()))))
	var source_y: float = text_rect.position.y + 18.0 + float(paragraph_index) * row_height
	var source_x: float = text_rect.position.x + 18.0 + float(sentence_index_in_paragraph) * 28.0
	return Rect2(Vector2(source_x, source_y), Vector2(maxf(160.0, text_rect.size.x * 0.62), 30.0))


func _animate_statement_extraction(source_rect: Rect2) -> void:
	_clear_flying_letters()
	var target: Vector2 = _statement_target_position
	if target == Vector2.ZERO:
		target = get_viewport_rect().size * Vector2(0.11, 0.82)
	var visible_index: int = 0
	var total_letters: int = 0
	for character: String in _correct_statement:
		if character != " ":
			total_letters += 1
	var columns: int = maxi(1, mini(24, total_letters))
	var tween: Tween = create_tween().set_parallel(true)
	for character: String in _correct_statement:
		if character == " ":
			continue
		var label := Label.new()
		label.text = character
		label.z_index = 30
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", extracted_letter_color)
		label.add_theme_font_size_override("font_size", extracted_letter_font_size)
		add_child(label)
		var column: int = visible_index % columns
		var row: int = visible_index / columns
		var source := Vector2(
			source_rect.position.x + float(column) * maxf(8.0, source_rect.size.x / float(columns)),
			source_rect.position.y + float(row) * 18.0
		)
		source += Vector2(
			sin(float(visible_index) * 1.7) * letter_source_spread * 0.08,
			cos(float(visible_index) * 1.13) * letter_source_spread * 0.08
		)
		label.global_position = source
		label.scale = Vector2.ONE
		label.modulate.a = 1.0
		_flying_letters.append(label)
		var delay: float = float(visible_index) * letter_stagger_seconds
		var destination: Vector2 = target + Vector2(
			sin(float(visible_index) * 2.3) * 7.0,
			cos(float(visible_index) * 1.9) * 7.0
		)
		tween.tween_property(label, ^"global_position", destination, statement_extract_seconds).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(label, ^"scale", Vector2(0.15, 0.15), statement_extract_seconds).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(label, ^"modulate:a", 0.0, statement_extract_seconds * 0.42).set_delay(delay + statement_extract_seconds * 0.58)
		visible_index += 1
	tween.chain().tween_callback(_clear_flying_letters)


func _clear_flying_letters() -> void:
	for letter: Label in _flying_letters:
		if is_instance_valid(letter):
			letter.queue_free()
	_flying_letters.clear()

func _play_incorrect_feedback() -> void:
	_play_feedback_flash(incorrect_flash_color, incorrect_flash_seconds)


func _play_feedback_flash(flash_color: Color, duration: float) -> void:
	if not is_instance_valid(_error_flash_material):
		return
	if is_instance_valid(_error_flash_tween):
		_error_flash_tween.kill()
	_error_flash_material.set_shader_parameter(&"flash_color", flash_color)
	_set_error_flash_strength(0.0)
	_error_flash_tween = create_tween()
	_error_flash_tween.tween_method(
		_set_error_flash_strength,
		0.0,
		1.0,
		duration * 0.22
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_error_flash_tween.tween_method(
		_set_error_flash_strength,
		1.0,
		0.0,
		duration * 0.78
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _set_error_flash_strength(value: float) -> void:
	if is_instance_valid(_error_flash_material):
		_error_flash_material.set_shader_parameter(&"strength", clampf(value, 0.0, 1.0))


func _present_record() -> void:
	_kill_presentation_tween()
	_refresh_record_scale()
	_record_anchor.position = _record_rest_position + Vector2(190.0, 0.0)
	_record_anchor.modulate.a = 0.0
	_shade.modulate.a = 0.0
	_presentation_tween = create_tween().set_parallel(true)
	_presentation_tween.tween_property(_record_anchor, ^"position", _record_rest_position, 0.32) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_presentation_tween.tween_property(_record_anchor, ^"modulate:a", 1.0, 0.2)
	_presentation_tween.tween_property(_shade, ^"modulate:a", 1.0, 0.24)


func _refresh_record_scale() -> void:
	if not is_instance_valid(_record_anchor):
		return
	var available_height: float = maxf(size.y - 32.0, 1.0)
	var scale_factor: float = minf(1.0, available_height / maxf(_record_anchor.size.y, 1.0))
	_record_anchor.pivot_offset = Vector2(_record_anchor.size.x, _record_anchor.size.y * 0.5)
	_record_anchor.scale = Vector2.ONE * scale_factor


func _finish_close() -> void:
	hide()
	_hovered_sentence_index = -1
	_correct_reveal_characters = -1
	_extracted_sentence_index = -1
	_clear_flying_letters()
	_set_error_flash_strength(0.0)
	_record_anchor.position = _record_rest_position
	_record_anchor.modulate.a = 1.0
	_shade.modulate.a = 1.0
	_closing = false
	closed.emit()


func _kill_presentation_tween() -> void:
	if is_instance_valid(_presentation_tween) and _presentation_tween.is_valid():
		_presentation_tween.kill()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key_event := event as InputEventKey
	if key_event != null and key_event.echo:
		return
	if event.is_action_pressed(&"interact"):
		request_close()
		get_viewport().set_input_as_handled()
