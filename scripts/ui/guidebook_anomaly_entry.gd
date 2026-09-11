@tool
class_name GuidebookAnomalyEntry
extends HBoxContainer
## Scene-authored anomaly section for the guidebook.

enum PhotoSide { LEFT, RIGHT }
enum PhotoFit { COVER, CONTAIN, MANUAL }

@export var heading: String = "ANOMALY":
	set(value):
		heading = value
		_refresh()
@export_multiline var description: String = "":
	set(value):
		description = value
		_refresh()
@export var photo: Texture2D:
	set(value):
		photo = value
		_refresh()
## Optional second photo. Applied to a Sprite2D named "PhotoB" under
## PhotoFrame/PhotoClip/PhotoContent when such a node exists.
@export var photo_secondary: Texture2D:
	set(value):
		photo_secondary = value
		_refresh()
@export var allow_manual_photo_content: bool = true:
	set(value):
		allow_manual_photo_content = value
		_refresh()
@export_enum("Left", "Right") var photo_side: int = PhotoSide.LEFT:
	set(value):
		photo_side = value
		_refresh()
@export var photo_frame_size: Vector2 = Vector2(150.0, 78.0):
	set(value):
		photo_frame_size = value
		_refresh()
@export_enum("Cover", "Contain", "Manual") var photo_fit: int = PhotoFit.COVER:
	set(value):
		photo_fit = value
		_refresh()
@export var photo_offset: Vector2 = Vector2.ZERO:
	set(value):
		photo_offset = value
		_refresh()
@export var photo_scale: Vector2 = Vector2.ONE:
	set(value):
		photo_scale = value
		_refresh()
@export_range(-180.0, 180.0, 0.5) var photo_rotation_degrees: float = 0.0:
	set(value):
		photo_rotation_degrees = value
		_refresh()
@export var align_text_toward_photo: bool = true:
	set(value):
		align_text_toward_photo = value
		_refresh()

func _ready() -> void:
	# Adopt runs in the editor too: @tool _refresh() on scene-open would
	# otherwise snap nested arrangements back to stale exports before play.
	_adopt_scene_state()
	_refresh()


## Whatever is arranged directly on the scene wins at runtime: texture,
## frame size, copy, offset, rotation, and scale are read back into the
## exports before the layout pass, so the editor view and the game match.
## (Export edits already propagate to the nested nodes live via @tool.)
func _adopt_scene_state() -> void:
	_adopt_scene_photo()
	var photo_frame := get_node_or_null(^"PhotoFrame") as Control
	if photo_frame != null and not photo_frame.custom_minimum_size.is_equal_approx(photo_frame_size):
		photo_frame_size = photo_frame.custom_minimum_size
	var heading_label := get_node_or_null(^"Text/Heading") as Label
	if heading_label != null and heading_label.text != heading:
		heading = heading_label.text
	var description_label := get_node_or_null(^"Text/Description") as Label
	if description_label != null and description_label.text != description:
		description = description_label.text
	_adopt_scene_content_transform()


func _adopt_scene_content_transform() -> void:
	var photo_content := get_node_or_null(^"PhotoFrame/PhotoClip/PhotoContent") as Node2D
	if photo_content == null:
		return
	var inner_size := _inner_photo_size()
	var scene_offset: Vector2 = photo_content.position - inner_size * 0.5
	if scene_offset.distance_to(photo_offset) > 0.01:
		photo_offset = scene_offset
	var scene_rotation: float = rad_to_deg(float(photo_content.rotation))
	if not is_equal_approx(scene_rotation, photo_rotation_degrees):
		photo_rotation_degrees = scene_rotation
	var scene_scale := photo_content.scale as Vector2
	if photo_fit == PhotoFit.MANUAL:
		if not scene_scale.is_equal_approx(photo_scale):
			photo_scale = scene_scale
		return
	var fit_scale: Vector2 = _fit_scale_for_texture(photo)
	if fit_scale.x <= 0.0 or fit_scale.y <= 0.0:
		return
	var derived := Vector2(
		scene_scale.x / fit_scale.x,
		scene_scale.y / fit_scale.y
	)
	if not derived.is_equal_approx(photo_scale):
		photo_scale = derived


## A texture painted directly on the scene's Photo sprite wins over the
## photo export, so editor edits stay WYSIWYG at runtime.
func _adopt_scene_photo() -> void:
	var photo_sprite := get_node_or_null(^"PhotoFrame/PhotoClip/PhotoContent/Photo") as Sprite2D
	if (
		photo != null
		and photo_sprite != null
		and photo_sprite.texture != null
		and photo_sprite.texture != photo
	):
		photo = photo_sprite.texture
		return
	var photo_b := get_node_or_null(^"PhotoFrame/PhotoClip/PhotoContent/PhotoB") as Sprite2D
	if (
		photo_secondary != null
		and photo_b != null
		and photo_b.texture != null
		and photo_b.texture != photo_secondary
	):
		photo_secondary = photo_b.texture
		return
	var legacy_photo := get_node_or_null(^"PhotoFrame/Photo") as TextureRect
	if legacy_photo != null and legacy_photo.texture != null and legacy_photo.texture != photo:
		photo = legacy_photo.texture

