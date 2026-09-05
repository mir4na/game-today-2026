class_name TrainMinimap
extends Control

@export_category("Scene Layout")
@export var carriage_numbers: PackedInt32Array = PackedInt32Array([4, 3, 2, 1])
@export var slot_paths: Array[NodePath] = []
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

var current_carriage_number: int = 0
var _passenger_counts_by_carriage: Dictionary = {}
var _selection_tween: Tween
var _slots: Array[Control] = []

func _ready() -> void:
	_resolve_scene_slots()
	if not carriage_numbers.is_empty():
		current_carriage_number = carriage_numbers[0]
	_refresh()

func set_current_carriage_number(value: int) -> void:
	if carriage_numbers.find(value) < 0 or current_carriage_number == value:
		return
	current_carriage_number = value
	_refresh()
	_animate_current_carriage()

func set_passenger_counts_by_carriage(counts: Dictionary) -> void:
	if counts == _passenger_counts_by_carriage:
		return
	_passenger_counts_by_carriage = counts.duplicate()
	_refresh()

func _resolve_scene_slots() -> void:
	_slots.clear()
	for slot_path: NodePath in slot_paths:
		var slot := get_node_or_null(slot_path) as Control
		if is_instance_valid(slot):
			_slots.append(slot)
	if _slots.size() != carriage_numbers.size():
		push_error(
			"TrainMinimap requires one Inspector slot path per carriage number (%d slots, %d numbers)."
			% [_slots.size(), carriage_numbers.size()]
		)

func _refresh() -> void:
	var displayed_slot_count: int = mini(_slots.size(), carriage_numbers.size())
	for index: int in displayed_slot_count:
		var slot: Control = _slots[index]
		var carriage_number: int = carriage_numbers[index]
		var selected: bool = carriage_number == current_carriage_number
		var box := slot.get_node("Box") as TextureRect
		var marker_label := slot.get_node("Box/MarkerLabel") as Label
		box.texture = active_carriage_texture if selected else inactive_carriage_texture
		marker_label.modulate = selected_marker_color if selected else normal_marker_color
		var passenger_count: int = int(_passenger_counts_by_carriage.get(carriage_number, 0))
		marker_label.text = _marker_text(mini(passenger_count, 10))

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
	var active_index: int = carriage_numbers.find(current_carriage_number)
	if active_index < 0 or active_index >= _slots.size():
		return
	var active_slot: Control = _slots[active_index]
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
