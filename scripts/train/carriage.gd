class_name CarriageVisual
extends Node2D
## Behavior for scene-authored carriage art. Geometry, colors, props and labels live in .tscn/SVG assets.

# Middle colors from the same three-stop gradients used by the travel sky.
const MORNING_WINDOW_LIGHT := Color("b7fff3")
const SUNSET_WINDOW_LIGHT := Color("fefdaa")
const NIGHT_WINDOW_LIGHT := Color("3aa2e9")

@export_enum("passenger", "conductor") var carriage_type: String = "passenger"
@export var carriage_number: int = 0
@export_range(1.0, 4096.0, 1.0) var carriage_width: float = 960.0
@export_category("Passenger Layout")
@export_node_path("Node2D") var passenger_seat_slots_path: NodePath
@export_node_path("Node2D") var passenger_activity_slots_path: NodePath
@export_node_path("Node2D") var passenger_door_slots_path: NodePath
@export_category("Scene Visuals")
@export_node_path("Node2D") var sway_root_path: NodePath
@export_node_path("CanvasItem") var window_light_root_path: NodePath
@export_node_path("Node2D") var exterior_visual_path: NodePath
@export_node_path("Node2D") var exterior_door_visual_path: NodePath
@export_node_path("Marker2D") var exterior_wipe_top_anchor_path: NodePath
@export_node_path("Marker2D") var exterior_wipe_bottom_anchor_path: NodePath
@export var exterior_wipe_visual_paths: Array[NodePath] = []
@export_node_path("AnimationPlayer") var door_animation_path: NodePath
@export_node_path("AnimationPlayer") var wheel_animation_path: NodePath
@export_node_path("CanvasItem") var cinematic_interior_shade_path: NodePath
@export_node_path("Control") var radar_scan_effect_path: NodePath
@export_node_path("CanvasItem") var radar_anomaly_overlay_path: NodePath
@export_node_path("Node") var dirty_seat_events_root_path: NodePath
@export_category("Blocked Aisle Presentation")
@export var blocked_grayscale_visual_group: StringName = &"blocked_carriage_visuals"
@export_range(0.05, 0.8, 0.01) var blocked_grayscale_fade_seconds: float = 0.28
@export var exterior_wipe_parameter: StringName = &"wipe_progress"
@export var exterior_wipe_top_parameter: StringName = &"wipe_top_screen_y"
@export var exterior_wipe_bottom_parameter: StringName = &"wipe_bottom_screen_y"
@export var radar_scan_progress_parameter: StringName = &"scan_progress"
@export var radar_scan_aspect_parameter: StringName = &"scan_aspect"
@export var radar_scan_origin_parameter: StringName = &"scan_origin"
@export_category("Radar Anomaly Lighting")
@export var radar_anomaly_light_color: Color = Color(1.0, 0.08, 0.055, 1.0)
@export_range(1.0, 4.0, 0.05) var radar_anomaly_energy_multiplier: float = 2.15
@export_range(0.1, 1.0, 0.05) var radar_anomaly_overlay_alpha_scale: float = 0.42
@export_range(0.1, 1.0, 0.05) var radar_anomaly_overlay_alpha_cap: float = 0.72
@export_range(0.05, 1.0, 0.05) var radar_anomaly_light_energy_scale: float = 0.22
@export_range(0.1, 1.5, 0.05) var radar_anomaly_flare_strength_scale: float = 0.55
@export_range(0.1, 1.5, 0.05) var radar_anomaly_flare_strength_cap: float = 0.9
@export_range(0.05, 1.0, 0.01) var radar_anomaly_fade_in_seconds: float = 0.22
@export_range(0.05, 2.0, 0.01) var radar_anomaly_fade_out_seconds: float = 0.55
@export_range(0.0, 2.0, 0.05) var cinematic_interior_fade_seconds: float = 0.45
@export_range(0.1, 8.0, 0.1) var wheel_full_speed_scale: float = 3.5
@export_category("Door Animations")
@export var door_reset_animation: StringName = &"RESET"
@export var door_open_animation: StringName = &"door_open"
@export var door_close_animation: StringName = &"door_close"
@export var wheel_spin_animation: StringName = &"wheel_spin"

