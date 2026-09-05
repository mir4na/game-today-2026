class_name BlockedAislePuzzleUI
extends Control
## Drag all luggage pieces into the target without gaps or overlap.

signal closed
signal completed(event: Node)

@export_category("Puzzle Grid")
@export_range(1, 8, 1) var grid_columns: int = 4
@export_range(1, 8, 1) var grid_rows: int = 3
@export_range(24.0, 128.0, 1.0) var cell_size: float = 64.0
@export_category("Scene Piece Library")
@export var suitcase_piece_scenes: Array[PackedScene] = []
@export var randomize_piece_set_on_new_event: bool = true
@export_range(1, 12, 1) var minimum_generated_pieces: int = 3
@export_range(1, 12, 1) var maximum_generated_pieces: int = 6
@export_range(1, 6, 1) var minimum_distinct_piece_types: int = 2
@export_range(1, 12, 1) var maximum_duplicate_per_scene: int = 3
@export_category("Loose Block Layout")
@export_range(2, 8, 1) var loose_shelf_columns: int = 5
@export var loose_shelf_origin_offset: Vector2 = Vector2(24.0, 48.0)
@export var loose_piece_spacing: Vector2 = Vector2(12.0, 12.0)

@onready var _shelf: Control = %Shelf
@onready var _target_board: Control = %TargetBoard
@onready var _pieces_root: Control = %Pieces

var _active_event: Node
var _pieces: Array[Control] = []
var _home_positions: Dictionary = {}
var _placement_by_piece: Dictionary = {}
var _occupied_cells: Dictionary = {}
var _completed: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func open_puzzle(event: Node) -> void:
	if event != _active_event:
		_active_event = event
		if randomize_piece_set_on_new_event or _pieces.is_empty():
			_rebuild_piece_set()
		_arrange_piece_homes()
		_reset_pieces()
	show()
	_completed = false


func request_close() -> void:
	if not visible or _completed:
		return
	hide()
	closed.emit()


func reset_puzzle() -> void:
	if not visible:
		return
	_reset_pieces()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		request_close()
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		reset_puzzle()
		get_viewport().set_input_as_handled()


func _on_piece_grabbed(piece: Control, _grab_offset: Vector2) -> void:
	_release_piece_cells(piece)
	piece.z_index = 20


func _on_piece_dragged(piece: Control, pointer_position: Vector2, grab_offset: Vector2) -> void:
	piece.global_position = pointer_position - grab_offset


func _on_piece_released(piece: Control, _pointer_position: Vector2, _grab_offset: Vector2) -> void:
	piece.z_index = 1
	var relative: Vector2 = piece.global_position - _target_board.global_position
	var cell := Vector2i(roundi(relative.x / cell_size), roundi(relative.y / cell_size))
	var occupied_offsets: Array[Vector2i] = _get_piece_cell_offsets(piece)
	if _can_place_cells(cell, occupied_offsets, _occupied_cells, grid_columns, grid_rows):
		_place_piece(piece, cell, occupied_offsets)
	else:
		piece.position = _home_positions[piece]
	_check_completion()


func _can_place_cells(
	origin: Vector2i,
	cell_offsets: Array[Vector2i],
	occupied: Dictionary,
	columns: int,
	rows: int
) -> bool:
	for offset: Vector2i in cell_offsets:
		var cell: Vector2i = origin + offset
		if cell.x < 0 or cell.y < 0 or cell.x >= columns or cell.y >= rows:
			return false
		if occupied.has(cell):
			return false
	return true


func _place_piece(piece: Control, origin: Vector2i, occupied_offsets: Array[Vector2i]) -> void:
	piece.global_position = _target_board.global_position + Vector2(origin) * cell_size
	_placement_by_piece[piece] = origin
	for offset: Vector2i in occupied_offsets:
		_occupied_cells[origin + offset] = piece


