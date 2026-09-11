class_name IntroHoldRing
extends Control
## Lightweight radial progress indicator for the intro's hold-to-skip gesture.

@export_range(2.0, 10.0, 0.5) var ring_width: float = 4.0
@export var track_color := Color(0.29, 0.36, 0.58, 0.62)
@export var fill_color := Color(0.45, 0.67, 0.94, 1.0)
@export var center_color := Color(0.06, 0.08, 0.18, 0.86)

var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var center := size * 0.5
	var radius: float = maxf(1.0, minf(size.x, size.y) * 0.5 - ring_width)
	draw_circle(center, maxf(1.0, radius - ring_width * 0.35), center_color)
	draw_arc(center, radius, 0.0, TAU, 64, track_color, ring_width, true)
	if progress <= 0.0:
		return
	draw_arc(
		center,
		radius,
		-PI * 0.5,
		-PI * 0.5 + TAU * progress,
		64,
		fill_color,
		ring_width,
		true
	)
