class_name TravelBackground
extends CanvasLayer
## Switches and scrolls the fully scene-authored travel background hierarchy.

signal period_changed(display_cycle_progress: float)

enum Period { SUNRISE, AFTERNOON, SUNSET, NIGHT }

@export_category("Scene Periods")
@export_node_path("Node2D") var sunrise_root_path: NodePath
@export_node_path("Node2D") var afternoon_root_path: NodePath
@export_node_path("Node2D") var sunset_root_path: NodePath
@export_node_path("Node2D") var night_root_path: NodePath
@export_node_path("Control") var tunnel_panel_path: NodePath
@export_category("Parallax")
@export_range(-1.0, 1.0, 0.05) var travel_direction: float = 1.0
@export_category("Period Thresholds")
@export_range(0.0, 1.0, 0.01) var afternoon_start: float = 0.25
@export_range(0.0, 1.0, 0.01) var sunset_start: float = 0.56
@export_range(0.0, 1.0, 0.01) var night_start: float = 0.82
@export_category("Tunnel Transition")
@export var minimum_viewport_size: Vector2 = Vector2(1280.0, 720.0)
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
	_tunnel_panel = get_node_or_null(tunnel_panel_path) as Control
	if is_instance_valid(_tunnel_panel):
		_tunnel_panel.hide()
	_validate_scene_configuration()
	_build_period(Period.SUNRISE)
	period_changed.emit(_display_progress_for_period(Period.SUNRISE))


func _process(delta: float) -> void:
	if _motion_strength <= 0.001 or not is_instance_valid(_period_root):
		return
	for child: Node in _period_root.get_children():
		var layer := child as Node2D
		if is_instance_valid(layer):
			_scroll_layer(layer, delta)


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
	var next_root: Node2D = _period_scene_root(period)
	if not is_instance_valid(next_root):
		push_error("Travel Background is missing the scene root for %s." % Period.keys()[period])
		return
	for configured_period: Period in Period.values():
		var configured_root: Node2D = _period_scene_root(configured_period)
		if is_instance_valid(configured_root):
			configured_root.visible = configured_root == next_root
	_period_root = next_root
	_current_period = period


func _period_scene_root(period: Period) -> Node2D:
	var configured_path: NodePath
	match period:
		Period.AFTERNOON:
			configured_path = afternoon_root_path
		Period.SUNSET:
			configured_path = sunset_root_path
		Period.NIGHT:
			configured_path = night_root_path
		_:
			configured_path = sunrise_root_path
	return get_node_or_null(configured_path) as Node2D


func _scroll_layer(layer: Node2D, delta: float) -> void:
	var wrap_width: float = float(layer.get(&"wrap_width"))
	if wrap_width <= 0.0:
		return
	var speed: float = float(layer.get(&"scroll_speed"))
	layer.position.x += speed * travel_direction * _motion_strength * delta
	if travel_direction >= 0.0 and layer.position.x >= 0.0:
		layer.position.x -= wrap_width
	elif travel_direction < 0.0 and layer.position.x <= -wrap_width:
		layer.position.x += wrap_width


func _start_tunnel_transition(next_period: Period) -> void:
	if not is_instance_valid(_tunnel_panel):
		_swap_period(next_period)
		return
	_transition_active = true
	var viewport_width: float = maxf(get_viewport().get_visible_rect().size.x, minimum_viewport_size.x)
	var viewport_height: float = maxf(get_viewport().get_visible_rect().size.y, minimum_viewport_size.y)
	_tunnel_panel.size = Vector2(viewport_width, viewport_height)
	_tunnel_panel.position.x = -viewport_width
	_tunnel_panel.show()
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
		_tunnel_panel.hide()
	_transition_active = false
	if _requested_period != _current_period:
		_start_tunnel_transition(_requested_period)


func _validate_scene_configuration() -> void:
	for period: Period in Period.values():
		var root_for_period: Node2D = _period_scene_root(period)
		if not is_instance_valid(root_for_period):
			push_error("Travel Background needs an Inspector-assigned root for %s." % Period.keys()[period])
			continue
		for child: Node in root_for_period.get_children():
			if child is Node2D and child.get_script() == null:
				push_warning("Travel Background layer '%s' needs its scene-authored parallax script." % child.get_path())
	if not is_instance_valid(_tunnel_panel):
		push_warning("Travel Background has no Inspector-assigned tunnel panel.")