func _release_piece_cells(piece: Control) -> void:
	if not _placement_by_piece.has(piece):
		return
	_placement_by_piece.erase(piece)
	var cells_to_remove: Array[Vector2i] = []
	for cell: Vector2i in _occupied_cells:
		if _occupied_cells[cell] == piece:
			cells_to_remove.append(cell)
	for cell: Vector2i in cells_to_remove:
		_occupied_cells.erase(cell)


func _reset_pieces() -> void:
	_completed = false
	_placement_by_piece.clear()
	_occupied_cells.clear()
	for piece: Control in _pieces:
		piece.position = _home_positions[piece]
		piece.z_index = 1


func _rebuild_piece_set() -> void:
	_clear_piece_instances()
	var definitions: Array[Dictionary] = _build_piece_definitions()
	var selected_scenes: Array[PackedScene] = []
	var generation_cells: Dictionary = {}
	var usage_counts: Dictionary = {}
	if not _find_complete_piece_set(definitions, generation_cells, selected_scenes, usage_counts):
		push_error("The Inspector-configured suitcase scenes cannot tile the packing rack.")
		return
	_shuffle_packed_scenes(selected_scenes)
	for piece_scene: PackedScene in selected_scenes:
		var instance: Node = piece_scene.instantiate()
		if not instance is Control:
			push_warning("Suitcase scene root must inherit Control: %s" % piece_scene.resource_path)
			instance.free()
			continue
		var piece := instance as Control
		_pieces_root.add_child(piece)
		_register_piece(piece)


func _clear_piece_instances() -> void:
	_home_positions.clear()
	_placement_by_piece.clear()
	_occupied_cells.clear()
	for piece: Control in _pieces:
		if is_instance_valid(piece):
			piece.free()
	_pieces.clear()


func _register_piece(piece: Control) -> void:
	_pieces.append(piece)
	piece.connect(&"grabbed", Callable(self, &"_on_piece_grabbed"))
	piece.connect(&"dragged", Callable(self, &"_on_piece_dragged"))
	piece.connect(&"released", Callable(self, &"_on_piece_released"))


func _build_piece_definitions() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for piece_scene: PackedScene in suitcase_piece_scenes:
		if piece_scene == null:
			continue
		var probe: Node = piece_scene.instantiate()
		if not probe is Control:
			push_warning("Suitcase scene root must inherit Control: %s" % piece_scene.resource_path)
			probe.free()
			continue
		var piece := probe as Control
		var cell_offsets: Array[Vector2i] = _get_piece_cell_offsets(piece)
		probe.free()
		if cell_offsets.is_empty() or not cell_offsets.has(Vector2i.ZERO):
			push_warning("Suitcase occupancy must include local cell (0, 0): %s" % piece_scene.resource_path)
			continue
		definitions.append({"scene": piece_scene, "cells": cell_offsets})
	return definitions


func _find_complete_piece_set(
	definitions: Array[Dictionary],
	occupied: Dictionary,
	selected_scenes: Array[PackedScene],
	usage_counts: Dictionary
) -> bool:
	var minimum_piece_count: int = mini(minimum_generated_pieces, maximum_generated_pieces)
	var target_cell_count: int = grid_columns * grid_rows
	if occupied.size() == target_cell_count:
		return (
			selected_scenes.size() >= minimum_piece_count
			and usage_counts.size() >= mini(minimum_distinct_piece_types, definitions.size())
		)
	if selected_scenes.size() >= maximum_generated_pieces:
		return false
	var first_empty: Vector2i = _find_first_empty_cell(occupied, grid_columns, grid_rows)
	if first_empty.x < 0:
		return false
	var definition_order: Array[int] = []
	for index: int in range(definitions.size()):
		definition_order.append(index)
	_shuffle_ints(definition_order)
	for definition_index: int in definition_order:
		var definition: Dictionary = definitions[definition_index]
		var piece_scene := definition["scene"] as PackedScene
		var used_count: int = int(usage_counts.get(piece_scene, 0))
		if used_count >= maximum_duplicate_per_scene:
			continue
		var cell_offsets: Array[Vector2i] = definition["cells"]
		if not _can_place_cells(first_empty, cell_offsets, occupied, grid_columns, grid_rows):
			continue
		for offset: Vector2i in cell_offsets:
			occupied[first_empty + offset] = true
		selected_scenes.append(piece_scene)
		usage_counts[piece_scene] = used_count + 1
		if _find_complete_piece_set(definitions, occupied, selected_scenes, usage_counts):
			return true
		selected_scenes.pop_back()
		if used_count == 0:
			usage_counts.erase(piece_scene)
		else:
			usage_counts[piece_scene] = used_count
		for offset: Vector2i in cell_offsets:
			occupied.erase(first_empty + offset)
	return false


