class_name GameHUD
extends CanvasLayer
## Persistent, low-profile HUD. Modal screens live in sibling UI scenes.

@export_category("Inspector Copy")
@export var clock_template: String = "%02d:%02d %s"
@export var tool_inventory_template: String = "BLESSINGS %d   •   [R] RADAR ×%d   •   AUDIT ×%d   •   SPEED LV.%d"
@export_category("Interaction Prompt")
@export var prompt_screen_offset: Vector2 = Vector2(0.0, -8.0)
@export var prompt_edge_margin: Vector2 = Vector2(24.0, 20.0)
@export var prompt_minimum_size: Vector2 = Vector2(180.0, 75.0)
@export_range(180.0, 720.0, 10.0) var prompt_maximum_width: float = 440.0
@export var prompt_content_padding: Vector2 = Vector2(32.0, 20.0)
@export_range(0.0, 64.0, 1.0) var prompt_pointer_visible_height: float = 27.0
@export_category("Dialogue Wobble")
@export_range(0.0, 8.0, 0.1) var prompt_wobble_speed: float = 3.2
@export var prompt_wobble_position: Vector2 = Vector2(1.8, 1.1)
@export_range(0.0, 4.0, 0.05) var prompt_wobble_rotation_degrees: float = 0.7
@export_range(0.0, 0.08, 0.001) var prompt_wobble_scale: float = 0.012
@export_category("Dialogue Pop Tween")
@export_range(0.05, 0.6, 0.01) var prompt_grow_duration: float = 0.22
@export_range(0.05, 0.6, 0.01) var prompt_shrink_duration: float = 0.16
@export_range(0.5, 1.0, 0.01) var prompt_collapsed_scale: float = 0.82
@export_range(1.0, 1.2, 0.01) var prompt_pop_scale: float = 1.06

@onready var _root: Control = %Root
@onready var _minimap: TrainMinimap = %TrainMinimap
@onready var _clock_panel: PanelContainer = %ClockPanel
@onready var _clock_label: Label = %ClockLabel
@onready var _floating_prompt: Control = %FloatingPrompt
@onready var _prompt_label: Label = %PromptLabel
@onready var _dialogue_pointer: TextureRect = %DialoguePointer
@onready var _notification_panel: PanelContainer = %NotificationPanel
@onready var _notification_label: Label = %NotificationLabel
@onready var _tool_panel: PanelContainer = %ToolPanel
@onready var _tool_inventory_label: Label = %ToolInventoryLabel
@onready var _maintenance_trackers: Array[Control] = [
	$Root/MaintenanceTrackers/TrackerPrimary,
	$Root/MaintenanceTrackers/TrackerSecondary,
]
var _notification_tween: Tween
var _prompt_visibility_tween: Tween
var _prompt_target: Node2D
var _prompt_source_text: String = ""
var _prompt_wobble_time: float = 0.0
var _prompt_reveal_scale: float = 1.0

func _process(delta: float) -> void:
	_prompt_wobble_time += delta
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
	_tool_inventory_label.text = tool_inventory_template % [
		int(snapshot.get("blessings", 0)),
		int(snapshot.get("radar_charges", 0)),
		int(snapshot.get("audit_slips", 0)),
		int(snapshot.get("speed_level", 0))
	]


func set_maintenance_targets(target_entries: Array[Dictionary]) -> void:
	for index: int in _maintenance_trackers.size():
		var tracker: Control = _maintenance_trackers[index]
		if index >= target_entries.size():
			tracker.call(&"clear_target")
			continue
		var entry: Dictionary = target_entries[index]
		var target := entry.get("target") as Node2D
		var tracker_text: String = str(entry.get("label", "MAINTENANCE"))
		tracker.call(&"set_target", target, tracker_text)

func set_prompt(text: String, target: Node2D = null) -> void:
	if text.is_empty():
		_hide_prompt_animated()
		return
	var next_target: Node2D = target if is_instance_valid(target) else null
	var should_pop_in: bool = not _floating_prompt.visible
	var content_changed: bool = text != _prompt_source_text or next_target != _prompt_target
	if text != _prompt_source_text:
		_prompt_source_text = text
		_prompt_wobble_time = 0.0
	_resize_prompt_to_text(text)
	_prompt_target = next_target
	_floating_prompt.visible = true
	_update_prompt_position()
	if should_pop_in:
		_show_prompt_animated(prompt_collapsed_scale)
	elif content_changed:
		_show_prompt_animated(0.94)

