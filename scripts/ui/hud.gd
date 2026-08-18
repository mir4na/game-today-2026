class_name GameHUD
extends CanvasLayer
## Persistent, low-profile HUD. Modal screens live in sibling UI scenes.

@export_category("Runtime State Colors")
@export var normal_duties_tint: Color = Color.WHITE
@export var low_coal_duties_tint: Color
@export_category("Inspector Copy")
@export var clock_template: String = "%02d:%02d %s"
@export var coal_template: String = "FURNACE %d%%"
@export var performance_template: String = "MERIT %d / %d   •   REVIEW AT TRANSITION"

@onready var _root: Control = %Root
@onready var _duties_panel: PanelContainer = %DutiesPanel
@onready var _objective_label: Label = %ObjectiveLabel
@onready var _performance_label: Label = %PerformanceLabel
@onready var _coal_bar: ProgressBar = %CoalBar
@onready var _coal_label: Label = %CoalLabel
@onready var _coal_row: HBoxContainer = %CoalRow
@onready var _minimap: TrainMinimap = %TrainMinimap
@onready var _clock_panel: PanelContainer = %ClockPanel
@onready var _clock_label: Label = %ClockLabel
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

func set_coal(value: float) -> void:
	_coal_bar.value = value
	_coal_label.text = coal_template % int(value)
	_duties_panel.modulate = low_coal_duties_tint if value < 35.0 else normal_duties_tint

func set_objective(text: String) -> void:
	_objective_label.text = text

func set_performance(merit: int, threshold: int, _penalty_points: int, _service_points: int) -> void:
	_performance_label.text = performance_template % [merit, threshold]

func set_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt_label.visible = not text.is_empty()

func set_day_hud_visible(value: bool) -> void:
	_duties_panel.visible = value
	_clock_panel.visible = value
	_coal_row.visible = value
	_prompt_label.visible = value and not _prompt_label.text.is_empty()
	# The train minimap remains visible through the night walk.

func set_cutscene_hidden(value: bool) -> void:
	_root.visible = not value

func set_night_walk_mode() -> void:
	_duties_panel.visible = true
	_clock_panel.visible = false
	_coal_row.visible = false
	_prompt_label.visible = not _prompt_label.text.is_empty()

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
