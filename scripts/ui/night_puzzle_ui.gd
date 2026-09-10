class_name NightPuzzleUI
extends Control
## Scene-authored Night Assignment board. Passenger cards support native Godot
## drag-and-drop while clicks remain available as an accessible fallback.

signal closed
signal departures_confirmed(assignments: Dictionary)
signal validation_finished(succeeded: bool, attempt_count: int)
signal validation_impact_requested(succeeded: bool)

@export_category("Inspector Copy")
@export var instruction_text: String = "Drag each soul to a station."
@export var incomplete_assignment_error: String = "Assign every soul before finalizing."
@export var assignment_count_template: String = "%d / %d SOULS ASSIGNED"
@export var clue_count_template: String = "%d/%d FOUND"
@export_category("Validation Presentation")
@export var ledger_exit_offset: Vector2 = Vector2(-390.0, 0.0)
@export var station_path_focus_offset: Vector2 = Vector2(-172.0, 0.0)
@export var station_path_focus_scale: Vector2 = Vector2(1.12, 1.12)
@export var station_path_focus_pivot: Vector2 = Vector2(812.0, 360.0)
@export_range(0.05, 2.0, 0.05) var focus_transition_seconds: float = 0.5
@export_range(0.0, 1.0, 0.05) var validation_map_shade_alpha: float = 0.5
@export_range(0.05, 2.0, 0.05) var light_travel_seconds: float = 0.34
@export_range(0.0, 1.0, 0.05) var station_hold_seconds: float = 0.16
@export_range(0.1, 3.0, 0.05) var result_hold_seconds: float = 0.9
@export_range(0.05, 1.0, 0.05) var failed_attempt_exit_seconds: float = 0.28
@export_category("Five-Soul Ledger Layout")
@export var regular_card_origin: Vector2 = Vector2.ZERO
@export_range(80.0, 140.0, 1.0) var regular_card_spacing: float = 120.0
@export var compact_card_origin: Vector2 = Vector2.ZERO
@export_range(0.5, 1.0, 0.01) var compact_card_scale: float = 1.0
@export_range(70.0, 140.0, 1.0) var compact_card_spacing: float = 120.0
@export_range(300.0, 700.0, 1.0) var ledger_scroll_viewport_height: float = 518.0
@export_category("Scene-Based Station Paths")
@export var station_path_layout_scenes: Array[PackedScene] = []

var _puzzle: DeparturePuzzleData
var _selected_passenger: String = ""
var _assignments: Dictionary = {}
var _passenger_data_by_name: Dictionary = {}
var _ledger_passenger_order: Array[String] = []
var _collected_statements: Dictionary = {}
var _veil_note_statement: String = ""
var _validating: bool = false
var _focus_tween: Tween
var _map_impact_tween: Tween
var _ledger_rest_position: Vector2
var _station_path_rest_position: Vector2
var _current_instruction: String = ""
var _station_path_layout: NightStationPathLayout
var _station_targets: Array[NightStationTarget] = []
var _validation_fuse_points := PackedVector2Array()

@onready var _instruction_label: Label = %InstructionLabel
@onready var _selection_label: Label = %SelectionLabel
@onready var _assignment_count_label: Label = %AssignmentCountLabel
@onready var _clue_count_label: Label = %ClueCountLabel
@onready var _veil_note_panel: Control = %VeilNotePanel
@onready var _veil_note_label: Label = %VeilNoteStatement
@onready var _error_label: Label = %ErrorLabel
@onready var _confirm_button: Button = %ConfirmButton
@onready var _board_anchor: Control = %BoardAnchor
@onready var _ledger_anchor: Control = %LedgerAnchor
@onready var _ledger_scroll: ScrollContainer = %LedgerScroll
@onready var _ledger_card_canvas: Control = %CardCanvas
@onready var _station_path_anchor: Control = %StationPathAnchor
@onready var _station_path_layout_host: Control = %PathLayoutHost
@onready var _validation_light: TextureRect = %ValidationLightToken
@onready var _validation_fuse_glow: Line2D = %ValidationFuseGlow
@onready var _validation_fuse_trail: Line2D = %ValidationFuseTrail
@onready var _validation_fuse_spark: CPUParticles2D = %ValidationFuseSpark
@onready var _validation_map_shade: ColorRect = %ValidationMapShade
@onready var _legend_label: Label = $BoardAnchor/StationPathAnchor/LegendLabel
@onready var _close_button: Control = $BoardAnchor/StationPathAnchor/CloseButton
@onready var _passenger_cards: Array[NightPassengerCard] = [
	%PassengerCard1,
	%PassengerCard2,
	%PassengerCard3,
	%PassengerCard4,
	%PassengerCard5,
]


