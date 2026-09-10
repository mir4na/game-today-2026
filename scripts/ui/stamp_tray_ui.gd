class_name StampTrayUI
extends Control
## Bottom-left station-stamp drawer. It intentionally owns pointer input only while
## a ticket is face-up, leaving the ID card and the rest of the overlay untouched.

signal stamp_dropped(station_name: String, ticket_local_position: Vector2)

const STATIONS: Array[String] = [
	"Alderwick",
	"Brambleford",
	"Cinderfield",
	"Dunmere",
	"Eastmere",
]

const RESULT_TEXTURES := {
	"Alderwick": preload("res://assets/ui/Stamp/StampResult_A.png"),
	"Brambleford": preload("res://assets/ui/Stamp/StampResult_B.png"),
	"Cinderfield": preload("res://assets/ui/Stamp/StampResult_C.png"),
	"Dunmere": preload("res://assets/ui/Stamp/StampResult_d.png"),
	"Eastmere": preload("res://assets/ui/Stamp/StampResult_E.png"),
}

@export_category("Drawer Motion")
@export var expanded_x: float = 18.0
@export var collapsed_x: float = -626.0
@export_range(0.1, 1.0, 0.01) var drawer_duration: float = 0.34
@export_range(0.0, 1.0, 0.01) var collapse_delay: float = 0.2
@export_category("Stamp Motion")
@export_range(0.05, 0.5, 0.01) var pickup_flip_duration: float = 0.18
@export_range(0.05, 0.6, 0.01) var return_duration: float = 0.24
@export_range(0.1, 0.6, 0.01) var choice_entry_duration: float = 0.24
@export_range(0.0, 0.15, 0.005) var choice_stagger: float = 0.035

var _ticket_target: Control
var _ticket_is_visible: bool = false
var _stamp_locked: bool = false
var _committed: bool = false
var _expanded: bool = false
var _dragging: bool = false
var _selected_station: String = ""
var _selected_choice: Control
var _collapse_remaining: float = 0.0
var _drawer_tween: Tween
var _drag_tween: Tween
var _choice_tweens: Dictionary = {}
var _choice_rest_positions: Dictionary = {}

@onready var _tray: Control = %Tray
@onready var _drag_preview: TextureRect = %DragPreview
@onready var _drag_seal_hint: TextureRect = %DragSealHint


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview.hide()
	for station_name: String in STATIONS:
		var choice := get_node_or_null("Tray/StampChoices/%s" % station_name) as Control
		if choice == null:
			push_error("Stamp tray is missing the %s stamp choice." % station_name)
			continue
		choice.tooltip_text = "%s station stamp" % station_name
		_choice_rest_positions[choice] = choice.position
		choice.gui_input.connect(_on_choice_gui_input.bind(station_name, choice))
		choice.mouse_entered.connect(_on_choice_hover.bind(choice, true))
		choice.mouse_exited.connect(_on_choice_hover.bind(choice, false))
	_set_drawer_x(collapsed_x)
	hide()


func configure(ticket_target: Control, already_stamped: bool, is_locked: bool) -> void:
	_kill_tween(_drawer_tween)
	_kill_tween(_drag_tween)
	_ticket_target = ticket_target
	_committed = already_stamped
	_stamp_locked = is_locked
	_dragging = false
	_selected_station = ""
	_selected_choice = null
	_drag_preview.hide()
	self_modulate = Color.WHITE
	for station_name: String in STATIONS:
		var choice := get_node_or_null("Tray/StampChoices/%s" % station_name) as Control
		if choice != null:
			_reset_choice_for_closed_drawer(choice)
	_expanded = false
	_set_drawer_x(collapsed_x)
	_refresh_availability(false)


func set_ticket_visible(value: bool) -> void:
	_ticket_is_visible = value
	_refresh_availability(true)


func set_stamp_locked(value: bool) -> void:
	_stamp_locked = value
	_refresh_availability(true)


func mark_committed() -> void:
	if _committed:
		return
	_committed = true
	_ticket_is_visible = false
	_slide_out_and_hide()


func cancel_drag() -> void:
	if not _dragging:
		return
	_finish_drag(false)


