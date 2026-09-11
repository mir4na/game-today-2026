class_name NightPassengerDragPreview
extends Control
## Scene-authored static soul pose that leans toward the current drag motion.

@export var pose_animation_name: StringName = &"walk"
@export_range(0, 30, 1) var pose_frame: int = 0
@export var preview_center: Vector2 = Vector2(63.0, 82.0)
@export var maximum_visual_size: Vector2 = Vector2(118.0, 164.0)
@export_range(0.1, 3.0, 0.05) var visual_scale_multiplier: float = 1.0
@export_category("Drag Lean")
@export_range(0.0, 30.0, 1.0) var maximum_lean_degrees: float = 16.0
@export_range(100.0, 3000.0, 50.0) var speed_for_maximum_lean: float = 900.0
@export_range(1.0, 30.0, 0.5) var lean_response_speed: float = 14.0
@export_range(1.0, 30.0, 0.5) var lean_return_speed: float = 10.0

var _drag_motion_initialized: bool = false
var _last_cursor_position: Vector2

@onready var _character_sprite: AnimatedSprite2D = %CharacterSprite


func _ready() -> void:
	_apply_cursor_hotspot()


func configure(data: PassengerData) -> void:
	_apply_cursor_hotspot()
	if data == null:
		return
	var character_sprite := get_node("%CharacterSprite") as AnimatedSprite2D
	_character_sprite = character_sprite
	var passenger_scene: PackedScene = (
		data.identity_profile.passenger_scene
		if data.identity_profile != null
		else null
	)
	if passenger_scene == null:
		character_sprite.hide()
		return

	# Copy one authored animation frame only. The full Passenger scene never
	# enters the tree, and the preview deliberately has no walking playback.
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
		or not source_sprite.sprite_frames.has_animation(pose_animation_name)
		or source_sprite.sprite_frames.get_frame_count(pose_animation_name) == 0
	):
		passenger.free()
		character_sprite.hide()
		return

	character_sprite.sprite_frames = source_sprite.sprite_frames
	character_sprite.stop()
	character_sprite.animation = pose_animation_name
	character_sprite.frame = clampi(
		pose_frame,
		0,
		character_sprite.sprite_frames.get_frame_count(pose_animation_name) - 1
	)
	character_sprite.frame_progress = 0.0
	_fit_animation(character_sprite)
	character_sprite.show()
	passenger.free()
	tooltip_text = data.short_name


func update_drag_position(cursor_position: Vector2, delta: float) -> void:
	global_position = cursor_position - preview_center
	if not _drag_motion_initialized:
		_drag_motion_initialized = true
		_last_cursor_position = cursor_position
		return
	var safe_delta: float = maxf(delta, 0.001)
	var horizontal_speed: float = (cursor_position.x - _last_cursor_position.x) / safe_delta
	_last_cursor_position = cursor_position
	var speed_ratio: float = clampf(
		horizontal_speed / maxf(speed_for_maximum_lean, 1.0),
		-1.0,
		1.0
	)
	var target_rotation: float = deg_to_rad(maximum_lean_degrees) * speed_ratio
	var response_speed: float = (
		lean_return_speed if is_zero_approx(target_rotation) else lean_response_speed
	)
	var blend: float = 1.0 - exp(-response_speed * safe_delta)
	_character_sprite.rotation = lerp_angle(
		_character_sprite.rotation,
		target_rotation,
		clampf(blend, 0.0, 1.0)
	)


func _apply_cursor_hotspot() -> void:
	# Godot places a drag preview at the pointer using the preview root's
	# origin. Use the visible placeholder's authored position as the hotspot so
	# moving CharacterSprite in this scene keeps the NPC centered on the cursor.
	var character_sprite := get_node_or_null("%CharacterSprite") as AnimatedSprite2D
	if character_sprite != null:
		preview_center = character_sprite.position
	position = -preview_center


func _fit_animation(sprite: AnimatedSprite2D) -> void:
	var frames: SpriteFrames = sprite.sprite_frames
	var frame_texture: Texture2D = frames.get_frame_texture(
		pose_animation_name,
		clampi(pose_frame, 0, frames.get_frame_count(pose_animation_name) - 1)
	)
	if frame_texture == null:
		return
	var texture_size: Vector2 = frame_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var fit_scale: float = minf(
		maximum_visual_size.x / texture_size.x,
		maximum_visual_size.y / texture_size.y
	)
	sprite.scale = Vector2.ONE * fit_scale * visual_scale_multiplier
