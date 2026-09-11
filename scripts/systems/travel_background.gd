class_name TravelBackground
extends CanvasLayer
## Scrolls one scene-authored background per route leg and transitions periods through a tunnel.

signal period_changed(display_cycle_progress: float)

enum Period { SUNRISE, AFTERNOON, SUNSET, NIGHT }
const TUNNEL_SFX_CHANNEL: StringName = &"travel_tunnel"

@export_category("Scene Periods")
@export_node_path("Node2D") var sunrise_root_path: NodePath
@export_node_path("Node2D") var afternoon_root_path: NodePath
@export_node_path("Node2D") var sunset_root_path: NodePath
@export_node_path("Node2D") var night_root_path: NodePath
@export_node_path("Control") var tunnel_panel_path: NodePath
@export_node_path("TextureRect") var tunnel_art_path: NodePath
@export_node_path("ColorRect") var tunnel_tint_path: NodePath
@export_category("Route Leg Backgrounds")
@export_enum("Beach", "City", "Desert", "Night Sky") var route_leg_1_background: int = Period.SUNRISE
@export_enum("Beach", "City", "Desert", "Night Sky") var route_leg_2_background: int = Period.AFTERNOON
@export_enum("Beach", "City", "Desert", "Night Sky") var route_leg_3_background: int = Period.SUNSET
@export_enum("Beach", "City", "Desert", "Night Sky") var route_leg_4_background: int = Period.NIGHT
@export_category("Parallax")
@export_range(-1.0, 1.0, 0.05) var travel_direction: float = 1.0
@export_category("Tunnel Transition")
@export_range(0.5, 10.0, 0.25) var tunnel_loop_seconds: float = 4.0
@export var minimum_viewport_size: Vector2 = Vector2(1280.0, 720.0)
@export_range(0.1, 2.0, 0.05) var tunnel_enter_seconds: float = 0.85
@export_range(0.1, 2.0, 0.05) var tunnel_exit_seconds: float = 0.7
@export_range(1.0, 1.3, 0.01) var tunnel_art_height_scale: float = 1.08
@export_range(0.1, 3.0, 0.05) var tunnel_scroll_cycles_per_second: float = 1.15
@export_range(0.0, 0.04, 0.001) var tunnel_motion_blur_distance: float = 0.014
@export_range(0.0, 1.0, 0.05) var tunnel_motion_blur_strength: float = 0.72
@export_range(0.0, 1.0, 0.05) var tunnel_gray_strength: float = 0.58
@export_category("Tunnel Audio")
@export_range(-40.0, 6.0, 0.5) var tunnel_sfx_volume_db: float = -9.0
@export_range(0.5, 1.5, 0.01) var tunnel_sfx_pitch: float = 1.0
@export_range(0.1, 2.0, 0.05) var tunnel_sfx_fade_out_seconds: float = 0.8
@export_category("Travel Weather")
@export_range(0.0, 1.0, 0.01) var daytime_rain_chance: float = 0.38
@export_range(0.0, 1.0, 0.01) var night_rain_chance: float = 0.55
@export_range(0.1, 3.0, 0.05) var weather_fade_seconds: float = 1.0
@export_range(0.0, 1.0, 0.01) var rain_opacity: float = 0.82
@export_range(0.0, 1.0, 0.01) var rain_fog_opacity: float = 0.28
@export_category("Tunnel Time Tint")
@export var tunnel_sunrise_tint: Color = Color(0.18, 0.21, 0.25, 0.38)
@export var tunnel_afternoon_tint: Color = Color(0.27, 0.25, 0.22, 0.34)
@export var tunnel_sunset_tint: Color = Color(0.25, 0.21, 0.21, 0.4)
@export var tunnel_night_tint: Color = Color(0.1, 0.13, 0.18, 0.58)

var _current_period: Period = Period.SUNRISE
var _current_route_leg: int = -1
var _motion_strength: float = 0.0
var _period_root: Node2D
var _tunnel_panel: Control
var _tunnel_art: TextureRect
var _tunnel_tint: ColorRect
var _tunnel_tween: Tween
var _tunnel_active: bool = false
var _tunnel_scroll_offset: float = 0.0
var _tunnel_layout_viewport_size: Vector2 = Vector2.ZERO
var _pending_period: int = -1
var _world_time_scale: float = 1.0
var _cinematic_speed_multiplier: float = 1.0
var _weather_raining: bool = false
var _route_weather: Dictionary = {}
var _weather_tween: Tween
var _weather_rng := RandomNumberGenerator.new()

