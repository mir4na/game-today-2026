class_name CarriageVisual
extends Node2D
## Behavior for scene-authored carriage art. Geometry, colors, props and labels live in .tscn/SVG assets.

# Middle colors from the same three-stop gradients used by the travel sky.
const MORNING_WINDOW_LIGHT := Color("b7fff3")
const SUNSET_WINDOW_LIGHT := Color("fefdaa")
const NIGHT_WINDOW_LIGHT := Color("3aa2e9")

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
@export_node_path("CanvasItem") var window_light_root_path: NodePath
@export_node_path("Node2D") var exterior_visual_path: NodePath
@export_node_path("AnimationPlayer") var door_animation_path: NodePath
@export var exterior_wipe_parameter: StringName = &"wipe_progress"
@export_category("Door Animations")
@export var door_reset_animation: StringName = &"RESET"
@export var door_open_animation: StringName = &"door_open"
@export var door_close_animation: StringName = &"door_close"

@onready var _sway_root: Node2D = _get_optional_node(sway_root_path) as Node2D
@onready var _night_overlay: CanvasItem = _get_optional_node(night_overlay_path) as CanvasItem
@onready var _window_light_root: CanvasItem = _get_optional_node(window_light_root_path) as CanvasItem
@onready var _exterior_visual: Node2D = _get_optional_node(exterior_visual_path) as Node2D
@onready var _door_animation: AnimationPlayer = _get_optional_node(door_animation_path) as AnimationPlayer
var _window_lights: Array[Light2D] = []
var _window_flare_materials: Array[ShaderMaterial] = []

func _ready() -> void:
	if is_instance_valid(_window_light_root):
		_collect_window_lights(_window_light_root)
	end_exterior_mode()

func set_environment(_scroll: float, night_strength: float, day_cycle_progress: float, sway_time: float) -> void:
	if is_instance_valid(_night_overlay):
		_night_overlay.modulate.a = clampf(night_strength, 0.0, 1.0)
	if is_instance_valid(_window_light_root):
		var sunset_blend: float = smoothstep(0.08, 0.62, day_cycle_progress)
		var night_blend: float = smoothstep(0.70, 0.98, day_cycle_progress)
		var window_color: Color = MORNING_WINDOW_LIGHT.lerp(SUNSET_WINDOW_LIGHT, sunset_blend)
		window_color = window_color.lerp(NIGHT_WINDOW_LIGHT, night_blend)
		var base_strength: float = lerpf(0.72, 0.94, sunset_blend)
		base_strength = lerpf(base_strength, 1.08, night_blend)
		var pulse: float = 0.97 + sin(sway_time * 1.35 + carriage_number * 1.7) * 0.025
		var secondary_pulse: float = sin(sway_time * 3.1 + carriage_number * 0.8) * 0.01
		var animated_strength: float = base_strength * (pulse + secondary_pulse)
		_set_window_light(window_color, animated_strength, day_cycle_progress)
	if is_instance_valid(_sway_root):
		# A quicker, slightly rougher suspension rhythm sells the higher rail speed.
		_sway_root.position.y = (
			sin(sway_time * 3.45 + carriage_number * 0.45) * 1.75
			+ sin(sway_time * 7.8 + carriage_number * 0.9) * 0.35
		)

func _set_window_light(window_color: Color, strength: float, day_cycle_progress: float) -> void:
	# Sprite-based window masks inherit this tint from WindowLightRoot.
	var overlay_color := window_color
	overlay_color.a = clampf(strength * 0.42, 0.0, 0.48)
	_window_light_root.modulate = overlay_color

	# CanvasItem modulation does not reliably recolor Light2D nodes, so tint the
	# actual window lights explicitly as well.
	for window_light: Light2D in _window_lights:
		if is_instance_valid(window_light):
			window_light.color = window_color
			window_light.energy = maxf(0.0, strength * 0.22)
	for flare_material: ShaderMaterial in _window_flare_materials:
		if is_instance_valid(flare_material):
			flare_material.set_shader_parameter(&"cycle_progress", day_cycle_progress)
			flare_material.set_shader_parameter(&"flare_strength", clampf(strength * 0.55, 0.0, 0.65))

func _collect_window_lights(parent: Node) -> void:
	for child: Node in parent.get_children():
		if child is Light2D:
			_window_lights.append(child as Light2D)
		if child is CanvasItem:
			var canvas_item := child as CanvasItem
			var shader_material := canvas_item.material as ShaderMaterial
			if shader_material != null and not _window_flare_materials.has(shader_material):
				_window_flare_materials.append(shader_material)
		_collect_window_lights(child)

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
