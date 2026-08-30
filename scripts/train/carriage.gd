class_name CarriageVisual
extends Node2D
## Behavior for scene-authored carriage art. Geometry, colors, props and labels live in .tscn/SVG assets.

@export_enum("passenger", "conductor") var carriage_type: String = "passenger"
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
@export_node_path("Node2D") var exterior_door_visual_path: NodePath
@export_node_path("AnimationPlayer") var door_animation_path: NodePath
@export_node_path("AnimationPlayer") var wheel_animation_path: NodePath
@export_node_path("CanvasItem") var cinematic_interior_shade_path: NodePath
@export_node_path("Control") var radar_scan_effect_path: NodePath
@export_node_path("PointLight2D") var radar_anomaly_light_path: NodePath
@export_node_path("Node") var dirty_seat_events_root_path: NodePath
@export var exterior_wipe_parameter: StringName = &"wipe_progress"
@export var radar_scan_origin_parameter: StringName = &"scan_origin_uv"
@export var radar_scan_progress_parameter: StringName = &"scan_progress"
@export var radar_scan_aspect_parameter: StringName = &"scan_aspect"
@export_range(0.0, 2.0, 0.05) var cinematic_interior_fade_seconds: float = 0.45
@export_range(0.0, 8.0, 0.1) var radar_light_energy: float = 2.4
@export_range(0.05, 2.0, 0.05) var radar_light_fade_seconds: float = 0.35
@export_category("Door Animations")
@export var door_reset_animation: StringName = &"RESET"
@export var door_open_animation: StringName = &"door_open"
@export var door_close_animation: StringName = &"door_close"
@export var wheel_spin_animation: StringName = &"wheel_spin"

@onready var _sway_root: Node2D = _get_optional_node(sway_root_path) as Node2D
@onready var _night_overlay: CanvasItem = _get_optional_node(night_overlay_path) as CanvasItem
@onready var _exterior_visual: Node2D = _get_optional_node(exterior_visual_path) as Node2D
@onready var _exterior_door_visual: Node2D = _get_optional_node(exterior_door_visual_path) as Node2D
@onready var _door_animation: AnimationPlayer = _get_optional_node(door_animation_path) as AnimationPlayer
@onready var _wheel_animation: AnimationPlayer = _get_optional_node(wheel_animation_path) as AnimationPlayer
@onready var _cinematic_interior_shade: CanvasItem = _get_optional_node(cinematic_interior_shade_path) as CanvasItem
@onready var _radar_scan_effect: Control = _get_optional_node(radar_scan_effect_path) as Control
@onready var _radar_anomaly_light: PointLight2D = _get_optional_node(radar_anomaly_light_path) as PointLight2D
@onready var _dirty_seat_events_root: Node = _get_optional_node(dirty_seat_events_root_path)

var _cinematic_shade_tween: Tween
var _radar_scan_tween: Tween
var _radar_light_tween: Tween

func _ready() -> void:
	_validate_exterior_hierarchy()
	_configure_dirty_seat_events(_dirty_seat_events_root)
	_reset_radar_scan_effect()
	if is_instance_valid(_radar_anomaly_light):
		_radar_anomaly_light.energy = 0.0
	end_exterior_mode()

func set_environment(_scroll: float, night_strength: float, sway_time: float) -> void:
	if is_instance_valid(_night_overlay):
		_night_overlay.modulate.a = clampf(night_strength, 0.0, 1.0)
	if is_instance_valid(_sway_root):
		_sway_root.position.y = sin(sway_time * 2.1 + carriage_number * 0.45) * 1.4

func begin_exterior_mode() -> void:
	_fade_cinematic_interior_shade(1.0)
	_prepare_exterior_layer(_exterior_visual)
	_set_exterior_wipe_progress(0.0)
	_reset_exterior_doors()

func set_exterior_transition(alpha: float, vertical_offset: float, wipe_progress: float) -> void:
	_set_exterior_layer_transition(_exterior_visual, alpha, vertical_offset)
	_set_exterior_wipe_progress(wipe_progress)

func end_exterior_mode() -> void:
	_fade_cinematic_interior_shade(0.0)
	_reset_exterior_layer(_exterior_visual)
	_set_exterior_wipe_progress(0.0)
	_reset_exterior_doors()

func set_exterior_doors_open(value: bool) -> void:
	_play_door_animation(door_open_animation if value else door_close_animation)


func set_motion_strength(value: float) -> void:
	if not is_instance_valid(_wheel_animation):
		return
	var motion_strength: float = clampf(value, 0.0, 1.0)
	if not _wheel_animation.is_playing() and _wheel_animation.has_animation(wheel_spin_animation):
		_wheel_animation.play(wheel_spin_animation)
	_wheel_animation.speed_scale = motion_strength


