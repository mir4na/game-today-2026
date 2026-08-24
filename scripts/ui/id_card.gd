class_name PassengerIDCard
extends Control
## Scene-authored identity card. Runtime content is projected from PassengerData.

@export_category("Fallback Copy")
@export var missing_value_text: String = "NOT RECORDED"

var passenger_data: PassengerData

@onready var _photo: TextureRect = %Photo
@onready var _full_name: Label = %FullName
@onready var _identity_number: Label = %IdentityNumber
@onready var _birth_place: Label = %BirthPlace
@onready var _date_of_birth: Label = %DateOfBirth

func set_passenger(value: PassengerData) -> void:
	passenger_data = value
	if not is_node_ready():
		await ready
	if passenger_data == null:
		clear()
		return
	_photo.texture = passenger_data.id_photo
	_full_name.text = _display_value(passenger_data.passenger_name)
	_identity_number.text = _display_value(passenger_data.identity_number)
	_birth_place.text = _display_value(passenger_data.birth_place)
	_date_of_birth.text = _display_value(passenger_data.date_of_birth)

func clear() -> void:
	_photo.texture = null
	_full_name.text = missing_value_text
	_identity_number.text = missing_value_text
	_birth_place.text = missing_value_text
	_date_of_birth.text = missing_value_text

func _display_value(value: String) -> String:
	var cleaned_value: String = value.strip_edges()
	return cleaned_value if not cleaned_value.is_empty() else missing_value_text
