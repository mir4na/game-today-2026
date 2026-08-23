class_name TravelForeground
extends CanvasLayer
## Screen-space railway scenery shown only while the train is traveling.

@export_category("Pole Timing")
@export_range(0.5, 30.0, 0.5) var minimum_pole_interval: float = 5.0
@export_range(0.5, 30.0, 0.5) var maximum_pole_interval: float = 11.0
@export_category("Cable Timing")
@export_range(0.5, 30.0, 0.5) var minimum_cable_interval: float = 3.5
@export_range(0.5, 30.0, 0.5) var maximum_cable_interval: float = 8.0
@export_category("Scene Animation")
@export var pole_pass_animation: StringName = &"pole_pass"
@export var cable_pass_animation: StringName = &"cable_pass"

var _traveling: bool = false
var _rng := RandomNumberGenerator.new()

@onready var _travel_scenery: Node2D = %TravelScenery
@onready var _passing_cables: Node2D = %PassingCables
@onready var _passing_pole: Sprite2D = %PassingPole
@onready var _cable_timer: Timer = %CableTimer
@onready var _pole_timer: Timer = %PoleTimer
@onready var _cable_animation: AnimationPlayer = %CableAnimation
@onready var _pole_animation: AnimationPlayer = %PoleAnimation

func _ready() -> void:
	_rng.randomize()
	_travel_scenery.hide()
	_passing_cables.hide()
	_passing_pole.hide()

func set_traveling(value: bool) -> void:
	if _traveling == value:
		return
	_traveling = value
	_travel_scenery.visible = value
	_cable_timer.stop()
	_pole_timer.stop()
	_cable_animation.stop()
	_pole_animation.stop()
	_passing_cables.hide()
	_passing_pole.hide()
	if value:
		_schedule_next_cable()
		_schedule_next_pole()

func _schedule_next_cable() -> void:
	if not _traveling:
		return
	var minimum_interval: float = minf(minimum_cable_interval, maximum_cable_interval)
	var maximum_interval: float = maxf(minimum_cable_interval, maximum_cable_interval)
	_cable_timer.start(_rng.randf_range(minimum_interval, maximum_interval))

func _schedule_next_pole() -> void:
	if not _traveling:
		return
	var minimum_interval: float = minf(minimum_pole_interval, maximum_pole_interval)
	var maximum_interval: float = maxf(minimum_pole_interval, maximum_pole_interval)
	_pole_timer.start(_rng.randf_range(minimum_interval, maximum_interval))

func _on_pole_timer_timeout() -> void:
	if not _traveling:
		return
	_passing_pole.show()
	_pole_animation.play(pole_pass_animation)

func _on_cable_timer_timeout() -> void:
	if not _traveling:
		return
	_passing_cables.show()
	_cable_animation.play(cable_pass_animation)

func _on_pole_animation_finished(animation_name: StringName) -> void:
	if animation_name != pole_pass_animation:
		return
	_passing_pole.hide()
	_schedule_next_pole()

func _on_cable_animation_finished(animation_name: StringName) -> void:
	if animation_name != cable_pass_animation:
		return
	_passing_cables.hide()
	_schedule_next_cable()
