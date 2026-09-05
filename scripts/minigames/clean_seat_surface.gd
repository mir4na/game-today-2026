class_name CleanSeatSurface
extends Control
## Updates one reusable erase mask while the cloth is dragged across scene-authored stains.

signal cleaning_progress(value: float)
signal cleaned

@export_category("Wiping")
@export_range(64, 512, 1) var mask_resolution: int = 256
@export_range(8.0, 80.0, 1.0) var brush_radius: float = 27.0
@export_range(0.5, 1.0, 0.01) var completion_threshold: float = 0.98
@export_category("Foam Trail")
@export_range(0.5, 4.0, 0.05) var foam_lifetime_seconds: float = 1.8
@export_range(0.75, 2.0, 0.05) var foam_brush_scale: float = 1.3
@export_range(0.03, 0.2, 0.01) var foam_decay_update_seconds: float = 0.08
@export_node_path("Node2D") var stain_markers_path: NodePath
@export_node_path("ColorRect") var dirt_layer_path: NodePath
@export_node_path("TextureRect") var cloth_path: NodePath
@export_node_path("ColorRect") var cleaning_foam_path: NodePath

@onready var _dirt_layer: ColorRect = get_node_or_null(dirt_layer_path) as ColorRect
@onready var _cloth: TextureRect = get_node_or_null(cloth_path) as TextureRect
@onready var _cleaning_foam: ColorRect = get_node_or_null(cleaning_foam_path) as ColorRect

var _mask_image: Image
var _mask_texture: ImageTexture
var _foam_mask_image: Image
var _foam_mask_texture: ImageTexture
var _material: ShaderMaterial
var _foam_material: ShaderMaterial
var _sample_points: Array[Vector2i] = []
var _wiping: bool = false
var _completed: bool = false
var _last_wipe_position: Vector2 = Vector2.ZERO
var _foam_decay_accumulator: float = 0.0
var _foam_present: bool = false


func _ready() -> void:
	_material = _dirt_layer.material.duplicate() as ShaderMaterial
	_material.resource_local_to_scene = true
	_dirt_layer.material = _material
	if is_instance_valid(_cleaning_foam):
		_foam_material = _cleaning_foam.material.duplicate() as ShaderMaterial
		_foam_material.resource_local_to_scene = true
		_cleaning_foam.material = _foam_material
		_foam_material.set_shader_parameter(&"surface_size", size)
	_mask_image = Image.create(mask_resolution, mask_resolution, false, Image.FORMAT_L8)
	_mask_image.fill(Color.BLACK)
	_mask_texture = ImageTexture.create_from_image(_mask_image)
	_material.set_shader_parameter(&"erase_mask", _mask_texture)
	_foam_mask_image = Image.create(mask_resolution, mask_resolution, false, Image.FORMAT_L8)
	_foam_mask_image.fill(Color.BLACK)
	_foam_mask_texture = ImageTexture.create_from_image(_foam_mask_image)
	if is_instance_valid(_foam_material):
		_foam_material.set_shader_parameter(&"foam_mask", _foam_mask_texture)
	call_deferred(&"_configure_scene_stains")
	reset_cleaning()


func reset_cleaning() -> void:
	_completed = false
	_wiping = false
	if _mask_image != null:
		_mask_image.fill(Color.BLACK)
		_mask_texture.update(_mask_image)
	if _foam_mask_image != null:
		_foam_mask_image.fill(Color.BLACK)
		_foam_mask_texture.update(_foam_mask_image)
	_foam_decay_accumulator = 0.0
	_foam_present = false
	if is_instance_valid(_cloth):
		_cloth.hide()
	_set_foam(Vector2.ZERO, false)
	cleaning_progress.emit(0.0)


func cancel_wipe() -> void:
	_wiping = false
	if is_instance_valid(_cloth):
		_cloth.hide()
	_set_foam(Vector2.ZERO, false)


