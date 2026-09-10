class_name NightMarketUI
extends Control
## Animated angel market shown between the daylight paycheck and night service.

signal purchase_requested(tool_id: StringName)
signal continue_requested

@export_category("Inspector Copy")
@export var blessings_template: String = "Blessings  %d"
@export var audit_stock_template: String = "%d owned  •  %d Blessings"
@export var radar_stock_template: String = "%d owned  •  %d Blessings"
@export var speed_level_template: String = "Level %d / %d  •  15 seconds  •  %d Blessings"
@export var maximum_speed_text: String = "Maximum time-bending level"
@export_category("Floating Motion")
@export_range(0.0, 20.0, 0.5) var angel_float_height: float = 8.0
@export_range(0.0, 5.0, 0.05) var angel_float_speed: float = 1.15
@export_range(0.0, 5.0, 0.05) var angel_sway_degrees: float = 1.25
@export_range(0.0, 16.0, 0.5) var shelf_float_height: float = 6.0
@export_range(0.0, 5.0, 0.05) var shelf_float_speed: float = 1.35
@export_range(0.0, 5.0, 0.05) var shelf_sway_degrees: float = 1.1
@export_range(0.0, 90.0, 1.0) var shelf_rotation_degrees_per_second: float = 22.0
@export_range(0.0, 10.0, 0.5) var item_hover_height: float = 3.5
@export_range(0.0, 5.0, 0.05) var item_hover_speed: float = 1.6
@export_range(0.25, 3.0, 0.05) var light_rotation_intensity: float = 1.0
@export_category("Transition")
@export_range(0.2, 2.0, 0.05) var entrance_fog_rise_duration: float = 0.8
@export_range(0.0, 1.0, 0.05) var entrance_fog_hold_seconds: float = 0.12
@export_range(0.2, 2.0, 0.05) var gate_open_duration: float = 0.78
@export_range(0.2, 2.0, 0.05) var entrance_fog_release_duration: float = 0.72
@export_range(0.1, 1.5, 0.05) var entrance_duration: float = 0.62
@export_range(0.1, 1.5, 0.05) var content_exit_duration: float = 0.52
@export_range(0.1, 1.5, 0.05) var gate_close_duration: float = 0.68
@export_range(0.2, 3.0, 0.05) var transition_fog_rise_duration: float = 1.15
@export_range(0.0, 1.5, 0.05) var transition_fog_hold_seconds: float = 0.2
@export_range(0.2, 2.0, 0.05) var transition_fog_release_duration: float = 0.8
@export_category("Button Feedback")
@export_range(1.0, 1.2, 0.01) var item_button_hover_scale: float = 1.06
@export_range(0.05, 0.35, 0.01) var item_button_hover_duration: float = 0.14
@export_category("Standalone Preview")
@export_range(0, 999, 1) var preview_blessings: int = 100

var _snapshot: Dictionary = {}
var _continue_sent: bool = false
var _input_locked: bool = false
var _motion_time: float = 0.0
var _market_tween: Tween
var _highlight_tweens: Dictionary = {}
var _item_float_tweens: Dictionary = {}
var _entrance_positions: Dictionary = {}
var _light_scales: Dictionary = {}
var _highlight_scales: Dictionary = {}
var _item_rest_positions: Dictionary = {}
var _left_door_open_position: Vector2
var _right_door_open_position: Vector2
var _left_wall_open_position: Vector2
var _left_wall_open_size: Vector2
var _right_wall_open_position: Vector2
var _right_wall_open_size: Vector2

const LEFT_DOOR_CLOSED_X: float = 470.0
const RIGHT_DOOR_CLOSED_X: float = 810.0
const LEFT_WALL_CLOSED_POSITION := Vector2(0.0, 0.0)
const LEFT_WALL_CLOSED_SIZE := Vector2(300.0, 720.0)
const RIGHT_WALL_CLOSED_POSITION := Vector2(980.0, 0.0)
const RIGHT_WALL_CLOSED_SIZE := Vector2(300.0, 720.0)

