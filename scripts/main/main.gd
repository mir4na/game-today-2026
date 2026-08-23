class_name AfterTheEndGame
extends Node2D
## Owns the vertical-slice state and coordinates data, world presentation and UI.

enum GameState { OPENING, DAY, SUNSET, SHIFT_REPORT, NIGHT, NIGHT_PUZZLE, COMPLETE }
enum NewspaperEditionMode { RANDOM, FORCE_RELEVANT, FORCE_UNRELATED }

@export_category("Data & Scenes")
@export var passenger_resources: Array[Resource] = []
@export var puzzle_resource: Resource
@export var passenger_scene: PackedScene
@export_category("Day Route")
@export var day_route: PackedStringArray
@export_category("Station Service")
@export_range(1, 8, 1) var unlisted_destination_penalty_units: int = 1
@export_category("Newspaper")
@export_enum("Random", "Force Relevant", "Force Unrelated") var newspaper_edition_mode: int = NewspaperEditionMode.RANDOM
@export_range(0.0, 1.0, 0.01) var newspaper_relevant_chance: float = 0.5
@export_category("Anomaly Balance")
@export_range(1, 4, 1) var max_passengers_per_anomaly_trait: int = 2
@export_category("Debug")
@export var debug_print_anomaly_roster: bool = false

const MAX_ACTIVE_PASSENGERS: int = 10
const MAX_NIGHT_PASSENGERS: int = 4
const ABNORMAL_NOTE_PENALTY: int = 10
const WRONG_STOP_PENALTY: int = 12
const START_MINUTES: float = 14.0 * 60.0
const STATION_TRAVEL_SECONDS: float = 60.0
const SUNSET_MINUTES: float = 17.5 * 60.0
const FINAL_ARRIVAL_MINUTES: float = START_MINUTES + STATION_TRAVEL_SECONDS * 4.0

var state: GameState = GameState.OPENING
var _day_minutes: float = START_MINUTES
var _station_arrival_announced: bool = false
var _station_exchange_processed: bool = false
var _station_assignment := PackedStringArray()
var _newspaper_read: bool = false
var _newspaper_has_relevant_name: bool = false
var _newspaper_subject_name: String = ""
var _newspaper_document: String = ""
var _route_index: int = 0
var _passengers: Array[Passenger] = []
var _seat_occupant_by_slot: Dictionary = {}
var _seat_slot_by_passenger: Dictionary = {}
var _inspected_data: Array[PassengerData] = []
var _interactables: Array[Interactable] = []
var _penalized_wrong_names: Dictionary = {}
var _shift_report_finalized: bool = false
var _correct_drop_offs: int = 0
var _penalty_points: int = 0
var _penalty_log := PackedStringArray()
var _newspaper: NewspaperInteractable
var _desk: ConductorDeskInteractable
var _arrival_clock: Interactable
var _nearby_interactable: Interactable
var _active_modal: Control
var _station_cutscene_context: StringName = &""

@onready var _train: TrainWorld = %Train
@onready var _player: ConductorPlayer = %Player
@onready var _passenger_container: Node2D = %Passengers
@onready var _hud: GameHUD = %HUD
@onready var _inspect_ui: PassengerInspectUI = %PassengerInspectUI
@onready var _notebook_ui: NotebookUI = %NotebookUI
@onready var _arrival_clock_ui: Control = %ArrivalClockUI
@onready var _day_intro_ui: DayIntroUI = %DayIntroUI
@onready var _station_stop_ui: StationStopCutsceneUI = %StationStopCutsceneUI
@onready var _dead_selection_ui: DeadSelectionUI = %DeadSelectionUI
@onready var _shift_report_ui: ShiftReportUI = %ShiftReportUI
@onready var _night_puzzle_ui: NightPuzzleUI = %NightPuzzleUI
@onready var _sequence_ui: DepartureSequenceUI = %DepartureSequenceUI
@onready var _pause_ui: PauseUI = %PauseUI
@onready var _ambience: TrainAmbience = %TrainAmbience
@onready var _travel_foreground: TravelForeground = %TravelForeground
@onready var _night_sky_overlay: ColorRect = %NightSkyOverlay

func _ready() -> void:
	if day_route.size() < 2:
		push_error("Main/Day Route requires at least an opening and final station.")
		return
	_validate_passenger_resource_constraints()
	_spawn_initial_passengers()
	_prepare_newspaper_edition()
	_debug_print_configured_anomaly_roster()
	_debug_print_active_anomaly_roster("INITIAL BOARDING")
	_collect_interactables(self)
	_player.set_interactables(_interactables)
	_hud.set_clock(int(_day_minutes))
	_set_arrival_clock_display(int(_day_minutes))
	_update_passenger_minimap()
	_set_passenger_ai_enabled(false)
	_active_modal = _day_intro_ui
	_day_intro_ui.play_intro(1)

