extends Node
## Installs the project cursor set once and keeps it legible at every window size.

const HAND_SOURCE: Texture2D = preload("res://assets/ui/Cursor_Hand.png")
const POINT_SOURCE: Texture2D = preload("res://assets/ui/Cursor_Point.png")
const HOLD_SOURCE: Texture2D = preload("res://assets/ui/Cursor_Hold.png")

const REFERENCE_WINDOW_HEIGHT: float = 1080.0
const CURSOR_LONG_SIDE_AT_REFERENCE: float = 30.0
const MIN_CURSOR_LONG_SIDE: int = 20
const MAX_CURSOR_LONG_SIDE: int = 46

# Hotspots are stored relative to the source artwork, so resizing cannot move
# the click point away from the fingertip/palm.
const HAND_HOTSPOT_RATIO := Vector2(0.43, 0.42)
const POINT_HOTSPOT_RATIO := Vector2(0.43, 0.025)
const HOLD_HOTSPOT_RATIO := Vector2(0.50, 0.43)

var _holding_mouse: bool = false
var _last_window_size := Vector2i.ZERO
var _hand_cursor: Texture2D
var _point_cursor: Texture2D
var _hold_cursor: Texture2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_window_size = DisplayServer.window_get_size()
	get_tree().node_added.connect(_configure_interactive_control)
	get_viewport().size_changed.connect(_queue_cursor_refresh)
	_configure_existing_controls(get_tree().root)
	_refresh_cursor_textures()


func _process(_delta: float) -> void:
	var window_size := DisplayServer.window_get_size()
	if window_size != _last_window_size:
		_last_window_size = window_size
		_queue_cursor_refresh()
	# Controls can update the cursor on mouse motion. Reassert the clenched hand
	# while the button is held so dragging remains visually unambiguous.
	if _holding_mouse:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_DRAG)


func _input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button == null or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	_holding_mouse = mouse_button.pressed
	if _holding_mouse:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_DRAG)
	else:
		_restore_hover_cursor_shape()


func _queue_cursor_refresh() -> void:
	call_deferred(&"_refresh_cursor_textures")


func _refresh_cursor_textures() -> void:
	var cursor_long_side := _cursor_long_side_for_window(DisplayServer.window_get_size())
	_hand_cursor = _scaled_texture(HAND_SOURCE, cursor_long_side)
	_point_cursor = _scaled_texture(POINT_SOURCE, cursor_long_side)
	_hold_cursor = _scaled_texture(HOLD_SOURCE, cursor_long_side)

	Input.set_custom_mouse_cursor(_hand_cursor, Input.CURSOR_ARROW, _hotspot(_hand_cursor, HAND_HOTSPOT_RATIO))
	Input.set_custom_mouse_cursor(_point_cursor, Input.CURSOR_POINTING_HAND, _hotspot(_point_cursor, POINT_HOTSPOT_RATIO))
	Input.set_custom_mouse_cursor(_hold_cursor, Input.CURSOR_DRAG, _hotspot(_hold_cursor, HOLD_HOTSPOT_RATIO))
	Input.set_custom_mouse_cursor(_hold_cursor, Input.CURSOR_CAN_DROP, _hotspot(_hold_cursor, HOLD_HOTSPOT_RATIO))
	Input.set_custom_mouse_cursor(_hold_cursor, Input.CURSOR_MOVE, _hotspot(_hold_cursor, HOLD_HOTSPOT_RATIO))
	_restore_hover_cursor_shape()


func _cursor_long_side_for_window(window_size: Vector2i) -> int:
	var safe_height: float = maxf(float(window_size.y), 1.0)
	var scaled_size := roundi(CURSOR_LONG_SIDE_AT_REFERENCE * safe_height / REFERENCE_WINDOW_HEIGHT)
	return clampi(scaled_size, MIN_CURSOR_LONG_SIDE, MAX_CURSOR_LONG_SIDE)


func _scaled_texture(source: Texture2D, target_long_side: int) -> Texture2D:
	var source_image := source.get_image()
	if source_image == null or source_image.is_empty():
		return source
	var source_size := Vector2i(source_image.get_width(), source_image.get_height())
	var scale_factor: float = float(target_long_side) / float(maxi(source_size.x, source_size.y))
	var target_size := Vector2i(
		maxi(1, roundi(float(source_size.x) * scale_factor)),
		maxi(1, roundi(float(source_size.y) * scale_factor))
	)
	var resized_image := source_image.duplicate()
	resized_image.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(resized_image)


func _hotspot(texture: Texture2D, ratio: Vector2) -> Vector2:
	var texture_size := texture.get_size()
	return Vector2(
		clampf(texture_size.x * ratio.x, 0.0, maxf(texture_size.x - 1.0, 0.0)),
		clampf(texture_size.y * ratio.y, 0.0, maxf(texture_size.y - 1.0, 0.0))
	)


func _restore_hover_cursor_shape() -> void:
	var hovered_control := get_viewport().gui_get_hovered_control()
	if is_instance_valid(hovered_control) and hovered_control.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_POINTING_HAND)
	else:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)


func _configure_existing_controls(node: Node) -> void:
	_configure_interactive_control(node)
	for child: Node in node.get_children():
		_configure_existing_controls(child)


func _configure_interactive_control(node: Node) -> void:
	# Buttons should use the pointing finger even when a scene author leaves the
	# engine's arrow default in place. Deliberate drag/resize cursors are kept.
	if node is BaseButton and node.mouse_default_cursor_shape == Control.CURSOR_ARROW:
		node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif node is Slider and node.mouse_default_cursor_shape == Control.CURSOR_ARROW:
		node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