@onready var _background: ColorRect = %Background
@onready var _light_rig: Node2D = $LightRig
@onready var _light_nodes: Array[Sprite2D] = [%Light1, %Light2, %Light3, %Light4, %Light5, %Light6, %Light7]
@onready var _light_speeds: PackedFloat32Array = PackedFloat32Array([0.30, -0.255, 0.215, -0.175, 0.135, -0.095, 0.06])
@onready var _angel_entrance: Node2D = %AngelEntrance
@onready var _market_actors: Node2D = $MarketActors
@onready var _angel_float: Node2D = %AngelFloat
@onready var _item_entrances: Array[Node2D] = [%AuditEntrance, %RadarEntrance, %SpeedEntrance]
@onready var _item_floats: Array[Node2D] = [%AuditFloat, %RadarFloat, %SpeedFloat]
@onready var _shelf_spins: Array[Node2D] = [%AuditShelfSpin, %RadarShelfSpin, %SpeedShelfSpin]
@onready var _item_sprites: Array[Sprite2D] = [%AuditItem, %RadarItem, %SpeedItem]
@onready var _item_highlights: Array[Sprite2D] = [%AuditHighlight, %RadarHighlight, %SpeedHighlight]
@onready var _item_buttons: Array[Button] = [%AuditButton, %RadarButton, %SpeedButton]
@onready var _item_info_labels: Array[Label] = [%AuditInfoLabel, %RadarInfoLabel, %SpeedInfoLabel]
@onready var _header_root: Control = %HeaderRoot
@onready var _blessings_label: Label = %BlessingsLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _gate_layer: Control = $GateLayer
@onready var _gate_motion: Node2D = %GateMotion
@onready var _left_door: Sprite2D = %LeftDoor
@onready var _right_door: Sprite2D = %RightDoor
@onready var _left_wall: ColorRect = %LeftWall
@onready var _right_wall: ColorRect = %RightWall
@onready var _door_dust_burst: CPUParticles2D = %DoorDustBurst
@onready var _door_dust_haze: CPUParticles2D = %DoorDustHaze
@onready var _transition_fog: Control = %TransitionFog
@onready var _transition_veil: ColorRect = %TransitionVeil
@onready var _transition_fog_layers: Array[ColorRect] = [%FogBack, %FogMiddle, %FogFront]


func _ready() -> void:
	_entrance_positions[_angel_entrance] = _angel_entrance.position
	for entrance: Node2D in _item_entrances:
		_entrance_positions[entrance] = entrance.position
	for light: Sprite2D in _light_nodes:
		_light_scales[light] = light.scale
	for highlight: Sprite2D in _item_highlights:
		_highlight_scales[highlight] = highlight.scale
	for item_sprite: Sprite2D in _item_sprites:
		_item_rest_positions[item_sprite] = item_sprite.position
	_left_door_open_position = _left_door.position
	_right_door_open_position = _right_door.position
	_left_wall_open_position = _left_wall.position
	_left_wall_open_size = _left_wall.size
	_right_wall_open_position = _right_wall.position
	_right_wall_open_size = _right_wall.size
	_connect_item_feedback()
	if get_tree().current_scene == self:
		call_deferred(&"_open_standalone_preview")


func _process(delta: float) -> void:
	if not visible:
		return
	_motion_time += delta
	_angel_float.position.y = sin(_motion_time * angel_float_speed) * angel_float_height
	_angel_float.rotation = deg_to_rad(sin(_motion_time * angel_float_speed * 0.63) * angel_sway_degrees)
	for index: int in range(_item_floats.size()):
		var phase: float = float(index) * 1.85
		var item_float: Node2D = _item_floats[index]
		item_float.position.y = sin(_motion_time * shelf_float_speed + phase) * shelf_float_height
		item_float.rotation = deg_to_rad(sin(_motion_time * shelf_float_speed * 0.72 + phase) * shelf_sway_degrees)
		var direction: float = -1.0 if index == 1 else 1.0
		var speed_variation: float = 1.0 + float(index) * 0.12
		var axis_phase: float = (
			_motion_time * deg_to_rad(shelf_rotation_degrees_per_second) * direction * speed_variation
			+ float(index) * TAU / 3.0
		)
		# Rotate the circular source before its parent applies the perspective
		# squash, creating the original horizontal turntable motion.
		_shelf_spins[index].rotation = axis_phase
		_shelf_spins[index].scale = Vector2.ONE
		var item_sprite: Sprite2D = _item_sprites[index]
		var item_rest_position: Vector2 = _item_rest_positions[item_sprite]
		item_sprite.position.y = item_rest_position.y + sin(_motion_time * item_hover_speed + phase + 0.8) * item_hover_height
	for index: int in range(_light_nodes.size()):
		_light_nodes[index].rotation += delta * _light_speeds[index] * light_rotation_intensity