func _process(delta: float) -> void:
	_update_floating_interaction_prompt()
	_update_travel_foreground()
	_set_passenger_ai_enabled(_active_modal == null and state in [GameState.DAY, GameState.SUNSET])
	_update_passenger_minimap()
	_update_carriage_indicator()
	if state != GameState.DAY and state != GameState.SUNSET:
		return
	if _active_modal != null:
		return

	if not _station_arrival_announced:
		_day_minutes = minf(_day_minutes + delta, _next_arrival_minutes())
	_hud.set_clock(int(_day_minutes))
	_set_arrival_clock_display(int(_day_minutes))
	var night_strength: float = clampf((_day_minutes - 990.0) / maxf(FINAL_ARRIVAL_MINUTES - 990.0, 1.0), 0.0, 1.0)
	_train.set_night_strength(night_strength)
	_ambience.night_strength = night_strength
	_night_sky_overlay.modulate.a = night_strength

	if not _station_arrival_announced and _has_next_day_station() and _day_minutes >= _next_arrival_minutes():
		_announce_next_station()

	if state == GameState.DAY and _day_minutes >= SUNSET_MINUTES:
		state = GameState.SUNSET
		_hud.notify("THE LAST LIGHT IS FADING", 3.0)

func _update_travel_foreground() -> void:
	var is_traveling: bool = _active_modal == null and state in [GameState.DAY, GameState.SUNSET, GameState.NIGHT]
	if state in [GameState.DAY, GameState.SUNSET]:
		is_traveling = is_traveling and not _station_arrival_announced
	_travel_foreground.set_traveling(is_traveling)


func _announce_next_station() -> void:
	if not _has_next_day_station() or _station_arrival_announced:
		return
	_station_arrival_announced = true
	_process_station_arrival()

func _has_next_day_station() -> bool:
	return _route_index < day_route.size() - 1

func _current_day_station() -> String:
	return day_route[clampi(_route_index, 0, day_route.size() - 1)]

func _next_day_station() -> String:
	return day_route[clampi(_route_index + 1, 0, day_route.size() - 1)]

func _next_arrival_minutes() -> float:
	return minf(START_MINUTES + float(_route_index + 1) * STATION_TRAVEL_SECONDS, FINAL_ARRIVAL_MINUTES)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"notebook"):
		if _notebook_ui.visible:
			_notebook_ui.request_close()
		elif _active_modal == null and state in [GameState.DAY, GameState.SUNSET, GameState.NIGHT]:
			_open_notebook()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _day_intro_ui.visible:
		_day_intro_ui.skip_intro()
	elif _inspect_ui.visible:
		_inspect_ui.request_close()
	elif _notebook_ui.visible:
		_notebook_ui.request_close()
	elif _arrival_clock_ui.visible:
		_arrival_clock_ui.call(&"request_close")
	elif _station_stop_ui.visible:
		_station_stop_ui.skip_sequence()
	elif _dead_selection_ui.visible:
		_dead_selection_ui.request_close()
	elif _night_puzzle_ui.visible:
		_close_night_puzzle()
	elif _pause_ui.visible:
		_resume_from_pause()
	elif state not in [GameState.OPENING, GameState.SHIFT_REPORT, GameState.COMPLETE]:
		_open_pause()
	get_viewport().set_input_as_handled()

func _spawn_initial_passengers() -> void:
	var dead_count: int = 0
	for resource: Resource in passenger_resources:
		var data := resource as PassengerData
		if data == null or not data.initially_on_train:
			continue
		if _active_passenger_count() >= MAX_ACTIVE_PASSENGERS:
			push_warning("Passenger roster exceeds the ten-passenger capacity; extra entries were skipped.")
			break
		if data.is_dead and dead_count >= MAX_NIGHT_PASSENGERS:
			push_warning("Night roster exceeds four deceased passengers; %s was skipped." % data.passenger_name)
			continue
		var carriage: int = clampi(data.current_carriage, 1, 4)
		var seat_slot: Marker2D = _find_available_seat(carriage)
		if seat_slot == null:
			push_warning("No unoccupied passenger seat is available in carriage %d; %s was skipped." % [carriage, data.passenger_name])
			continue
		var passenger: Passenger = _spawn_passenger(data, seat_slot)
		if passenger == null:
			continue
		if data.is_dead:
			dead_count += 1
	if _active_passenger_count() != MAX_ACTIVE_PASSENGERS:
		push_warning("The playable day roster should start with exactly ten passengers.")
	_validate_active_passenger_constraints("initial boarding")

