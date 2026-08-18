class_name AfterTheEndGame
extends Node2D
## Owns the vertical-slice state and coordinates data, world presentation and UI.

enum GameState { OPENING, DAY, SUNSET, DEAD_SELECTION, SHIFT_REPORT, NIGHT, NIGHT_PUZZLE, COMPLETE }
enum NewspaperEditionMode { RANDOM, FORCE_RELEVANT, FORCE_UNRELATED }

@export_category("Data & Scenes")
@export var passenger_resources: Array[Resource] = []
@export var puzzle_resource: Resource
@export var passenger_scene: PackedScene
@export_category("Station Service")
@export_range(1, 8, 1) var unlisted_destination_penalty_units: int = 1
@export var incomplete_assignment_message: String = "Assign exactly %d passengers before operating the station door."
@export_category("Newspaper")
@export_enum("Random", "Force Relevant", "Force Unrelated") var newspaper_edition_mode: int = NewspaperEditionMode.RANDOM
@export_range(0.0, 1.0, 0.01) var newspaper_relevant_chance: float = 0.5

const MAX_ACTIVE_PASSENGERS: int = 10
const MAX_NIGHT_PASSENGERS: int = 4
const PAYCHECK_THRESHOLD: int = 180
const STARTING_MERIT: int = 10
const INSPECTION_MERIT: int = 4
const COAL_DUTY_MERIT: int = 15
const STATION_EXCHANGE_MERIT: int = 20
const CORRECT_NAME_MERIT: int = 12
const COMPLETE_MANIFEST_MERIT: int = 12
const WRONG_NAME_MERIT_PENALTY: int = 12
const WRONG_NAME_POINTS: int = 10
const MISSED_STOP_MERIT_PENALTY: int = 10
const MISSED_STOP_POINTS: int = 12
const LOW_COAL_MERIT_PENALTY: int = 10
const LOW_COAL_POINTS: int = 8
const STATION_BOARDING_COUNT: int = 2
const DAY_ROUTE: Array[String] = ["Alderwick", "Brambleford", "Cinderfield", "Dunmere", "Eastmere"]
const LEG_DEPARTURE_STATION: String = "Alderwick"
const ROUTE_DISPLAY: String = "Alderwick → Brambleford → Cinderfield → Dunmere → Eastmere"
const CARRIAGE_BASE_X: Dictionary = {
	1: 3840.0,
	2: 2880.0,
	3: 1920.0,
	4: 960.0,
}
const CARRIAGE_SLOT_X: Array[float] = [210.0, 460.0, 700.0]
const START_MINUTES: float = 14.0 * 60.0
const STATION_TRAVEL_SECONDS: float = 60.0
const SUNSET_MINUTES: float = 17.5 * 60.0
const FINAL_ARRIVAL_MINUTES: float = START_MINUTES + STATION_TRAVEL_SECONDS * 4.0
const COAL_LOW_THRESHOLD: float = 35.0

var state: GameState = GameState.OPENING
var _day_minutes: float = START_MINUTES
var _coal: float = 62.0
var _station_arrival_announced: bool = false
var _station_duty_done: bool = false
var _station_exchange_processed: bool = false
var _station_exchange_correct: bool = false
var _station_mistake_count: int = 0
var _current_station_mistake_count: int = 0
var _completed_station_exchanges: int = 0
var _station_assignment := PackedStringArray()
var _newspaper_read: bool = false
var _newspaper_has_relevant_name: bool = false
var _newspaper_document: String = ""
var _route_index: int = 0
var _passengers: Array[Passenger] = []
var _inspected_data: Array[PassengerData] = []
var _interactables: Array[Interactable] = []
var _rewarded_inspections: Dictionary = {}
var _rewarded_dead_names: Dictionary = {}
var _penalized_wrong_names: Dictionary = {}
var _coal_merit_awarded: bool = false
var _manifest_bonus_awarded: bool = false
var _shift_report_finalized: bool = false
var _merit: int = STARTING_MERIT
var _penalty_points: int = 0
var _service_points: int = 0
var _performance_log := PackedStringArray(["Starting shift Merit +%d" % STARTING_MERIT])
var _furnace: FurnaceInteractable
var _newspaper: NewspaperInteractable
var _desk: ConductorDeskInteractable
var _station_door: StationDoorInteractable
var _active_modal: Control
var _station_cutscene_context: StringName = &""

