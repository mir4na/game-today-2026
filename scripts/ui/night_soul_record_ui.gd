class_name NightSoulRecordUI
extends Control
## Three-paragraph biography reader used during the night walk. Every sentence
## is clickable, but only the constellation statement is copied to the ledger.

signal closed
signal statement_recorded(passenger_name: String, statement: String)

@export_category("Inspector Copy")
@export var record_title: String = "SOUL RECORD"
@export var instruction_text: String = "Select the sentence that describes the constellation."
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

@onready var _record_anchor: Control = %RecordAnchor
@onready var _title_label: Label = %RecordTitle
@onready var _portrait: TextureRect = %Portrait
@onready var _name_label: Label = %PassengerName
@onready var _details_label: Label = %PassengerDetails
@onready var _instruction_label: Label = %InstructionLabel
@onready var _status_label: Label = %StatusLabel
@onready var _paragraph_labels: Array[RichTextLabel] = [%Paragraph1, %Paragraph2, %Paragraph3]


func _ready() -> void:
	_title_label.text = record_title
	_instruction_label.text = instruction_text
	for paragraph: RichTextLabel in _paragraph_labels:
		paragraph.meta_clicked.connect(_on_sentence_clicked)
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
	_status_label.text = existing_status_text if _recorded else ""
	_build_biography(puzzle.get_biography_for_passenger(_passenger_name))
	show()
	_present_record()


func request_close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _build_biography(paragraphs: Array) -> void:
	_sentence_by_index.clear()
	var sentence_index: int = 0
	for paragraph_index: int in range(_paragraph_labels.size()):
		var label: RichTextLabel = _paragraph_labels[paragraph_index]
		if paragraph_index >= paragraphs.size():
			label.text = empty_record_text if paragraph_index == 0 else ""
			continue
		var sentences: Variant = paragraphs[paragraph_index]
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
		label.text = " ".join(rendered)


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
	for paragraph: RichTextLabel in _paragraph_labels:
		paragraph.text = paragraph.text.replace(
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
	_record_anchor.pivot_offset = _record_anchor.size * 0.5
	_record_anchor.modulate.a = 0.0
	_record_anchor.scale = Vector2(0.95, 0.95)
	var tween: Tween = create_tween()
	tween.tween_property(_record_anchor, ^"modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(_record_anchor, ^"scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key_event := event as InputEventKey
	if key_event != null and key_event.echo:
		return
	if event.is_action_pressed(&"interact"):
		request_close()
		get_viewport().set_input_as_handled()
