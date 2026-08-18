class_name TrainWorld
extends Node2D

var _scroll: float = 0.0
var _night_strength: float = 0.0
var _sway_time: float = 0.0
var _carriages: Array[CarriageVisual] = []

@onready var _exterior_body: TrainExteriorBody = %ExteriorBody

func _ready() -> void:
	for child: Node in get_children():
		if child is CarriageVisual:
			_carriages.append(child as CarriageVisual)

func _process(delta: float) -> void:
	_sway_time += delta
	_scroll = fmod(_scroll + delta * lerpf(95.0, 48.0, _night_strength), 10000.0)
	for carriage: CarriageVisual in _carriages:
		carriage.set_environment(_scroll, _night_strength, _sway_time)

func set_night_strength(value: float) -> void:
	_night_strength = clampf(value, 0.0, 1.0)

func show_exterior_body(duration: float, arrival_end: float, departure_start: float) -> void:
	_exterior_body.begin_sequence(duration, arrival_end, departure_start, _night_strength)

func hide_exterior_body() -> void:
	_exterior_body.end_sequence()

func set_exterior_sequence_elapsed(value: float) -> void:
	_exterior_body.set_sequence_elapsed(value)

func is_exterior_body_visible() -> bool:
	return _exterior_body.visible