@onready var _train: TrainWorld = %Train
@onready var _player: ConductorPlayer = %Player
@onready var _passenger_container: Node2D = %Passengers
@onready var _hud: GameHUD = %HUD
@onready var _inspect_ui: PassengerInspectUI = %PassengerInspectUI
@onready var _notebook_ui: NotebookUI = %NotebookUI
@onready var _day_intro_ui: DayIntroUI = %DayIntroUI
@onready var _station_stop_ui: StationStopCutsceneUI = %StationStopCutsceneUI
@onready var _dead_selection_ui: DeadSelectionUI = %DeadSelectionUI
@onready var _shift_report_ui: ShiftReportUI = %ShiftReportUI
@onready var _night_puzzle_ui: NightPuzzleUI = %NightPuzzleUI
@onready var _sequence_ui: DepartureSequenceUI = %DepartureSequenceUI
@onready var _pause_ui: PauseUI = %PauseUI
@onready var _ambience: TrainAmbience = %TrainAmbience

func _ready() -> void:
	_spawn_initial_passengers()
	_prepare_newspaper_edition()
	_collect_interactables(self)
	_player.set_interactables(_interactables)
	_hud.set_clock(int(_day_minutes))
	_hud.set_coal(_coal)
	_update_performance_hud()
	_update_passenger_minimap()
	_refresh_objective()
	_station_door.set_station(_next_day_station())
	_set_passenger_ai_enabled(false)
	_active_modal = _day_intro_ui
	_day_intro_ui.play_intro(1, LEG_DEPARTURE_STATION)

func _process(delta: float) -> void:
	_set_passenger_ai_enabled(_active_modal == null and state in [GameState.DAY, GameState.SUNSET])
	_update_passenger_minimap()
	_update_carriage_indicator()
	if state != GameState.DAY and state != GameState.SUNSET:
		return
	if _active_modal != null:
		return

	if not _station_arrival_announced:
		_day_minutes = minf(_day_minutes + delta, _next_arrival_minutes())
	_coal = maxf(0.0, _coal - delta * 0.35)
	_hud.set_clock(int(_day_minutes))
	_hud.set_coal(_coal)
	var night_strength: float = clampf((_day_minutes - 990.0) / maxf(FINAL_ARRIVAL_MINUTES - 990.0, 1.0), 0.0, 1.0)
	_train.set_night_strength(night_strength)
	_ambience.night_strength = night_strength
	_refresh_objective()

	if not _station_arrival_announced and _has_next_day_station() and _day_minutes >= _next_arrival_minutes():
		_announce_next_station()

	if state == GameState.DAY and _day_minutes >= SUNSET_MINUTES:
		state = GameState.SUNSET
		_hud.notify("THE LAST LIGHT IS FADING", 3.0)


func _announce_next_station() -> void:
	if not _has_next_day_station() or _station_arrival_announced:
		return
	_station_arrival_announced = true
	_station_door.set_station(_next_day_station())
	_station_door.enabled = true
	_hud.notify("ARRIVING: %s\nExecute your assignment at the Passenger Car 4 door" % _next_day_station().to_upper(), 5.0)
	_refresh_objective()

func _has_next_day_station() -> bool:
	return _route_index < DAY_ROUTE.size() - 1

func _current_day_station() -> String:
	return DAY_ROUTE[clampi(_route_index, 0, DAY_ROUTE.size() - 1)]

func _next_day_station() -> String:
	return DAY_ROUTE[clampi(_route_index + 1, 0, DAY_ROUTE.size() - 1)]

