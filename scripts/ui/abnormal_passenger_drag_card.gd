extends Button
## A passenger card that can be dragged into the persistent abnormality log.

var passenger_name: String = ""
var _base_text: String = ""

func configure(data: PassengerData) -> void:
	passenger_name = data.short_name
	_base_text = "%s\nCOACH %d  •  AGE %d" % [data.short_name.to_upper(), data.current_carriage, data.age]
	text = _base_text
	custom_minimum_size = Vector2(0.0, 62.0)
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = "Drag %s into an abnormality log slot." % data.short_name

func set_logged(value: bool) -> void:
	text = "%s\nLOGGED" % _base_text if value else _base_text
	modulate = Color(0.78, 0.82, 0.88, 0.72) if value else Color.WHITE

func _get_drag_data(_at_position: Vector2) -> Variant:
	if passenger_name.is_empty():
		return null
	var preview := Button.new()
	preview.text = passenger_name.to_upper()
	preview.custom_minimum_size = Vector2(230.0, 54.0)
	preview.modulate = Color(1.0, 0.93, 0.76, 0.94)
	set_drag_preview(preview)
	return {
		"kind": &"abnormal_passenger",
		"passenger_name": passenger_name,
		"source_slot": -1,
	}
