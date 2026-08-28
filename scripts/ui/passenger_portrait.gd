class_name PassengerPortrait
extends Control

var passenger_data: PassengerData

@onready var _portrait_visual: Node2D = %PortraitVisual
@onready var _body_tint: Node2D = %BodyTint
@onready var _name_label: Label = %NameLabel

func set_passenger(value: PassengerData) -> void:
	passenger_data = value
	if passenger_data == null:
		_portrait_visual.visible = false
		_name_label.text = ""
		return
	_portrait_visual.visible = true
	_portrait_visual.scale = Vector2.ONE
	_portrait_visual.position.y = 270.0
	_body_tint.modulate = passenger_data.body_color
	_name_label.text = passenger_data.short_name.to_upper()
