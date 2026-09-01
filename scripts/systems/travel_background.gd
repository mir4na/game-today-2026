class_name TravelBackground
extends CanvasLayer
## Layered railway backdrop with period-specific parallax and tunnel transitions.

signal period_changed(display_cycle_progress: float)

enum Period { SUNRISE, AFTERNOON, SUNSET, NIGHT }

const VIEWPORT_REFERENCE_WIDTH: float = 1280.0
const ART_REFERENCE_WIDTH: float = 5356.0
const ART_REFERENCE_HEIGHT: float = 1320.0
const PERIOD_TEXTURES: Dictionary = {
	Period.SUNRISE: [
		# The reference uses layer 1 as the full sunrise color field, with the
		# cropped cloud artwork composed over it near the top of the canvas.
		{"texture": preload("res://assets/environment/sunrise_layer1.png"), "speed": 56.0, "alpha": 1.0, "fill_canvas": true},
		{"texture": preload("res://assets/environment/sunrise_layer2.png"), "speed": 18.0, "alpha": 1.0, "cloud": true},
	],
	Period.AFTERNOON: [
		{"texture": preload("res://assets/environment/afternoon_layer4.png"), "speed": 18.0, "alpha": 1.0, "cloud": true},
		{"texture": preload("res://assets/environment/afternoon_layer3.png"), "speed": 30.0, "alpha": 1.0, "align": "bottom"},
		{"texture": preload("res://assets/environment/afternoon_layer2.png"), "speed": 43.0, "alpha": 1.0, "align": "bottom"},
		{"texture": preload("res://assets/environment/afternoon_layer1.png"), "speed": 58.0, "alpha": 1.0, "align": "bottom"},
	],
	Period.SUNSET: [
		{"texture": preload("res://assets/environment/sunset_layer4.png"), "speed": 28.0, "alpha": 1.0, "align": "top"},
		{"texture": preload("res://assets/environment/sunset_layer3.png"), "speed": 18.0, "alpha": 1.0, "cloud": true},
		{"texture": preload("res://assets/environment/sunset_layer2.png"), "speed": 45.0, "alpha": 1.0, "align": "top"},
		{"texture": preload("res://assets/environment/sunset_layer1.png"), "speed": 60.0, "alpha": 1.0, "align": "bottom", "y_offset": 24.0},
	],
	Period.NIGHT: [
		{"texture": preload("res://assets/environment/night_layer2.png"), "speed": 5.0, "alpha": 1.0, "align": "bottom"},
		{"texture": preload("res://assets/environment/night_layer1.png"), "speed": 18.0, "alpha": 1.0, "cloud": true, "y_offset": -18.0},
	],
}

@export_category("Background Layout")
@export_range(0.1, 2.0, 0.05) var art_scale_multiplier: float = 1.0
@export var background_position: Vector2 = Vector2(0.0, 200.0)
@export_range(0.0, 1.0, 0.01) var cloud_vertical_ratio: float = 0.58
@export_group("Sunrise Override", "sunrise_")
@export_range(0.1, 2.0, 0.05) var sunrise_scale: float = 1.0
@export var sunrise_offset: Vector2 = Vector2.ZERO
@export_group("Afternoon Override", "afternoon_")
@export_range(0.1, 2.0, 0.05) var afternoon_scale: float = 1.0
@export var afternoon_offset: Vector2 = Vector2.ZERO
@export_group("Sunset Override", "sunset_")
@export_range(0.1, 2.0, 0.05) var sunset_scale: float = 1.0
@export var sunset_offset: Vector2 = Vector2.ZERO
@export_group("Night Override", "night_")
@export_range(0.1, 2.0, 0.05) var night_scale: float = 1.0
@export var night_offset: Vector2 = Vector2.ZERO
@export_group("")
@export_category("Parallax")
@export_range(-1.0, 1.0, 0.05) var travel_direction: float = 1.0
@export_category("Period Thresholds")
@export_range(0.0, 1.0, 0.01) var afternoon_start: float = 0.25
@export_range(0.0, 1.0, 0.01) var sunset_start: float = 0.56
@export_range(0.0, 1.0, 0.01) var night_start: float = 0.82
@export_category("Tunnel Transition")
@export_range(0.1, 2.0, 0.05) var tunnel_enter_seconds: float = 0.7
@export_range(0.0, 1.0, 0.05) var tunnel_hold_seconds: float = 0.18
@export_range(0.1, 2.0, 0.05) var tunnel_exit_seconds: float = 0.8

var _current_period: Period = Period.SUNRISE
var _requested_period: Period = Period.SUNRISE
var _motion_strength: float = 0.0
var _period_root: Node2D
var _tunnel_panel: Control
var _transition_tween: Tween
var _transition_active: bool = false


func _ready() -> void:
	_build_period(Period.SUNRISE)
	period_changed.emit(_display_progress_for_period(Period.SUNRISE))


func _process(delta: float) -> void:
	if _motion_strength <= 0.001 or not is_instance_valid(_period_root):
		return
	for layer: Node in _period_root.get_children():
		if layer is Node2D:
			_scroll_layer(layer as Node2D, delta)


func set_traveling(value: bool) -> void:
	set_motion_strength(1.0 if value else 0.0)


func set_motion_strength(value: float) -> void:
	_motion_strength = clampf(value, 0.0, 1.0)


func set_cycle_progress(value: float) -> void:
	_requested_period = _period_for_progress(clampf(value, 0.0, 1.0))
	if _requested_period == _current_period or _transition_active:
		return
	_start_tunnel_transition(_requested_period)


func _period_for_progress(progress: float) -> Period:
	if progress >= night_start:
		return Period.NIGHT
	if progress >= sunset_start:
		return Period.SUNSET
	if progress >= afternoon_start:
		return Period.AFTERNOON
	return Period.SUNRISE


