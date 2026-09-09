class_name NightPassengerCard
extends Control
## Scene-authored draggable Soul Record card used by the Night Ledger.

signal selected(passenger_name: String)

@export var drag_preview_scene: PackedScene

var passenger_name: String = ""
var assigned_station: String = ""
var _passenger_data: PassengerData

@onready var _portrait: TextureRect = %Portrait
@onready var _assigned_overlay: ColorRect = %AssignedOverlay
@onready var _name_label: Label = %PassengerName
@onready var _anomaly_label: Label = %AnomalyLabel
@onready var _statement_label: Label = %StatementLabel
@onready var _assignment_label: Label = %AssignmentLabel


func configure(data: PassengerData, statement: String, anomaly_label: String) -> void:
	_passenger_data = data
	passenger_name = data.short_name
	_portrait.texture = data.get_character_artwork()
	_name_label.text = data.short_name.to_upper()
	_anomaly_label.text = anomaly_label
	# Keep the ledger wording byte-for-byte identical to the sentence selected
	# from the Soul Record. Wrapping is visual only; the copy is never shortened.
	_statement_label.text = statement if not statement.is_empty() else "Statement not recorded"
	_statement_label.tooltip_text = statement
	_statement_label.modulate = Color("453b38") if not statement.is_empty() else Color("8f8178")
	show()


func set_assignment(station: String) -> void:
	assigned_station = station
	_assignment_label.text = station.to_upper() if not station.is_empty() else "UNASSIGNED"
	_assigned_overlay.visible = not station.is_empty()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if passenger_name.is_empty() or _passenger_data == null:
		return null
	selected.emit(passenger_name)
	if drag_preview_scene != null:
		var preview := drag_preview_scene.instantiate() as NightPassengerDragPreview
		if preview != null:
			preview.configure(_passenger_data)
			set_drag_preview(preview)
	return {
		"kind": &"night_soul_card",
		"passenger_name": passenger_name,
	}


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		selected.emit(passenger_name)