func _next_arrival_minutes() -> float:
	return minf(START_MINUTES + float(_route_index + 1) * STATION_TRAVEL_SECONDS, FINAL_ARRIVAL_MINUTES)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"notebook"):
		if _notebook_ui.visible:
			_notebook_ui.request_close()
		elif _active_modal == null and state in [GameState.DAY, GameState.SUNSET, GameState.DEAD_SELECTION, GameState.NIGHT]:
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
	var used_slots: Dictionary = {}
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
		var slot: int = int(used_slots.get(carriage, 0))
		used_slots[carriage] = slot + 1
		_spawn_passenger(data, _position_for_carriage_slot(carriage, slot))
		if data.is_dead:
			dead_count += 1
	if _active_passenger_count() != MAX_ACTIVE_PASSENGERS:
		push_warning("The playable day roster should start with exactly ten passengers.")

func _prepare_newspaper_edition() -> void:
	var subject: PassengerData = _find_newspaper_subject()
	match newspaper_edition_mode:
		NewspaperEditionMode.FORCE_RELEVANT:
			_newspaper_has_relevant_name = subject != null
		NewspaperEditionMode.FORCE_UNRELATED:
			_newspaper_has_relevant_name = false
		_:
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			_newspaper_has_relevant_name = subject != null and rng.randf() < newspaper_relevant_chance
	_newspaper_document = _inspect_ui.compose_newspaper_document(subject if _newspaper_has_relevant_name else null)

func _find_newspaper_subject() -> PassengerData:
	for resource: Resource in passenger_resources:
		var data := resource as PassengerData
		if data != null and data.is_dead and data.anomaly_type == "newspaper_death":
			return data
	return null

func _spawn_passenger(data: PassengerData, spawn_position: Vector2) -> Passenger:
	var passenger := passenger_scene.instantiate() as Passenger
	passenger.name = data.short_name
	passenger.data = data
	passenger.position = spawn_position
	passenger.inspection_requested.connect(_on_passenger_inspection)
	_passenger_container.add_child(passenger)
	_passengers.append(passenger)
	return passenger

func _position_for_carriage_slot(carriage: int, slot: int) -> Vector2:
	var wrapped_slot: int = posmod(slot, CARRIAGE_SLOT_X.size())
	return Vector2(float(CARRIAGE_BASE_X.get(carriage, 3840.0)) + CARRIAGE_SLOT_X[wrapped_slot], 520.0)

