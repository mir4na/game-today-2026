class_name GameHUD
extends CanvasLayer
## Persistent, low-profile HUD. Modal screens live in sibling UI scenes.

@export_category("Inspector Copy")
@export var clock_template: String = "%02d:%02d %s"
@export_category("Floating Interaction Prompt")
@export var floating_prompt_screen_offset: Vector2
@export var floating_prompt_screen_margin: Vector2

@onready var _root: Control = %Root
@onready var _minimap: TrainMinimap = %TrainMinimap
@onready var _clock_panel: PanelContainer = %ClockPanel
@onready var _clock_label: Label = %ClockLabel
@onready var _floating_prompt: Control = %FloatingPrompt
@onready var _prompt_label: Label = %PromptLabel
@onready var _notification_panel: PanelContainer = %NotificationPanel
@onready var _notification_label: Label = %NotificationLabel
var _notification_tween: Tween

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

func set_prompt(text: String) -> void:
	_prompt_label.text = text
	_floating_prompt.visible = not text.is_empty()

func set_prompt_target_screen_position(target_screen_position: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var desired_position: Vector2 = target_screen_position + floating_prompt_screen_offset
	_floating_prompt.position = Vector2(
		clampf(desired_position.x, floating_prompt_screen_margin.x, viewport_size.x - floating_prompt_screen_margin.x),
		clampf(desired_position.y, floating_prompt_screen_margin.y, viewport_size.y - floating_prompt_screen_margin.y)
	)

func set_day_hud_visible(value: bool) -> void:
	_clock_panel.visible = value
	_floating_prompt.visible = value and not _prompt_label.text.is_empty()
	# The train minimap remains visible through the night walk.

func set_cutscene_hidden(value: bool) -> void:
	_root.visible = not value

func set_night_walk_mode() -> void:
	_clock_panel.visible = false
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