func _show_prompt_animated(start_scale: float) -> void:
	_kill_prompt_visibility_tween()
	_prompt_reveal_scale = clampf(start_scale, 0.5, 1.0)
	_floating_prompt.modulate.a = 0.0 if start_scale <= prompt_collapsed_scale else 1.0
	_apply_prompt_scale()
	var rise_duration: float = prompt_grow_duration * 0.68
	var settle_duration: float = maxf(prompt_grow_duration - rise_duration, 0.01)
	_prompt_visibility_tween = create_tween()
	_prompt_visibility_tween.tween_method(
		_set_prompt_reveal_scale,
		_prompt_reveal_scale,
		prompt_pop_scale,
		rise_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_prompt_visibility_tween.parallel().tween_property(
		_floating_prompt,
		^"modulate:a",
		1.0,
		rise_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_prompt_visibility_tween.tween_method(
		_set_prompt_reveal_scale,
		prompt_pop_scale,
		1.0,
		settle_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _hide_prompt_animated() -> void:
	if not _floating_prompt.visible:
		_prompt_source_text = ""
		_prompt_target = null
		return
	_kill_prompt_visibility_tween()
	_prompt_visibility_tween = create_tween()
	_prompt_visibility_tween.tween_method(
		_set_prompt_reveal_scale,
		_prompt_reveal_scale,
		prompt_collapsed_scale,
		prompt_shrink_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_prompt_visibility_tween.parallel().tween_property(
		_floating_prompt,
		^"modulate:a",
		0.0,
		prompt_shrink_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_prompt_visibility_tween.tween_callback(_finish_hiding_prompt)

func _set_prompt_reveal_scale(value: float) -> void:
	_prompt_reveal_scale = value
	_apply_prompt_scale()

func _finish_hiding_prompt() -> void:
	_floating_prompt.visible = false
	_floating_prompt.modulate.a = 1.0
	_prompt_reveal_scale = 1.0
	_prompt_source_text = ""
	_prompt_target = null
	_prompt_label.text = ""

func _kill_prompt_visibility_tween() -> void:
	if is_instance_valid(_prompt_visibility_tween) and _prompt_visibility_tween.is_valid():
		_prompt_visibility_tween.kill()
	_prompt_visibility_tween = null

func _resize_prompt_to_text(text: String) -> void:
	if text.is_empty():
		_prompt_label.text = ""
		return
	var font: Font = _prompt_label.get_theme_font(&"font")
	var font_size: int = _prompt_label.get_theme_font_size(&"font_size")
	var maximum_content_width: float = maxf(prompt_maximum_width - prompt_content_padding.x, 1.0)
	var wrapped_lines: PackedStringArray = _wrap_prompt_lines(text, font, font_size, maximum_content_width)
	_prompt_label.text = "\n".join(wrapped_lines)
	var widest_line: float = 0.0
	for line: String in wrapped_lines:
		widest_line = maxf(widest_line, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	var line_spacing: float = float(_prompt_label.get_theme_constant(&"line_spacing"))
	var text_height: float = float(wrapped_lines.size()) * font.get_height(font_size)
	text_height += maxf(float(wrapped_lines.size() - 1), 0.0) * line_spacing
	var target_size := Vector2(
		clampf(widest_line + prompt_content_padding.x, prompt_minimum_size.x, prompt_maximum_width),
		maxf(text_height + prompt_content_padding.y + prompt_pointer_visible_height, prompt_minimum_size.y)
	)
	_floating_prompt.custom_minimum_size = target_size
	_floating_prompt.size = target_size

func _wrap_prompt_lines(text: String, font: Font, font_size: int, maximum_width: float) -> PackedStringArray:
	var result := PackedStringArray()
	for paragraph: String in text.split("\n", true):
		if paragraph.is_empty():
			result.append("")
			continue
		var current_line: String = ""
		for word: String in paragraph.split(" ", false):
			var candidate: String = word if current_line.is_empty() else "%s %s" % [current_line, word]
			var candidate_width: float = font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
			if current_line.is_empty() or candidate_width <= maximum_width:
				current_line = candidate
			else:
				result.append(current_line)
				current_line = word
		if not current_line.is_empty():
			result.append(current_line)
	if result.is_empty():
		result.append("")
	return result

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
	var wobble_phase: float = _prompt_wobble_time * prompt_wobble_speed
	var wobble_offset := Vector2(
		sin(wobble_phase * 0.83) * prompt_wobble_position.x,
		cos(wobble_phase * 1.17) * prompt_wobble_position.y
	)
	desired_position += wobble_offset
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
	_update_dialogue_pointer(screen_anchor.x - desired_position.x, prompt_size.x)
	_floating_prompt.position = desired_position
	_floating_prompt.pivot_offset = prompt_size * 0.5
	var rotation_wave: float = sin(wobble_phase * 0.61) + sin(wobble_phase * 1.31) * 0.35
	_floating_prompt.rotation = deg_to_rad(rotation_wave * prompt_wobble_rotation_degrees)
	_apply_prompt_scale()

func _apply_prompt_scale() -> void:
	var wobble_phase: float = _prompt_wobble_time * prompt_wobble_speed
	var breathing: float = sin(wobble_phase * 0.47) * prompt_wobble_scale
	_floating_prompt.scale = Vector2(
		(1.0 + breathing) * _prompt_reveal_scale,
		(1.0 - breathing * 0.55) * _prompt_reveal_scale
	)

func _update_dialogue_pointer(target_local_x: float, prompt_width: float) -> void:
	if not is_instance_valid(_dialogue_pointer) or prompt_width <= 0.0:
		return
	var pointer_half_width: float = _dialogue_pointer.size.x * 0.5
	var edge_padding: float = pointer_half_width + 12.0
	var pointer_center_x: float = clampf(target_local_x, edge_padding, prompt_width - edge_padding)
	var pointer_anchor: float = pointer_center_x / prompt_width
	_dialogue_pointer.anchor_left = pointer_anchor
	_dialogue_pointer.anchor_right = pointer_anchor

func set_day_hud_visible(value: bool) -> void:
	_clock_panel.visible = value
	_tool_panel.visible = value
	_floating_prompt.visible = value and not _prompt_label.text.is_empty()
	# The train minimap remains visible through the night walk.

func set_cutscene_hidden(value: bool) -> void:
	_root.visible = not value


func set_radar_hidden(value: bool) -> void:
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
