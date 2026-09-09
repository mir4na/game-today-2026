class_name NightPassengerDragPreview
extends Control
## Scene-authored drag preview. The ledger provides only the passenger data;
## sizing, shadow, and presentation remain editable in the scene.

func configure(data: PassengerData) -> void:
	if data == null:
		return
	# Drag previews are configured before Godot adds them to the viewport, so
	# resolve their scene-authored nodes directly instead of relying on _ready.
	var character_sprite := get_node("%CharacterSprite") as TextureRect
	var name_label := get_node("%PassengerName") as Label
	character_sprite.texture = data.get_character_artwork()
	name_label.text = data.short_name.to_upper()
	tooltip_text = data.short_name
