class_name NightCharacterPortrait
extends TextureRect
## Crops the immutable character artwork into a compact upper-body portrait.
## Daytime ID anomalies may replace PassengerData.id_photo, so night UI must
## use the passenger's underlying character identity instead.

@export_category("Upper-body Crop")
@export_range(0.0, 1.0, 0.01) var crop_left_ratio: float = 0.13
@export_range(0.0, 1.0, 0.01) var crop_top_ratio: float = 0.04
@export_range(0.01, 1.0, 0.01) var crop_width_ratio: float = 0.74
@export_range(0.01, 1.0, 0.01) var crop_height_ratio: float = 0.55


func set_passenger(data: PassengerData) -> void:
	set_character_artwork(data.get_character_artwork() if data != null else null)


func set_character_artwork(artwork: Texture2D) -> void:
	if artwork == null:
		texture = null
		return
	var artwork_size: Vector2 = artwork.get_size()
	if artwork_size.x <= 0.0 or artwork_size.y <= 0.0:
		texture = artwork
		return

	var left: float = clampf(crop_left_ratio, 0.0, 0.99)
	var top: float = clampf(crop_top_ratio, 0.0, 0.99)
	var width: float = minf(crop_width_ratio, 1.0 - left)
	var height: float = minf(crop_height_ratio, 1.0 - top)
	var cropped := AtlasTexture.new()
	cropped.atlas = artwork
	cropped.region = Rect2(
		Vector2(artwork_size.x * left, artwork_size.y * top),
		Vector2(artwork_size.x * width, artwork_size.y * height)
	)
	texture = cropped


func get_source_artwork() -> Texture2D:
	var cropped := texture as AtlasTexture
	return cropped.atlas if cropped != null else texture
