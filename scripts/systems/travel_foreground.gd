class_name TravelForeground
extends CanvasLayer
## Screen-space railway scenery that moves in transit and rests at stations.

@export_category("Pole Timing")
@export_range(0.5, 30.0, 0.5) var minimum_pole_interval: float = 2.5
@export_range(0.5, 30.0, 0.5) var maximum_pole_interval: float = 5.5
@export_category("Cable Timing")
@export_range(0.5, 30.0, 0.5) var minimum_cable_interval: float = 1.5
@export_range(0.5, 30.0, 0.5) var maximum_cable_interval: float = 3.5
@export_category("Scene Animation")
@export var pole_pass_animation: StringName = &"pole_pass"
@export var cable_pass_animation: StringName = &"cable_pass"

var _traveling: bool = false
var _motion_strength: float = 0.0
var _scenery_started: bool = false
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
	set_motion_strength(1.0 if value else 0.0)


func set_motion_strength(value: float) -> void:
	var next_strength: float = clampf(value, 0.0, 1.0)
	var was_traveling: bool = _traveling
	_motion_strength = next_strength
	_traveling = _motion_strength > 0.001
	_cable_animation.speed_scale = _motion_strength
	_pole_animation.speed_scale = _motion_strength
	if _traveling == was_traveling:
		return
	_cable_timer.stop()
	_pole_timer.stop()
	if _traveling:
		_scenery_started = true
		_travel_scenery.show()
		_resume_or_start_animation(_cable_animation, cable_pass_animation, _passing_cables)
		_cable_animation.speed_scale = _motion_strength
		if _passing_pole.visible:
			_resume_or_start_animation(_pole_animation, pole_pass_animation, _passing_pole)
			_pole_animation.speed_scale = _motion_strength
		else:
			_schedule_next_pole()
	elif _scenery_started:
		# Keep the exact final positions from deceleration. Stopping the animation
		# would apply its RESET track and make the scenery visibly teleport.
		_cable_animation.pause()
		_pole_animation.pause()
		_travel_scenery.show()

func _resume_or_start_animation(animation: AnimationPlayer, animation_name: StringName, visual: CanvasItem) -> void:
	visual.show()
	var can_resume: bool = (
		animation.assigned_animation == animation_name
		and animation.current_animation_position > 0.0
		and animation.current_animation_position < animation.current_animation_length
	)
	if can_resume:
		animation.play()
	else:
		animation.play(animation_name)

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
	_pole_animation.speed_scale = _motion_strength

func _on_cable_timer_timeout() -> void:
	if not _traveling:
		return
	_passing_cables.show()
	_cable_animation.play(cable_pass_animation)
	_cable_animation.speed_scale = _motion_strength

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
