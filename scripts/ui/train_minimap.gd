class_name TrainMinimap
extends Control

@export_category("Runtime State Colors")
@export var selected_fill: Color
@export var normal_fill: Color
@export var selected_marker_color: Color
@export var normal_marker_color: Color

var current_carriage: int = 0
var _passenger_counts := PackedInt32Array([0, 0, 0, 0, 0])
@onready var _slots: Array[Control] = [%Slot0, %Slot1, %Slot2, %Slot3, %Slot4]

func set_current_carriage(value: int) -> void:
	var next_carriage: int = clampi(value, 0, 4)
	if current_carriage == next_carriage:
		return
	current_carriage = next_carriage
	_refresh()

func set_passenger_counts(counts: PackedInt32Array) -> void:
	if counts.size() != 5 or counts == _passenger_counts:
		return
	_passenger_counts = counts.duplicate()
	_refresh()

func _refresh() -> void:
	for index: int in range(_slots.size()):
		var slot: Control = _slots[index]
		var selected: bool = index == current_carriage
		var box: ColorRect = slot.get_node("Box") as ColorRect
		var marker_label: Label = slot.get_node("Box/MarkerLabel") as Label
		box.color = selected_fill if selected else normal_fill
		marker_label.modulate = selected_marker_color if selected else normal_marker_color
		marker_label.text = _marker_text(mini(_passenger_counts[index], 10))

func _marker_text(count: int) -> String:
	if count <= 0:
		return ""
	if count <= 5:
		return "•".repeat(count)
	return "%s\n%s" % ["•".repeat(5), "•".repeat(count - 5)]
