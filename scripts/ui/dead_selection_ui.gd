class_name DeadSelectionUI
extends Control
## Persistent five-line abnormal-passenger notebook, auto-filed when daylight service ends.

signal closed
signal audit_requested(typed_name: String)

@export_category("Inspector Copy")
@export_multiline var notes_instruction_template: String

@onready var _entries: Array[LineEdit] = [%NameEntry1, %NameEntry2, %NameEntry3, %NameEntry4, %NameEntry5]
@onready var _instruction_label: Label = %InstructionLabel
@onready var _close_button: Button = %CancelButton
@onready var _audit_stock_label: Label = %AuditStockLabel
@onready var _audit_result_label: Label = %AuditResultLabel
@onready var _audit_button: Button = %AuditButton

var _last_active_entry_index: int = 0

func open_notes(passengers: Array[PassengerData]) -> void:
	_instruction_label.text = notes_instruction_template % passengers.size()
	_audit_result_label.text = "Audit Slips only verify manifest spelling; they never reveal life status."
	_audit_result_label.modulate = Color("8f887b")
	show()
	_focus_first_available_line()


func configure_audit_slips(count: int) -> void:
	var available: int = maxi(0, count)
	_audit_stock_label.text = "AUDIT SLIPS AVAILABLE: %d" % available
	_audit_button.disabled = available <= 0


func show_audit_result(message: String, is_match: bool) -> void:
	_audit_result_label.text = message
	_audit_result_label.modulate = Color("3f7451") if is_match else Color("a94442")

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		request_close()
		get_viewport().set_input_as_handled()

func request_close() -> void:
	hide()
	closed.emit()

func get_typed_names() -> PackedStringArray:
	var selected := PackedStringArray()
	for entry: LineEdit in _entries:
		var typed_name: String = entry.text.strip_edges()
		if not typed_name.is_empty():
			selected.append(typed_name)
	return selected

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
	for index: int in range(_entries.size()):
		var entry: LineEdit = _entries[index]
		if entry.text.strip_edges().is_empty():
			_last_active_entry_index = index
			entry.grab_focus()
			return
	_last_active_entry_index = 0
	_entries[0].grab_focus()
	_entries[0].caret_column = _entries[0].text.length()

func _focus_final_action() -> void:
	_close_button.grab_focus()


func _set_active_entry(index: int) -> void:
	_last_active_entry_index = clampi(index, 0, _entries.size() - 1)


func _on_audit_button_pressed() -> void:
	var typed_name: String = _entries[_last_active_entry_index].text.strip_edges()
	if typed_name.is_empty():
		show_audit_result("TYPE A NAME ON THE ACTIVE LINE FIRST", false)
		return
	audit_requested.emit(typed_name)

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