func _prepare_newspaper_edition() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var subject: PassengerData = _find_newspaper_subject(rng)
	match newspaper_edition_mode:
		NewspaperEditionMode.FORCE_RELEVANT:
			_newspaper_has_relevant_name = subject != null
		NewspaperEditionMode.FORCE_UNRELATED:
			_newspaper_has_relevant_name = false
		_:
			_newspaper_has_relevant_name = subject != null and rng.randf() < newspaper_relevant_chance
	_newspaper_subject_name = subject.passenger_name if _newspaper_has_relevant_name else ""
	_newspaper_document = _inspect_ui.compose_newspaper_document(subject if _newspaper_has_relevant_name else null)

func _find_newspaper_subject(rng: RandomNumberGenerator) -> PassengerData:
	var candidates: Array[PassengerData] = []
	for passenger: Passenger in _passengers:
		if _is_active_passenger(passenger) and passenger.data.is_dead and passenger.data.anomaly_type == "newspaper_death":
			candidates.append(passenger.data)
	if candidates.is_empty():
		return null
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func _spawn_passenger(data: PassengerData, seat_slot: Marker2D) -> Passenger:
	if seat_slot == null or not is_instance_valid(seat_slot):
		push_error("Passenger %s cannot spawn without a valid scene-authored seat." % data.passenger_name)
		return null
	var current_occupant := _seat_occupant_by_slot.get(seat_slot) as Passenger
	if _is_active_passenger(current_occupant):
		push_error("Seat %s is already occupied; %s was not spawned." % [seat_slot.name, data.passenger_name])
		return null
	if not _can_add_passenger_without_trait_overflow(data):
		push_warning("%s was skipped because an anomaly trait already has %d active passengers." % [data.passenger_name, max_passengers_per_anomaly_trait])
		return null
	var passenger := passenger_scene.instantiate() as Passenger
	if passenger == null:
		push_error("The configured passenger scene does not instantiate Passenger.")
		return null
	passenger.name = data.short_name
	passenger.data = data
	passenger.position = _passenger_container.to_local(seat_slot.global_position)
	passenger.inspection_requested.connect(_on_passenger_inspection)
	_passenger_container.add_child(passenger)
	_passengers.append(passenger)
	_seat_occupant_by_slot[seat_slot] = passenger
	_seat_slot_by_passenger[passenger] = seat_slot
	passenger.configure_seat_navigation(passenger.position, _get_passenger_activity_positions(), _get_passenger_carriage_ranges())
	return passenger

func _find_available_seat(carriage: int) -> Marker2D:
	for seat_slot: Marker2D in _train.get_passenger_seat_slots(carriage):
		var occupant := _seat_occupant_by_slot.get(seat_slot) as Passenger
		if not _is_active_passenger(occupant):
			_seat_occupant_by_slot.erase(seat_slot)
			return seat_slot
	return null

func _release_passenger_seat(passenger: Passenger) -> Marker2D:
	var seat_slot := _seat_slot_by_passenger.get(passenger) as Marker2D
	if seat_slot != null:
		_seat_occupant_by_slot.erase(seat_slot)
	_seat_slot_by_passenger.erase(passenger)
	return seat_slot

func _get_passenger_activity_positions() -> PackedVector2Array:
	var positions := PackedVector2Array()
	for activity_slot: Marker2D in _train.get_all_passenger_activity_slots():
		positions.append(_passenger_container.to_local(activity_slot.global_position))
	return positions

func _get_passenger_carriage_ranges() -> Dictionary:
	var result: Dictionary = {}
	var world_ranges: Dictionary = _train.get_passenger_carriage_world_ranges()
	for carriage_key: Variant in world_ranges:
		var world_range: Vector2 = world_ranges[carriage_key]
		var local_start: float = _passenger_container.to_local(Vector2(world_range.x, _passenger_container.global_position.y)).x
		var local_end: float = _passenger_container.to_local(Vector2(world_range.y, _passenger_container.global_position.y)).x
		result[carriage_key] = Vector2(local_start, local_end)
	return result

func _can_add_passenger_without_trait_overflow(data: PassengerData) -> bool:
	var trait_counts: Dictionary = _get_active_anomaly_trait_counts()
	for anomaly_key: StringName in data.get_anomaly_traits(day_route):
		if int(trait_counts.get(anomaly_key, 0)) >= max_passengers_per_anomaly_trait:
			return false
	return true

func _get_active_anomaly_trait_counts() -> Dictionary:
	var counts: Dictionary = {}
	for passenger: Passenger in _passengers:
		if not _is_active_passenger(passenger):
			continue
		for anomaly_key: StringName in passenger.data.get_anomaly_traits(day_route):
			counts[anomaly_key] = int(counts.get(anomaly_key, 0)) + 1
	return counts

