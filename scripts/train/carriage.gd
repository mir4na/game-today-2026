class_name CarriageVisual
extends Node2D
## Behavior for scene-authored carriage art. Geometry, colors, props and labels live in .tscn/SVG assets.

@export_enum("coal", "passenger", "conductor") var carriage_type: String = "passenger"
@export var carriage_number: int = 0

@onready var _art_root: Node2D = %ArtRoot
@onready var _night_overlay: Polygon2D = %NightOverlay

func set_environment(_scroll: float, night_strength: float, sway_time: float) -> void:
	_night_overlay.modulate.a = clampf(night_strength, 0.0, 1.0)
	_art_root.position.y = sin(sway_time * 2.1 + carriage_number * 0.45) * 1.4
