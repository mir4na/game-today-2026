class_name SwiftstepEffectUI
extends CanvasLayer
## Screen-space presentation and scene-authored balancing for Swiftstep Soles.

signal effect_finished

@export_category("Effect Timing")
@export_range(1.0, 60.0, 0.5) var effect_duration_seconds: float = 15.0
@export_range(0.1, 2.0, 0.05) var absorb_duration_seconds: float = 0.7
@export_range(0.1, 2.0, 0.05) var release_duration_seconds: float = 0.8
@export_category("World Speed By Upgrade Level")
@export var world_time_scales: PackedFloat32Array = PackedFloat32Array([0.30, 0.20, 0.12])

@onready var _screen_effect: ColorRect = %ScreenEffect
@onready var _effect_timer: Timer = %EffectTimer

var _effect_material: ShaderMaterial
var _player: Node2D
var _effect_tween: Tween
var _elapsed_seconds: float = 0.0
var _active: bool = false


func _ready() -> void:
	_effect_material = _screen_effect.material as ShaderMaterial
	if _effect_material != null:
		_effect_material = _effect_material.duplicate() as ShaderMaterial
		_screen_effect.material = _effect_material
	_screen_effect.hide()
	set_process(false)


func activate(player: Node2D, upgrade_level: int) -> float:
	if _active:
		return get_world_time_scale(upgrade_level)
	_active = true
	_player = player
	_elapsed_seconds = 0.0
	_screen_effect.show()
	set_process(true)
	_set_shader_parameter(&"effect_strength", 0.0)
	_set_shader_parameter(&"burst_strength", 1.0)
	_set_shader_parameter(&"flow_direction", -1.0)
	_update_player_screen_position()

	_kill_effect_tween()
	_effect_tween = create_tween().set_parallel(true)
	_effect_tween.tween_method(_set_effect_strength, 0.0, 1.0, absorb_duration_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_effect_tween.tween_method(_set_burst_strength, 1.0, 0.0, absorb_duration_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_effect_timer.start(effect_duration_seconds)
	return get_world_time_scale(upgrade_level)


func get_world_time_scale(upgrade_level: int) -> float:
	if world_time_scales.is_empty():
		return 0.2
	return clampf(world_time_scales[clampi(upgrade_level - 1, 0, world_time_scales.size() - 1)], 0.05, 1.0)


func is_effect_active() -> bool:
	return _active


func _process(delta: float) -> void:
	_elapsed_seconds += delta
	_set_shader_parameter(&"elapsed_seconds", _elapsed_seconds)
	_update_player_screen_position()


func _on_effect_timer_timeout() -> void:
	if not _active:
		return
	_set_shader_parameter(&"flow_direction", 1.0)
	_set_shader_parameter(&"burst_strength", 1.0)
	_kill_effect_tween()
	_effect_tween = create_tween().set_parallel(true)
	_effect_tween.tween_method(_set_effect_strength, 1.0, 0.0, release_duration_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_effect_tween.tween_method(_set_burst_strength, 1.0, 0.0, release_duration_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_effect_tween.chain().tween_callback(_finish_effect)


func _finish_effect() -> void:
	_active = false
	_player = null
	_screen_effect.hide()
	set_process(false)
	effect_finished.emit()


func _update_player_screen_position() -> void:
	if not is_instance_valid(_player) or _effect_material == null:
		return
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var screen_position: Vector2 = _player.get_global_transform_with_canvas().origin
	_effect_material.set_shader_parameter(&"player_screen_uv", screen_position / viewport_size)


func _set_effect_strength(value: float) -> void:
	_set_shader_parameter(&"effect_strength", value)


func _set_burst_strength(value: float) -> void:
	_set_shader_parameter(&"burst_strength", value)


func _set_shader_parameter(parameter_name: StringName, value: Variant) -> void:
	if _effect_material != null:
		_effect_material.set_shader_parameter(parameter_name, value)


func _kill_effect_tween() -> void:
	if is_instance_valid(_effect_tween) and _effect_tween.is_valid():
		_effect_tween.kill()