func _find_first_empty_cell(occupied: Dictionary, columns: int, rows: int) -> Vector2i:
	for y: int in range(rows):
		for x: int in range(columns):
			var cell := Vector2i(x, y)
			if not occupied.has(cell):
				return cell
	return Vector2i(-1, -1)


func _shuffle_ints(values: Array[int]) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var swap_index: int = _rng.randi_range(0, index)
		var held: int = values[index]
		values[index] = values[swap_index]
		values[swap_index] = held


func _shuffle_packed_scenes(values: Array[PackedScene]) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var swap_index: int = _rng.randi_range(0, index)
		var held: PackedScene = values[index]
		values[index] = values[swap_index]
		values[swap_index] = held


func _arrange_piece_homes() -> void:
	var spacing := Vector2(maxf(0.0, loose_piece_spacing.x), maxf(0.0, loose_piece_spacing.y))
	var shelf_step := Vector2(cell_size, cell_size) + spacing
	var available_height: float = _shelf.size.y - loose_shelf_origin_offset.y - 16.0
	var shelf_rows: int = maxi(1, floori((available_height + spacing.y) / shelf_step.y))
	var occupied: Dictionary = {}
	var local_origin: Vector2 = _shelf.global_position - _pieces_root.global_position + loose_shelf_origin_offset
	var shelf_pieces: Array[Control] = _pieces.duplicate()
	shelf_pieces.sort_custom(func(left: Control, right: Control) -> bool:
		return _get_piece_cell_offsets(left).size() > _get_piece_cell_offsets(right).size()
	)
	for piece: Control in shelf_pieces:
		var cell_offsets: Array[Vector2i] = _get_piece_cell_offsets(piece)
		var chosen_cell := Vector2i(-1, -1)
		for row: int in range(shelf_rows):
			for column: int in range(loose_shelf_columns):
				var candidate := Vector2i(column, row)
				if _can_place_cells(candidate, cell_offsets, occupied, loose_shelf_columns, shelf_rows):
					chosen_cell = candidate
					break
			if chosen_cell.x >= 0:
				break
		if chosen_cell.x < 0:
			push_warning("Loose-luggage shelf is too small for the Inspector-configured suitcase set.")
			continue
		for offset: Vector2i in cell_offsets:
			occupied[chosen_cell + offset] = piece
		var home_position: Vector2 = local_origin + Vector2(chosen_cell) * shelf_step
		_home_positions[piece] = home_position
		piece.position = home_position


func _get_piece_cell_offsets(piece: Control) -> Array[Vector2i]:
	if piece.has_method(&"get_occupied_cell_offsets"):
		var configured_cells: Array[Vector2i] = piece.call(&"get_occupied_cell_offsets")
		return configured_cells
	var piece_size: Vector2i = piece.get(&"grid_size")
	var cells: Array[Vector2i] = []
	for y: int in range(piece_size.y):
		for x: int in range(piece_size.x):
			cells.append(Vector2i(x, y))
	return cells


func _check_completion() -> void:
	if _completed or _occupied_cells.size() < grid_columns * grid_rows:
		return
	_completed = true
	await get_tree().create_timer(0.25).timeout
	if not is_inside_tree():
		return
	hide()
	completed.emit(_active_event)
	_active_event = null