func _validate_passenger_resource_constraints() -> void:
	var trait_counts: Dictionary = {}
	for resource: Resource in passenger_resources:
		var data := resource as PassengerData
		if data == null:
			continue
		for anomaly_key: StringName in data.get_anomaly_traits(day_route):
			trait_counts[anomaly_key] = int(trait_counts.get(anomaly_key, 0)) + 1
	for anomaly_key: StringName in trait_counts:
		var count: int = int(trait_counts[anomaly_key])
		if count > max_passengers_per_anomaly_trait:
			push_error("Passenger resources contain %d instances of anomaly trait '%s'; the configured maximum is %d." % [count, anomaly_key, max_passengers_per_anomaly_trait])

func _validate_active_passenger_constraints(context: String) -> void:
	var observed_seats: Dictionary = {}
	for passenger: Passenger in _passengers:
		if not _is_active_passenger(passenger):
			continue
		var seat_slot := _seat_slot_by_passenger.get(passenger) as Marker2D
		if seat_slot == null:
			push_error("%s: active passenger %s has no reserved seat." % [context, passenger.data.passenger_name])
			continue
		if observed_seats.has(seat_slot):
			push_error("%s: seat %s is occupied by more than one passenger." % [context, seat_slot.name])
		observed_seats[seat_slot] = passenger
	var trait_counts: Dictionary = _get_active_anomaly_trait_counts()
	for anomaly_key: StringName in trait_counts:
		var count: int = int(trait_counts[anomaly_key])
		if count > max_passengers_per_anomaly_trait:
			push_error("%s: anomaly trait '%s' is used by %d active passengers." % [context, anomaly_key, count])

func _debug_print_configured_anomaly_roster() -> void:
	if not debug_print_anomaly_roster:
		return
	var anomaly_rows := PackedStringArray()
	for resource: Resource in passenger_resources:
		var data := resource as PassengerData
		if data == null:
			continue
		var traits: Array[StringName] = data.get_anomaly_traits(day_route)
		if traits.is_empty() and not data.is_dead:
			continue
		anomaly_rows.append(_format_anomaly_debug_row(data, traits))
	print("\n========== ANOMALY DEBUG: CONFIGURED DAY ROSTER (%d) ==========" % anomaly_rows.size())
	for debug_line: String in anomaly_rows:
		print(debug_line)
	var newspaper_status: String = "RELEVANT: %s" % _newspaper_subject_name if _newspaper_has_relevant_name else "UNRELATED EDITION"
	print("[NEWSPAPER] %s" % newspaper_status)
	print("===============================================================\n")

func _debug_print_active_anomaly_roster(context: String) -> void:
	if not debug_print_anomaly_roster:
		return
	var anomaly_rows := PackedStringArray()
	for passenger: Passenger in _passengers:
		if not _is_active_passenger(passenger):
			continue
		var data: PassengerData = passenger.data
		var traits: Array[StringName] = data.get_anomaly_traits(day_route)
		if traits.is_empty() and not data.is_dead:
			continue
		anomaly_rows.append(_format_anomaly_debug_row(data, traits))
	print("[ANOMALY DEBUG] ACTIVE AFTER %s (%d)" % [context, anomaly_rows.size()])
	if anomaly_rows.is_empty():
		print("  - NONE")
		return
	for debug_line: String in anomaly_rows:
		print(debug_line)

func _format_anomaly_debug_row(data: PassengerData, traits: Array[StringName]) -> String:
	var trait_names := PackedStringArray()
	for anomaly_trait: StringName in traits:
		trait_names.append(String(anomaly_trait))
	return "  - %s | traits=%s | deceased=%s | route=%s -> %s | coach=%d | boards=%s" % [
		data.passenger_name,
		", ".join(trait_names),
		str(data.is_dead),
		data.origin_station,
		data.destination_station,
		data.current_carriage,
		"DAY START" if data.initially_on_train else data.origin_station,
	]

