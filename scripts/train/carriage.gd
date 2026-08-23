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
@export_node_path("Node2D") var interior_visual_path: NodePath
@export_node_path("Node2D") var exterior_visual_path: NodePath
@export_node_path("CanvasItem") var closed_doors_path: NodePath

@onready var _sway_root: Node2D = _get_optional_node(sway_root_path) as Node2D
@onready var _night_overlay: CanvasItem = _get_optional_node(night_overlay_path) as CanvasItem
@onready var _interior_visual: Node2D = _get_optional_node(interior_visual_path) as Node2D
@onready var _exterior_visual: Node2D = _get_optional_node(exterior_visual_path) as Node2D
@onready var _closed_doors: CanvasItem = _get_optional_node(closed_doors_path) as CanvasItem

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
	_exterior_visual.modulate.a = 0.0
	_exterior_visual.position.y = 10.0
	if is_instance_valid(_interior_visual):
		_interior_visual.show()
		_interior_visual.process_mode = Node.PROCESS_MODE_INHERIT

func set_exterior_transition(alpha: float, vertical_offset: float) -> void:
	if not is_instance_valid(_exterior_visual) or not _exterior_visual.visible:
		return
	_exterior_visual.modulate.a = clampf(alpha, 0.0, 1.0)
	_exterior_visual.position.y = vertical_offset

func finish_exterior_transition() -> void:
	if is_instance_valid(_exterior_visual) and is_instance_valid(_interior_visual):
		_interior_visual.hide()
		_interior_visual.process_mode = Node.PROCESS_MODE_DISABLED

func begin_interior_transition() -> void:
	if is_instance_valid(_interior_visual):
		_interior_visual.show()
		_interior_visual.process_mode = Node.PROCESS_MODE_INHERIT

func end_exterior_mode() -> void:
	if is_instance_valid(_exterior_visual):
		_exterior_visual.hide()
		_exterior_visual.process_mode = Node.PROCESS_MODE_DISABLED
		_exterior_visual.modulate.a = 0.0
		_exterior_visual.position.y = 0.0
	if is_instance_valid(_interior_visual):
		_interior_visual.show()
		_interior_visual.process_mode = Node.PROCESS_MODE_INHERIT

func set_exterior_doors_open(value: bool) -> void:
	if is_instance_valid(_closed_doors):
		_closed_doors.visible = not value

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
