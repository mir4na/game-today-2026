class_name NightSoulRecordUI
extends Control
## Vertical biography reader used during the night walk. Every sentence is
## clickable, but only the naturally embedded station-path clue is recorded.

signal closed
signal closing
signal statement_recorded(passenger_name: String, statement: String)

@export_category("Inspector Copy")
@export var record_title: String = "SOUL RECORD"
@export var instruction_text: String = "Read carefully. Some words may belong to the Night Ledger."
@export var empty_record_text: String = "No Soul Record could be recovered."
@export var correct_status_text: String = "Statement recorded in the Night Ledger."
@export var existing_status_text: String = "This statement is already recorded."
@export var incorrect_status_text: String = "The Night Ledger does not respond."
@export_category("Sentence Colors")
@export var sentence_color: Color = Color("3f3734")
@export var recorded_sentence_color: Color = Color("a84e4d")

var _passenger_name: String = ""
var _correct_statement: String = ""
var _sentence_by_index: Dictionary = {}
var _recorded: bool = false
var _status_tween: Tween
var _presentation_tween: Tween
var _record_rest_position: Vector2
var _closing: bool = false

@onready var _shade: ColorRect = %Shade
@onready var _record_anchor: Control = %RecordAnchor
@onready var _title_label: Label = %RecordTitle
@onready var _portrait: TextureRect = %Portrait
@onready var _name_label: Label = %PassengerName
@onready var _details_label: Label = %PassengerDetails
@onready var _instruction_label: Label = %InstructionLabel
@onready var _status_label: Label = %StatusLabel
@onready var _biography_label: RichTextLabel = %BiographyText


func _ready() -> void:
	_title_label.text = record_title
	_instruction_label.text = instruction_text
	_biography_label.meta_clicked.connect(_on_sentence_clicked)
	_record_rest_position = _record_anchor.position
	resized.connect(_refresh_record_scale)
	_refresh_record_scale()
	hide()


func open_record(data: PassengerData, puzzle: DeparturePuzzleData, already_recorded: bool) -> void:
	if data == null or puzzle == null:
		return
	_passenger_name = data.short_name
	_correct_statement = puzzle.get_statement_for_passenger(_passenger_name)
	_recorded = already_recorded
	_portrait.texture = data.id_photo
	_name_label.text = data.short_name.to_upper()
	_details_label.text = "%s  •  %s" % [
		data.occupation.to_upper(),
		puzzle.get_anomaly_label(data.anomaly_type),
	]
	_closing = false
	_status_label.text = existing_status_text if _recorded else ""
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
	var sentence_index: int = 0
	var rendered_paragraphs := PackedStringArray()
	for sentences: Variant in paragraphs:
		var rendered := PackedStringArray()
		for sentence_value: Variant in sentences:
			var sentence: String = str(sentence_value).strip_edges()
			if sentence.is_empty():
				continue
			_sentence_by_index[sentence_index] = sentence
			var color: Color = recorded_sentence_color if _recorded and sentence == _correct_statement else sentence_color
			rendered.append("[url=%d][color=#%s]%s[/color][/url]" % [
				sentence_index,
				color.to_html(false),
				sentence,
			])
			sentence_index += 1
		if not rendered.is_empty():
			rendered_paragraphs.append(" ".join(rendered))
	_biography_label.text = "\n\n".join(rendered_paragraphs) if not rendered_paragraphs.is_empty() else empty_record_text


func _on_sentence_clicked(meta: Variant) -> void:
	var index: int = int(str(meta))
	if not _sentence_by_index.has(index):
		return
	var selected_sentence: String = str(_sentence_by_index[index])
	if selected_sentence != _correct_statement:
		_show_status(incorrect_status_text, Color("9a514d"))
		return
	if _recorded:
		_show_status(existing_status_text, Color("83574b"))
		return
	_recorded = true
	_show_status(correct_status_text, recorded_sentence_color)
	statement_recorded.emit(_passenger_name, _correct_statement)
	# Rebuild so the recovered line remains visibly written in red ink.
	_recolor_recorded_statement()


func _recolor_recorded_statement() -> void:
	_biography_label.text = _biography_label.text.replace(
		"[color=#%s]%s[/color]" % [sentence_color.to_html(false), _correct_statement],
		"[color=#%s]%s[/color]" % [recorded_sentence_color.to_html(false), _correct_statement]
	)


func _show_status(message: String, color: Color) -> void:
	if is_instance_valid(_status_tween):
		_status_tween.kill()
	_status_label.text = message
	_status_label.modulate = color
	_status_label.modulate.a = 0.0
	_status_tween = create_tween()
	_status_tween.tween_property(_status_label, ^"modulate:a", 1.0, 0.16)
	_status_tween.tween_interval(1.2)
	_status_tween.tween_property(_status_label, ^"modulate:a", 0.68, 0.3)


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
