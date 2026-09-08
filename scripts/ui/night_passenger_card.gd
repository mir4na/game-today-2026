class_name NightPassengerCard
extends Control
## Scene-authored draggable Soul Record card used by the Night Ledger.

signal selected(passenger_name: String)

var passenger_name: String = ""
var assigned_station: String = ""

@onready var _portrait: TextureRect = %Portrait
@onready var _name_label: Label = %PassengerName
@onready var _anomaly_label: Label = %AnomalyLabel
@onready var _statement_label: Label = %StatementLabel
@onready var _assignment_label: Label = %AssignmentLabel


func configure(data: PassengerData, statement: String, anomaly_label: String) -> void:
	passenger_name = data.short_name
	_portrait.texture = data.id_photo
	_name_label.text = data.short_name.to_upper()
	_anomaly_label.text = anomaly_label
	_statement_label.text = statement if not statement.is_empty() else "Statement not recorded"
	_statement_label.modulate = Color("453b38") if not statement.is_empty() else Color("8f8178")
	show()


func set_assignment(station: String) -> void:
	assigned_station = station
	_assignment_label.text = station.to_upper() if not station.is_empty() else "UNASSIGNED"


func _get_drag_data(_at_position: Vector2) -> Variant:
	if passenger_name.is_empty():
		return null
	selected.emit(passenger_name)
	var preview := duplicate() as Control
	if preview != null:
		preview.modulate.a = 0.92
		preview.scale = Vector2(0.86, 0.86)
		_set_mouse_ignored(preview)
		set_drag_preview(preview)
	return {
		"kind": &"night_soul_card",
		"passenger_name": passenger_name,
	}


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		selected.emit(passenger_name)


func _set_mouse_ignored(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_set_mouse_ignored(child)