func _process(delta: float) -> void:
	if not _foam_present or _foam_mask_image == null:
		return
	_foam_decay_accumulator += delta
	if _foam_decay_accumulator < foam_decay_update_seconds:
		return
	var elapsed: float = _foam_decay_accumulator
	_foam_decay_accumulator = 0.0
	_decay_foam_mask(elapsed)


func _gui_input(event: InputEvent) -> void:
	if _completed:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_wiping = event.pressed
		_last_wipe_position = event.position
		_update_cloth(event.position, event.pressed)
		if event.pressed:
			_paint_segment(event.position, event.position)
		accept_event()
	elif event is InputEventMouseMotion:
		_update_cloth(event.position, true)
		if _wiping:
			_paint_segment(_last_wipe_position, event.position)
			_last_wipe_position = event.position
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and not _wiping and is_instance_valid(_cloth):
		_cloth.hide()


func _configure_scene_stains() -> void:
	var markers_root: Node = get_node_or_null(stain_markers_path)
	if markers_root == null or not is_instance_valid(_material) or size.x <= 0.0 or size.y <= 0.0:
		return
	var markers: Array[Node] = markers_root.get_children()
	var shader_names: Array[StringName] = [&"stain_a", &"stain_b", &"stain_c", &"stain_d"]
	_sample_points.clear()
	_material.set_shader_parameter(&"surface_size", size)
	for index: int in range(mini(markers.size(), shader_names.size())):
		var marker := markers[index] as Node2D
		var radius: float = float(marker.get_meta(&"radius", 34.0))
		var center_uv := Vector2(marker.position.x / size.x, marker.position.y / size.y)
		_material.set_shader_parameter(shader_names[index], Vector4(center_uv.x, center_uv.y, radius, float(index + 1)))
		_append_stain_samples(marker.position, radius)


func _append_stain_samples(center: Vector2, radius: float) -> void:
	for image_y: int in range(0, mask_resolution, 4):
		for image_x: int in range(0, mask_resolution, 4):
			var local_point := Vector2(
				(float(image_x) + 0.5) / float(mask_resolution) * size.x,
				(float(image_y) + 0.5) / float(mask_resolution) * size.y
			)
			if local_point.distance_to(center) <= radius * 1.05:
				_sample_points.append(Vector2i(image_x, image_y))


func _paint_segment(from: Vector2, to: Vector2) -> void:
	var distance: float = from.distance_to(to)
	var step_distance: float = maxf(brush_radius * 0.32, 2.0)
	var steps: int = maxi(1, ceili(distance / step_distance))
	for step: int in range(steps + 1):
		var wipe_position: Vector2 = from.lerp(to, float(step) / float(steps))
		_paint_circle(wipe_position)
		_paint_foam_circle(wipe_position)
	_mask_texture.update(_mask_image)
	_foam_mask_texture.update(_foam_mask_image)
	_foam_present = true
	var progress: float = _calculate_progress()
	cleaning_progress.emit(progress)
	if progress >= completion_threshold:
		_complete_cleaning()


func _complete_cleaning() -> void:
	_completed = true
	_wiping = false
	# Completion is visually authoritative: no shader fringe may remain while the
	# UI reports 100%. The stricter threshold still requires nearly every stain
	# sample to be wiped before this final mask fill occurs.
	_mask_image.fill(Color.WHITE)
	_mask_texture.update(_mask_image)
	cleaning_progress.emit(1.0)
	if is_instance_valid(_cloth):
		_cloth.hide()
	_set_foam(Vector2.ZERO, false)
	cleaned.emit()


