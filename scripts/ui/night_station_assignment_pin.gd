class_name NightStationAssignmentPin
extends Control
## One assigned soul on a station path. The portrait placeholder stays in this
## scene so its framing can be adjusted independently from the map layout.

@onready var _character_placeholder: NightCharacterPortrait = %CharacterPlaceholder


func configure(passenger_name: String, portrait: Texture2D) -> void:
	_character_placeholder.set_character_artwork(portrait)
	tooltip_text = passenger_name
