class_name GameHUD
extends CanvasLayer
## Persistent, low-profile HUD. Modal screens live in sibling UI scenes.

@export_category("Inspector Copy")
@export var clock_template: String = "%02d:%02d %s"
@export_category("Interaction Prompt")
@export var prompt_screen_offset: Vector2 = Vector2(0.0, -8.0)
@export var prompt_edge_margin: Vector2 = Vector2(24.0, 20.0)

@onready var _root: Control = %Root
@onready var _minimap: TrainMinimap = %TrainMinimap
@onready var _clock_panel: PanelContainer = %ClockPanel
@onready var _clock_label: Label = %ClockLabel
@onready var _floating_prompt: Control = %FloatingPrompt
@onready var _prompt_label: Label = %PromptLabel
@onready var _notification_panel: PanelContainer = %NotificationPanel
@onready var _notification_label: Label = %NotificationLabel
@onready var _tool_panel: PanelContainer = %ToolPanel
@onready var _tool_inventory_label: Label = %ToolInventoryLabel
var _notification_tween: Tween
var _prompt_target: Node2D

func _process(_delta: float) -> void:
	_update_prompt_position()

func set_clock(total_minutes: int) -> void:
	var hour_24: int = total_minutes / 60
	var minute: int = total_minutes % 60
	var suffix: String = "AM" if hour_24 < 12 else "PM"
	var hour_12: int = hour_24 % 12
	if hour_12 == 0:
		hour_12 = 12
	_clock_label.text = clock_template % [hour_12, minute, suffix]

func set_current_carriage(index: int) -> void:
	_minimap.set_current_carriage(index)

func set_passenger_counts(counts: PackedInt32Array) -> void:
	_minimap.set_passenger_counts(counts)


func set_market_tool_inventory(snapshot: Dictionary) -> void:
	_tool_inventory_label.text = "[R] RADAR ×%d   •   AUDIT ×%d   •   SPEED LV.%d" % [
		int(snapshot.get("radar_charges", 0)),
		int(snapshot.get("audit_slips", 0)),
		int(snapshot.get("speed_level", 0))
	]

func set_prompt(text: String, target: Node2D = null) -> void:
	_prompt_label.text = text
	_prompt_target = target if not text.is_empty() and is_instance_valid(target) else null
	_floating_prompt.visible = not text.is_empty()
	_update_prompt_position()

func _update_prompt_position() -> void:
	if not _floating_prompt.visible or not is_instance_valid(_prompt_target):
		return
	var screen_anchor := _prompt_target.get_global_transform_with_canvas().origin + prompt_screen_offset
	var prompt_size := _floating_prompt.size
	var viewport_size := get_viewport().get_visible_rect().size
	var desired_position := screen_anchor - Vector2(prompt_size.x * 0.5, prompt_size.y)
	desired_position.x = clampf(
		desired_position.x,
		prompt_edge_margin.x,
		maxf(prompt_edge_margin.x, viewport_size.x - prompt_size.x - prompt_edge_margin.x)
	)
	desired_position.y = clampf(
		desired_position.y,
		prompt_edge_margin.y,
		maxf(prompt_edge_margin.y, viewport_size.y - prompt_size.y - prompt_edge_margin.y)
	)
	_floating_prompt.position = desired_position

func set_day_hud_visible(value: bool) -> void:
	_clock_panel.visible = value
	_tool_panel.visible = value
	_floating_prompt.visible = value and not _prompt_label.text.is_empty()
	# The train minimap remains visible through the night walk.

func set_cutscene_hidden(value: bool) -> void:
	_root.visible = not value

func set_night_walk_mode() -> void:
	_clock_panel.visible = false
	_tool_panel.visible = true
	_floating_prompt.visible = not _prompt_label.text.is_empty()

func notify(message: String, seconds: float = 3.0) -> void:
	if is_instance_valid(_notification_tween):
		_notification_tween.kill()
	_notification_label.text = message
	_notification_panel.visible = true
	_notification_panel.modulate.a = 0.0
	_notification_tween = create_tween()
	_notification_tween.tween_property(_notification_panel, "modulate:a", 1.0, 0.2)
	_notification_tween.tween_interval(seconds)
	_notification_tween.tween_property(_notification_panel, "modulate:a", 0.0, 0.35)
	_notification_tween.tween_callback(func() -> void: _notification_panel.visible = false)
