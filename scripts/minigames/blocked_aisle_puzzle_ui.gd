class_name BlockedAislePuzzleUI
extends Control
## Drag all luggage pieces into the target without gaps or overlap.

signal closed
signal completed(event: Node)

@export_category("Puzzle Grid")
@export_range(1, 8, 1) var grid_columns: int = 4
@export_range(1, 8, 1) var grid_rows: int = 3
@export_range(24.0, 128.0, 1.0) var cell_size: float = 64.0
@export_category("Random Piece Shapes")
@export var randomize_piece_shapes_on_new_event: bool = true
@export_range(1, 6, 1) var minimum_piece_cells: int = 2
@export_range(2, 8, 1) var loose_shelf_columns: int = 5
@export var loose_shelf_origin_offset: Vector2 = Vector2(24.0, 48.0)
@export_category("Inspector Copy")
@export var progress_template: String = "%d / %d CELLS PACKED"

@onready var _window: Control = %PuzzleWindow
@onready var _shelf: Control = %Shelf
@onready var _target_board: Control = %TargetBoard
@onready var _pieces_root: Control = %Pieces
@onready var _progress_label: Label = %ProgressLabel
@onready var _success_label: Label = %SuccessLabel

var _active_event: Node
var _pieces: Array[Control] = []
var _home_positions: Dictionary = {}
var _placement_by_piece: Dictionary = {}
var _occupied_cells: Dictionary = {}
var _completed: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for child: Node in %Pieces.get_children():
		if child is Control and child.has_signal(&"grabbed"):
			var piece := child as Control
			_pieces.append(piece)
			_home_positions[piece] = piece.position
	_update_progress()


func open_puzzle(event: Node) -> void:
	if event != _active_event:
		_active_event = event
		if randomize_piece_shapes_on_new_event:
			_randomize_piece_shapes()
		_arrange_piece_homes()
		_reset_pieces()
	show()
	_success_label.hide()
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
	var piece_grid_size: Vector2i = piece.get(&"grid_size")
	if _can_place(cell, piece_grid_size):
		_place_piece(piece, cell, piece_grid_size)
	else:
		piece.position = _home_positions[piece]
	_update_progress()
	_check_completion()


func _can_place(origin: Vector2i, piece_size: Vector2i) -> bool:
	if origin.x < 0 or origin.y < 0:
		return false
	if origin.x + piece_size.x > grid_columns or origin.y + piece_size.y > grid_rows:
		return false
	for y: int in range(piece_size.y):
		for x: int in range(piece_size.x):
			if _occupied_cells.has(origin + Vector2i(x, y)):
				return false
	return true


func _place_piece(piece: Control, origin: Vector2i, piece_size: Vector2i) -> void:
	piece.global_position = _target_board.global_position + Vector2(origin) * cell_size
	_placement_by_piece[piece] = origin
	for y: int in range(piece_size.y):
		for x: int in range(piece_size.x):
			_occupied_cells[origin + Vector2i(x, y)] = piece


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
	_success_label.hide()
	_update_progress()


func _randomize_piece_shapes() -> void:
	var piece_sizes: Array[Vector2i] = _generate_piece_partition(_pieces.size())
	if piece_sizes.size() != _pieces.size():
		push_warning("Could not generate a complete randomized luggage layout; keeping the current piece shapes.")
		return
	_shuffle_piece_sizes(piece_sizes)
	for index: int in range(_pieces.size()):
		var piece: Control = _pieces[index]
		if piece.has_method(&"configure_grid_size"):
			piece.call(&"configure_grid_size", piece_sizes[index], cell_size)
		else:
			piece.set(&"grid_size", piece_sizes[index])
			piece.size = Vector2(piece_sizes[index]) * cell_size


func _generate_piece_partition(piece_count: int) -> Array[Vector2i]:
	var partitions: Array[Vector2i] = [Vector2i(grid_columns, grid_rows)]
	while partitions.size() < piece_count:
		var split_options: Array[Dictionary] = []
		for partition_index: int in range(partitions.size()):
			var partition: Vector2i = partitions[partition_index]
			for cut_x: int in range(1, partition.x):
				if cut_x * partition.y >= minimum_piece_cells and (partition.x - cut_x) * partition.y >= minimum_piece_cells:
					split_options.append({"index": partition_index, "vertical": true, "cut": cut_x})
			for cut_y: int in range(1, partition.y):
				if cut_y * partition.x >= minimum_piece_cells and (partition.y - cut_y) * partition.x >= minimum_piece_cells:
					split_options.append({"index": partition_index, "vertical": false, "cut": cut_y})
		if split_options.is_empty():
			return []
		var option: Dictionary = split_options[_rng.randi_range(0, split_options.size() - 1)]
		var selected_index: int = int(option["index"])
		var selected: Vector2i = partitions[selected_index]
		var first: Vector2i
		var second: Vector2i
		if bool(option["vertical"]):
			var cut_x: int = int(option["cut"])
			first = Vector2i(cut_x, selected.y)
			second = Vector2i(selected.x - cut_x, selected.y)
		else:
			var cut_y: int = int(option["cut"])
			first = Vector2i(selected.x, cut_y)
			second = Vector2i(selected.x, selected.y - cut_y)
		partitions.remove_at(selected_index)
		partitions.append(first)
		partitions.append(second)
	return partitions


func _shuffle_piece_sizes(values: Array[Vector2i]) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var swap_index: int = _rng.randi_range(0, index)
		var held: Vector2i = values[index]
		values[index] = values[swap_index]
		values[swap_index] = held


func _arrange_piece_homes() -> void:
	var shelf_rows: int = maxi(1, floori((_shelf.size.y - loose_shelf_origin_offset.y - 16.0) / cell_size))
	var occupied: Dictionary = {}
	var local_origin: Vector2 = _shelf.global_position - _pieces_root.global_position + loose_shelf_origin_offset
	for piece: Control in _pieces:
		var piece_size: Vector2i = piece.get(&"grid_size")
		var chosen_cell := Vector2i(-1, -1)
		for row: int in range(shelf_rows):
			for column: int in range(loose_shelf_columns):
				var candidate := Vector2i(column, row)
				if _can_place_in_grid(candidate, piece_size, loose_shelf_columns, shelf_rows, occupied):
					chosen_cell = candidate
					break
			if chosen_cell.x >= 0:
				break
		if chosen_cell.x < 0:
			push_warning("Loose-luggage shelf is too small for the randomized pieces; using the scene-authored fallback position.")
			continue
		for y: int in range(piece_size.y):
			for x: int in range(piece_size.x):
				occupied[chosen_cell + Vector2i(x, y)] = piece
		var home_position: Vector2 = local_origin + Vector2(chosen_cell) * cell_size
		_home_positions[piece] = home_position
		piece.position = home_position


func _can_place_in_grid(
	origin: Vector2i,
	piece_size: Vector2i,
	columns: int,
	rows: int,
	occupied: Dictionary
) -> bool:
	if origin.x + piece_size.x > columns or origin.y + piece_size.y > rows:
		return false
	for y: int in range(piece_size.y):
		for x: int in range(piece_size.x):
			if occupied.has(origin + Vector2i(x, y)):
				return false
	return true


func _update_progress() -> void:
	if is_instance_valid(_progress_label):
		_progress_label.text = progress_template % [_occupied_cells.size(), grid_columns * grid_rows]


func _check_completion() -> void:
	if _completed or _occupied_cells.size() < grid_columns * grid_rows:
		return
	_completed = true
	_success_label.show()
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree():
		return
	hide()
	completed.emit(_active_event)
	_active_event = null