func open_market(snapshot: Dictionary, _day_award: Dictionary) -> void:
	_continue_sent = false
	_input_locked = true
	_motion_time = 0.0
	_reset_gate()
	show()
	set_snapshot(snapshot)
	for index: int in range(_item_highlights.size()):
		var highlight: Sprite2D = _item_highlights[index]
		highlight.modulate.a = 0.0
		highlight.scale = (_highlight_scales[highlight] as Vector2) * 0.88
		_item_floats[index].scale = Vector2.ONE
	_play_entrance_animation()


func _open_standalone_preview() -> void:
	open_market(
		{
			"blessings": preview_blessings,
			"audit_slips": 1,
			"radar_charges": 2,
			"speed_level": 0,
			"speed_max_level": 3,
			"audit_slip_cost": 3,
			"radar_charge_cost": 4,
			"speed_upgrade_cost": 6,
		},
		{
			"earned": 120,
			"dropoff_reward": 180,
			"penalty_deduction": 60,
		}
	)


func set_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	var blessings: int = int(_snapshot.get("blessings", 0))
	var audit_cost: int = int(_snapshot.get("audit_slip_cost", 0))
	var radar_cost: int = int(_snapshot.get("radar_charge_cost", 0))
	var speed_cost: int = int(_snapshot.get("speed_upgrade_cost", -1))
	var speed_level: int = int(_snapshot.get("speed_level", 0))
	var speed_maximum: int = int(_snapshot.get("speed_max_level", 0))
	_blessings_label.text = blessings_template % blessings
	_item_info_labels[0].text = audit_stock_template % [int(_snapshot.get("audit_slips", 0)), audit_cost]
	_item_info_labels[1].text = radar_stock_template % [int(_snapshot.get("radar_charges", 0)), radar_cost]
	_item_info_labels[2].text = maximum_speed_text if speed_cost < 0 else speed_level_template % [speed_level, speed_maximum, speed_cost]
	_item_buttons[0].disabled = _input_locked or blessings < audit_cost
	_item_buttons[1].disabled = _input_locked or blessings < radar_cost
	_item_buttons[2].disabled = _input_locked or speed_cost < 0 or blessings < speed_cost
	_continue_button.disabled = _input_locked
	for index: int in range(_item_buttons.size()):
		_item_entrances[index].self_modulate = Color(0.62, 0.62, 0.68, 1.0) if _item_buttons[index].disabled else Color.WHITE
		if _item_buttons[index].disabled:
			_set_item_highlight(index, false)


func show_purchase_result(result: Dictionary, snapshot: Dictionary) -> void:
	if bool(result.get("success", false)):
		GameSFX.play(&"success", -5.0, 1.08, 0.02, 0.16)
	else:
		GameSFX.play(&"ui_error", -7.0, 0.92, 0.02, 0.16)
	set_snapshot(snapshot)
	_focus_first_available_action()


func _connect_item_feedback() -> void:
	for index: int in range(_item_buttons.size()):
		var button: Button = _item_buttons[index]
		button.mouse_entered.connect(_set_item_highlight.bind(index, true))
		button.mouse_exited.connect(_refresh_item_highlight.bind(index))
		button.focus_entered.connect(_set_item_highlight.bind(index, true))
		button.focus_exited.connect(_refresh_item_highlight.bind(index))


func _focus_first_available_action() -> void:
	for button: Button in _item_buttons:
		if not button.disabled:
			button.grab_focus()
			return
	_continue_button.grab_focus()


func _refresh_item_highlight(index: int) -> void:
	call_deferred(&"_apply_item_highlight_state", index)


func _apply_item_highlight_state(index: int) -> void:
	if index < 0 or index >= _item_buttons.size():
		return
	# A deferred focus refresh can outlive the market when a transition or retry
	# immediately replaces the gameplay scene.
	if not is_inside_tree() or get_viewport() == null:
		return
	var button: Button = _item_buttons[index]
	var hovered: bool = button.get_global_rect().has_point(get_viewport().get_mouse_position())
	_set_item_highlight(index, not button.disabled and (button.has_focus() or hovered))