func show_radar_anomaly_glow(duration: float) -> void:
	if not is_instance_valid(_radar_anomaly_light):
		return
	if is_instance_valid(_radar_light_tween):
		_radar_light_tween.kill()
	_radar_anomaly_light.energy = 0.0
	var hold_seconds: float = maxf(0.0, duration - radar_light_fade_seconds * 2.0)
	_radar_light_tween = create_tween()
	_radar_light_tween.tween_property(
		_radar_anomaly_light,
		"energy",
		radar_light_energy,
		radar_light_fade_seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_radar_light_tween.tween_interval(hold_seconds)
	_radar_light_tween.tween_property(
		_radar_anomaly_light,
		"energy",
		0.0,
		radar_light_fade_seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func has_radar_scan_effect() -> bool:
	if not is_instance_valid(_radar_scan_effect):
		return false
	var shader_material := _radar_scan_effect.material as ShaderMaterial
	return (
		shader_material != null
		and _radar_scan_effect.size.x > 0.0
		and _radar_scan_effect.size.y > 0.0
	)


func play_radar_scan(world_origin: Vector2, duration: float) -> void:
	if not has_radar_scan_effect():
		return
	var shader_material := _radar_scan_effect.material as ShaderMaterial
	if is_instance_valid(_radar_scan_tween):
		_radar_scan_tween.kill()
	var effect_local_origin: Vector2 = (
		_radar_scan_effect.get_global_transform().affine_inverse() * world_origin
	)
	var origin_uv := Vector2(
		clampf(effect_local_origin.x / _radar_scan_effect.size.x, 0.0, 1.0),
		clampf(effect_local_origin.y / _radar_scan_effect.size.y, 0.0, 1.0)
	)
	shader_material.set_shader_parameter(radar_scan_origin_parameter, origin_uv)
	shader_material.set_shader_parameter(
		radar_scan_aspect_parameter,
		_radar_scan_effect.size.x / _radar_scan_effect.size.y
	)
	_set_radar_scan_progress(0.0)
	_radar_scan_effect.show()
	_radar_scan_tween = create_tween()
	_radar_scan_tween.tween_method(
		_set_radar_scan_progress,
		0.0,
		1.0,
		maxf(duration, 0.05)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var active_tween: Tween = _radar_scan_tween
	await active_tween.finished
	if _radar_scan_tween != active_tween:
		return
	_reset_radar_scan_effect()

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

func _configure_dirty_seat_events(root: Node) -> void:
	if not is_instance_valid(root):
		return
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child: Node in current.get_children():
			pending.append(child)
			if child.is_in_group(&"dirty_seat_events") and child.has_method(&"set_carriage_number"):
				child.call(&"set_carriage_number", carriage_number)

func _set_exterior_wipe_progress(value: float) -> void:
	_set_layer_wipe_progress(_exterior_visual, value)


func _set_radar_scan_progress(value: float) -> void:
	if not is_instance_valid(_radar_scan_effect):
		return
	var shader_material := _radar_scan_effect.material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter(radar_scan_progress_parameter, clampf(value, 0.0, 1.0))


func _reset_radar_scan_effect() -> void:
	_set_radar_scan_progress(0.0)
	if is_instance_valid(_radar_scan_effect):
		_radar_scan_effect.hide()


func _validate_exterior_hierarchy() -> void:
	if not is_instance_valid(_exterior_visual) or not is_instance_valid(_exterior_door_visual):
		return
	if not _exterior_visual.is_ancestor_of(_exterior_door_visual):
		push_error("Exterior doors must remain inside the scene-authored Exterior fade group.")


func _prepare_exterior_layer(layer: Node2D) -> void:
	if not is_instance_valid(layer):
		return
	layer.show()
	layer.process_mode = Node.PROCESS_MODE_INHERIT
	layer.modulate.a = 1.0
	layer.position.y = 0.0


func _set_exterior_layer_transition(layer: Node2D, alpha: float, vertical_offset: float) -> void:
	if not is_instance_valid(layer) or not layer.visible:
		return
	layer.modulate.a = clampf(alpha, 0.0, 1.0)
	layer.position.y = vertical_offset


func _reset_exterior_layer(layer: Node2D) -> void:
	if not is_instance_valid(layer):
		return
	layer.hide()
	layer.process_mode = Node.PROCESS_MODE_DISABLED
	layer.modulate.a = 1.0
	layer.position.y = 0.0


func _set_layer_wipe_progress(layer: Node2D, value: float) -> void:
	if not is_instance_valid(layer):
		return
	var shader_material := layer.material as ShaderMaterial
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

func _fade_cinematic_interior_shade(target_alpha: float) -> void:
	if not is_instance_valid(_cinematic_interior_shade):
		return
	if _cinematic_shade_tween != null and _cinematic_shade_tween.is_valid():
		_cinematic_shade_tween.kill()
	var clamped_alpha: float = clampf(target_alpha, 0.0, 1.0)
	if cinematic_interior_fade_seconds <= 0.0 or not is_inside_tree():
		_cinematic_interior_shade.modulate.a = clamped_alpha
		return
	_cinematic_shade_tween = create_tween()
	_cinematic_shade_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cinematic_shade_tween.tween_property(
		_cinematic_interior_shade,
		^"modulate:a",
		clamped_alpha,
		cinematic_interior_fade_seconds
	)