@onready var _sway_root: Node2D = _get_optional_node(sway_root_path) as Node2D
@onready var _window_light_root: CanvasItem = _get_optional_node(window_light_root_path) as CanvasItem
@onready var _exterior_visual: Node2D = _get_optional_node(exterior_visual_path) as Node2D
@onready var _exterior_door_visual: Node2D = _get_optional_node(exterior_door_visual_path) as Node2D
@onready var _exterior_wipe_top_anchor: Marker2D = _get_optional_node(exterior_wipe_top_anchor_path) as Marker2D
@onready var _exterior_wipe_bottom_anchor: Marker2D = _get_optional_node(exterior_wipe_bottom_anchor_path) as Marker2D
@onready var _door_animation: AnimationPlayer = _get_optional_node(door_animation_path) as AnimationPlayer
@onready var _wheel_animation: AnimationPlayer = _get_optional_node(wheel_animation_path) as AnimationPlayer
@onready var _cinematic_interior_shade: CanvasItem = _get_optional_node(cinematic_interior_shade_path) as CanvasItem
@onready var _radar_scan_effect: Control = _get_optional_node(radar_scan_effect_path) as Control
@onready var _radar_anomaly_overlay: CanvasItem = _get_optional_node(radar_anomaly_overlay_path) as CanvasItem
@onready var _dirty_seat_events_root: Node = _get_optional_node(dirty_seat_events_root_path)

var _window_lights: Array[Light2D] = []
var _window_flare_materials: Array[ShaderMaterial] = []
var _exterior_wipe_material: ShaderMaterial
var _cinematic_shade_tween: Tween
var _radar_scan_tween: Tween
var _radar_anomaly_tween: Tween
var _radar_anomaly_strength: float = 0.0
var _base_window_color: Color = MORNING_WINDOW_LIGHT
var _base_window_strength: float = 0.72
var _base_day_cycle_progress: float = 0.0
var _blocked_grayscale_materials: Array[ShaderMaterial] = []
var _blocked_grayscale_tween: Tween
var _blocked_grayscale_strength: float = 0.0

func _ready() -> void:
	_prepare_blocked_grayscale_materials()
	_prepare_exterior_wipe_material()
	if is_instance_valid(_window_light_root):
		_collect_window_lights(_window_light_root)
	_validate_exterior_hierarchy()
	_configure_dirty_seat_events(_dirty_seat_events_root)
	_reset_radar_scan_effect()
	_set_radar_anomaly_strength(0.0)
	end_exterior_mode()