func _ready() -> void:
	_ledger_rest_position = _ledger_anchor.position
	_station_path_rest_position = _station_path_anchor.position
	_station_path_anchor.pivot_offset = station_path_focus_pivot
	_current_instruction = instruction_text
	_instruction_label.text = _current_instruction
	for card: NightPassengerCard in _passenger_cards:
		card.selected.connect(_on_passenger_selected)
	_reset_validation_presentation()
	hide()


func open_puzzle(
	passengers: Array[PassengerData],
	puzzle: DeparturePuzzleData,
	collected_statements: Dictionary,
	veil_note_statement: String = ""
) -> void:
	var is_new_case: bool = _puzzle != puzzle
	_puzzle = puzzle
	if is_new_case:
		_assignments.clear()
	_selected_passenger = ""
	_passenger_data_by_name.clear()
	_ledger_passenger_order.clear()
	_collected_statements = collected_statements.duplicate(true)
	set_veil_note_statement(veil_note_statement)
	_validating = false
	_error_label.text = ""
	_current_instruction = puzzle.get_assignment_instruction() if puzzle != null else instruction_text
	_instruction_label.text = _current_instruction
	_selection_label.text = _current_instruction
	_reset_validation_presentation()

	for card: NightPassengerCard in _passenger_cards:
		card.hide()
	if puzzle == null:
		show_error("The night station path is unavailable.")
		show()
		return
	_configure_station_path(puzzle)
	if not is_instance_valid(_station_path_layout):
		show()
		return
	if passengers.size() > _passenger_cards.size() or puzzle.night_stations.size() > _station_targets.size():
		show_error("This ledger supports five souls and four stations.")
		show()
		return
	for data: PassengerData in passengers:
		_passenger_data_by_name[data.short_name] = data
		_ledger_passenger_order.append(data.short_name)

	_remove_invalid_assignments()
	_refresh_ledger_cards()
	_update_assignment_visuals()
	show()
	_present_board()


func _layout_passenger_cards(passenger_count: int) -> void:
	var use_scroll_layout: bool = _ledger_passenger_order.size() >= 5
	var origin: Vector2 = compact_card_origin if use_scroll_layout else regular_card_origin
	var spacing: float = compact_card_spacing if use_scroll_layout else regular_card_spacing
	var card_scale: float = 1.0
	_ledger_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
		if use_scroll_layout
		else ScrollContainer.SCROLL_MODE_DISABLED
	)
	var authored_count: int = maxi(passenger_count, _ledger_passenger_order.size() if use_scroll_layout else passenger_count)
	var content_height: float = origin.y + spacing * maxf(0.0, float(authored_count - 1)) + 116.0
	_ledger_card_canvas.custom_minimum_size = Vector2(
		318.0,
		maxf(ledger_scroll_viewport_height, content_height)
	)
	for index: int in range(_passenger_cards.size()):
		var card: NightPassengerCard = _passenger_cards[index]
		card.position = origin + Vector2(0.0, spacing * index)
		card.scale = Vector2.ONE * card_scale
		card.set_compact_mode(false)


func _refresh_ledger_cards() -> void:
	var found_names: Array[String] = []
	for passenger_name: String in _ledger_passenger_order:
		if _is_statement_found(passenger_name):
			found_names.append(passenger_name)
	_layout_passenger_cards(found_names.size())
	for card: NightPassengerCard in _passenger_cards:
		card.hide()
	for index: int in range(found_names.size()):
		var passenger_name: String = found_names[index]
		var data := _passenger_data_by_name.get(passenger_name) as PassengerData
		if data == null:
			continue
		var card: NightPassengerCard = _passenger_cards[index]
		card.configure(data, str(_collected_statements.get(passenger_name, "")))
		card.set_assignment(_station_for_passenger(passenger_name))
		card.show()