func _collect_interactables(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Interactable:
			var interactable := child as Interactable
			_interactables.append(interactable)
			if interactable is NewspaperInteractable:
				_newspaper = interactable as NewspaperInteractable
			elif interactable is ConductorDeskInteractable:
				_desk = interactable as ConductorDeskInteractable
			elif interactable.has_signal(&"clock_read"):
				_arrival_clock = interactable
		_collect_interactables(child)

func _set_arrival_clock_display(total_minutes: int) -> void:
	if is_instance_valid(_arrival_clock):
		_arrival_clock.call(&"set_clock", total_minutes)

func _on_interaction_pressed(interactable: Interactable) -> void:
	if interactable is ConductorDeskInteractable:
		_on_desk_interacted()
	else:
		interactable.interact()

func _on_nearby_interactable_changed(interactable: Interactable) -> void:
	_nearby_interactable = interactable
	_hud.set_prompt(interactable.get_prompt() if interactable != null else "")
	_update_floating_interaction_prompt()

func _update_floating_interaction_prompt() -> void:
	if not is_instance_valid(_nearby_interactable):
		return
	var target_world_position: Vector2 = _player.get_interaction_prompt_global_position()
	var target_screen_position: Vector2 = get_viewport().get_canvas_transform() * target_world_position
	_hud.set_prompt_target_screen_position(target_screen_position)

func _on_passenger_inspection(passenger: Passenger) -> void:
	if passenger.departed:
		return
	if not _inspected_data.has(passenger.data):
		_inspected_data.append(passenger.data)
	_active_modal = _inspect_ui
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_inspect_ui.show_passenger(passenger.data)
	if state in [GameState.DAY, GameState.SUNSET] and _has_next_day_station() and not _station_exchange_processed:
		_inspect_ui.configure_station_assignment(_next_day_station(), _station_assignment.has(passenger.data.passenger_name), _station_assignment.size())

func _on_station_assignment_toggled(passenger_name: String, should_assign: bool) -> void:
	if state not in [GameState.DAY, GameState.SUNSET] or not _has_next_day_station() or _station_exchange_processed:
		_inspect_ui.show_assignment_error("The current station service record is already sealed.")
		return
	var passenger: Passenger = _find_active_passenger_by_name(passenger_name)
	if passenger == null:
		_inspect_ui.show_assignment_error("This passenger is no longer aboard.")
		return
	var canonical_name: String = passenger.data.passenger_name
	var assignment_index: int = _station_assignment.find(canonical_name)
	if should_assign:
		if assignment_index < 0:
			_station_assignment.append(canonical_name)
	else:
		if assignment_index >= 0:
			_station_assignment.remove_at(assignment_index)
	var next_station: String = _next_day_station()
	_inspect_ui.configure_station_assignment(next_station, _station_assignment.has(canonical_name), _station_assignment.size())
	_hud.notify("%s\n%s FOR %s • %d SELECTED" % [canonical_name.to_upper(), "ASSIGNED" if should_assign else "REMOVED", next_station.to_upper(), _station_assignment.size()], 2.0)

func _on_newspaper_read() -> void:
	_newspaper_read = true
	_active_modal = _inspect_ui
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_inspect_ui.show_newspaper(_newspaper_document)

func _on_arrival_clock_read() -> void:
	if _active_modal != null:
		return
	var route_active: bool = state in [GameState.DAY, GameState.SUNSET] and _has_next_day_station()
	var arrival_minutes: int = int(_next_arrival_minutes()) if route_active else int(_day_minutes)
	var remaining_seconds: int = maxi(0, int(ceil(float(arrival_minutes) - _day_minutes))) if route_active else 0
	_active_modal = _arrival_clock_ui
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_arrival_clock_ui.call(
		&"open_schedule",
		_current_day_station(),
		_next_day_station() if route_active else "",
		int(_day_minutes),
		arrival_minutes,
		remaining_seconds,
		route_active
	)

func _process_station_arrival() -> void:
	if _station_exchange_processed or not _station_arrival_announced or not _has_next_day_station():
		return
	var arrival_station: String = _next_day_station()
	var is_terminal_arrival: bool = _route_index == day_route.size() - 2
	_station_exchange_processed = true

	var departing: Array[Passenger] = []
	if is_terminal_arrival:
		# Eastmere ends daylight service: every living passenger leaves automatically.
		for passenger: Passenger in _passengers:
			if _is_active_passenger(passenger) and not passenger.data.is_dead:
				departing.append(passenger)
	else:
		for assigned_name: String in _station_assignment:
			var assigned_passenger: Passenger = _find_active_passenger_by_name(assigned_name)
			# Deceased passengers cannot actually leave during daylight. They remain for night service.
			if assigned_passenger != null and not assigned_passenger.data.is_dead and not departing.has(assigned_passenger):
				departing.append(assigned_passenger)

	var invalid_assignment_count: int = 0 if is_terminal_arrival else _station_assignment.size() - departing.size()
	if invalid_assignment_count > 0:
		_add_penalty(
			WRONG_STOP_PENALTY * invalid_assignment_count,
			"%s: %d invalid drop-off assignment%s" % [arrival_station, invalid_assignment_count, "s" if invalid_assignment_count != 1 else ""]
		)

	var available_boarders: Array[PassengerData] = []
	if not is_terminal_arrival:
		for resource: Resource in passenger_resources:
			var data := resource as PassengerData
			if data != null and not data.initially_on_train and data.origin_station == arrival_station:
				available_boarders.append(data)

	var boarded: int = 0
	var departing_actors: Array[Dictionary] = []
	var boarding_actors: Array[Dictionary] = []
	for departing_passenger: Passenger in departing:
		var departure_carriage: int = departing_passenger.get_runtime_carriage()
		var vacated_seat: Marker2D = _release_passenger_seat(departing_passenger)
		departing_actors.append({
			"name": departing_passenger.data.passenger_name,
			"color": departing_passenger.data.body_color,
			"carriage": departure_carriage,
		})
		var distance_units: int = _station_distance_units(departing_passenger.data.destination_station, arrival_station)
		if distance_units == 0:
			_correct_drop_offs += 1
		else:
			_add_penalty(
				WRONG_STOP_PENALTY * distance_units,
				"%s left at %s, %d stop%s from %s" % [departing_passenger.data.passenger_name, arrival_station, distance_units, "s" if distance_units != 1 else "", departing_passenger.data.destination_station]
			)
		departing_passenger.depart_train()
		if is_terminal_arrival:
			continue
		if vacated_seat == null:
			vacated_seat = _find_available_seat(departure_carriage)
		var boarder_index: int = _find_boarder_for_carriage(available_boarders, departure_carriage)
		if boarder_index < 0:
			continue
		var boarder_data: PassengerData = available_boarders[boarder_index]
		available_boarders.remove_at(boarder_index)
		var boarder: Passenger = _spawn_passenger(boarder_data, vacated_seat)
		if boarder == null:
			continue
		_interactables.append(boarder)
		boarding_actors.append({
			"name": boarder_data.passenger_name,
			"color": boarder_data.body_color,
			"carriage": boarder.get_runtime_carriage(),
		})
		boarded += 1

	if not is_terminal_arrival and boarded < departing.size():
		var boarding_shortfall: int = departing.size() - boarded
		_add_penalty(
			WRONG_STOP_PENALTY * boarding_shortfall,
			"%s: %d replacement passenger%s could not board" % [arrival_station, boarding_shortfall, "s" if boarding_shortfall != 1 else ""]
		)
	_validate_active_passenger_constraints("%s station exchange" % arrival_station)
	_debug_print_active_anomaly_roster("%s STATION EXCHANGE" % arrival_station.to_upper())
	_player.set_interactables(_interactables)
	_start_station_stop_cutscene(arrival_station, departing_actors, boarding_actors)

func _start_station_stop_cutscene(station_name: String, departing_actors: Array[Dictionary], boarding_actors: Array[Dictionary]) -> void:
	_station_cutscene_context = &"station_exchange"
	_active_modal = _station_stop_ui
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_hud.set_day_hud_visible(false)
	_hud.set_cutscene_hidden(true)
	_set_passenger_ai_enabled(false)
	_player.begin_station_cutscene_camera()
	_train.show_exterior_body(StationStopCutsceneUI.STOP_DURATION, StationStopCutsceneUI.STOP_ARRIVAL_END, StationStopCutsceneUI.STOP_DEPARTURE_START)
	_station_stop_ui.play_stop(station_name, departing_actors, boarding_actors, _train.get_passenger_door_markers())

func _on_day_intro_finished() -> void:
	if state != GameState.OPENING:
		return
	var boarding_actors: Array[Dictionary] = []
	for passenger: Passenger in _passengers:
		if _is_active_passenger(passenger) and passenger.data.origin_station == day_route[0]:
			boarding_actors.append(_passenger_cutscene_actor(passenger))
	_station_cutscene_context = &"opening"
	_active_modal = _station_stop_ui
	_hud.set_cutscene_hidden(true)
	_player.begin_station_cutscene_camera()
	_train.show_exterior_body(StationStopCutsceneUI.OPENING_DURATION, 0.0, StationStopCutsceneUI.OPENING_DEPARTURE_START)
	_station_stop_ui.play_opening(day_route[0], boarding_actors, _train.get_passenger_door_markers())

func _on_station_cutscene_timeline_changed(elapsed: float) -> void:
	_train.set_exterior_sequence_elapsed(elapsed)

func _on_station_cutscene_camera_return_started() -> void:
	_player.begin_gameplay_camera_return()

func _on_station_stop_finished() -> void:
	var finished_context: StringName = _station_cutscene_context
	_station_cutscene_context = &""
	_train.hide_exterior_body()
	_hud.set_cutscene_hidden(false)
	if _active_modal == _station_stop_ui:
		_active_modal = null
	if finished_context == &"opening":
		state = GameState.DAY
		_hud.set_day_hud_visible(true)
		_hud.notify("DEPARTING %s\nNEXT: %s • TRAVEL 01:00\nInspect passengers and assign departures" % [_current_day_station().to_upper(), _next_day_station().to_upper()], 5.0)
		_update_passenger_minimap()
		_set_passenger_ai_enabled(true)
		_set_player_control_for_state()
		return
	var serviced_station: String = _next_day_station()
	_route_index += 1
	if not _has_next_day_station():
		_update_passenger_minimap()
		_auto_submit_abnormal_notes()
		return
	_station_assignment.clear()
	_station_arrival_announced = false
	_station_exchange_processed = false
	if state in [GameState.DAY, GameState.SUNSET]:
		_hud.set_day_hud_visible(true)
	_hud.notify("DEPARTING %s\nNEXT: %s • TRAVEL 01:00\n%d / %d passengers aboard" % [serviced_station.to_upper(), _next_day_station().to_upper(), _active_passenger_count(), MAX_ACTIVE_PASSENGERS], 4.0)
	_update_passenger_minimap()
	_set_player_control_for_state()

func _passenger_cutscene_actor(passenger: Passenger) -> Dictionary:
	return {
		"name": passenger.data.passenger_name,
		"color": passenger.data.body_color,
		"carriage": passenger.get_runtime_carriage(),
	}

func _find_boarder_for_carriage(boarders: Array[PassengerData], carriage: int) -> int:
	# Preserve the mystery roster if a player mistakenly assigns a deceased passenger.
	for i: int in range(boarders.size()):
		if boarders[i].is_dead and boarders[i].current_carriage == carriage and _can_add_passenger_without_trait_overflow(boarders[i]):
			return i
	for i: int in range(boarders.size()):
		if boarders[i].is_dead and _can_add_passenger_without_trait_overflow(boarders[i]):
			return i
	for i: int in range(boarders.size()):
		if boarders[i].current_carriage == carriage and _can_add_passenger_without_trait_overflow(boarders[i]):
			return i
	for i: int in range(boarders.size()):
		if _can_add_passenger_without_trait_overflow(boarders[i]):
			return i
	return -1

func _station_distance_units(destination_station: String, actual_station: String) -> int:
	var destination_index: int = day_route.find(destination_station)
	var actual_index: int = day_route.find(actual_station)
	if destination_index < 0 or actual_index < 0:
		return unlisted_destination_penalty_units
	return absi(actual_index - destination_index)

func _on_desk_interacted() -> void:
	if state == GameState.NIGHT:
		_open_night_puzzle()
	elif state in [GameState.DAY, GameState.SUNSET]:
		_open_abnormal_notes()

func _open_notebook() -> void:
	_active_modal = _notebook_ui
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_notebook_ui.open_notebook(_inspected_data, _newspaper_document if _newspaper_read else "", _route_index)

func _on_modal_closed() -> void:
	_active_modal = null
	_set_player_control_for_state()

func _open_pause() -> void:
	_active_modal = _pause_ui
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_pause_ui.open_pause()

func _resume_from_pause() -> void:
	_pause_ui.hide()
	_active_modal = null
	_set_player_control_for_state()

func _open_abnormal_notes() -> void:
	if _active_modal != null:
		return
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_active_modal = _dead_selection_ui
	_dead_selection_ui.open_notes(_get_active_passenger_data())

func _auto_submit_abnormal_notes() -> void:
	var selected_names: PackedStringArray = _dead_selection_ui.get_typed_names()
	var expected_by_name: Dictionary = {}
	var expected_canonical_names: Dictionary = {}
	for data: PassengerData in _get_dead_passenger_data():
		expected_by_name[_normalize_name(data.passenger_name)] = data.short_name
		expected_by_name[_normalize_name(data.short_name)] = data.short_name
		expected_canonical_names[data.short_name] = true

	var resolved_dead: Dictionary = {}
	var submitted_entries: Dictionary = {}
	for typed_name: String in selected_names:
		var normalized: String = _normalize_name(typed_name)
		if normalized.is_empty():
			continue
		if submitted_entries.has(normalized):
			_penalize_wrong_name("duplicate:%s" % normalized, "Duplicate abnormal note")
			continue
		submitted_entries[normalized] = true
		if expected_by_name.has(normalized):
			var canonical_name: String = str(expected_by_name[normalized])
			if resolved_dead.has(canonical_name):
				_penalize_wrong_name("duplicate-dead:%s" % canonical_name.to_lower(), "Duplicate deceased identity in abnormal notes")
				continue
			resolved_dead[canonical_name] = true
		else:
			_penalize_wrong_name(normalized, "Incorrect abnormal passenger name")

	for canonical_name: String in expected_canonical_names:
		if not resolved_dead.has(canonical_name):
			_penalize_missed_name(canonical_name)

	_dead_selection_ui.hide()
	_finalize_day_shift()

func _penalize_wrong_name(key: String, reason: String) -> void:
	if _penalized_wrong_names.has(key):
		return
	_penalized_wrong_names[key] = true
	_add_penalty(ABNORMAL_NOTE_PENALTY, reason)

func _penalize_missed_name(canonical_name: String) -> void:
	var key: String = "missed:%s" % canonical_name.to_lower()
	if _penalized_wrong_names.has(key):
		return
	_penalized_wrong_names[key] = true
	_add_penalty(ABNORMAL_NOTE_PENALTY, "Missed deceased identity in abnormal notes")

func _normalize_name(value: String) -> String:
	return " ".join(value.strip_edges().to_lower().split(" ", false))

func _finalize_day_shift() -> void:
	if _shift_report_finalized:
		return
	_shift_report_finalized = true
	state = GameState.SHIFT_REPORT
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_hud.set_day_hud_visible(false)
	_active_modal = _shift_report_ui
	_shift_report_ui.open_report(_correct_drop_offs, _penalty_points, _penalty_log)

func _on_shift_report_continue() -> void:
	if state != GameState.SHIFT_REPORT:
		return
	_shift_report_ui.hide()
	_active_modal = null
	_enter_night()

func _enter_night() -> void:
	state = GameState.NIGHT
	_train.set_night_strength(1.0)
	_ambience.night_strength = 1.0
	_night_sky_overlay.modulate.a = 1.0
	for passenger: Passenger in _passengers:
		if _is_active_passenger(passenger):
			passenger.set_night_mode(true)
	_desk.set_night_mode(true)
	_hud.set_night_walk_mode()
	_hud.notify("NIGHT SHIFT\nRETURN TO THE FRONT CREW CAB", 4.0)
	_set_player_control_for_state()

func _open_night_puzzle() -> void:
	state = GameState.NIGHT_PUZZLE
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_active_modal = _night_puzzle_ui
	_night_puzzle_ui.open_puzzle(_get_dead_passenger_data(), puzzle_resource as DeparturePuzzleData)

func _close_night_puzzle() -> void:
	_night_puzzle_ui.hide()
	_active_modal = null
	state = GameState.NIGHT
	_set_player_control_for_state()

func _on_departures_confirmed(assignments: Dictionary) -> void:
	var puzzle := puzzle_resource as DeparturePuzzleData
	for station: String in puzzle.night_stations:
		if assignments.get(station, "") != puzzle.correct_passenger_by_station.get(station, ""):
			_night_puzzle_ui.show_error("Something is wrong with the night drop-off assignments.")
			return
	_night_puzzle_ui.hide()
	_active_modal = _sequence_ui
	state = GameState.COMPLETE
	_sequence_ui.start_sequence(assignments, puzzle)

func _add_penalty(points: int, reason: String) -> void:
	var applied_points: int = maxi(0, points)
	if applied_points == 0:
		return
	_penalty_points += applied_points
	_penalty_log.append("%s  (+%d)" % [reason, applied_points])

func _set_player_control_for_state() -> void:
	var can_walk: bool = _active_modal == null and state in [GameState.DAY, GameState.SUNSET, GameState.NIGHT]
	_player.movement_enabled = can_walk
	_player.interaction_enabled = can_walk
	_hud.set_prompt(_nearby_interactable.get_prompt() if can_walk and is_instance_valid(_nearby_interactable) else "")

func _update_carriage_indicator() -> void:
	if not is_instance_valid(_player):
		return
	var carriage_index: int = _train.get_carriage_index_at_world_x(_player.global_position.x)
	_hud.set_current_carriage(carriage_index)

func _update_passenger_minimap() -> void:
	var counts := PackedInt32Array([0, 0, 0, 0, 0, 0])
	for passenger: Passenger in _passengers:
		if not _is_active_passenger(passenger):
			continue
		var minimap_index: int = clampi(5 - passenger.get_runtime_carriage(), 1, 4)
		counts[minimap_index] += 1
	_hud.set_passenger_counts(counts)

func _set_passenger_ai_enabled(value: bool) -> void:
	for passenger: Passenger in _passengers:
		passenger.set_ai_enabled(value)

func _is_active_passenger(passenger: Passenger) -> bool:
	return is_instance_valid(passenger) and not passenger.departed

func _find_active_passenger_by_name(passenger_name: String) -> Passenger:
	var normalized: String = _normalize_name(passenger_name)
	for passenger: Passenger in _passengers:
		if not _is_active_passenger(passenger):
			continue
		if normalized in [_normalize_name(passenger.data.passenger_name), _normalize_name(passenger.data.short_name)]:
			return passenger
	return null

func _active_passenger_count() -> int:
	var count: int = 0
	for passenger: Passenger in _passengers:
		if _is_active_passenger(passenger):
			count += 1
	return count

func _get_active_passenger_data() -> Array[PassengerData]:
	var result: Array[PassengerData] = []
	for passenger: Passenger in _passengers:
		if _is_active_passenger(passenger):
			result.append(passenger.data)
	return result

func _get_dead_passenger_data() -> Array[PassengerData]:
	var result: Array[PassengerData] = []
	for passenger: Passenger in _passengers:
		if _is_active_passenger(passenger) and passenger.data.is_dead and result.size() < MAX_NIGHT_PASSENGERS:
			result.append(passenger.data)
	return result

func _restart_game() -> void:
	get_tree().reload_current_scene()

func _return_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