func _process(delta: float) -> void:
	if not visible or _committed or _stamp_locked:
		return
	if _dragging:
		_update_drag_preview()
		return
	var hovered: bool = _tray.get_global_rect().has_point(get_viewport().get_mouse_position())
	if hovered:
		_collapse_remaining = collapse_delay
		if not _expanded:
			_set_expanded(true)
	elif _expanded:
		_collapse_remaining -= delta
		if _collapse_remaining <= 0.0:
			_set_expanded(false)


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
		var local_drop_position := _ticket_local_position(mouse_event.position)
		var valid_drop: bool = _ticket_target != null and Rect2(Vector2.ZERO, _ticket_target.size).has_point(local_drop_position)
		if valid_drop:
			stamp_dropped.emit(_selected_station, local_drop_position)
		_finish_drag(valid_drop)
		get_viewport().set_input_as_handled()


func _on_choice_gui_input(event: InputEvent, station_name: String, choice: Control) -> void:
	if _dragging or _committed or _stamp_locked or not _ticket_is_visible:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	_begin_drag(station_name, choice)
	get_viewport().set_input_as_handled()


func _begin_drag(station_name: String, choice: Control) -> void:
	_kill_tween(_drag_tween)
	_kill_tween(_choice_tweens.get(choice) as Tween)
	_dragging = true
	_selected_station = station_name
	_selected_choice = choice
	_expanded = true
	_drag_preview.texture = preload("res://assets/ui/Stamp/Stamp_TopView.png")
	_drag_seal_hint.texture = RESULT_TEXTURES.get(station_name) as Texture2D
	_drag_preview.show()
	_drag_preview.pivot_offset = _drag_preview.size * 0.5
	_drag_preview.scale = Vector2(0.06, 0.94)
	_drag_preview.rotation = deg_to_rad(-8.0)
	_drag_preview.self_modulate = Color(1.0, 1.0, 1.0, 0.96)
	choice.self_modulate.a = 0.34
	_update_drag_preview()
	_drag_tween = create_tween()
	_drag_tween.set_parallel(true)
	_drag_tween.tween_property(_drag_preview, ^"scale", Vector2.ONE, pickup_flip_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_drag_tween.tween_property(_drag_preview, ^"rotation", 0.0, pickup_flip_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	GameSFX.play(&"grab", -8.0, 1.06, 0.025, 0.1)


func _finish_drag(was_committed: bool) -> void:
	if not _dragging:
		return
	_dragging = false
	_kill_tween(_drag_tween)
	var return_center: Vector2 = get_viewport().get_mouse_position()
	if is_instance_valid(_selected_choice):
		return_center = _selected_choice.get_global_rect().get_center()
	var return_position: Vector2 = return_center - _drag_preview.size * 0.5
	_drag_tween = create_tween()
	_drag_tween.set_parallel(true)
	_drag_tween.tween_property(_drag_preview, ^"position", return_position, return_duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_drag_tween.tween_property(_drag_preview, ^"scale", Vector2(0.08, 0.9), return_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_drag_tween.tween_property(_drag_preview, ^"rotation", deg_to_rad(8.0), return_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_drag_tween.chain().tween_callback(_complete_drag_return.bind(was_committed))
	if not was_committed:
		GameSFX.play(&"grab", -11.0, 0.84, 0.025, 0.08)


func _complete_drag_return(was_committed: bool) -> void:
	_drag_preview.hide()
	_drag_preview.scale = Vector2.ONE
	_drag_preview.rotation = 0.0
	if is_instance_valid(_selected_choice):
		_selected_choice.self_modulate = Color.WHITE
	_selected_choice = null
	_selected_station = ""
	if was_committed:
		mark_committed()


func _update_drag_preview() -> void:
	var mouse_position := get_viewport().get_mouse_position()
	_drag_preview.position = mouse_position - _drag_preview.size * 0.5


func _ticket_local_position(viewport_position: Vector2) -> Vector2:
	if not is_instance_valid(_ticket_target):
		return Vector2(-10000.0, -10000.0)
	return _ticket_target.get_global_transform_with_canvas().affine_inverse() * viewport_position


func _refresh_availability(animate: bool) -> void:
	var should_show: bool = _ticket_is_visible and not _committed and not _stamp_locked and is_instance_valid(_ticket_target)
	if should_show:
		show()
		_expanded = false
		_set_drawer_x(collapsed_x)
		self_modulate.a = 0.0 if animate else 1.0
		if animate:
			var reveal := create_tween()
			reveal.tween_property(self, ^"self_modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		return
	if not visible:
		return
	if animate:
		_slide_out_and_hide()
	else:
		hide()


func _set_expanded(value: bool) -> void:
	if _expanded == value:
		return
	_expanded = value
	_kill_tween(_drawer_tween)
	_drawer_tween = create_tween()
	_drawer_tween.tween_property(
		_tray,
		^"position:x",
		expanded_x if value else collapsed_x,
		drawer_duration
	).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	if value:
		_animate_choices_in()
	else:
		_animate_choices_out()
	GameSFX.play(&"paper_rustle", -15.0, 1.08 if value else 0.9, 0.02, 0.06)


func _slide_out_and_hide() -> void:
	_kill_tween(_drawer_tween)
	_animate_choices_out()
	_drawer_tween = create_tween()
	_drawer_tween.set_parallel(true)
	_drawer_tween.tween_property(_tray, ^"position:x", -_tray.size.x - 36.0, drawer_duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	_drawer_tween.tween_property(self, ^"self_modulate:a", 0.0, drawer_duration * 0.72).set_delay(drawer_duration * 0.28)
	_drawer_tween.chain().tween_callback(hide)


func _on_choice_hover(choice: Control, hovered: bool) -> void:
	if _dragging or _committed:
		return
	var old_tween := _choice_tweens.get(choice) as Tween
	_kill_tween(old_tween)
	var tween := create_tween()
	_choice_tweens[choice] = tween
	tween.set_parallel(true)
	tween.tween_property(choice, ^"scale", Vector2(1.07, 1.07) if hovered else Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(choice, ^"self_modulate", Color(1.08, 1.08, 1.08, 1.0) if hovered else Color.WHITE, 0.12)
	if hovered:
		GameSFX.play(&"button_hover", -17.0, 1.05, 0.02, 0.04)


func _animate_choices_in() -> void:
	for index: int in range(STATIONS.size()):
		var choice := get_node_or_null("Tray/StampChoices/%s" % STATIONS[index]) as Control
		if choice == null:
			continue
		_kill_tween(_choice_tweens.get(choice) as Tween)
		var rest_position: Vector2 = _choice_rest_positions.get(choice, choice.position)
		choice.position = rest_position + Vector2(0.0, 28.0)
		choice.scale = Vector2(0.72, 0.72)
		choice.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		var tween := create_tween()
		_choice_tweens[choice] = tween
		var entry_delay: float = float(index) * choice_stagger
		tween.set_parallel(true)
		tween.tween_property(choice, ^"position", rest_position - Vector2(0.0, 4.0), choice_entry_duration).set_delay(entry_delay).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween.tween_property(choice, ^"scale", Vector2(1.055, 1.055), choice_entry_duration).set_delay(entry_delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(choice, ^"self_modulate", Color.WHITE, choice_entry_duration * 0.62).set_delay(entry_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.chain().set_parallel(true)
		tween.tween_property(choice, ^"position", rest_position, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(choice, ^"scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _animate_choices_out() -> void:
	for reverse_index: int in range(STATIONS.size()):
		var station_index: int = STATIONS.size() - 1 - reverse_index
		var choice := get_node_or_null("Tray/StampChoices/%s" % STATIONS[station_index]) as Control
		if choice == null or choice == _selected_choice:
			continue
		_kill_tween(_choice_tweens.get(choice) as Tween)
		var rest_position: Vector2 = _choice_rest_positions.get(choice, choice.position)
		var tween := create_tween()
		_choice_tweens[choice] = tween
		var exit_delay: float = float(reverse_index) * choice_stagger * 0.45
		tween.set_parallel(true)
		tween.tween_property(choice, ^"position", rest_position + Vector2(0.0, 16.0), 0.14).set_delay(exit_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(choice, ^"scale", Vector2(0.82, 0.82), 0.14).set_delay(exit_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(choice, ^"self_modulate", Color(1.0, 1.0, 1.0, 0.0), 0.12).set_delay(exit_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _reset_choice_for_closed_drawer(choice: Control) -> void:
	var rest_position: Vector2 = _choice_rest_positions.get(choice, choice.position)
	choice.position = rest_position + Vector2(0.0, 28.0)
	choice.scale = Vector2(0.72, 0.72)
	choice.self_modulate = Color(1.0, 1.0, 1.0, 0.0)


func _set_drawer_x(value: float) -> void:
	_tray.position.x = value


func _kill_tween(tween: Tween) -> void:
	if is_instance_valid(tween) and tween.is_valid():
		tween.kill()