func _is_statement_found(passenger_name: String) -> bool:
	return not str(_collected_statements.get(passenger_name, "")).strip_edges().is_empty()


func _configure_station_path(puzzle: DeparturePuzzleData) -> void:
	if is_instance_valid(_station_path_layout):
		_station_path_layout.free()
	_station_path_layout = null
	_station_targets.clear()
	var layout_scene: PackedScene = puzzle.get_station_path_layout_scene()
	if layout_scene == null and not station_path_layout_scenes.is_empty():
		var scene_index: int = clampi(
			puzzle.service_level - 1,
			0,
			station_path_layout_scenes.size() - 1
		)
		layout_scene = station_path_layout_scenes[scene_index]
	if layout_scene == null:
		show_error("Night Service Level %d has no scene-authored station path." % puzzle.service_level)
		return
	_station_path_layout = layout_scene.instantiate() as NightStationPathLayout
	if _station_path_layout == null:
		show_error("The configured station path scene is invalid.")
		return
	_station_path_layout_host.add_child(_station_path_layout)
	_station_targets = _station_path_layout.get_station_targets()
	for target: NightStationTarget in _station_targets:
		target.visible = puzzle.night_stations.has(target.station_name)
		target.passenger_dropped.connect(_assign_passenger_to_station)
		target.selected.connect(_on_station_selected)
		target.validation_impact.connect(_on_station_validation_impact)


func set_veil_note_statement(statement: String) -> void:
	_veil_note_statement = statement.strip_edges()
	if not is_node_ready():
		return
	_veil_note_label.text = _veil_note_statement
	_veil_note_panel.visible = not _veil_note_statement.is_empty()


func refresh_collected_statements(collected_statements: Dictionary) -> void:
	_collected_statements = collected_statements.duplicate(true)
	if not visible or _puzzle == null:
		return
	_remove_invalid_assignments()
	_refresh_ledger_cards()
	_update_assignment_visuals()


func request_close() -> void:
	if not visible or _validating:
		return
	hide()
	closed.emit()


func show_error(message: String) -> void:
	_validating = false
	_error_label.text = message
	_update_counts()


func _on_passenger_selected(passenger_name: String) -> void:
	if _validating or not _is_statement_found(passenger_name):
		return
	_selected_passenger = passenger_name
	_selection_label.text = _current_instruction
	_error_label.text = ""


func _on_station_selected(station_name: String) -> void:
	if _validating:
		return
	if _selected_passenger.is_empty():
		_selection_label.text = _current_instruction
		return
	_assign_passenger_to_station(station_name, _selected_passenger)


func _assign_passenger_to_station(station_name: String, passenger_name: String) -> void:
	if _validating:
		return
	if _puzzle == null or not _puzzle.night_stations.has(station_name):
		return
	if not _passenger_data_by_name.has(passenger_name) or not _is_statement_found(passenger_name):
		return
	# Each soul has one destination, while a station may hold any number of
	# souls. Re-dropping a soul moves it without displacing the existing stack.
	for old_station: String in _assignments.keys():
		var old_passengers: Array = _passengers_assigned_to(old_station)
		old_passengers.erase(passenger_name)
		if old_passengers.is_empty():
			_assignments.erase(old_station)
		else:
			_assignments[old_station] = old_passengers
	var station_passengers: Array = _passengers_assigned_to(station_name)
	if not station_passengers.has(passenger_name):
		station_passengers.append(passenger_name)
	_assignments[station_name] = station_passengers
	_selected_passenger = passenger_name
	_selection_label.text = _current_instruction
	_error_label.text = ""
	_update_assignment_visuals()


func _update_assignment_visuals() -> void:
	for target: NightStationTarget in _station_targets:
		if not target.visible:
			continue
		target.set_assignments(
			_passengers_assigned_to(target.station_name),
			_passenger_data_by_name
		)
	for card: NightPassengerCard in _passenger_cards:
		if card.visible:
			card.set_assignment(_station_for_passenger(card.passenger_name))
	_update_counts()


func _update_counts() -> void:
	var total: int = _passenger_data_by_name.size()
	var assigned_count: int = _assigned_passenger_count()
	_assignment_count_label.text = assignment_count_template % [assigned_count, total]
	var clue_count: int = 0
	for passenger_name: String in _passenger_data_by_name:
		if not str(_collected_statements.get(passenger_name, "")).is_empty():
			clue_count += 1
	_clue_count_label.text = clue_count_template % [clue_count, total]
	_confirm_button.disabled = _validating or total == 0 or assigned_count != total