func _collect_interactables(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Interactable:
			var interactable := child as Interactable
			_interactables.append(interactable)
			if interactable is FurnaceInteractable:
				_furnace = interactable as FurnaceInteractable
			elif interactable is NewspaperInteractable:
				_newspaper = interactable as NewspaperInteractable
			elif interactable is ConductorDeskInteractable:
				_desk = interactable as ConductorDeskInteractable
			elif interactable is StationDoorInteractable:
				_station_door = interactable as StationDoorInteractable
		_collect_interactables(child)

func _on_interaction_pressed(interactable: Interactable) -> void:
	if interactable is ConductorDeskInteractable:
		_on_desk_interacted()
	else:
		interactable.interact()

func _on_nearby_interactable_changed(interactable: Interactable) -> void:
	_hud.set_prompt(interactable.get_prompt() if interactable != null else "")

func _on_passenger_inspection(passenger: Passenger) -> void:
	if passenger.departed:
		return
	if not _inspected_data.has(passenger.data):
		_inspected_data.append(passenger.data)
	var inspection_key: String = passenger.data.passenger_name.to_lower()
	if not _rewarded_inspections.has(inspection_key):
		_rewarded_inspections[inspection_key] = true
		_change_performance(INSPECTION_MERIT, 0, "Passenger inspection +%d Merit" % INSPECTION_MERIT)
	_refresh_objective()
	_active_modal = _inspect_ui
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_inspect_ui.show_passenger(passenger.data)
	if state in [GameState.DAY, GameState.SUNSET] and _has_next_day_station() and not _station_exchange_processed:
		_inspect_ui.configure_station_assignment(_next_day_station(), _station_assignment.has(passenger.data.passenger_name), _station_assignment.size(), STATION_BOARDING_COUNT)

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
		if assignment_index < 0 and _station_assignment.size() >= STATION_BOARDING_COUNT:
			_inspect_ui.show_assignment_error("Only %d passengers can be assigned. Remove another assignment first." % STATION_BOARDING_COUNT)
			return
		if assignment_index < 0:
			_station_assignment.append(canonical_name)
	else:
		if assignment_index >= 0:
			_station_assignment.remove_at(assignment_index)
	var next_station: String = _next_day_station()
	_inspect_ui.configure_station_assignment(next_station, _station_assignment.has(canonical_name), _station_assignment.size(), STATION_BOARDING_COUNT)
	_hud.notify("%s\n%s FOR %s • %d / %d" % [canonical_name.to_upper(), "ASSIGNED" if should_assign else "REMOVED", next_station.to_upper(), _station_assignment.size(), STATION_BOARDING_COUNT], 2.0)
	_refresh_objective()

func _on_newspaper_read() -> void:
	_newspaper_read = true
	_active_modal = _inspect_ui
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_inspect_ui.show_newspaper(_newspaper_document)

func _on_coal_added(amount: float) -> void:
	_coal = minf(100.0, _coal + amount)
	_hud.set_coal(_coal)
	if not _coal_merit_awarded:
		_coal_merit_awarded = true
		_change_performance(COAL_DUTY_MERIT, 0, "Furnace duty +%d Merit" % COAL_DUTY_MERIT)
	_hud.notify("FURNACE FED — COAL %d%%" % int(_coal), 1.4)
	_refresh_objective()

func _on_station_door_activated() -> void:
	if _station_exchange_processed or not _station_arrival_announced or not _has_next_day_station():
		return
	if _station_assignment.size() != STATION_BOARDING_COUNT:
		_hud.notify(incomplete_assignment_message % STATION_BOARDING_COUNT, 3.0)
		return
	var arrival_station: String = _next_day_station()
	_station_exchange_processed = true
	_station_duty_done = true
	var expected_names: Dictionary = {}
	for passenger: Passenger in _passengers:
		if _is_active_passenger(passenger) and not passenger.data.is_dead and passenger.data.destination_station == arrival_station:
			expected_names[_normalize_name(passenger.data.passenger_name)] = true

	var departing: Array[Passenger] = []
	for assigned_name: String in _station_assignment:
		var assigned_passenger: Passenger = _find_active_passenger_by_name(assigned_name)
		# Deceased passengers cannot actually leave during daylight. They remain for night service.
		if assigned_passenger != null and not assigned_passenger.data.is_dead and not departing.has(assigned_passenger):
			departing.append(assigned_passenger)

	_current_station_mistake_count = _station_assignment.size() - departing.size()
	if _current_station_mistake_count > 0:
		_performance_log.append("%s: %d assigned passenger%s could not disembark" % [arrival_station, _current_station_mistake_count, "s" if _current_station_mistake_count != 1 else ""])

	var available_boarders: Array[PassengerData] = []
	for resource: Resource in passenger_resources:
		var data := resource as PassengerData
		if data != null and not data.initially_on_train and data.origin_station == arrival_station:
			available_boarders.append(data)

	var boarded: int = 0
	var departing_actors: Array[Dictionary] = []
	var boarding_actors: Array[Dictionary] = []
	for departing_passenger: Passenger in departing:
		var departure_carriage: int = departing_passenger.get_runtime_carriage()
		var boarder_index: int = _find_boarder_for_carriage(available_boarders, departure_carriage)
		if boarder_index < 0:
			break
		var boarder_data: PassengerData = available_boarders[boarder_index]
		available_boarders.remove_at(boarder_index)
		var vacated_position: Vector2 = departing_passenger.position
		departing_actors.append({
			"name": departing_passenger.data.passenger_name,
			"color": departing_passenger.data.body_color,
			"carriage": departure_carriage,
		})
		var distance_units: int = _station_distance_units(departing_passenger.data.destination_station, arrival_station)
		if distance_units > 0:
			_current_station_mistake_count += distance_units
			_performance_log.append("%s left at %s, %d stop%s from %s" % [departing_passenger.data.passenger_name, arrival_station, distance_units, "s" if distance_units != 1 else "", departing_passenger.data.destination_station])
		departing_passenger.depart_train()
		var boarder := _spawn_passenger(boarder_data, vacated_position)
		_interactables.append(boarder)
		boarding_actors.append({
			"name": boarder_data.passenger_name,
			"color": boarder_data.body_color,
			"carriage": boarder.get_runtime_carriage(),
		})
		boarded += 1

	if boarded != departing.size():
		_current_station_mistake_count += departing.size() - boarded
	_station_mistake_count += _current_station_mistake_count
	var departed_names: Dictionary = {}
	for departing_passenger: Passenger in departing:
		departed_names[_normalize_name(departing_passenger.data.passenger_name)] = true
	_station_exchange_correct = _current_station_mistake_count == 0 and departed_names == expected_names and boarded == departing.size() and _active_passenger_count() == MAX_ACTIVE_PASSENGERS
	if _station_exchange_correct:
		_change_performance(STATION_EXCHANGE_MERIT, 0, "%s exchange +%d Merit" % [arrival_station, STATION_EXCHANGE_MERIT])
	else:
		_performance_log.append("%s assignment flagged for transition review" % arrival_station)
	_player.set_interactables(_interactables)
	_refresh_objective()
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
	_train.show_exterior_body(StationStopCutsceneUI.STOP_DURATION, StationStopCutsceneUI.STOP_ARRIVAL_END, StationStopCutsceneUI.STOP_DEPARTURE_START)
	_station_stop_ui.play_stop(station_name, departing_actors, boarding_actors, _get_visible_train_door_positions())

func _on_day_intro_finished() -> void:
	if state != GameState.OPENING:
		return
	var boarding_actors: Array[Dictionary] = []
	for passenger: Passenger in _passengers:
		if _is_active_passenger(passenger) and passenger.data.origin_station == LEG_DEPARTURE_STATION:
			boarding_actors.append(_passenger_cutscene_actor(passenger))
	_station_cutscene_context = &"opening"
	_active_modal = _station_stop_ui
	_hud.set_cutscene_hidden(true)
	_train.show_exterior_body(StationStopCutsceneUI.OPENING_DURATION, 0.0, StationStopCutsceneUI.OPENING_DEPARTURE_START)
	_station_stop_ui.play_opening(LEG_DEPARTURE_STATION, boarding_actors, _get_visible_train_door_positions())

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
		_hud.notify("DEPARTING %s\nNEXT: %s • TRAVEL 01:00\nInspect passengers and assign %d exits" % [_current_day_station().to_upper(), _next_day_station().to_upper(), STATION_BOARDING_COUNT], 5.0)
		_update_passenger_minimap()
		_refresh_objective()
		_set_passenger_ai_enabled(true)
		_set_player_control_for_state()
		return
	var serviced_station: String = _next_day_station()
	_route_index += 1
	_completed_station_exchanges += 1
	if not _has_next_day_station():
		_update_passenger_minimap()
		_begin_dead_selection()
		return
	_station_assignment.clear()
	_station_arrival_announced = false
	_station_duty_done = false
	_station_exchange_processed = false
	_station_exchange_correct = false
	_current_station_mistake_count = 0
	_station_door.set_station(_next_day_station())
	if state in [GameState.DAY, GameState.SUNSET]:
		_hud.set_day_hud_visible(true)
	_hud.notify("DEPARTING %s\nNEXT: %s • TRAVEL 01:00\n%d / %d passengers aboard" % [serviced_station.to_upper(), _next_day_station().to_upper(), _active_passenger_count(), MAX_ACTIVE_PASSENGERS], 4.0)
	_update_passenger_minimap()
	_refresh_objective()
	_set_player_control_for_state()

func _passenger_cutscene_actor(passenger: Passenger) -> Dictionary:
	return {
		"name": passenger.data.passenger_name,
		"color": passenger.data.body_color,
		"carriage": passenger.get_runtime_carriage(),
	}

func _get_visible_train_door_positions() -> PackedVector2Array:
	var result := PackedVector2Array()
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
	var viewport_size: Vector2 = get_viewport_rect().size
	# Station passengers only use the four passenger cars, never the crew cab or coal car.
	for car_index: int in range(1, 5):
		for local_x: float in [80.0, 880.0]:
			var screen_position: Vector2 = canvas_transform * Vector2(car_index * 960.0 + local_x, 525.0)
			if screen_position.x >= 45.0 and screen_position.x <= viewport_size.x - 45.0:
				result.append(screen_position)
	if result.is_empty():
		result.append(Vector2(viewport_size.x * 0.34, viewport_size.y * 0.72))
		result.append(Vector2(viewport_size.x * 0.66, viewport_size.y * 0.72))
	return result

func _find_boarder_for_carriage(boarders: Array[PassengerData], carriage: int) -> int:
	# Preserve the mystery roster if a player mistakenly assigns a deceased passenger.
	for i: int in range(boarders.size()):
		if boarders[i].is_dead and boarders[i].current_carriage == carriage:
			return i
	for i: int in range(boarders.size()):
		if boarders[i].is_dead:
			return i
	for i: int in range(boarders.size()):
		if boarders[i].current_carriage == carriage:
			return i
	return 0 if not boarders.is_empty() else -1

func _station_distance_units(destination_station: String, actual_station: String) -> int:
	var destination_index: int = DAY_ROUTE.find(destination_station)
	var actual_index: int = DAY_ROUTE.find(actual_station)
	if destination_index < 0 or actual_index < 0:
		return unlisted_destination_penalty_units
	return absi(actual_index - destination_index)

func _on_desk_interacted() -> void:
	if state == GameState.NIGHT:
		_open_night_puzzle()
	elif state == GameState.DEAD_SELECTION:
		_open_dead_selection_tool()
	elif state in [GameState.DAY, GameState.SUNSET]:
		_hud.notify("DAY ROUTE\n%s\nCurrent: %s • Next: %s" % [ROUTE_DISPLAY, _current_day_station(), _next_day_station()], 4.0)

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

func _begin_dead_selection() -> void:
	if state in [GameState.OPENING, GameState.DEAD_SELECTION, GameState.SHIFT_REPORT, GameState.NIGHT, GameState.NIGHT_PUZZLE, GameState.COMPLETE]:
		return
	state = GameState.DEAD_SELECTION
	_train.set_night_strength(1.0)
	_ambience.night_strength = 1.0
	_desk.set_manifest_mode()
	_hud.set_night_walk_mode()
	_hud.set_objective("RETURN TO THE FRONT CREW CAB\n• File abnormal passenger names before paycheck review")
	_hud.set_prompt("")
	_hud.notify("DAY ROUTE COMPLETE\nRETURN TO THE CREW CAB AND FILE THE ABNORMAL PASSENGER REPORT", 5.0)
	_active_modal = null
	_set_player_control_for_state()

func _open_dead_selection_tool() -> void:
	if state != GameState.DEAD_SELECTION or _active_modal != null:
		return
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_active_modal = _dead_selection_ui
	_dead_selection_ui.open_selection(_get_active_passenger_data())

func _on_dead_selection_confirmed(selected_names: PackedStringArray) -> void:
	var expected_by_name: Dictionary = {}
	for data: PassengerData in _get_dead_passenger_data():
		expected_by_name[_normalize_name(data.passenger_name)] = data.short_name
		expected_by_name[_normalize_name(data.short_name)] = data.short_name

	var resolved_dead: Dictionary = {}
	var submitted_entries: Dictionary = {}
	var invalid_entry_found: bool = false
	var merit_before: int = _merit
	var penalty_before: int = _penalty_points
	for typed_name: String in selected_names:
		var normalized: String = _normalize_name(typed_name)
		if normalized.is_empty():
			continue
		if submitted_entries.has(normalized):
			invalid_entry_found = true
			_penalize_wrong_name("duplicate:%s" % normalized)
			continue
		submitted_entries[normalized] = true
		if expected_by_name.has(normalized):
			var canonical_name: String = str(expected_by_name[normalized])
			if resolved_dead.has(canonical_name):
				invalid_entry_found = true
				_penalize_wrong_name("duplicate-dead:%s" % canonical_name.to_lower())
				continue
			resolved_dead[canonical_name] = true
			if not _rewarded_dead_names.has(canonical_name):
				_rewarded_dead_names[canonical_name] = true
				_change_performance(CORRECT_NAME_MERIT, 0, "Verified identity +%d Merit" % CORRECT_NAME_MERIT)
		else:
			invalid_entry_found = true
			_penalize_wrong_name(normalized)

	var expected_count: int = _get_dead_passenger_data().size()
	var exact_manifest: bool = not invalid_entry_found and resolved_dead.size() == expected_count and submitted_entries.size() == expected_count
	if not exact_manifest:
		var merit_delta: int = _merit - merit_before
		var penalty_delta: int = _penalty_points - penalty_before
		_dead_selection_ui.show_error("Abnormal passenger report rejected. This attempt: %+d Merit, +%d Penalty. Correct entries are credited only once; no identities are revealed." % [merit_delta, penalty_delta])
		return

	if not _manifest_bonus_awarded:
		_manifest_bonus_awarded = true
		_change_performance(COMPLETE_MANIFEST_MERIT, 0, "Complete manifest +%d Merit" % COMPLETE_MANIFEST_MERIT)
	_dead_selection_ui.hide()
	_finalize_day_shift()

func _penalize_wrong_name(key: String) -> void:
	if _penalized_wrong_names.has(key):
		return
	_penalized_wrong_names[key] = true
	_change_performance(-WRONG_NAME_MERIT_PENALTY, WRONG_NAME_POINTS, "Incorrect manifest entry -%d Merit / +%d Penalty" % [WRONG_NAME_MERIT_PENALTY, WRONG_NAME_POINTS])

func _normalize_name(value: String) -> String:
	return " ".join(value.strip_edges().to_lower().split(" ", false))

func _finalize_day_shift() -> void:
	if _shift_report_finalized:
		return
	_shift_report_finalized = true
	_record_unresolved_day_passengers()
	if _station_mistake_count > 0:
		_apply_station_penalty(_station_mistake_count)
	if _coal < COAL_LOW_THRESHOLD:
		_change_performance(-LOW_COAL_MERIT_PENALTY, LOW_COAL_POINTS, "Low furnace at shift end -%d Merit / +%d Penalty" % [LOW_COAL_MERIT_PENALTY, LOW_COAL_POINTS])

	var threshold_met: bool = _merit >= PAYCHECK_THRESHOLD
	if threshold_met:
		_performance_log.append("Paycheck threshold cleared")
	else:
		_service_points += 1
		_performance_log.append("Paycheck threshold missed: SP +1")
	_update_performance_hud()
	state = GameState.SHIFT_REPORT
	_active_modal = _shift_report_ui
	_shift_report_ui.open_report(_merit, PAYCHECK_THRESHOLD, _penalty_points, _service_points, threshold_met, _performance_log)

func _record_unresolved_day_passengers() -> void:
	var current_station_index: int = clampi(_route_index, 0, DAY_ROUTE.size() - 1)
	for passenger: Passenger in _passengers:
		if not _is_active_passenger(passenger) or passenger.data.is_dead:
			continue
		var destination_index: int = DAY_ROUTE.find(passenger.data.destination_station)
		if destination_index < 0 or destination_index > current_station_index:
			continue
		var distance_units: int = maxi(1, current_station_index - destination_index)
		_station_mistake_count += distance_units
		_performance_log.append("%s remained aboard at %s, %d stop%s past %s" % [passenger.data.passenger_name, _current_day_station(), distance_units, "s" if distance_units != 1 else "", passenger.data.destination_station])

func _apply_station_penalty(distance_units: int) -> void:
	var units: int = maxi(1, distance_units)
	_change_performance(-MISSED_STOP_MERIT_PENALTY * units, MISSED_STOP_POINTS * units, "Wrong station handling (%d distance unit%s) -%d Merit / +%d Penalty" % [units, "s" if units != 1 else "", MISSED_STOP_MERIT_PENALTY * units, MISSED_STOP_POINTS * units])

func _on_shift_report_continue() -> void:
	if state != GameState.SHIFT_REPORT:
		return
	_shift_report_ui.hide()
	_active_modal = null
	_enter_night()

func _enter_night() -> void:
	state = GameState.NIGHT
	for passenger: Passenger in _passengers:
		if _is_active_passenger(passenger):
			passenger.set_night_mode(true)
	_desk.set_night_mode(true)
	_hud.set_night_walk_mode()
	_hud.set_objective("RETURN TO THE FRONT CREW CAB\n• Open the night drop-off ledger")
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

func _change_performance(merit_delta: int, penalty_delta: int, ledger_entry: String) -> void:
	_merit = maxi(0, _merit + merit_delta)
	_penalty_points = maxi(0, _penalty_points + penalty_delta)
	_performance_log.append(ledger_entry)
	_update_performance_hud()

func _update_performance_hud() -> void:
	_hud.set_performance(_merit, PAYCHECK_THRESHOLD, _penalty_points, _service_points)

func _set_player_control_for_state() -> void:
	var can_walk: bool = _active_modal == null and state in [GameState.DAY, GameState.SUNSET, GameState.DEAD_SELECTION, GameState.NIGHT]
	_player.movement_enabled = can_walk
	_player.interaction_enabled = can_walk

func _refresh_objective() -> void:
	if state not in [GameState.DAY, GameState.SUNSET]:
		return
	var lines := PackedStringArray(["• Inspect active passengers  %d / %d" % [_active_inspected_count(), _active_passenger_count()]])
	if _coal < COAL_LOW_THRESHOLD:
		lines.append("• REFILL THE FURNACE")
	else:
		lines.append("• Maintain furnace")
	if not _has_next_day_station():
		lines.append("✓ Day route complete at %s" % _current_day_station())
	elif not _station_arrival_announced:
		var next_station: String = _next_day_station()
		var seconds_remaining: int = maxi(0, int(ceil(_next_arrival_minutes() - _day_minutes)))
		if _station_assignment.size() == STATION_BOARDING_COUNT:
			lines.append("✓ %d exits assigned for %s" % [STATION_BOARDING_COUNT, next_station])
		else:
			lines.append("• Assign %d exits for %s [Inspect]" % [STATION_BOARDING_COUNT, next_station])
		lines.append("• Stop %d / %d: %s  %02d:%02d" % [_route_index + 1, DAY_ROUTE.size() - 1, next_station, seconds_remaining / 60, seconds_remaining % 60])
	elif not _station_duty_done:
		lines.append("• Execute assignment at %s door" % _next_day_station())
	elif _station_exchange_correct:
		lines.append("✓ %s service sealed" % _next_day_station())
	else:
		lines.append("• %s result sealed for transition" % _next_day_station())
	_hud.set_objective("\n".join(lines))

func _update_carriage_indicator() -> void:
	if not is_instance_valid(_player):
		return
	var carriage_index: int = clampi(int(_player.global_position.x / 960.0), 0, 5)
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

func _active_inspected_count() -> int:
	var count: int = 0
	for passenger: Passenger in _passengers:
		if _is_active_passenger(passenger) and _inspected_data.has(passenger.data):
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
