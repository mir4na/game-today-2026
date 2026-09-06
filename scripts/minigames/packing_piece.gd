class_name PackingPiece
extends Panel
## One draggable, grid-sized luggage block in the aisle packing puzzle.

signal grabbed(piece: Control, grab_offset: Vector2)
signal dragged(piece: Control, pointer_position: Vector2, grab_offset: Vector2)
signal released(piece: Control, pointer_position: Vector2, grab_offset: Vector2)

@export var grid_size: Vector2i = Vector2i.ONE
@export var occupied_cell_offsets: Array[Vector2i] = []
@export var display_name: String = "LUGGAGE"
@export_node_path("Label") var label_path: NodePath = NodePath("Label")
@export_category("Interaction Feel")
@export_range(1.0, 1.2, 0.01) var hover_scale: float = 1.04
@export_range(1.0, 1.25, 0.01) var grabbed_scale: float = 1.09
@export_range(0.05, 0.3, 0.01) var feedback_duration: float = 0.12

@onready var _label: Label = get_node_or_null(label_path) as Label
@onready var _artwork: Control = get_node_or_null("Artwork") as Control

var _dragging: bool = false
var _grab_offset: Vector2 = Vector2.ZERO
var _hovered: bool = false
var _feedback_tween: Tween
var _artwork_rest_position: Vector2


func _ready() -> void:
	if not is_instance_valid(_artwork):
		return
	_artwork_rest_position = _artwork.position
	_artwork.pivot_offset = _artwork.size * 0.5
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func configure_grid_size(value: Vector2i, cell_size: float) -> void:
	grid_size = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
	occupied_cell_offsets.clear()
	size = Vector2(grid_size) * cell_size
	if is_instance_valid(_label):
		_label.text = "%s\n%d × %d" % [display_name, grid_size.x, grid_size.y]


func get_occupied_cell_offsets() -> Array[Vector2i]:
	if not occupied_cell_offsets.is_empty():
		return occupied_cell_offsets.duplicate()
	var cells: Array[Vector2i] = []
	for y: int in range(grid_size.y):
		for x: int in range(grid_size.x):
			cells.append(Vector2i(x, y))
	return cells


func cancel_drag() -> void:
	_dragging = false
	_animate_artwork(Vector2.ONE if not _hovered else Vector2.ONE * hover_scale, 0.0, Color.WHITE)


func play_spawn_feedback(delay: float = 0.0) -> void:
	if not is_instance_valid(_artwork):
		return
	_kill_feedback_tween()
	_artwork.scale = Vector2.ONE * 0.72
	_artwork.rotation = -0.045
	_artwork.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_feedback_tween = create_tween()
	if delay > 0.0:
		_feedback_tween.tween_interval(delay)
	_feedback_tween.set_parallel(true)
	_feedback_tween.tween_property(_artwork, ^"scale", Vector2.ONE * 1.06, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(_artwork, ^"rotation", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(_artwork, ^"modulate", Color.WHITE, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_feedback_tween.chain().tween_property(_artwork, ^"scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func set_grabbed_feedback(value: bool) -> void:
	if value:
		_animate_artwork(Vector2.ONE * grabbed_scale, -0.025, Color(1.08, 1.08, 1.08, 1.0))
	else:
		_animate_artwork(Vector2.ONE if not _hovered else Vector2.ONE * hover_scale, 0.0, Color.WHITE)


func play_valid_drop() -> void:
	if not is_instance_valid(_artwork):
		return
	_kill_feedback_tween()
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(_artwork, ^"scale", Vector2(1.1, 0.9), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_feedback_tween.parallel().tween_property(_artwork, ^"rotation", 0.018, 0.07)
	_feedback_tween.tween_property(_artwork, ^"scale", Vector2(0.97, 1.06), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.parallel().tween_property(_artwork, ^"rotation", 0.0, 0.09)
	_feedback_tween.tween_property(_artwork, ^"scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func play_invalid_drop() -> void:
	if not is_instance_valid(_artwork):
		return
	_kill_feedback_tween()
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(_artwork, ^"scale", Vector2(0.94, 1.06), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_feedback_tween.parallel().tween_property(_artwork, ^"modulate", Color(1.25, 0.58, 0.58, 1.0), 0.08)
	_feedback_tween.tween_property(_artwork, ^"position:x", _artwork_rest_position.x + 7.0, 0.045)
	_feedback_tween.tween_property(_artwork, ^"position:x", _artwork_rest_position.x - 6.0, 0.055)
	_feedback_tween.tween_property(_artwork, ^"position:x", _artwork_rest_position.x + 3.0, 0.045)
	_feedback_tween.tween_property(_artwork, ^"position:x", _artwork_rest_position.x, 0.045)
	_feedback_tween.tween_property(_artwork, ^"scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.parallel().tween_property(_artwork, ^"modulate", Color.WHITE, 0.14)


func play_completion_feedback(delay: float) -> void:
	if not is_instance_valid(_artwork):
		return
	_kill_feedback_tween()
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(delay)
	_feedback_tween.tween_property(_artwork, ^"scale", Vector2.ONE * 1.12, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.parallel().tween_property(_artwork, ^"modulate", Color(1.25, 1.16, 0.72, 1.0), 0.1)
	_feedback_tween.tween_property(_artwork, ^"scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_feedback_tween.parallel().tween_property(_artwork, ^"modulate", Color.WHITE, 0.14)


func reset_feedback() -> void:
	_kill_feedback_tween()
	_dragging = false
	_hovered = false
	if not is_instance_valid(_artwork):
		return
	_artwork.position = _artwork_rest_position
	_artwork.scale = Vector2.ONE
	_artwork.rotation = 0.0
	_artwork.modulate = Color.WHITE


func _on_mouse_entered() -> void:
	_hovered = true
	if not _dragging:
		_animate_artwork(Vector2.ONE * hover_scale, 0.0, Color(1.08, 1.08, 1.08, 1.0))


func _on_mouse_exited() -> void:
	_hovered = false
	if not _dragging:
		_animate_artwork(Vector2.ONE, 0.0, Color.WHITE)


func _animate_artwork(target_scale: Vector2, target_rotation: float, target_modulate: Color) -> void:
	if not is_instance_valid(_artwork):
		return
	_kill_feedback_tween()
	_feedback_tween = create_tween().set_parallel(true)
	_feedback_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(_artwork, ^"scale", target_scale, feedback_duration)
	_feedback_tween.tween_property(_artwork, ^"rotation", target_rotation, feedback_duration)
	_feedback_tween.tween_property(_artwork, ^"modulate", target_modulate, feedback_duration)


func _kill_feedback_tween() -> void:
	if _feedback_tween and _feedback_tween.is_valid():
		_feedback_tween.kill()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_grab_offset = event.position
			set_grabbed_feedback(true)
			grabbed.emit(self, _grab_offset)
		else:
			if _dragging:
				_dragging = false
				set_grabbed_feedback(false)
				released.emit(self, event.global_position, _grab_offset)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		dragged.emit(self, event.global_position, _grab_offset)
		accept_event()