func _display_progress_for_period(period: Period) -> float:
	match period:
		Period.AFTERNOON:
			return 0.34
		Period.SUNSET:
			return 0.62
		Period.NIGHT:
			return 1.0
		_:
			return 0.0


func _build_period(period: Period) -> void:
	if is_instance_valid(_period_root):
		_period_root.queue_free()
	_period_root = Node2D.new()
	_period_root.name = "%sLayers" % Period.keys()[period]
	_period_root.position = background_position + _period_offset(period)
	add_child(_period_root)
	move_child(_period_root, 0)
	var viewport_width: float = maxf(get_viewport().get_visible_rect().size.x, VIEWPORT_REFERENCE_WIDTH)
	var art_scale: float = (
		(viewport_width / ART_REFERENCE_WIDTH)
		* art_scale_multiplier
		* _period_scale(period)
	)
	var canvas_width: float = ART_REFERENCE_WIDTH * art_scale
	var canvas_height: float = ART_REFERENCE_HEIGHT * art_scale
	var layer_index: int = 0
	for layer_spec: Dictionary in PERIOD_TEXTURES[period]:
		var texture: Texture2D = layer_spec["texture"] as Texture2D
		var layer_root := Node2D.new()
		layer_root.name = "ParallaxLayer%d" % layer_index
		layer_root.set_meta(&"scroll_speed", float(layer_spec["speed"]))
		layer_root.set_meta(&"wrap_width", canvas_width)
		_period_root.add_child(layer_root)
		var fill_canvas: bool = bool(layer_spec.get("fill_canvas", false))
		var is_cloud: bool = bool(layer_spec.get("cloud", false))
		var vertical_alignment: String = str(layer_spec.get("align", "bottom"))
		var layer_y: float = canvas_height * cloud_vertical_ratio if is_cloud else (
			0.0 if vertical_alignment == "top" else canvas_height - float(texture.get_height()) * art_scale
		)
		layer_y += float(layer_spec.get("y_offset", 0.0))
		var centered_x: float = (ART_REFERENCE_WIDTH - float(texture.get_width())) * 0.5 * art_scale
		var copy_count: int = maxi(2, ceili(viewport_width / maxf(canvas_width, 1.0)) + 2)
		for copy_index: int in range(copy_count):
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.centered = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			sprite.scale = Vector2(
				art_scale,
				canvas_height / float(texture.get_height()) if fill_canvas else art_scale
			)
			sprite.position = Vector2(
				float(copy_index) * canvas_width + centered_x,
				layer_y
			)
			sprite.modulate.a = float(layer_spec["alpha"])
			layer_root.add_child(sprite)
		layer_index += 1
	_current_period = period


func _period_scale(period: Period) -> float:
	match period:
		Period.AFTERNOON:
			return afternoon_scale
		Period.SUNSET:
			return sunset_scale
		Period.NIGHT:
			return night_scale
		_:
			return sunrise_scale


func _period_offset(period: Period) -> Vector2:
	match period:
		Period.AFTERNOON:
			return afternoon_offset
		Period.SUNSET:
			return sunset_offset
		Period.NIGHT:
			return night_offset
		_:
			return sunrise_offset


func _scroll_layer(layer: Node2D, delta: float) -> void:
	var wrap_width: float = float(layer.get_meta(&"wrap_width", 0.0))
	if wrap_width <= 0.0:
		return
	var speed: float = float(layer.get_meta(&"scroll_speed", 0.0))
	layer.position.x += speed * travel_direction * _motion_strength * delta
	if travel_direction >= 0.0 and layer.position.x >= 0.0:
		layer.position.x -= wrap_width
	elif travel_direction < 0.0 and layer.position.x <= -wrap_width:
		layer.position.x += wrap_width


func _start_tunnel_transition(next_period: Period) -> void:
	_transition_active = true
	_tunnel_panel = _create_tunnel_panel()
	add_child(_tunnel_panel)
	var viewport_width: float = maxf(get_viewport().get_visible_rect().size.x, 1280.0)
	_tunnel_panel.position.x = -viewport_width
	_transition_tween = create_tween()
	_transition_tween.tween_property(
		_tunnel_panel,
		"position:x",
		0.0,
		tunnel_enter_seconds
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition_tween.tween_callback(_swap_period.bind(next_period))
	_transition_tween.tween_interval(tunnel_hold_seconds)
	_transition_tween.tween_property(
		_tunnel_panel,
		"position:x",
		viewport_width,
		tunnel_exit_seconds
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_callback(_finish_tunnel_transition)


func _swap_period(next_period: Period) -> void:
	_build_period(next_period)
	period_changed.emit(_display_progress_for_period(next_period))


func _finish_tunnel_transition() -> void:
	if is_instance_valid(_tunnel_panel):
		_tunnel_panel.queue_free()
	_tunnel_panel = null
	_transition_active = false
	if _requested_period != _current_period:
		_start_tunnel_transition(_requested_period)


func _create_tunnel_panel() -> Control:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel := Control.new()
	panel.name = "TunnelTransition"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = Vector2(maxf(viewport_size.x, 1280.0), maxf(viewport_size.y, 720.0))
	var darkness := ColorRect.new()
	darkness.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE
	darkness.color = Color("090b10")
	panel.add_child(darkness)
	for line_y: float in [138.0, 360.0, 582.0]:
		var tunnel_line := ColorRect.new()
		tunnel_line.position = Vector2(0.0, line_y)
		tunnel_line.size = Vector2(panel.size.x, 3.0)
		tunnel_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tunnel_line.color = Color(0.18, 0.2, 0.23, 0.22)
		panel.add_child(tunnel_line)
	return panel