@onready var _weather_fog: ColorRect = %WeatherFog
@onready var _weather_rain: ColorRect = %WeatherRain


func _ready() -> void:
	_weather_rng.randomize()
	_tunnel_panel = get_node_or_null(tunnel_panel_path) as Control
	_tunnel_art = get_node_or_null(tunnel_art_path) as TextureRect
	_tunnel_tint = get_node_or_null(tunnel_tint_path) as ColorRect
	if is_instance_valid(_tunnel_panel):
		_tunnel_panel.hide()
	_weather_fog.self_modulate.a = 0.0
	_weather_rain.self_modulate.a = 0.0
	_layout_tunnel_art(_get_background_viewport_size())
	_validate_scene_configuration()
	_set_route_leg_background(0)


func _process(delta: float) -> void:
	var scaled_delta: float = delta * _world_time_scale * _cinematic_speed_multiplier
	if _motion_strength > 0.001 and is_instance_valid(_period_root):
		for child: Node in _period_root.get_children():
			var layer := child as Node2D
			if is_instance_valid(layer):
				_scroll_layer(layer, scaled_delta)
	if _tunnel_active:
		# Keep the tunnel alive during the short departure acceleration instead of
		# letting its first frame freeze while the train motion strength ramps up.
		_update_tunnel_scroll(scaled_delta * maxf(_motion_strength, 0.35))


func set_traveling(value: bool) -> void:
	set_motion_strength(1.0 if value else 0.0)


func set_motion_strength(value: float) -> void:
	_motion_strength = clampf(value, 0.0, 1.0)
	_update_rain_motion()


func set_world_time_scale(value: float) -> void:
	_world_time_scale = clampf(value, 0.05, 1.0)
	_update_rain_motion()


func set_cinematic_speed_multiplier(value: float) -> void:
	_cinematic_speed_multiplier = clampf(value, 1.0, 6.0)
	_update_rain_motion()


func configure_weather_seed(seed: int) -> void:
	_weather_rng.seed = ("travel-weather:%d" % seed).hash()
	_route_weather.clear()


func begin_night_service_weather() -> void:
	_set_weather_raining(_weather_rng.randf() < night_rain_chance)


func is_raining() -> bool:
	return _weather_raining


func begin_route_leg(route_leg_index: int, immediate: bool = false) -> void:
	_current_route_leg = maxi(route_leg_index, 0)
	_roll_route_weather(_current_route_leg, immediate)
	var next_period: Period = _period_for_route_leg(_current_route_leg)
	if immediate or next_period == _current_period:
		_cancel_tunnel_transition()
		_build_period(next_period)
		period_changed.emit(_display_progress_for_period(next_period))
		return
	_start_period_transition(next_period)


func update_route_leg_remaining(_remaining_seconds: float) -> void:
	# Period changes now own the tunnel. Keeping this compatibility hook empty
	# prevents the station countdown from spawning a second tunnel pass.
	pass


func show_night_background() -> void:
	_cancel_tunnel_transition()
	_build_period(Period.NIGHT)
	period_changed.emit(_display_progress_for_period(Period.NIGHT))