func _station_for_passenger(passenger_name: String) -> String:
	for station_name: String in _assignments:
		if _passengers_assigned_to(station_name).has(passenger_name):
			return station_name
	return ""


func _remove_invalid_assignments() -> void:
	var seen_passengers: Dictionary = {}
	for station_name: String in _assignments.keys():
		if not _puzzle.night_stations.has(station_name):
			_assignments.erase(station_name)
			continue
		var valid_passengers: Array[String] = []
		for passenger_value: Variant in _passengers_assigned_to(station_name):
			var passenger_name: String = str(passenger_value)
			if (
				_passenger_data_by_name.has(passenger_name)
				and _is_statement_found(passenger_name)
				and not seen_passengers.has(passenger_name)
			):
				valid_passengers.append(passenger_name)
				seen_passengers[passenger_name] = true
		if valid_passengers.is_empty():
			_assignments.erase(station_name)
		else:
			_assignments[station_name] = valid_passengers


func _confirm() -> void:
	if _validating:
		return
	if _puzzle == null or _assigned_passenger_count() != _passenger_data_by_name.size():
		_error_label.text = incomplete_assignment_error
		return
	_confirm_button.disabled = true
	departures_confirmed.emit(_assignments.duplicate(true))


func play_validation(station_results: Dictionary, attempt_count: int) -> void:
	if not visible or _puzzle == null:
		show_error("The station path could not read this assignment.")
		return
	_validating = true
	_confirm_button.disabled = true
	await _focus_station_path()

	var ordered_targets: Array[NightStationTarget] = _get_validation_order()
	var all_correct: bool = true
	for index: int in range(ordered_targets.size()):
		var target: NightStationTarget = ordered_targets[index]
		var is_correct: bool = bool(station_results.get(target.station_name, false))
		all_correct = all_correct and is_correct
		await _move_validation_light(target, index == 0)
		await target.play_validation(is_correct)
		if station_hold_seconds > 0.0:
			await get_tree().create_timer(station_hold_seconds).timeout

	await _fade_validation_light()
	if all_correct:
		if result_hold_seconds > 0.0:
			await get_tree().create_timer(result_hold_seconds).timeout
		validation_finished.emit(true, attempt_count)
		return

	if result_hold_seconds > 0.0:
		await get_tree().create_timer(result_hold_seconds).timeout
	_assignments.clear()
	_selected_passenger = ""
	_selection_label.text = _current_instruction
	_error_label.text = ""
	_update_assignment_visuals()
	await _dismiss_failed_attempt()
	# Restore failed stars only after the board is fully gone, so a rejected
	# station stays absent for the entire visible result beat.
	for target: NightStationTarget in _station_targets:
		target.reset_validation_visual()
	_validating = false
	validation_finished.emit(false, attempt_count)


