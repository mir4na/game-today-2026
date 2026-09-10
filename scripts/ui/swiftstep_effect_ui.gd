class_name SwiftstepEffectUI
extends CanvasLayer
## Screen-space presentation and scene-authored balancing for Swiftstep Soles.

signal effect_finished

@export_category("Effect Timing")
@export_range(1.0, 60.0, 0.5) var effect_duration_seconds: float = 15.0
@export_range(0.1, 2.0, 0.05) var absorb_duration_seconds: float = 0.7
@export_range(0.1, 2.0, 0.05) var release_duration_seconds: float = 0.8
@export_category("World Slowdown")
@export_range(0.05, 1.0, 0.01) var world_time_scale: float = 0.30
@export_category("Player Color Preservation")
@export var world_lighting_path: NodePath

@onready var _screen_effect: ColorRect = %ScreenEffect
@onready var _player_color_copy: Sprite2D = %PlayerColorCopy
@onready var _effect_timer: Timer = %EffectTimer

var _effect_material: ShaderMaterial
var _player: Node2D
var _player_visual: AnimatedSprite2D
var _player_visual_was_visible: bool = false
var _player_visual_original_self_modulate: Color = Color.WHITE
var _world_lighting: CanvasModulate
var _effect_tween: Tween
var _elapsed_seconds: float = 0.0
var _active: bool = false


func _ready() -> void:
	_effect_material = _screen_effect.material as ShaderMaterial
	if _effect_material != null:
		_effect_material = _effect_material.duplicate() as ShaderMaterial
		_screen_effect.material = _effect_material
	if not world_lighting_path.is_empty():
		_world_lighting = get_node_or_null(world_lighting_path) as CanvasModulate
	_screen_effect.hide()
	_player_color_copy.hide()
	set_process(false)


func activate(player: Node2D) -> float:
	if _active:
		return get_world_time_scale()
	_active = true
	_player = player
	_elapsed_seconds = 0.0
	_screen_effect.show()
	set_process(true)
	_set_shader_parameter(&"effect_strength", 0.0)
	_set_shader_parameter(&"burst_strength", 1.0)
	_set_shader_parameter(&"flow_direction", -1.0)
	_update_player_screen_position()
	_prepare_player_color_copy()

	_kill_effect_tween()
	_effect_tween = create_tween().set_parallel(true)
	_effect_tween.tween_method(_set_effect_strength, 0.0, 1.0, absorb_duration_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_effect_tween.tween_method(_set_burst_strength, 1.0, 0.0, absorb_duration_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_effect_timer.start(effect_duration_seconds)
	return get_world_time_scale()


func get_world_time_scale() -> float:
	return clampf(world_time_scale, 0.05, 1.0)


func is_effect_active() -> bool:
	return _active


func _process(delta: float) -> void:
	_elapsed_seconds += delta
	_set_shader_parameter(&"elapsed_seconds", _elapsed_seconds)
	_update_player_screen_position()
	_update_player_color_copy()


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
	_restore_player_visual()
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


func _prepare_player_color_copy() -> void:
	_player_visual = null
	if is_instance_valid(_player):
		_player_visual = _player.get_node_or_null("MCVisual") as AnimatedSprite2D
	if not is_instance_valid(_player_visual):
		_player_color_copy.hide()
		return
	_player_visual_was_visible = _player_visual.visible
	_player_visual_original_self_modulate = _player_visual.self_modulate
	if not _player.is_visible_in_tree() or not _player_visual_was_visible:
		_player_color_copy.hide()
		return
	_update_player_color_copy()
	_player_color_copy.show()
	_player_visual.self_modulate.a = 0.0


func _update_player_color_copy() -> void:
	if not is_instance_valid(_player_visual) or not is_instance_valid(_player) or not _player.is_visible_in_tree():
		_player_color_copy.hide()
		return
	var frames := _player_visual.sprite_frames
	if frames == null or not frames.has_animation(_player_visual.animation):
		_player_color_copy.hide()
		return
	var frame_texture := frames.get_frame_texture(_player_visual.animation, _player_visual.frame)
	if frame_texture == null:
		_player_color_copy.hide()
		return
	_player_color_copy.texture = frame_texture
	_player_color_copy.centered = _player_visual.centered
	_player_color_copy.offset = _player_visual.offset
	_player_color_copy.flip_h = _player_visual.flip_h
	_player_color_copy.flip_v = _player_visual.flip_v
	_player_color_copy.transform = _player_visual.get_global_transform_with_canvas()
	var display_tint := _player_visual.modulate * _player_visual_original_self_modulate
	if is_instance_valid(_world_lighting):
		display_tint *= _world_lighting.color
	_player_color_copy.self_modulate = display_tint


func _restore_player_visual() -> void:
	_player_color_copy.hide()
	if is_instance_valid(_player_visual):
		_player_visual.self_modulate = _player_visual_original_self_modulate
		_player_visual.visible = _player_visual_was_visible
	_player_visual = null


func _exit_tree() -> void:
	_restore_player_visual()


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