func _refresh() -> void:
	if not is_node_ready():
		return
	var photo_frame := get_node_or_null(^"PhotoFrame") as Control
	var text_container := get_node_or_null(^"Text") as Control
	if photo_frame != null and text_container != null:
		if photo_side == PhotoSide.RIGHT:
			move_child(text_container, 0)
			move_child(photo_frame, 1)
		else:
			move_child(photo_frame, 0)
			move_child(text_container, 1)
		photo_frame.custom_minimum_size = photo_frame_size

	var heading_label := get_node_or_null(^"Text/Heading") as Label
	var description_label := get_node_or_null(^"Text/Description") as Label
	if heading_label != null:
		heading_label.text = heading
	if description_label != null:
		description_label.text = description

	var photo_clip := get_node_or_null(^"PhotoFrame/PhotoClip") as Control
	if photo_clip == null:
		_refresh_legacy_photo_frame()
		_apply_text_alignment(heading_label, description_label)
		return

	var photo_content := get_node_or_null(^"PhotoFrame/PhotoClip/PhotoContent") as CanvasGroup
	var photo_sprite := get_node_or_null(^"PhotoFrame/PhotoClip/PhotoContent/Photo") as Sprite2D
	var placeholder := get_node_or_null(^"PhotoFrame/PhotoClip/Placeholder") as Label
	photo_clip.custom_minimum_size = _inner_photo_size()
	if photo_sprite != null:
		photo_sprite.texture = photo
		photo_sprite.visible = photo != null
	_refresh_secondary_photo()
	var has_manual_content: bool = allow_manual_photo_content and _has_manual_photo_content(photo_content)
	if placeholder != null:
		placeholder.visible = photo == null and not has_manual_content
	if photo_content != null:
		photo_content.position = _inner_photo_size() * 0.5 + photo_offset
		photo_content.rotation = deg_to_rad(photo_rotation_degrees)
		photo_content.scale = _resolved_photo_scale(photo)
	_apply_text_alignment(heading_label, description_label)



func _refresh_secondary_photo() -> void:
	var photo_b := get_node_or_null(^"PhotoFrame/PhotoClip/PhotoContent/PhotoB") as Sprite2D
	if photo_b == null:
		return
	photo_b.texture = photo_secondary
	photo_b.visible = photo_secondary != null


func _refresh_legacy_photo_frame() -> void:
	var legacy_photo := get_node_or_null(^"PhotoFrame/Photo") as TextureRect
	if legacy_photo != null:
		legacy_photo.texture = photo
		legacy_photo.visible = photo != null
	var legacy_placeholder := get_node_or_null(^"PhotoFrame/Placeholder") as Label
	if legacy_placeholder != null:
		legacy_placeholder.visible = photo == null


func _apply_text_alignment(heading_label: Label, description_label: Label) -> void:
	if not align_text_toward_photo:
		return
	var text_alignment := (
		HORIZONTAL_ALIGNMENT_RIGHT
		if photo_side == PhotoSide.RIGHT
		else HORIZONTAL_ALIGNMENT_LEFT
	)
	if heading_label != null:
		heading_label.horizontal_alignment = text_alignment
	if description_label != null:
		description_label.horizontal_alignment = text_alignment


func _inner_photo_size() -> Vector2:
	return Vector2(
		maxf(1.0, photo_frame_size.x - 12.0),
		maxf(1.0, photo_frame_size.y - 12.0)
	)


func _resolved_photo_scale(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ONE
	if photo_fit == PhotoFit.MANUAL:
		return photo_scale
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return photo_scale
	return _fit_scale_for_texture(texture) * photo_scale


func _fit_scale_for_texture(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ONE
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Vector2.ONE
	var frame_size: Vector2 = _inner_photo_size()
	var fit: float = maxf(frame_size.x / texture_size.x, frame_size.y / texture_size.y)
	if photo_fit == PhotoFit.CONTAIN:
		fit = minf(frame_size.x / texture_size.x, frame_size.y / texture_size.y)
	return Vector2(fit, fit)


func _has_manual_photo_content(photo_content: Node) -> bool:
	if photo_content == null:
		return false
	for child: Node in photo_content.get_children():
		if child.name == &"Photo":
			continue
		var canvas_item := child as CanvasItem
		if canvas_item == null or canvas_item.visible:
			return true
	return false
