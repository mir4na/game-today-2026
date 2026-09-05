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

var _focus_visual: CanvasItem
var _focus_material: ShaderMaterial
var _default_z_index: int
var _default_z_as_relative: bool


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
	_focus_material.set_shader_parameter(&"outline_enabled", false)

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
	if is_instance_valid(_focus_material):
		_focus_material.set_shader_parameter(&"outline_enabled", value)
	if value and raise_on_focus:
		z_as_relative = false
		z_index = focus_z_index
	else:
		z_index = _default_z_index
		z_as_relative = _default_z_as_relative
