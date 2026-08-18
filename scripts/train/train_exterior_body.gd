class_name TrainExteriorBody
extends Node2D
## Controls scene-authored exterior layers during station sequences.

var _elapsed: float = 0.0
var _duration: float = 1.0
var _arrival_end: float = 0.0
var _departure_start: float = 1.0

@onready var _closed_cars: Node2D = %ClosedCars
@onready var _open_cars: Node2D = %OpenCars
@onready var _night_overlay: Polygon2D = %ExteriorNightOverlay

func begin_sequence(duration: float, arrival_end: float, departure_start: float, night_strength: float) -> void:
	_duration = maxf(duration, 0.01)
	_arrival_end = maxf(arrival_end, 0.0)
	_departure_start = clampf(departure_start, 0.0, _duration)
	_elapsed = 0.0
	_night_overlay.modulate.a = clampf(night_strength, 0.0, 1.0)
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	_update_door_layers()

func end_sequence() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()

func set_sequence_elapsed(value: float) -> void:
	_elapsed = clampf(value, 0.0, _duration)
	_update_door_layers()

func _process(delta: float) -> void:
	_elapsed = minf(_elapsed + delta, _duration)
	_update_door_layers()

func _update_door_layers() -> void:
	var doors_open: bool = _elapsed >= _arrival_end and _elapsed < _departure_start
	_open_cars.visible = doors_open
	_closed_cars.visible = not doors_open
