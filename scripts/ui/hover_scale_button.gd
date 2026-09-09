class_name HoverScaleButton
extends BaseButton
## Reusable scene component that gives UI buttons a centered hover lift.

@export_range(1.0, 1.2, 0.01) var hover_scale: float = 1.07
@export_range(0.05, 0.35, 0.01) var hover_in_duration: float = 0.11
@export_range(0.05, 0.35, 0.01) var hover_out_duration: float = 0.14

var _rest_scale: Vector2
var _hovered: bool = false
var _hover_tween: Tween


func _ready() -> void:
	_rest_scale = scale
	_refresh_pivot()
	resized.connect(_refresh_pivot)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	visibility_changed.connect(_on_visibility_changed)


func _process(_delta: float) -> void:
	if _hovered and disabled:
		_set_hovered(false)


func _refresh_pivot() -> void:
	pivot_offset = size * 0.5


func _set_hovered(value: bool) -> void:
	_hovered = value and not disabled
	_animate_scale(_rest_scale * (hover_scale if _hovered else 1.0), value)


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		return
	_hovered = false
	if is_instance_valid(_hover_tween):
		_hover_tween.kill()
	scale = _rest_scale


func _animate_scale(target_scale: Vector2, entering: bool) -> void:
	if is_instance_valid(_hover_tween):
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(
		self,
		^"scale",
		target_scale,
		hover_in_duration if entering else hover_out_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