func _start_period_transition(next_period: Period) -> void:
	if not is_instance_valid(_tunnel_panel):
		_build_period(next_period)
		period_changed.emit(_display_progress_for_period(next_period))
		return
	if _tunnel_tween and _tunnel_tween.is_valid():
		_tunnel_tween.kill()
	_start_tunnel_sfx()
	var viewport_size: Vector2 = _get_background_viewport_size()
	_pending_period = int(next_period)
	_tunnel_active = true
	_tunnel_scroll_offset = 0.0
	_tunnel_panel.size = viewport_size
	_layout_tunnel_art(viewport_size)
	# Enter with the tint of the scenery we are leaving. The tunnel then shifts
	# gradually toward the destination period while it is fully covering the sky.
	_apply_tunnel_period_tint()
	_tunnel_panel.position.x = 0.0
	_tunnel_panel.modulate.a = 0.0
	_tunnel_panel.show()
	_tunnel_tween = create_tween()
	_tunnel_tween.tween_property(
		_tunnel_panel,
		^"modulate:a",
		1.0,
		tunnel_enter_seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Only swap the period after the old scenery is fully covered. Tinting across
	# this hold avoids a one-frame color jump when the destination period commits.
	if is_instance_valid(_tunnel_tint):
		_tunnel_tween.tween_property(
			_tunnel_tint,
			^"color",
			_tunnel_tint_color_for_period(next_period),
			tunnel_loop_seconds
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_tunnel_tween.tween_interval(tunnel_loop_seconds)
	_tunnel_tween.tween_callback(_commit_pending_period)
	_tunnel_tween.tween_callback(_fade_out_tunnel_sfx)
	_tunnel_tween.tween_property(
		_tunnel_panel,
		^"modulate:a",
		0.0,
		tunnel_exit_seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tunnel_tween.tween_callback(_finish_period_transition)


func _commit_pending_period() -> void:
	if _pending_period < Period.SUNRISE:
		return
	var next_period: Period = clampi(_pending_period, Period.SUNRISE, Period.NIGHT)
	_build_period(next_period)
	period_changed.emit(_display_progress_for_period(next_period))


func _finish_period_transition() -> void:
	_pending_period = -1
	_tunnel_active = false
	_tunnel_tween = null
	if not is_instance_valid(_tunnel_panel):
		return
	_tunnel_panel.hide()
	_tunnel_panel.position.x = 0.0
	_tunnel_panel.modulate.a = 1.0


func _cancel_tunnel_transition() -> void:
	if _tunnel_tween and _tunnel_tween.is_valid():
		_tunnel_tween.kill()
	_tunnel_tween = null
	_pending_period = -1
	_tunnel_active = false
	_stop_tunnel_sfx_immediately()
	if not is_instance_valid(_tunnel_panel):
		return
	_tunnel_panel.hide()
	_tunnel_panel.position.x = 0.0
	_tunnel_panel.modulate.a = 1.0


func set_tunnel_active(value: bool, immediate: bool = false) -> void:
	if not is_instance_valid(_tunnel_panel):
		return
	if not value and immediate:
		_cancel_tunnel_transition()
		return
	if value == _tunnel_active:
		return
	if _tunnel_tween and _tunnel_tween.is_valid():
		_tunnel_tween.kill()
	var viewport_size := _get_background_viewport_size()
	_tunnel_panel.size = viewport_size
	_tunnel_active = value
	if value:
		_start_tunnel_sfx()
		_pending_period = -1
		_tunnel_scroll_offset = 0.0
		_layout_tunnel_art(viewport_size)
		_apply_tunnel_period_tint()
		_tunnel_panel.show()
		if immediate:
			_tunnel_panel.position.x = 0.0
			_tunnel_panel.modulate.a = 1.0
			return
		_tunnel_panel.position.x = 0.0
		_tunnel_panel.modulate.a = 0.0
		_tunnel_tween = create_tween()
		_tunnel_tween.tween_property(
			_tunnel_panel,
			^"modulate:a",
			1.0,
			tunnel_enter_seconds
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		return
	if not _tunnel_panel.visible:
		_tunnel_panel.position.x = 0.0
		_tunnel_panel.modulate.a = 1.0
		return
	_pending_period = -1
	_fade_out_tunnel_sfx()
	_tunnel_tween = create_tween()
	_tunnel_tween.tween_property(
		_tunnel_panel,
		^"modulate:a",
		0.0,
		tunnel_exit_seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tunnel_tween.tween_callback(_finish_period_transition)


func _start_tunnel_sfx() -> void:
	GameSFX.start_loop(
		TUNNEL_SFX_CHANNEL,
		&"speed_woosh",
		tunnel_sfx_volume_db,
		tunnel_sfx_pitch
	)


func _fade_out_tunnel_sfx() -> void:
	GameSFX.stop_loop(TUNNEL_SFX_CHANNEL, tunnel_sfx_fade_out_seconds)


func _stop_tunnel_sfx_immediately() -> void:
	GameSFX.stop_loop(TUNNEL_SFX_CHANNEL)


func _roll_route_weather(route_leg_index: int, immediate: bool) -> void:
	if not _route_weather.has(route_leg_index):
		_route_weather[route_leg_index] = _weather_rng.randf() < daytime_rain_chance
	_set_weather_raining(bool(_route_weather[route_leg_index]), immediate)


func _set_weather_raining(value: bool, immediate: bool = false) -> void:
	_weather_raining = value
	if is_instance_valid(_weather_tween) and _weather_tween.is_valid():
		_weather_tween.kill()
	var rain_target: float = rain_opacity if value else 0.0
	var fog_target: float = rain_fog_opacity if value else 0.0
	if immediate or not is_inside_tree():
		_weather_rain.self_modulate.a = rain_target
		_weather_fog.self_modulate.a = fog_target
		return
	_weather_tween = create_tween().set_parallel(true)
	_weather_tween.tween_property(
		_weather_rain, ^"self_modulate:a", rain_target, weather_fade_seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_weather_tween.tween_property(
		_weather_fog, ^"self_modulate:a", fog_target, weather_fade_seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _update_rain_motion() -> void:
	if not is_node_ready():
		return
	var rain_material := _weather_rain.material as ShaderMaterial
	if rain_material == null:
		return
	var movement: float = maxf(_motion_strength * _world_time_scale, 0.25)
	rain_material.set_shader_parameter(
		&"motion_boost",
		clampf(movement * _cinematic_speed_multiplier, 0.5, 5.0)
	)


func _set_route_leg_background(route_leg_index: int) -> void:
	_current_route_leg = maxi(route_leg_index, 0)
	var next_period: Period = _period_for_route_leg(_current_route_leg)
	_build_period(next_period)
	period_changed.emit(_display_progress_for_period(next_period))


func _period_for_route_leg(route_leg_index: int) -> Period:
	var configured_periods: Array[int] = [
		route_leg_1_background,
		route_leg_2_background,
		route_leg_3_background,
		route_leg_4_background,
	]
	var safe_index: int = clampi(route_leg_index, 0, configured_periods.size() - 1)
	return clampi(configured_periods[safe_index], Period.SUNRISE, Period.NIGHT)


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
	_apply_tunnel_period_tint()


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


func _update_tunnel_scroll(delta: float) -> void:
	if not is_instance_valid(_tunnel_art):
		return
	var viewport_size := _get_background_viewport_size()
	if not viewport_size.is_equal_approx(_tunnel_layout_viewport_size):
		_layout_tunnel_art(viewport_size)
	var direction: float = 1.0 if travel_direction >= 0.0 else -1.0
	_tunnel_scroll_offset = fposmod(
		_tunnel_scroll_offset + delta * tunnel_scroll_cycles_per_second * direction,
		1.0
	)
	_apply_tunnel_shader_parameters()


func _layout_tunnel_art(viewport_size: Vector2) -> void:
	if not is_instance_valid(_tunnel_art) or _tunnel_art.texture == null:
		return
	var source_size: Vector2 = _tunnel_art.texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	_tunnel_layout_viewport_size = viewport_size
	_apply_tunnel_shader_parameters()


func _apply_tunnel_shader_parameters() -> void:
	if not is_instance_valid(_tunnel_art) or _tunnel_art.texture == null:
		return
	var tunnel_material := _tunnel_art.material as ShaderMaterial
	if tunnel_material == null:
		return
	var source_size: Vector2 = _tunnel_art.texture.get_size()
	var viewport_size: Vector2 = _get_background_viewport_size()
	var source_aspect: float = source_size.x / maxf(source_size.y, 1.0)
	var viewport_aspect: float = viewport_size.x / maxf(viewport_size.y, 1.0)
	var visible_width: float = clampf(
		viewport_aspect / maxf(source_aspect * tunnel_art_height_scale, 0.001),
		0.05,
		1.0
	)
	tunnel_material.set_shader_parameter(&"scroll_offset", _tunnel_scroll_offset)
	tunnel_material.set_shader_parameter(&"visible_uv_width", visible_width)
	tunnel_material.set_shader_parameter(&"visible_uv_height", 1.0 / tunnel_art_height_scale)
	tunnel_material.set_shader_parameter(&"blur_distance", tunnel_motion_blur_distance)
	tunnel_material.set_shader_parameter(&"blur_strength", tunnel_motion_blur_strength)
	tunnel_material.set_shader_parameter(&"gray_strength", tunnel_gray_strength)


func _get_background_viewport_size() -> Vector2:
	var visible_size: Vector2 = get_viewport().get_visible_rect().size
	return Vector2(
		maxf(visible_size.x, minimum_viewport_size.x),
		maxf(visible_size.y, minimum_viewport_size.y)
	)


func _apply_tunnel_period_tint() -> void:
	_apply_tunnel_tint_for_period(_current_period)


func _apply_tunnel_tint_for_period(period: Period) -> void:
	if not is_instance_valid(_tunnel_tint):
		return
	_tunnel_tint.color = _tunnel_tint_color_for_period(period)


func _tunnel_tint_color_for_period(period: Period) -> Color:
	match period:
		Period.AFTERNOON:
			return tunnel_afternoon_tint
		Period.SUNSET:
			return tunnel_sunset_tint
		Period.NIGHT:
			return tunnel_night_tint
		_:
			return tunnel_sunrise_tint


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
	if not is_instance_valid(_tunnel_art):
		push_warning("Travel Background has no Inspector-assigned tunnel artwork.")
	if not is_instance_valid(_tunnel_tint):
		push_warning("Travel Background has no Inspector-assigned tunnel time tint.")
