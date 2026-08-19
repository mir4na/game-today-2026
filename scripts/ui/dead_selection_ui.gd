class_name DeadSelectionUI
extends Control
## Persistent five-line abnormal-passenger notebook, submitted at the end of day.

signal selection_confirmed(selected_names: PackedStringArray)
signal closed

const MAX_IDENTIFICATIONS: int = 5

@export_category("Inspector Copy")
@export_multiline var notes_instruction_template: String
@export_multiline var review_instruction_template: String

@onready var _entries: Array[LineEdit] = [%NameEntry1, %NameEntry2, %NameEntry3, %NameEntry4, %NameEntry5]
@onready var _instruction_label: Label = %InstructionLabel
@onready var _error_label: Label = %ErrorLabel
@onready var _close_button: Button = %CancelButton
@onready var _confirm_button: Button = %ConfirmButton
var _submission_enabled: bool = false

func open_notes(passengers: Array[PassengerData], submission_enabled: bool) -> void:
	_submission_enabled = submission_enabled
	_error_label.text = ""
	_instruction_label.text = (review_instruction_template if submission_enabled else notes_instruction_template) % passengers.size()
	_confirm_button.visible = submission_enabled
	show()
	_focus_first_available_line()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		request_close()
		get_viewport().set_input_as_handled()

func show_error(message: String) -> void:
	_error_label.text = message

func request_close() -> void:
	hide()
	closed.emit()

func set_typed_names(names: PackedStringArray) -> void:
	for i: int in range(_entries.size()):
		_entries[i].text = names[i] if i < names.size() else ""

func _on_name_submitted(_text: String, index: int) -> void:
	if index < _entries.size() - 1:
		_entries[index + 1].grab_focus()
	else:
		_focus_final_action()

func _advance_after_space(new_text: String, index: int) -> void:
	if index < 0 or index >= _entries.size() or not new_text.ends_with(" "):
		return
	var completed_name: String = new_text.strip_edges()
	_entries[index].text = completed_name
	_entries[index].caret_column = completed_name.length()
	if completed_name.is_empty():
		return
	if index < _entries.size() - 1:
		_entries[index + 1].grab_focus()
	else:
		_focus_final_action()

func _focus_first_available_line() -> void:
	for entry: LineEdit in _entries:
		if entry.text.strip_edges().is_empty():
			entry.grab_focus()
			return
	_entries[0].grab_focus()
	_entries[0].caret_column = _entries[0].text.length()

func _focus_final_action() -> void:
	if _submission_enabled:
		_confirm_button.grab_focus()
	else:
		_close_button.grab_focus()

func _on_name_entry_1_text_changed(text: String) -> void:
	_advance_after_space(text, 0)

func _on_name_entry_2_text_changed(text: String) -> void:
	_advance_after_space(text, 1)

func _on_name_entry_3_text_changed(text: String) -> void:
	_advance_after_space(text, 2)

func _on_name_entry_4_text_changed(text: String) -> void:
	_advance_after_space(text, 3)

func _on_name_entry_5_text_changed(text: String) -> void:
	_advance_after_space(text, 4)

func _on_name_entry_1_submitted(text: String) -> void:
	_on_name_submitted(text, 0)

func _on_name_entry_2_submitted(text: String) -> void:
	_on_name_submitted(text, 1)

func _on_name_entry_3_submitted(text: String) -> void:
	_on_name_submitted(text, 2)

func _on_name_entry_4_submitted(text: String) -> void:
	_on_name_submitted(text, 3)

func _on_name_entry_5_submitted(text: String) -> void:
	_on_name_submitted(text, 4)

func _confirm() -> void:
	if not _submission_enabled:
		return
	var selected := PackedStringArray()
	for entry: LineEdit in _entries:
		var typed_name: String = entry.text.strip_edges()
		if not typed_name.is_empty():
			selected.append(typed_name)
	selection_confirmed.emit(selected)
