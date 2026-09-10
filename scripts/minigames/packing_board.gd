class_name PackingBoard
extends Control
## Draws the scene-sized packing target; dimensions remain editable in Inspector.

@export_range(1, 8, 1) var columns: int = 4
@export_range(1, 8, 1) var rows: int = 3
@export_range(24.0, 128.0, 1.0) var cell_size: float = 64.0
@export var fill_color: Color = Color(0.10, 0.14, 0.19, 0.96)
@export var grid_color: Color = Color(0.72, 0.61, 0.39, 0.82)


func _ready() -> void:
	custom_minimum_size = Vector2(columns, rows) * cell_size
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(columns, rows) * cell_size), fill_color, true)
	for column: int in range(columns + 1):
		var x: float = float(column) * cell_size
		draw_line(Vector2(x, 0.0), Vector2(x, float(rows) * cell_size), grid_color, 2.0)
	for row: int in range(rows + 1):
		var y: float = float(row) * cell_size
		draw_line(Vector2(0.0, y), Vector2(float(columns) * cell_size, y), grid_color, 2.0)
