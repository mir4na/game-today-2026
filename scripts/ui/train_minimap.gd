class_name TrainMinimap
extends Control

@export_category("Carriage State Textures")
@export var active_carriage_texture: Texture2D
@export var inactive_carriage_texture: Texture2D
@export_category("Passenger Marker Colors")
@export var selected_marker_color: Color
@export var normal_marker_color: Color
@export_category("Active Carriage Animation")
@export_range(0.05, 0.5, 0.01) var selection_pop_duration: float = 0.14
@export_range(0.05, 0.5, 0.01) var selection_settle_duration: float = 0.18
@export_range(1.0, 1.3, 0.01) var selection_pop_scale: float = 1.12

var current_carriage: int = 0
var _passenger_counts := PackedInt32Array([0, 0, 0, 0, 0])
var _selection_tween: Tween
@onready var _slots: Array[Control] = [%Slot0, %Slot1, %Slot2, %Slot3, %Slot4]

func _ready() -> void:
	_refresh()

func set_current_carriage(value: int) -> void:
	var next_carriage: int = clampi(value, 0, 4)
	if current_carriage == next_carriage:
		return
	current_carriage = next_carriage
	_refresh()
	_animate_current_carriage()

func set_passenger_counts(counts: PackedInt32Array) -> void:
	if counts.size() != 5 or counts == _passenger_counts:
		return
	_passenger_counts = counts.duplicate()
	_refresh()

func _refresh() -> void:
	for index: int in range(_slots.size()):
		var slot: Control = _slots[index]
		var selected: bool = index == current_carriage
		var box: TextureRect = slot.get_node("Box") as TextureRect
		var marker_label: Label = slot.get_node("Box/MarkerLabel") as Label
		box.texture = active_carriage_texture if selected else inactive_carriage_texture
		marker_label.modulate = selected_marker_color if selected else normal_marker_color
		marker_label.text = _marker_text(mini(_passenger_counts[index], 10))

func _marker_text(count: int) -> String:
	if count <= 0:
		return ""
	if count <= 5:
		return "•".repeat(count)
	return "%s\n%s" % ["•".repeat(5), "•".repeat(count - 5)]

func _animate_current_carriage() -> void:
	if is_instance_valid(_selection_tween):
		_selection_tween.kill()
	for slot: Control in _slots:
		slot.scale = Vector2.ONE
		slot.modulate = Color.WHITE
	var active_slot: Control = _slots[current_carriage]
	active_slot.pivot_offset = active_slot.size * 0.5
	active_slot.scale = Vector2(0.9, 0.9)
	active_slot.modulate = Color(1.0, 1.0, 1.0, 0.72)
	_selection_tween = create_tween()
	_selection_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_selection_tween.set_parallel(true)
	_selection_tween.tween_property(active_slot, ^"scale", Vector2.ONE * selection_pop_scale, selection_pop_duration)
	_selection_tween.tween_property(active_slot, ^"modulate:a", 1.0, selection_pop_duration)
	_selection_tween.chain().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_selection_tween.tween_property(active_slot, ^"scale", Vector2.ONE, selection_settle_duration)