func _paint_circle(local_center: Vector2) -> void:
	var image_center := Vector2(
		local_center.x / size.x * float(mask_resolution),
		local_center.y / size.y * float(mask_resolution)
	)
	var radius_x: float = brush_radius / size.x * float(mask_resolution)
	var radius_y: float = brush_radius / size.y * float(mask_resolution)
	var min_x: int = clampi(floori(image_center.x - radius_x), 0, mask_resolution - 1)
	var max_x: int = clampi(ceili(image_center.x + radius_x), 0, mask_resolution - 1)
	var min_y: int = clampi(floori(image_center.y - radius_y), 0, mask_resolution - 1)
	var max_y: int = clampi(ceili(image_center.y + radius_y), 0, mask_resolution - 1)
	for image_y: int in range(min_y, max_y + 1):
		for image_x: int in range(min_x, max_x + 1):
			var normalized := Vector2(
				(float(image_x) - image_center.x) / maxf(radius_x, 1.0),
				(float(image_y) - image_center.y) / maxf(radius_y, 1.0)
			)
			if normalized.length_squared() <= 1.0:
				_mask_image.set_pixel(image_x, image_y, Color.WHITE)


func _paint_foam_circle(local_center: Vector2) -> void:
	var image_center := Vector2(
		local_center.x / size.x * float(mask_resolution),
		local_center.y / size.y * float(mask_resolution)
	)
	var foam_radius: float = brush_radius * foam_brush_scale
	var radius_x: float = foam_radius / size.x * float(mask_resolution)
	var radius_y: float = foam_radius / size.y * float(mask_resolution)
	var min_x: int = clampi(floori(image_center.x - radius_x), 0, mask_resolution - 1)
	var max_x: int = clampi(ceili(image_center.x + radius_x), 0, mask_resolution - 1)
	var min_y: int = clampi(floori(image_center.y - radius_y), 0, mask_resolution - 1)
	var max_y: int = clampi(ceili(image_center.y + radius_y), 0, mask_resolution - 1)
	for image_y: int in range(min_y, max_y + 1):
		for image_x: int in range(min_x, max_x + 1):
			var normalized := Vector2(
				(float(image_x) - image_center.x) / maxf(radius_x, 1.0),
				(float(image_y) - image_center.y) / maxf(radius_y, 1.0)
			)
			var distance_squared: float = normalized.length_squared()
			if distance_squared > 1.0:
				continue
			var strength: float = clampf(1.0 - distance_squared * 0.45, 0.0, 1.0)
			var current_strength: float = _foam_mask_image.get_pixel(image_x, image_y).r
			if strength > current_strength:
				_foam_mask_image.set_pixel(image_x, image_y, Color(strength, strength, strength, 1.0))


func _decay_foam_mask(elapsed: float) -> void:
	var decay_amount: int = maxi(1, roundi(255.0 * elapsed / maxf(foam_lifetime_seconds, 0.01)))
	var data: PackedByteArray = _foam_mask_image.get_data()
	var remaining: bool = false
	for index: int in range(data.size()):
		var faded_value: int = maxi(0, int(data[index]) - decay_amount)
		data[index] = faded_value
		remaining = remaining or faded_value > 0
	_foam_mask_image.set_data(
		mask_resolution,
		mask_resolution,
		false,
		Image.FORMAT_L8,
		data
	)
	_foam_mask_texture.update(_foam_mask_image)
	_foam_present = remaining


func _calculate_progress() -> float:
	if _sample_points.is_empty():
		return 0.0
	var erased_count: int = 0
	for point: Vector2i in _sample_points:
		if _mask_image.get_pixelv(point).r >= 0.5:
			erased_count += 1
	return float(erased_count) / float(_sample_points.size())


func _update_cloth(pointer_position: Vector2, should_show: bool) -> void:
	if not is_instance_valid(_cloth):
		return
	_cloth.position = pointer_position - _cloth.size * 0.5
	var pointer_inside: bool = Rect2(Vector2.ZERO, size).has_point(pointer_position)
	_cloth.visible = should_show and pointer_inside
	_set_foam(pointer_position, should_show and _wiping and pointer_inside)


func _set_foam(pointer_position: Vector2, active: bool) -> void:
	if not is_instance_valid(_foam_material):
		return
	var safe_size := Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	_foam_material.set_shader_parameter(&"foam_center", pointer_position / safe_size)
	_foam_material.set_shader_parameter(&"brush_active", 1.0 if active else 0.0)