func _set_item_highlight(index: int, active: bool) -> void:
	if index < 0 or index >= _item_highlights.size():
		return
	if _item_buttons[index].disabled:
		active = false
	var highlight: Sprite2D = _item_highlights[index]
	var existing := _highlight_tweens.get(highlight) as Tween
	if existing and existing.is_valid():
		existing.kill()
	var rest_scale: Vector2 = _highlight_scales.get(highlight, highlight.scale)
	var tween := create_tween().set_parallel(true)
	_highlight_tweens[highlight] = tween
	tween.tween_property(highlight, ^"modulate:a", 0.82 if active else 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(highlight, ^"scale", rest_scale * (1.06 if active else 0.88), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_animate_item_hover(index, active and _item_buttons[index].is_hovered())


func _animate_item_hover(index: int, active: bool) -> void:
	var item_float: Node2D = _item_floats[index]
	var existing := _item_float_tweens.get(item_float) as Tween
	if is_instance_valid(existing):
		existing.kill()
	var tween := create_tween()
	_item_float_tweens[item_float] = tween
	tween.tween_property(
		item_float,
		^"scale",
		Vector2.ONE * (item_button_hover_scale if active else 1.0),
		item_button_hover_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pulse_item(index: int) -> void:
	if index < 0 or index >= _item_floats.size():
		return
	var item_float: Node2D = _item_floats[index]
	var existing := _item_float_tweens.get(item_float) as Tween
	if is_instance_valid(existing):
		existing.kill()
	var resting_scale: Vector2 = Vector2.ONE * (
		item_button_hover_scale if _item_buttons[index].is_hovered() else 1.0
	)
	var tween := create_tween()
	_item_float_tweens[item_float] = tween
	tween.tween_property(item_float, ^"scale", Vector2.ONE * 1.1, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(item_float, ^"scale", resting_scale, 0.17).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_entrance_animation() -> void:
	if _market_tween and _market_tween.is_valid():
		_market_tween.kill()
	_background.modulate.a = 0.0
	_gate_layer.modulate.a = 0.0
	_header_root.modulate.a = 0.0
	_header_root.position.y = -18.0
	for light: Sprite2D in _light_nodes:
		light.modulate.a = 0.0
		light.scale = (_light_scales[light] as Vector2) * 0.82
	_angel_entrance.position = (_entrance_positions[_angel_entrance] as Vector2) + Vector2(0.0, -46.0)
	_angel_entrance.scale = Vector2.ONE * 0.9
	_angel_entrance.modulate.a = 0.0
	for entrance: Node2D in _item_entrances:
		entrance.position = (_entrance_positions[entrance] as Vector2) + Vector2(0.0, 74.0)
		entrance.scale = Vector2.ONE * 0.78
		entrance.modulate.a = 0.0

	# Conceal the world first. The closed gate is installed only after the fog is
	# dense, preventing the market set from popping over the train.
	await _raise_entrance_fog()
	if not is_inside_tree() or not visible:
		return
	_background.modulate.a = 1.0
	_gate_layer.modulate.a = 1.0
	for index: int in range(_light_nodes.size()):
		var light: Sprite2D = _light_nodes[index]
		var delay: float = float(_light_nodes.size() - 1 - index) * 0.035
		light.modulate.a = 1.0
		light.scale = (_light_scales[light] as Vector2) * (0.9 + delay * 0.08)
	await _open_gate_and_release_entrance_fog()
	if not is_inside_tree() or not visible:
		return

	# The merchant and merchandise are deliberately absent until the gate has
	# cleared the opening. The angel leads, then the shelves arrive in a stagger.
	GameSFX.play(&"magic_shimmer", -7.0, 1.0, 0.025, 0.3)
	_market_tween = create_tween().set_parallel(true)
	_market_tween.tween_property(_header_root, ^"position:y", 0.0, entrance_duration * 0.78).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.12)
	_market_tween.tween_property(_header_root, ^"modulate:a", 1.0, entrance_duration * 0.55).set_delay(0.12)
	_market_tween.tween_property(_angel_entrance, ^"position", _entrance_positions[_angel_entrance], entrance_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_market_tween.tween_property(_angel_entrance, ^"scale", Vector2.ONE, entrance_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_market_tween.tween_property(_angel_entrance, ^"modulate:a", 1.0, entrance_duration * 0.55)
	for index: int in range(_item_entrances.size()):
		var entrance: Node2D = _item_entrances[index]
		var delay: float = entrance_duration * 0.38 + float(index) * 0.1
		_market_tween.tween_property(entrance, ^"position", _entrance_positions[entrance], entrance_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		_market_tween.tween_property(entrance, ^"scale", Vector2.ONE, entrance_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		_market_tween.tween_property(entrance, ^"modulate:a", 1.0, entrance_duration * 0.55).set_delay(delay)
	await _market_tween.finished
	if not is_inside_tree() or not visible:
		return
	_input_locked = false
	set_snapshot(_snapshot)
	_focus_first_available_action()


func _raise_entrance_fog() -> void:
	_transition_fog.show()
	_transition_veil.self_modulate.a = 0.0
	for fog_layer: ColorRect in _transition_fog_layers:
		fog_layer.self_modulate.a = 0.0
	_market_tween = create_tween().set_parallel(true)
	_market_tween.tween_property(
		_transition_veil,
		^"self_modulate:a",
		0.72,
		entrance_fog_rise_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	for index: int in range(_transition_fog_layers.size()):
		_market_tween.tween_property(
			_transition_fog_layers[index],
			^"self_modulate:a",
			1.0,
			entrance_fog_rise_duration * (0.78 + float(index) * 0.11)
		).set_delay(float(index) * 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _market_tween.finished
	if entrance_fog_hold_seconds > 0.0 and is_inside_tree():
		await get_tree().create_timer(entrance_fog_hold_seconds).timeout


func _open_gate_and_release_entrance_fog() -> void:
	GameSFX.play(&"mechanical_door", -7.0, 1.04, 0.02, 0.3)
	_market_tween = create_tween().set_parallel(true)
	_market_tween.tween_property(_left_door, ^"position", _left_door_open_position, gate_open_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_market_tween.tween_property(_right_door, ^"position", _right_door_open_position, gate_open_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_market_tween.tween_property(_left_wall, ^"position", _left_wall_open_position, gate_open_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_market_tween.tween_property(_left_wall, ^"size", _left_wall_open_size, gate_open_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_market_tween.tween_property(_right_wall, ^"position", _right_wall_open_position, gate_open_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_market_tween.tween_property(_right_wall, ^"size", _right_wall_open_size, gate_open_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_market_tween.tween_property(_transition_veil, ^"self_modulate:a", 0.0, entrance_fog_release_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(gate_open_duration * 0.12)
	for index: int in range(_transition_fog_layers.size()):
		_market_tween.tween_property(
			_transition_fog_layers[index],
			^"self_modulate:a",
			0.0,
			entrance_fog_release_duration * (0.82 + float(index) * 0.09)
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(gate_open_duration * (0.08 + float(index) * 0.035))
	for light: Sprite2D in _light_nodes:
		_market_tween.tween_property(light, ^"scale", _light_scales[light], gate_open_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _market_tween.finished
	_transition_fog.hide()


func _play_exit_animation() -> void:
	if _market_tween and _market_tween.is_valid():
		_market_tween.kill()
	_input_locked = true
	set_snapshot(_snapshot)
	for index: int in range(_item_highlights.size()):
		_set_item_highlight(index, false)
	_market_tween = create_tween().set_parallel(true)
	_market_tween.tween_property(_header_root, ^"position:y", -28.0, content_exit_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_market_tween.tween_property(_header_root, ^"modulate:a", 0.0, content_exit_duration * 0.72)
	_market_tween.tween_property(_angel_entrance, ^"position:y", (_entrance_positions[_angel_entrance] as Vector2).y - 120.0, content_exit_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_market_tween.tween_property(_angel_entrance, ^"scale", Vector2.ONE * 0.82, content_exit_duration)
	_market_tween.tween_property(_angel_entrance, ^"modulate:a", 0.0, content_exit_duration * 0.78)
	for index: int in range(_item_entrances.size()):
		var entrance: Node2D = _item_entrances[index]
		var horizontal_exit: float = -210.0 if index == 0 else (210.0 if index == 2 else 0.0)
		var vertical_exit: float = 95.0 if index != 1 else 180.0
		_market_tween.tween_property(entrance, ^"position", (_entrance_positions[entrance] as Vector2) + Vector2(horizontal_exit, vertical_exit), content_exit_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(float(index) * 0.035)
		_market_tween.tween_property(entrance, ^"scale", Vector2.ONE * 0.72, content_exit_duration)
		_market_tween.tween_property(entrance, ^"modulate:a", 0.0, content_exit_duration * 0.72)
	for light: Sprite2D in _light_nodes:
		_market_tween.tween_property(light, ^"modulate:a", 0.0, content_exit_duration * 0.8)
		_market_tween.tween_property(light, ^"scale", (_light_scales[light] as Vector2) * 1.15, content_exit_duration)
	await _market_tween.finished
	await _close_gate()
	await _flood_with_transition_fog()


func _close_gate() -> void:
	GameSFX.play(&"mechanical_door", -6.0, 0.9, 0.02, 0.3)
	_market_tween = create_tween().set_parallel(true)
	_market_tween.tween_property(_left_door, ^"position:x", LEFT_DOOR_CLOSED_X, gate_close_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	_market_tween.tween_property(_right_door, ^"position:x", RIGHT_DOOR_CLOSED_X, gate_close_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	_market_tween.tween_property(_left_wall, ^"position", LEFT_WALL_CLOSED_POSITION, gate_close_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_market_tween.tween_property(_left_wall, ^"size", LEFT_WALL_CLOSED_SIZE, gate_close_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_market_tween.tween_property(_right_wall, ^"position", RIGHT_WALL_CLOSED_POSITION, gate_close_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_market_tween.tween_property(_right_wall, ^"size", RIGHT_WALL_CLOSED_SIZE, gate_close_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await _market_tween.finished
	_door_dust_burst.restart()
	_door_dust_burst.emitting = true
	_door_dust_haze.restart()
	_door_dust_haze.emitting = true
	var shake := create_tween()
	for shake_x: float in [9.0, -8.0, 6.0, -4.0, 2.0, 0.0]:
		shake.tween_property(_gate_motion, ^"position:x", shake_x, 0.045).set_trans(Tween.TRANS_SINE)
	await shake.finished


func _flood_with_transition_fog() -> void:
	_transition_fog.show()
	_transition_veil.self_modulate.a = 0.0
	for fog_layer: ColorRect in _transition_fog_layers:
		fog_layer.self_modulate.a = 0.0
	_market_tween = create_tween().set_parallel(true)
	_market_tween.tween_property(
		_transition_veil,
		^"self_modulate:a",
		0.78,
		transition_fog_rise_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	for index: int in range(_transition_fog_layers.size()):
		var fog_layer: ColorRect = _transition_fog_layers[index]
		var delay: float = float(index) * 0.09
		_market_tween.tween_property(
			fog_layer,
			^"self_modulate:a",
			1.0,
			transition_fog_rise_duration
		).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _market_tween.finished
	if transition_fog_hold_seconds > 0.0:
		await get_tree().create_timer(transition_fog_hold_seconds).timeout
	_set_market_content_visible(false)


func release_transition_fog() -> void:
	if not visible:
		return
	if _market_tween and _market_tween.is_valid():
		_market_tween.kill()
	_market_tween = create_tween().set_parallel(true)
	_market_tween.tween_property(
		_transition_veil,
		^"self_modulate:a",
		0.0,
		transition_fog_release_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for index: int in range(_transition_fog_layers.size()):
		_market_tween.tween_property(
			_transition_fog_layers[index],
			^"self_modulate:a",
			0.0,
			transition_fog_release_duration * (0.75 + float(index) * 0.12)
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _market_tween.finished
	if is_inside_tree():
		hide()


func _set_market_content_visible(value: bool) -> void:
	_background.visible = value
	_light_rig.visible = value
	_market_actors.visible = value
	_header_root.visible = value
	_gate_layer.visible = value


func _reset_gate() -> void:
	_set_market_content_visible(true)
	_gate_layer.modulate.a = 0.0
	_transition_fog.show()
	_transition_veil.self_modulate.a = 0.0
	for fog_layer: ColorRect in _transition_fog_layers:
		fog_layer.self_modulate.a = 0.0
	_gate_motion.position = Vector2.ZERO
	_door_dust_burst.emitting = false
	_door_dust_haze.emitting = false
	_left_door.position = Vector2(LEFT_DOOR_CLOSED_X, _left_door_open_position.y)
	_right_door.position = Vector2(RIGHT_DOOR_CLOSED_X, _right_door_open_position.y)
	_left_wall.position = LEFT_WALL_CLOSED_POSITION
	_left_wall.size = LEFT_WALL_CLOSED_SIZE
	_right_wall.position = RIGHT_WALL_CLOSED_POSITION
	_right_wall.size = RIGHT_WALL_CLOSED_SIZE


func _on_audit_button_pressed() -> void:
	if _input_locked or _item_buttons[0].disabled:
		return
	_pulse_item(0)
	purchase_requested.emit(&"audit_slip")


func _on_radar_button_pressed() -> void:
	if _input_locked or _item_buttons[1].disabled:
		return
	_pulse_item(1)
	purchase_requested.emit(&"radar_charge")


func _on_speed_button_pressed() -> void:
	if _input_locked or _item_buttons[2].disabled:
		return
	_pulse_item(2)
	purchase_requested.emit(&"speed_upgrade")


func _on_continue_button_pressed() -> void:
	if _continue_sent or _input_locked:
		return
	_continue_sent = true
	await _play_exit_animation()
	if is_inside_tree():
		continue_requested.emit()
