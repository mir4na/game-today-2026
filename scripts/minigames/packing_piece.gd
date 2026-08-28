class_name PackingPiece
extends Panel
## One draggable, grid-sized luggage block in the aisle packing puzzle.

signal grabbed(piece: Control, grab_offset: Vector2)
signal dragged(piece: Control, pointer_position: Vector2, grab_offset: Vector2)
signal released(piece: Control, pointer_position: Vector2, grab_offset: Vector2)

@export var grid_size: Vector2i = Vector2i.ONE
@export var display_name: String = "LUGGAGE"
@export_node_path("Label") var label_path: NodePath = NodePath("Label")

@onready var _label: Label = get_node_or_null(label_path) as Label

var _dragging: bool = false
var _grab_offset: Vector2 = Vector2.ZERO


func configure_grid_size(value: Vector2i, cell_size: float) -> void:
	grid_size = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
	size = Vector2(grid_size) * cell_size
	if is_instance_valid(_label):
		_label.text = "%s\n%d × %d" % [display_name, grid_size.x, grid_size.y]


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_grab_offset = event.position
			grabbed.emit(self, _grab_offset)
		else:
			if _dragging:
				_dragging = false
				released.emit(self, event.global_position, _grab_offset)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		dragged.emit(self, event.global_position, _grab_offset)
		accept_event()
