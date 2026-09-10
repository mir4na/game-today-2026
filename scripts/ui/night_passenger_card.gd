class_name NightPassengerCard
extends Control
## Scene-authored draggable Soul Record card used by the Night Ledger.

signal selected(passenger_name: String)

@export var drag_preview_scene: PackedScene
@export_category("Scene Layout Variants")
@export var regular_statement_bottom: float = 91.0
@export var compact_statement_bottom: float = 108.0
@export var hide_assignment_in_compact: bool = true

var passenger_name: String = ""
var assigned_station: String = ""
var _passenger_data: PassengerData
var _drag_ghost: NightPassengerDragPreview

@onready var _portrait: NightCharacterPortrait = %Portrait
@onready var _assigned_overlay: ColorRect = %AssignedOverlay
@onready var _name_label: Label = %PassengerName
@onready var _portrait_name_label: Label = %PortraitName
@onready var _statement_label: Label = %StatementLabel
@onready var _assignment_label: Label = %AssignmentLabel


func configure(data: PassengerData, statement: String) -> void:
	_passenger_data = data
	passenger_name = data.short_name
	_portrait.set_passenger(data)
	_name_label.text = data.short_name.to_upper()
	_portrait_name_label.text = data.short_name.to_upper()
	# Keep the ledger wording byte-for-byte identical to the sentence selected
	# from the Soul Record. Wrapping is visual only; the copy is never shortened.
	_statement_label.text = statement if not statement.is_empty() else "Statement not recorded"
	_statement_label.tooltip_text = statement
	_statement_label.modulate = Color("453b38") if not statement.is_empty() else Color("8f8178")
	show()


func set_compact_mode(enabled: bool) -> void:
	# Five records share the same fixed ledger page. In that layout the gray
	# portrait overlay already communicates assignment, so the repeated station
	# caption yields its row to the exact hidden statement.
	_assignment_label.visible = not (enabled and hide_assignment_in_compact)
	_statement_label.offset_bottom = (
		compact_statement_bottom if enabled else regular_statement_bottom
	)


func set_assignment(station: String) -> void:
	assigned_station = station
	_assignment_label.text = station.to_upper() if not station.is_empty() else "UNASSIGNED"
	_assigned_overlay.visible = not station.is_empty()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if passenger_name.is_empty() or _passenger_data == null:
		return null
	selected.emit(passenger_name)
	# Native drag previews live on the viewport's default canvas (layer 0),
	# while NightPuzzleUI lives inside ModalLayer (layer 20). CanvasLayer.layer
	# is the outermost sort key, so a native preview can never render above
	# the board no matter what z_index it uses. Keep the native preview empty
	# (it only carries the drop payload) and show a top-level ghost inside
	# our own layer instead.
	var empty := Control.new()
	empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(empty)
	_spawn_drag_ghost()
	return {
		"kind": &"night_soul_card",
		"passenger_name": passenger_name,
	}


func _process(_delta: float) -> void:
	if not is_instance_valid(_drag_ghost):
		_drag_ghost = null
		return
	if not get_viewport().gui_is_dragging():
		_free_drag_ghost()
		return
	_update_drag_ghost()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_free_drag_ghost()


func _exit_tree() -> void:
	_free_drag_ghost()


func _spawn_drag_ghost() -> void:
	_free_drag_ghost()
	if drag_preview_scene == null:
		return
	var ghost := drag_preview_scene.instantiate() as NightPassengerDragPreview
	if ghost == null:
		return
	ghost.configure(_passenger_data)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Host the ghost outside the LedgerScroll so the scroll rect never clips
	# it, but still inside ModalLayer (layer 20). top_level escapes the
	# ledger layout, z 100 clears the board chrome (max 31).
	ghost.top_level = true
	ghost.z_index = 100
	ghost.z_as_relative = false
	_drag_ghost_host().add_child(ghost)
	_drag_ghost = ghost
	_update_drag_ghost()


func _drag_ghost_host() -> Node:
	var host: Node = get_parent()
	while host != null:
		if host is NightPuzzleUI:
			return host
		if host is CanvasLayer:
			return host
		host = host.get_parent()
	return self


func _update_drag_ghost() -> void:
	if not is_instance_valid(_drag_ghost):
		return
	_drag_ghost.global_position = get_global_mouse_position() - _drag_ghost.preview_center


func _free_drag_ghost() -> void:
	if is_instance_valid(_drag_ghost):
		_drag_ghost.queue_free()
	_drag_ghost = null


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		selected.emit(passenger_name)
