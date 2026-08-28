extends Button
## Drop target for one line of the abnormality log; occupied lines can be reordered.

signal passenger_dropped(slot_index: int, passenger_name: String, source_slot: int)
signal clear_requested(slot_index: int)

@export_range(0, 4, 1) var slot_index: int = 0
var assigned_name: String = ""

func _ready() -> void:
	pressed.connect(_request_clear)
	mouse_default_cursor_shape = Control.CURSOR_CAN_DROP
	_refresh_text()

func set_assignment(passenger_name: String) -> void:
	assigned_name = passenger_name
	_refresh_text()

func _refresh_text() -> void:
	text = "%02d.  DROP PASSENGER HERE" % (slot_index + 1)
	if not assigned_name.is_empty():
		text = "%02d.  %s    ×" % [slot_index + 1, assigned_name.to_upper()]
	tooltip_text = "Drop a passenger here." if assigned_name.is_empty() else "Drag to reorder, or click to remove."

func _get_drag_data(_at_position: Vector2) -> Variant:
	if assigned_name.is_empty():
		return null
	var preview := Button.new()
	preview.text = assigned_name.to_upper()
	preview.custom_minimum_size = Vector2(230.0, 54.0)
	preview.modulate = Color(1.0, 0.93, 0.76, 0.94)
	set_drag_preview(preview)
	return {
		"kind": &"abnormal_passenger",
		"passenger_name": assigned_name,
		"source_slot": slot_index,
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var payload: Dictionary = data
	return (
		payload.get("kind", &"") == &"abnormal_passenger"
		and not str(payload.get("passenger_name", "")).is_empty()
	)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var payload: Dictionary = data
	passenger_dropped.emit(
		slot_index,
		str(payload.get("passenger_name", "")),
		int(payload.get("source_slot", -1))
	)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		self_modulate = Color(1.08, 1.02, 0.86, 1.0)
	elif what == NOTIFICATION_DRAG_END:
		self_modulate = Color.WHITE

func _request_clear() -> void:
	if not assigned_name.is_empty():
		clear_requested.emit(slot_index)
