class_name TravelForeground
extends CanvasLayer
## Screen-space railway scenery that moves in transit and rests at stations.

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
var _motion_strength: float = 0.0
var _scenery_started: bool = false
var _station_hidden: bool = false
var _world_time_scale: float = 1.0
var _cinematic_speed_multiplier: float = 1.0
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


func set_station_hidden(value: bool) -> void:
	_station_hidden = value
	_refresh_scenery_visibility()


func set_motion_strength(value: float) -> void:
	var next_strength: float = clampf(value, 0.0, 1.0)
	var was_traveling: bool = _traveling
	_motion_strength = next_strength
	_traveling = _motion_strength > 0.001
	_apply_animation_speed()
	if _traveling == was_traveling:
		return
	_cable_timer.stop()
	_pole_timer.stop()
	if _traveling:
		_scenery_started = true
		_refresh_scenery_visibility()
		_resume_or_start_animation(_cable_animation, cable_pass_animation, _passing_cables)
		_apply_animation_speed()
		if _passing_pole.visible:
			_resume_or_start_animation(_pole_animation, pole_pass_animation, _passing_pole)
			_apply_animation_speed()
		else:
			_schedule_next_pole()
	elif _scenery_started:
		# Keep the exact final positions from deceleration. Stopping the animation
		# would apply its RESET track and make the scenery visibly teleport.
		_cable_animation.pause()
		_pole_animation.pause()
		_refresh_scenery_visibility()


func set_world_time_scale(value: float) -> void:
	var previous_scale: float = _world_time_scale
	_world_time_scale = clampf(value, 0.05, 1.0)
	_rescale_running_timer(_cable_timer, previous_scale, _world_time_scale)
	_rescale_running_timer(_pole_timer, previous_scale, _world_time_scale)
	_apply_animation_speed()


func set_cinematic_speed_multiplier(value: float) -> void:
	var previous_multiplier: float = _cinematic_speed_multiplier
	_cinematic_speed_multiplier = clampf(value, 1.0, 6.0)
	_rescale_running_timer(
		_cable_timer,
		previous_multiplier,
		_cinematic_speed_multiplier
	)
	_rescale_running_timer(
		_pole_timer,
		previous_multiplier,
		_cinematic_speed_multiplier
	)
	_apply_animation_speed()


func _apply_animation_speed() -> void:
	var effective_speed: float = (
		_motion_strength
		* _world_time_scale
		* _cinematic_speed_multiplier
	)
	_cable_animation.speed_scale = effective_speed
	_pole_animation.speed_scale = effective_speed


func _rescale_running_timer(timer: Timer, previous_scale: float, next_scale: float) -> void:
	if not is_instance_valid(timer) or timer.is_stopped():
		return
	var world_seconds_remaining: float = timer.time_left * maxf(previous_scale, 0.05)
	timer.start(world_seconds_remaining / maxf(next_scale, 0.05))


func _refresh_scenery_visibility() -> void:
	_travel_scenery.visible = _scenery_started and not _station_hidden

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
	_cable_timer.start(
		_rng.randf_range(minimum_interval, maximum_interval)
		/ (_world_time_scale * _cinematic_speed_multiplier)
	)

func _schedule_next_pole() -> void:
	if not _traveling:
		return
	var minimum_interval: float = minf(minimum_pole_interval, maximum_pole_interval)
	var maximum_interval: float = maxf(minimum_pole_interval, maximum_pole_interval)
	_pole_timer.start(
		_rng.randf_range(minimum_interval, maximum_interval)
		/ (_world_time_scale * _cinematic_speed_multiplier)
	)

func _on_pole_timer_timeout() -> void:
	if not _traveling:
		return
	_passing_pole.show()
	_pole_animation.play(pole_pass_animation)
	_apply_animation_speed()

func _on_cable_timer_timeout() -> void:
	if not _traveling:
		return
	_passing_cables.show()
	_cable_animation.play(cable_pass_animation)
	_apply_animation_speed()

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
