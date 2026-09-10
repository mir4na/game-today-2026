class_name NightStationFaceToken
extends Control
## One compact face marker inside a symbolic station assignment stack.

@onready var _portrait: TextureRect = %Portrait


func configure(passenger_name: String, portrait: Texture2D) -> void:
	_portrait.texture = portrait
	tooltip_text = passenger_name
