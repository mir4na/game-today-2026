class_name TravelBackground
extends CanvasLayer
## Scrolls one scene-authored background per route leg and owns the tunnel approach.

signal period_changed(display_cycle_progress: float)

enum Period { SUNRISE, AFTERNOON, SUNSET, NIGHT }

@export_category("Scene Periods")
@export_node_path("Node2D") var sunrise_root_path: NodePath
@export_node_path("Node2D") var afternoon_root_path: NodePath
@export_node_path("Node2D") var sunset_root_path: NodePath
@export_node_path("Node2D") var night_root_path: NodePath
@export_node_path("Control") var tunnel_panel_path: NodePath
@export_category("Route Leg Backgrounds")
@export_enum("Beach", "City", "Desert", "Night Sky") var route_leg_1_background: int = Period.SUNRISE
@export_enum("Beach", "City", "Desert", "Night Sky") var route_leg_2_background: int = Period.AFTERNOON
@export_enum("Beach", "City", "Desert", "Night Sky") var route_leg_3_background: int = Period.SUNSET
@export_enum("Beach", "City", "Desert", "Night Sky") var route_leg_4_background: int = Period.NIGHT
@export_category("Parallax")
@export_range(-1.0, 1.0, 0.05) var travel_direction: float = 1.0
@export_category("Tunnel Approach")
@export_range(1.0, 60.0, 0.5) var tunnel_approach_seconds: float = 15.0
@export var minimum_viewport_size: Vector2 = Vector2(1280.0, 720.0)
@export_range(0.1, 2.0, 0.05) var tunnel_enter_seconds: float = 0.85
@export_range(0.1, 2.0, 0.05) var tunnel_exit_seconds: float = 0.7

var _current_period: Period = Period.SUNRISE
var _current_route_leg: int = -1
var _motion_strength: float = 0.0
var _period_root: Node2D
var _tunnel_panel: Control
var _tunnel_tween: Tween
var _tunnel_active: bool = false
var _world_time_scale: float = 1.0


func _ready() -> void:
	_tunnel_panel = get_node_or_null(tunnel_panel_path) as Control
	if is_instance_valid(_tunnel_panel):
		_tunnel_panel.hide()
	_validate_scene_configuration()
	_set_route_leg_background(0)


func _process(delta: float) -> void:
	if _motion_strength <= 0.001 or not is_instance_valid(_period_root):
		return
	for child: Node in _period_root.get_children():
		var layer := child as Node2D
		if is_instance_valid(layer):
			_scroll_layer(layer, delta * _world_time_scale)


func set_traveling(value: bool) -> void:
	set_motion_strength(1.0 if value else 0.0)


func set_motion_strength(value: float) -> void:
	_motion_strength = clampf(value, 0.0, 1.0)


func set_world_time_scale(value: float) -> void:
	_world_time_scale = clampf(value, 0.05, 1.0)


func begin_route_leg(route_leg_index: int, immediate: bool = false) -> void:
	_set_route_leg_background(route_leg_index)
	set_tunnel_active(false, immediate)


func update_route_leg_remaining(remaining_seconds: float) -> void:
	if remaining_seconds <= tunnel_approach_seconds:
		set_tunnel_active(true)


func show_night_background() -> void:
	_build_period(Period.NIGHT)
	period_changed.emit(_display_progress_for_period(Period.NIGHT))


func set_tunnel_active(value: bool, immediate: bool = false) -> void:
	if not is_instance_valid(_tunnel_panel):
		return
	if value == _tunnel_active:
		return
	if _tunnel_tween and _tunnel_tween.is_valid():
		_tunnel_tween.kill()
	var viewport_size := Vector2(
		maxf(get_viewport().get_visible_rect().size.x, minimum_viewport_size.x),
		maxf(get_viewport().get_visible_rect().size.y, minimum_viewport_size.y)
	)
	_tunnel_panel.size = viewport_size
	_tunnel_active = value
	if value:
		_tunnel_panel.show()
		if immediate:
			_tunnel_panel.position.x = 0.0
			return
		_tunnel_panel.position.x = -viewport_size.x
		_tunnel_tween = create_tween()
		_tunnel_tween.tween_property(
			_tunnel_panel,
			^"position:x",
			0.0,
			tunnel_enter_seconds
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		return
	if immediate:
		_tunnel_panel.hide()
		_tunnel_panel.position.x = -viewport_size.x
		return
	if not _tunnel_panel.visible:
		_tunnel_panel.position.x = -viewport_size.x
		return
	_tunnel_tween = create_tween()
	_tunnel_tween.tween_property(
		_tunnel_panel,
		^"position:x",
		viewport_size.x,
		tunnel_exit_seconds
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tunnel_tween.tween_callback(_finish_tunnel_exit.bind(viewport_size.x))


func _set_route_leg_background(route_leg_index: int) -> void:
	_current_route_leg = maxi(route_leg_index, 0)
	var configured_periods: Array[int] = [
		route_leg_1_background,
		route_leg_2_background,
		route_leg_3_background,
		route_leg_4_background,
	]
	var period_index: int = configured_periods[clampi(_current_route_leg, 0, configured_periods.size() - 1)]
	var next_period: Period = clampi(period_index, Period.SUNRISE, Period.NIGHT)
	_build_period(next_period)
	period_changed.emit(_display_progress_for_period(next_period))


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


func _finish_tunnel_exit(viewport_width: float) -> void:
	if not is_instance_valid(_tunnel_panel):
		return
	_tunnel_panel.hide()
	_tunnel_panel.position.x = -viewport_width


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
