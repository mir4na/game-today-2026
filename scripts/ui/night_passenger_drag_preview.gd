class_name NightPassengerDragPreview
extends Control
## Scene-authored drag preview that plays the passenger scene's walk cycle.

@export var animation_name: StringName = &"walk"
@export var preview_center: Vector2 = Vector2(63.0, 82.0)
@export var maximum_visual_size: Vector2 = Vector2(118.0, 164.0)


func _ready() -> void:
	_apply_cursor_hotspot()


func configure(data: PassengerData) -> void:
	_apply_cursor_hotspot()
	if data == null:
		return
	var character_sprite := get_node("%CharacterSprite") as AnimatedSprite2D
	var passenger_scene: PackedScene = (
		data.identity_profile.passenger_scene
		if data.identity_profile != null
		else null
	)
	if passenger_scene == null:
		character_sprite.hide()
		return

	# Copy only the authored walk presentation. The full Passenger scene never
	# enters the tree, so dragging cannot start AI, collisions, or interactions.
	var passenger := passenger_scene.instantiate() as Passenger
	if passenger == null:
		character_sprite.hide()
		return
	var source_sprite := passenger.get_node_or_null(
		"CharacterScale/PassengerVisual/NPCVisual"
	) as AnimatedSprite2D
	if (
		source_sprite == null
		or source_sprite.sprite_frames == null
		or not source_sprite.sprite_frames.has_animation(animation_name)
		or source_sprite.sprite_frames.get_frame_count(animation_name) == 0
	):
		passenger.free()
		character_sprite.hide()
		return

	character_sprite.sprite_frames = source_sprite.sprite_frames
	character_sprite.animation = animation_name
	character_sprite.position = preview_center
	_fit_animation(character_sprite)
	character_sprite.show()
	character_sprite.play(animation_name)
	passenger.free()
	tooltip_text = data.short_name


func _apply_cursor_hotspot() -> void:
	# Godot places a drag preview at the pointer using the preview root's
	# origin. Keeping the root offset negative makes preview_center sit exactly
	# under the cursor while the visual remains scene-authored.
	position = -preview_center


func _fit_animation(sprite: AnimatedSprite2D) -> void:
	var frames: SpriteFrames = sprite.sprite_frames
	var frame_texture: Texture2D = frames.get_frame_texture(animation_name, 0)
	if frame_texture == null:
		return
	var texture_size: Vector2 = frame_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var fit_scale: float = minf(
		maximum_visual_size.x / texture_size.x,
		maximum_visual_size.y / texture_size.y
	)
	sprite.scale = Vector2.ONE * fit_scale
