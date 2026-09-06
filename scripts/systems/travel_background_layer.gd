@tool
class_name TravelBackgroundLayer
extends Node2D
## Scene-authored parallax strip. Artwork sprites remain visible and editable in the scene.

@export_category("Parallax")
@export_range(-500.0, 500.0, 1.0) var scroll_speed: float = 40.0
@export_range(1.0, 8192.0, 1.0) var wrap_width: float = 1280.0
