class_name Interactable
extends Area2D
## Small common contract used by every contextual interaction in the train.

signal interaction_requested(interactable: Interactable)

@export var prompt_text: String = "Interact"
@export var interaction_distance: float = 112.0
@export var enabled: bool = true
@export_category("Interaction Placement")
@export_node_path("Node2D") var interaction_origin_path: NodePath
@export_category("Prompt Placement")
@export_node_path("Node2D") var prompt_anchor_path: NodePath
@export_category("Focus Presentation")
@export_node_path("CanvasItem") var focus_visual_path: NodePath
@export var raise_on_focus: bool = true
@export_range(1, 4096, 1) var focus_z_index: int = 100
@export var outline_while_enabled: bool = false
@export var passive_outline_color: Color = Color(0.015, 0.018, 0.024, 1.0)
@export_range(1.0, 8.0, 0.5) var passive_outline_width: float = 5.0
@export_range(0.05, 0.6, 0.01) var interaction_lock_fade_duration: float = 0.2

var _focus_visual: CanvasItem
var _focus_material: ShaderMaterial
var _default_z_index: int
var _default_z_as_relative: bool
var _interaction_locked: bool = false
var _interaction_focused: bool = false
var _interaction_lock_strength: float = 0.0
var _interaction_lock_tween: Tween
var _focus_outline_color: Color = Color(0.96, 0.78, 0.32, 1.0)
var _focus_outline_width: float = 4.0


func _ready() -> void:
	_default_z_index = z_index
	_default_z_as_relative = z_as_relative
	if focus_visual_path.is_empty():
		return
	_focus_visual = get_node_or_null(focus_visual_path) as CanvasItem
	if not is_instance_valid(_focus_visual):
		push_warning("%s is missing its configured focus visual." % name)
		return
	var configured_material := _focus_visual.material as ShaderMaterial
	if configured_material == null:
		push_warning("%s focus visual requires a ShaderMaterial in its scene." % name)
		return
	_focus_material = configured_material.duplicate() as ShaderMaterial
	_focus_material.resource_local_to_scene = true
	_focus_visual.material = _focus_material
	_focus_outline_color = _focus_material.get_shader_parameter(&"outline_color") as Color
	_focus_outline_width = float(_focus_material.get_shader_parameter(&"outline_width"))
	_focus_material.set_shader_parameter(&"interaction_lock_strength", 0.0)
	_focus_material.set_shader_parameter(&"radar_detection_strength", 0.0)
	_refresh_interaction_outline()

func get_prompt() -> String:
	return "[E] %s" % prompt_text

func get_interaction_world_position() -> Vector2:
	if not interaction_origin_path.is_empty():
		var configured_origin := get_node_or_null(interaction_origin_path) as Node2D
		if is_instance_valid(configured_origin):
			return configured_origin.global_position
	return global_position

func get_prompt_anchor() -> Node2D:
	if not prompt_anchor_path.is_empty():
		var configured_anchor := get_node_or_null(prompt_anchor_path) as Node2D
		if is_instance_valid(configured_anchor):
			return configured_anchor
	return self

func can_interact() -> bool:
	return enabled and visible

func interact() -> void:
	interaction_requested.emit(self)

func set_interaction_focus(value: bool) -> void:
	_interaction_focused = value
	_refresh_interaction_outline()
	if value and raise_on_focus:
		z_as_relative = false
		z_index = focus_z_index
	else:
		z_index = _default_z_index
		z_as_relative = _default_z_as_relative


func refresh_interaction_outline() -> void:
	_refresh_interaction_outline()


func _refresh_interaction_outline() -> void:
	if not is_instance_valid(_focus_material):
		return
	var passive_active: bool = outline_while_enabled and enabled and visible
	_focus_material.set_shader_parameter(&"outline_enabled", _interaction_focused or passive_active)
	_focus_material.set_shader_parameter(
		&"outline_color",
		_focus_outline_color if _interaction_focused else passive_outline_color
	)
	_focus_material.set_shader_parameter(
		&"outline_width",
		_focus_outline_width if _interaction_focused else passive_outline_width
	)


func set_interaction_locked(value: bool, immediate: bool = false) -> void:
	if value == _interaction_locked and not immediate:
		return
	_interaction_locked = value
	if is_instance_valid(_interaction_lock_tween):
		_interaction_lock_tween.kill()
	var target_strength: float = 1.0 if value else 0.0
	if immediate or not is_inside_tree() or not is_instance_valid(_focus_material):
		_set_interaction_lock_strength(target_strength)
		return
	_interaction_lock_tween = create_tween()
	_interaction_lock_tween.tween_method(
		_set_interaction_lock_strength,
		_interaction_lock_strength,
		target_strength,
		interaction_lock_fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_interaction_lock_strength(value: float) -> void:
	_interaction_lock_strength = clampf(value, 0.0, 1.0)
	if is_instance_valid(_focus_material):
		_focus_material.set_shader_parameter(&"interaction_lock_strength", _interaction_lock_strength)