func set_blocked_by_aisle(value: bool, immediate: bool = false) -> void:
	if is_instance_valid(_blocked_grayscale_tween):
		_blocked_grayscale_tween.kill()
	var target_strength: float = 1.0 if value else 0.0
	if immediate or not is_inside_tree():
		_set_blocked_grayscale_strength(target_strength)
		return
	_blocked_grayscale_tween = create_tween()
	_blocked_grayscale_tween.tween_method(
		_set_blocked_grayscale_strength,
		_blocked_grayscale_strength,
		target_strength,
		blocked_grayscale_fade_seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func is_blocked_grayscale_active() -> bool:
	return _blocked_grayscale_strength > 0.99


func _prepare_blocked_grayscale_materials() -> void:
	_blocked_grayscale_materials.clear()
	var pending: Array[Node] = [self]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child: Node in current.get_children():
			pending.append(child)
			if not child.is_in_group(blocked_grayscale_visual_group) or not child is CanvasItem:
				continue
			var visual := child as CanvasItem
			var configured_material := visual.material as ShaderMaterial
			if configured_material == null:
				push_warning("%s grayscale visual %s requires a scene-authored ShaderMaterial." % [name, child.name])
				continue
			var local_material := configured_material.duplicate() as ShaderMaterial
			local_material.resource_local_to_scene = true
			visual.material = local_material
			local_material.set_shader_parameter(&"grayscale_strength", 0.0)
			_blocked_grayscale_materials.append(local_material)


func _set_blocked_grayscale_strength(value: float) -> void:
	_blocked_grayscale_strength = clampf(value, 0.0, 1.0)
	for grayscale_material: ShaderMaterial in _blocked_grayscale_materials:
		if is_instance_valid(grayscale_material):
			grayscale_material.set_shader_parameter(&"grayscale_strength", _blocked_grayscale_strength)

func set_environment(_scroll: float, _night_strength: float, day_cycle_progress: float, sway_time: float) -> void:
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
		_sway_root.position.y = sin(sway_time * 2.1 + carriage_number * 0.45) * 1.4

func _set_window_light(window_color: Color, strength: float, day_cycle_progress: float) -> void:
	_base_window_color = window_color
	_base_window_strength = strength
	_base_day_cycle_progress = day_cycle_progress
	_apply_window_light()


func _apply_window_light() -> void:
	var signal_strength: float = _radar_anomaly_strength
	if is_instance_valid(_radar_anomaly_overlay):
		_radar_anomaly_overlay.visible = signal_strength > 0.001
		var overlay_modulate := _radar_anomaly_overlay.modulate
		overlay_modulate.a = signal_strength
		_radar_anomaly_overlay.modulate = overlay_modulate
	# WindowLightRoot is a scene-authored signal layer. Keep it out of the
	# regular coach grade, then reveal it only while this coach reports an anomaly.
	_window_light_root.visible = signal_strength > 0.001
	var effective_color: Color = _base_window_color.lerp(radar_anomaly_light_color, signal_strength)
	var effective_strength: float = _base_window_strength * lerpf(
		1.0,
		radar_anomaly_energy_multiplier,
		signal_strength
	)
	# Sprite-based window masks inherit this tint from WindowLightRoot.
	var overlay_color := effective_color
	overlay_color.a = clampf(
		effective_strength * radar_anomaly_overlay_alpha_scale,
		0.0,
		radar_anomaly_overlay_alpha_cap
	)
	_window_light_root.modulate = overlay_color

	# CanvasItem modulation does not reliably recolor Light2D nodes, so tint the
	# actual window lights explicitly as well.
	for window_light: Light2D in _window_lights:
		if is_instance_valid(window_light):
			window_light.color = effective_color
			window_light.energy = maxf(0.0, effective_strength * radar_anomaly_light_energy_scale)
	for flare_material: ShaderMaterial in _window_flare_materials:
		if is_instance_valid(flare_material):
			flare_material.set_shader_parameter(&"cycle_progress", _base_day_cycle_progress)
			flare_material.set_shader_parameter(
				&"flare_strength",
				clampf(
					effective_strength * radar_anomaly_flare_strength_scale,
					0.0,
					radar_anomaly_flare_strength_cap
				)
			)

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
	_fade_cinematic_interior_shade(1.0)
	_prepare_exterior_layer(_exterior_visual)
	_set_exterior_wipe_progress(0.0)
	_reset_exterior_doors()

func set_exterior_transition(alpha: float, vertical_offset: float, wipe_progress: float) -> void:
	_set_exterior_layer_transition(_exterior_visual, alpha, vertical_offset)
	_set_exterior_wipe_progress(wipe_progress)
	if is_instance_valid(_exterior_visual):
		_exterior_visual.visible = wipe_progress < 0.999

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
	if motion_strength <= 0.001:
		_wheel_animation.speed_scale = 0.0
		_wheel_animation.pause()
		return
	if not _wheel_animation.has_animation(wheel_spin_animation):
		return
	_wheel_animation.speed_scale = wheel_full_speed_scale * motion_strength
	if not _wheel_animation.is_playing():
		_wheel_animation.play(wheel_spin_animation)


func has_radar_scan_effect() -> bool:
	if not is_instance_valid(_radar_scan_effect):
		return false
	var shader_material := _radar_scan_effect.material as ShaderMaterial
	return (
		shader_material != null
		and _radar_scan_effect.size.x > 0.0
		and _radar_scan_effect.size.y > 0.0
	)


func play_radar_scan(duration: float, origin_world_position: Vector2) -> void:
	if not has_radar_scan_effect():
		return
	var shader_material := _radar_scan_effect.material as ShaderMaterial
	if is_instance_valid(_radar_scan_tween):
		_radar_scan_tween.kill()
	shader_material.set_shader_parameter(
		radar_scan_aspect_parameter,
		_radar_scan_effect.size.x / _radar_scan_effect.size.y
	)
	var origin_uv: Vector2 = _radar_world_position_to_uv(origin_world_position)
	shader_material.set_shader_parameter(radar_scan_origin_parameter, origin_uv)
	_set_radar_scan_progress(0.0)
	_radar_scan_effect.show()
	_radar_scan_tween = create_tween()
	_radar_scan_tween.tween_method(
		_set_radar_scan_progress,
		0.0,
		1.0,
		maxf(duration, 0.05)
	)
	_radar_scan_tween.tween_callback(_reset_radar_scan_effect)


func show_radar_anomaly_signal(duration: float) -> void:
	if is_instance_valid(_radar_anomaly_tween):
		_radar_anomaly_tween.kill()
	var fade_in: float = minf(radar_anomaly_fade_in_seconds, maxf(duration, 0.05) * 0.4)
	var fade_out: float = minf(radar_anomaly_fade_out_seconds, maxf(duration - fade_in, 0.0))
	var hold: float = maxf(duration - fade_in - fade_out, 0.0)
	_radar_anomaly_tween = create_tween()
	_radar_anomaly_tween.tween_method(
		_set_radar_anomaly_strength,
		_radar_anomaly_strength,
		1.0,
		fade_in
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_radar_anomaly_tween.tween_interval(hold)
	_radar_anomaly_tween.tween_method(
		_set_radar_anomaly_strength,
		1.0,
		0.0,
		maxf(fade_out, 0.05)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func clear_radar_anomaly_signal(immediate: bool = false) -> void:
	if is_instance_valid(_radar_anomaly_tween):
		_radar_anomaly_tween.kill()
	if immediate or not is_inside_tree():
		_set_radar_anomaly_strength(0.0)
		return
	_radar_anomaly_tween = create_tween()
	_radar_anomaly_tween.tween_method(
		_set_radar_anomaly_strength,
		_radar_anomaly_strength,
		0.0,
		minf(radar_anomaly_fade_out_seconds, 0.18)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func get_radar_anomaly_strength() -> float:
	return _radar_anomaly_strength


func _radar_world_position_to_uv(world_position: Vector2) -> Vector2:
	var local_point: Vector2 = _radar_scan_effect.get_global_transform().affine_inverse() * world_position
	return Vector2(
		clampf(local_point.x / maxf(_radar_scan_effect.size.x, 1.0), 0.0, 1.0),
		clampf(local_point.y / maxf(_radar_scan_effect.size.y, 1.0), 0.0, 1.0)
	)

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


func _set_radar_anomaly_strength(value: float) -> void:
	_radar_anomaly_strength = clampf(value, 0.0, 1.0)
	if is_instance_valid(_window_light_root):
		_apply_window_light()


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
	var shader_material := _exterior_wipe_material
	if shader_material == null:
		return
	_update_exterior_wipe_screen_bounds(shader_material)
	shader_material.set_shader_parameter(exterior_wipe_parameter, clampf(value, 0.0, 1.0))


func _prepare_exterior_wipe_material() -> void:
	var wipe_visuals: Array[CanvasItem] = []
	var configured_material: ShaderMaterial
	for visual_path: NodePath in exterior_wipe_visual_paths:
		var visual := get_node_or_null(visual_path) as CanvasItem
		if not is_instance_valid(visual):
			continue
		wipe_visuals.append(visual)
		if configured_material == null:
			configured_material = visual.material as ShaderMaterial
	if configured_material == null:
		push_warning("%s requires scene-authored exterior wipe Sprite2D materials." % name)
		return
	_exterior_wipe_material = configured_material.duplicate() as ShaderMaterial
	_exterior_wipe_material.resource_local_to_scene = true
	for visual: CanvasItem in wipe_visuals:
		visual.material = _exterior_wipe_material


func _update_exterior_wipe_screen_bounds(shader_material: ShaderMaterial) -> void:
	if (
		not is_instance_valid(_exterior_wipe_top_anchor)
		or not is_instance_valid(_exterior_wipe_bottom_anchor)
		or not is_inside_tree()
	):
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.y <= 0.0:
		return
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
	var top_screen_position: Vector2 = canvas_transform * _exterior_wipe_top_anchor.global_position
	var bottom_screen_position: Vector2 = canvas_transform * _exterior_wipe_bottom_anchor.global_position
	shader_material.set_shader_parameter(exterior_wipe_top_parameter, top_screen_position.y / viewport_size.y)
	shader_material.set_shader_parameter(exterior_wipe_bottom_parameter, bottom_screen_position.y / viewport_size.y)

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
	GameSFX.play(&"mechanical_door", -11.0, 1.0, 0.035, 0.2)
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
