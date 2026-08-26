class_name CarriageVisual
extends Node2D
## Behavior for scene-authored carriage art. Geometry, colors, props and labels live in .tscn/SVG assets.

@export_enum("coal", "passenger", "conductor") var carriage_type: String = "passenger"
@export var carriage_number: int = 0
@export_range(1.0, 4096.0, 1.0) var carriage_width: float = 960.0
@export_category("Passenger Layout")
@export_node_path("Node2D") var passenger_seat_slots_path: NodePath
@export_node_path("Node2D") var passenger_activity_slots_path: NodePath
@export_node_path("Node2D") var passenger_door_slots_path: NodePath
@export_category("Scene Visuals")
@export_node_path("Node2D") var sway_root_path: NodePath
@export_node_path("CanvasItem") var night_overlay_path: NodePath
@export_node_path("Node2D") var exterior_visual_path: NodePath
@export_node_path("AnimationPlayer") var door_animation_path: NodePath
@export var exterior_wipe_parameter: StringName = &"wipe_progress"
@export_category("Door Animations")
@export var door_reset_animation: StringName = &"RESET"
@export var door_open_animation: StringName = &"door_open"
@export var door_close_animation: StringName = &"door_close"

@onready var _sway_root: Node2D = _get_optional_node(sway_root_path) as Node2D
@onready var _night_overlay: CanvasItem = _get_optional_node(night_overlay_path) as CanvasItem
@onready var _exterior_visual: Node2D = _get_optional_node(exterior_visual_path) as Node2D
@onready var _door_animation: AnimationPlayer = _get_optional_node(door_animation_path) as AnimationPlayer

func _ready() -> void:
	end_exterior_mode()

func set_environment(_scroll: float, night_strength: float, sway_time: float) -> void:
	if is_instance_valid(_night_overlay):
		_night_overlay.modulate.a = clampf(night_strength, 0.0, 1.0)
	if is_instance_valid(_sway_root):
		_sway_root.position.y = sin(sway_time * 2.1 + carriage_number * 0.45) * 1.4

func begin_exterior_mode() -> void:
	if not is_instance_valid(_exterior_visual):
		return
	_exterior_visual.show()
	_exterior_visual.process_mode = Node.PROCESS_MODE_INHERIT
	_exterior_visual.modulate.a = 1.0
	_exterior_visual.position.y = 0.0
	_set_exterior_wipe_progress(0.0)
	_reset_exterior_doors()

func set_exterior_transition(alpha: float, vertical_offset: float, wipe_progress: float) -> void:
	if not is_instance_valid(_exterior_visual) or not _exterior_visual.visible:
		return
	_exterior_visual.modulate.a = clampf(alpha, 0.0, 1.0)
	_exterior_visual.position.y = vertical_offset
	_set_exterior_wipe_progress(wipe_progress)

func end_exterior_mode() -> void:
	if is_instance_valid(_exterior_visual):
		_exterior_visual.hide()
		_exterior_visual.process_mode = Node.PROCESS_MODE_DISABLED
		_exterior_visual.modulate.a = 1.0
		_exterior_visual.position.y = 0.0
		_set_exterior_wipe_progress(0.0)
	_reset_exterior_doors()

func set_exterior_doors_open(value: bool) -> void:
	_play_door_animation(door_open_animation if value else door_close_animation)

func get_passenger_seat_slots() -> Array[Marker2D]:
	return _get_marker_children(passenger_seat_slots_path)

func get_passenger_activity_slots() -> Array[Marker2D]:
	return _get_marker_children(passenger_activity_slots_path)

func get_passenger_door_slots() -> Array[Marker2D]:
	return _get_marker_children(passenger_door_slots_path)

func _get_marker_children(root_path: NodePath) -> Array[Marker2D]:
	var markers: Array[Marker2D] = []
	if root_path.is_empty():
		return markers
	var root: Node = get_node_or_null(root_path)
	if root == null:
		return markers
	for child: Node in root.get_children():
		if child is Marker2D:
			markers.append(child as Marker2D)
	return markers

func _get_optional_node(node_path: NodePath) -> Node:
	if node_path.is_empty():
		return null
	return get_node_or_null(node_path)

func _set_exterior_wipe_progress(value: float) -> void:
	if not is_instance_valid(_exterior_visual):
		return
	var shader_material := _exterior_visual.material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter(exterior_wipe_parameter, clampf(value, 0.0, 1.0))

func _reset_exterior_doors() -> void:
	if not is_instance_valid(_door_animation):
		return
	if not _door_animation.has_animation(door_reset_animation):
		push_warning("Missing carriage door reset animation: %s" % door_reset_animation)
		return
	_door_animation.play(door_reset_animation)
	_door_animation.advance(0.0)

func _play_door_animation(animation_name: StringName) -> void:
	if not is_instance_valid(_door_animation):
		return
	if not _door_animation.has_animation(animation_name):
		push_warning("Missing carriage door animation: %s" % animation_name)
		return
	_door_animation.play(animation_name)