func _focus_station_path() -> void:
	if is_instance_valid(_focus_tween) and _focus_tween.is_valid():
		_focus_tween.kill()
	_station_path_anchor.pivot_offset = station_path_focus_pivot
	_focus_tween = create_tween().set_parallel(true)
	_focus_tween.tween_property(
		_ledger_anchor,
		^"position",
		_ledger_rest_position + ledger_exit_offset,
		focus_transition_seconds
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_focus_tween.tween_property(
		_ledger_anchor, ^"modulate:a", 0.0, focus_transition_seconds * 0.76
	)
	_focus_tween.tween_property(
		_station_path_anchor,
		^"position",
		_station_path_rest_position + station_path_focus_offset,
		focus_transition_seconds
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.tween_property(
		_station_path_anchor,
		^"scale",
		station_path_focus_scale,
		focus_transition_seconds
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_focus_tween.tween_property(
		_validation_map_shade,
		^"modulate:a",
		validation_map_shade_alpha,
		focus_transition_seconds
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	for control: CanvasItem in _validation_chrome():
		_focus_tween.tween_property(
			control, ^"modulate:a", 0.0, focus_transition_seconds * 0.55
		)
	await _focus_tween.finished


func _dismiss_failed_attempt() -> void:
	_board_anchor.pivot_offset = _board_anchor.size * 0.5
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(
		_board_anchor, ^"scale", Vector2(0.97, 0.97), failed_attempt_exit_seconds
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(
		_board_anchor, ^"modulate:a", 0.0, failed_attempt_exit_seconds
	)
	await tween.finished


func _move_validation_light(target: NightStationTarget, first_target: bool) -> void:
	var target_center: Vector2 = _path_node_center(target)
	var target_position: Vector2 = target_center - _validation_light.size * 0.5
	if first_target:
		_validation_fuse_points = PackedVector2Array([target_center])
		_apply_validation_fuse_points()
		_validation_light.position = target_position
		_validation_light.scale = Vector2.ZERO
		_validation_light.modulate = Color(1.0, 0.77, 0.31, 0.92)
		_validation_light.show()
		_validation_fuse_spark.position = target_center
		_validation_fuse_spark.restart()
		_validation_fuse_spark.emitting = true
		var arrival_tween: Tween = create_tween()
		arrival_tween.tween_property(
			_validation_light, ^"scale", Vector2.ONE, light_travel_seconds
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await arrival_tween.finished
		return
	var current_center: Vector2 = _validation_light.position + _validation_light.size * 0.5
	var route_nodes: Array[Control] = []
	if is_instance_valid(_station_path_layout):
		var ordered_targets: Array[NightStationTarget] = _get_validation_order()
		var target_index: int = ordered_targets.find(target)
		if target_index > 0:
			route_nodes = _station_path_layout.get_route_nodes(
				ordered_targets[target_index - 1].station_name,
				target.station_name
			)
	var route_points := PackedVector2Array([current_center])
	for node: Control in route_nodes:
		var node_center: Vector2 = _path_node_center(node)
		if route_points[-1].distance_to(node_center) > 0.5:
			route_points.append(node_center)
	if route_points[-1].distance_to(target_center) > 0.5:
		route_points.append(target_center)
	var segment_count: int = maxi(1, route_points.size() - 1)
	var segment_seconds: float = maxf(0.04, light_travel_seconds / float(segment_count))
	for point_index: int in range(1, route_points.size()):
		var start: Vector2 = route_points[point_index - 1]
		var finish: Vector2 = route_points[point_index]
		_begin_validation_fuse_segment(start)
		var travel_tween: Tween = create_tween().set_parallel(true)
		travel_tween.tween_method(
			_set_validation_fuse_progress.bind(start, finish),
			0.0,
			1.0,
			segment_seconds
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		travel_tween.tween_property(
			_validation_light, ^"rotation", _validation_light.rotation + PI, segment_seconds
		)
		await travel_tween.finished
	_validation_light.position = target_position
	_validation_fuse_spark.position = target_center


func _fade_validation_light() -> void:
	if not _validation_light.visible:
		return
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_validation_light, ^"scale", Vector2(1.6, 1.6), 0.24)
	tween.tween_property(_validation_light, ^"modulate:a", 0.0, 0.24)
	await tween.finished
	_validation_light.hide()
	_validation_fuse_spark.emitting = false
	var fuse_fade: Tween = create_tween().set_parallel(true)
	fuse_fade.tween_property(_validation_fuse_trail, ^"modulate:a", 0.0, 0.22)
	fuse_fade.tween_property(_validation_fuse_glow, ^"modulate:a", 0.0, 0.22)
	await fuse_fade.finished


func _path_node_center(node: Control) -> Vector2:
	var authored_anchor := node.get_node_or_null("PathAnchor") as Node2D
	var global_center: Vector2 = (
		authored_anchor.get_global_transform_with_canvas().origin
		if authored_anchor != null
		else node.get_global_rect().get_center()
	)
	return _station_path_anchor.get_global_transform_with_canvas().affine_inverse() * global_center


func _begin_validation_fuse_segment(start: Vector2) -> void:
	if _validation_fuse_points.is_empty():
		_validation_fuse_points.append(start)
	elif _validation_fuse_points[-1].distance_to(start) > 0.5:
		_validation_fuse_points.append(start)
	_validation_fuse_points.append(start)
	_apply_validation_fuse_points()


func _set_validation_fuse_progress(value: float, start: Vector2, finish: Vector2) -> void:
	var center: Vector2 = start.lerp(finish, clampf(value, 0.0, 1.0))
	_validation_fuse_points[-1] = center
	_apply_validation_fuse_points()
	_validation_light.position = center - _validation_light.size * 0.5
	_validation_fuse_spark.position = center


func _apply_validation_fuse_points() -> void:
	_validation_fuse_trail.points = _validation_fuse_points
	_validation_fuse_glow.points = _validation_fuse_points
	_validation_fuse_trail.modulate.a = 1.0
	_validation_fuse_glow.modulate.a = 1.0


func _on_station_validation_impact(succeeded: bool) -> void:
	validation_impact_requested.emit(succeeded)
	if is_instance_valid(_map_impact_tween) and _map_impact_tween.is_valid():
		_map_impact_tween.kill()
	var base_position: Vector2 = _station_path_rest_position + station_path_focus_offset
	var strength: float = 7.0 if succeeded else 4.0
	_station_path_anchor.pivot_offset = station_path_focus_pivot
	_map_impact_tween = create_tween()
	for direction: Vector2 in [Vector2(-1.0, 0.25), Vector2(0.72, -0.38), Vector2(-0.35, 0.2)]:
		_map_impact_tween.tween_property(
			_station_path_anchor,
			^"position",
			base_position + direction * strength,
			0.04
		)
		_map_impact_tween.parallel().tween_property(
			_station_path_anchor,
			^"rotation",
			deg_to_rad(direction.x * strength * 0.08),
			0.04
		)
	_map_impact_tween.tween_property(_station_path_anchor, ^"position", base_position, 0.06)
	_map_impact_tween.parallel().tween_property(_station_path_anchor, ^"rotation", 0.0, 0.06)


func _get_validation_order() -> Array[NightStationTarget]:
	if not is_instance_valid(_station_path_layout):
		return []
	return _station_path_layout.get_validation_targets()


func _validation_chrome() -> Array[CanvasItem]:
	return [
		_instruction_label,
		_legend_label,
		_selection_label,
		_assignment_count_label,
		_confirm_button,
		_error_label,
		_close_button,
	]


func _reset_validation_presentation() -> void:
	if is_instance_valid(_focus_tween) and _focus_tween.is_valid():
		_focus_tween.kill()
	_ledger_anchor.position = _ledger_rest_position
	_ledger_anchor.modulate.a = 1.0
	_station_path_anchor.position = _station_path_rest_position
	_station_path_anchor.scale = Vector2.ONE
	_station_path_anchor.pivot_offset = station_path_focus_pivot
	for control: CanvasItem in _validation_chrome():
		control.modulate.a = 1.0
	_validation_light.hide()
	_validation_light.scale = Vector2.ONE
	_validation_light.modulate.a = 0.0
	_validation_fuse_points.clear()
	_validation_fuse_trail.clear_points()
	_validation_fuse_glow.clear_points()
	_validation_fuse_trail.modulate.a = 1.0
	_validation_fuse_glow.modulate.a = 1.0
	_validation_fuse_spark.emitting = false
	_validation_map_shade.modulate.a = 0.0
	for target: NightStationTarget in _station_targets:
		target.reset_validation_visual()


func _passengers_assigned_to(station_name: String) -> Array:
	var stored: Variant = _assignments.get(station_name, [])
	if stored is Array:
		return (stored as Array).duplicate()
	# Accept old in-memory/test manifests during the transition to stacked
	# assignments.
	var legacy_name: String = str(stored)
	return [] if legacy_name.is_empty() else [legacy_name]


func _assigned_passenger_count() -> int:
	var seen: Dictionary = {}
	for station_name: String in _assignments:
		for passenger_value: Variant in _passengers_assigned_to(station_name):
			seen[str(passenger_value)] = true
	return seen.size()


func _present_board() -> void:
	_board_anchor.pivot_offset = _board_anchor.size * 0.5
	_board_anchor.modulate.a = 0.0
	_board_anchor.scale = Vector2(0.97, 0.97)
	var tween: Tween = create_tween()
	tween.tween_property(_board_anchor, ^"modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(_board_anchor, ^"scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key_event := event as InputEventKey
	if key_event != null and key_event.echo:
		return
	if event.is_action_pressed(&"interact"):
		request_close()
		get_viewport().set_input_as_handled()
