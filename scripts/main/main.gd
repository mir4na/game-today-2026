class_name AfterTheEndGame
extends Node2D
## Owns the vertical-slice state and coordinates data, world presentation and UI.

enum GameState { OPENING, DAY, SUNSET, SHIFT_REPORT, NIGHT_TRANSITION, MARKET, NIGHT, NIGHT_PUZZLE, COMPLETE }
enum NewspaperCase { NON_DEATH_NEWS, MATCHING_PASSENGER_DEATH }
enum NewspaperEditionMode { RANDOM, FORCE_NON_DEATH, FORCE_DEATH }

@export_category("Data & Scenes")
@export var passenger_identity_profiles: Array[PassengerIdentityProfile] = []
@export var puzzle_resource: Resource
@export var passenger_scene: PackedScene
@export var manifest_config: DailyManifestConfig
@export_category("Day Progression")
@export_range(1, 5, 1) var day_number: int = 1
@export var day_pass_targets: PackedInt32Array = PackedInt32Array([300, 350, 400, 450, 500])
@export_category("Day Route")
@export var day_route: PackedStringArray
@export_category("Station Service")
## Travel time per route leg, excluding station cutscenes and pauses.
@export var station_travel_durations_seconds: PackedFloat32Array = PackedFloat32Array([120.0, 120.0, 120.0, 120.0])
@export_range(0, 8, 1) var station_sign_blocked_carriage: int = 1
@export_category("Bloom")
@export_range(0.0, 1.5, 0.01) var morning_bloom_intensity: float = 0.11
@export_range(0.0, 1.5, 0.01) var sunset_bloom_intensity: float = 0.27
@export_range(0.0, 1.5, 0.01) var night_bloom_intensity: float = 0.34
@export_category("Passenger Placement")
@export_range(120.0, 240.0, 5.0) var minimum_passenger_seat_spacing: float = 120.0
@export_category("Maintenance Distractions")
@export var blocked_aisle_delay_range_seconds: Vector2 = Vector2(9.0, 16.0)
@export var dirty_seat_delay_range_seconds: Vector2 = Vector2(24.0, 38.0)
@export_range(0.1, 120.0, 0.5) var level_two_blocked_first_delay_seconds: float = 10.0
@export_range(0.1, 180.0, 0.5) var level_two_blocked_repeat_delay_seconds: float = 50.0
@export_range(0.1, 120.0, 0.5) var level_three_clean_first_delay_seconds: float = 10.0
@export_range(0.1, 180.0, 0.5) var level_three_clean_second_delay_seconds: float = 60.0
@export_range(0.0, 60.0, 0.5) var clean_seat_route_edge_clearance_seconds: float = 20.0
@export_range(0.0, 80.0, 1.0) var maintenance_event_clearance: float = 14.0
@export_multiline var dirty_seat_passenger_blocked_text: String = "Please clean the dirty seat before checking my ticket."
@export_category("Market Tools")
@export_range(0.25, 5.0, 0.05) var radar_scan_seconds: float = 1.6
@export_range(0.1, 5.0, 0.05) var radar_result_reveal_seconds: float = 1.25
@export_range(1.0, 30.0, 0.5) var radar_anomaly_light_seconds: float = 4.0
@export_category("Night Service")
## Maximum active service time before the departure-assignment ledger opens.
@export_range(30.0, 600.0, 5.0) var night_service_duration_seconds: float = 180.0
@export_category("Newspaper")
@export_enum("Random", "Force Non-Death", "Force Death") var newspaper_edition_mode: int = NewspaperEditionMode.RANDOM
@export_category("Debug")
@export var debug_print_anomaly_roster: bool = false
@export_category("Inspector Copy")
@export_multiline var night_shift_instruction: String
@export_category("Night Statement Dialogue")
@export var missing_night_statement_text: String = "I have nothing left to tell you."
@export_range(0.1, 1.0, 0.05) var night_record_camera_shift_seconds: float = 0.35

const ShiftProgress = preload("res://scripts/systems/shift_progress.gd")
const START_MINUTES: float = 14.0 * 60.0
const DAY_SERVICE_FINAL_CYCLE_PROGRESS: float = 1.0
const SUNSET_STATE_PROGRESS: float = 0.62
const SERVICE_NIGHT_START_PROGRESS: float = 0.70
const SERVICE_FULL_NIGHT_PROGRESS: float = 0.98
const BLOOM_SUNSET_BLEND_START_PROGRESS: float = 0.38
const TOOL_VEIL_NOTE: StringName = &"veil_note"
const TOOL_RADAR_CHARGE: StringName = &"radar_charge"
const TOOL_SWIFTSTEP: StringName = &"swiftstep"

var state: GameState = GameState.OPENING
var _day_minutes: float = START_MINUTES
var _station_arrival_announced: bool = false
var _station_exchange_processed: bool = false
var _station_assignment := PackedStringArray()
var _newspaper_read: bool = false
var _newspaper_case: NewspaperCase = NewspaperCase.NON_DEATH_NEWS
var _newspaper_subject_name: String = ""
var _newspaper_document: String = ""
var _route_index: int = 0
var _passengers: Array[Passenger] = []
var _daily_manifest: Array[PassengerData] = []
var _seat_occupant_by_slot: Dictionary = {}
var _seat_slot_by_passenger: Dictionary = {}
var _boarding_passengers: Array[Passenger] = []
var _interactables: Array[Interactable] = []
var _collected_departure_statements: Dictionary = {}
var _collected_veil_note_statement: String = ""
var _runtime_puzzle: DeparturePuzzleData
var _daily_rng := RandomNumberGenerator.new()
var _daily_seed: int = 0
var _incorrectly_stamped_anomalies: Dictionary = {}
var _shift_report_finalized: bool = false
var _correct_drop_offs: int = 0
var _wrong_drop_offs: int = 0
var _retained_anomalies: int = 0
var _penalty_log := PackedStringArray()
var _shift_checkpoint: Dictionary = {}
var _progress_advanced: bool = false
var _newspaper: NewspaperInteractable
var _nearby_interactable: Interactable
var _active_modal: Control
var _modal_before_pause: Control
var _station_cutscene_context: StringName = &""
var _station_cutscene_timeline_complete: bool = false
var _station_camera_return_complete: bool = false
var _station_cutscene_motion_strength: float = 1.0
var _station_gameplay_actors_hidden: bool = false
var _station_foreground_hidden: bool = false
var _station_railroad_was_visible: bool = true
var _train_occupants_station_rest_position: Vector2
var _inspected_passenger: Passenger
var _night_statement_active: bool = false
var _night_record_camera_rest_offset: Vector2
var _night_record_camera_target_offset: Vector2
var _night_record_camera_tween: Tween
var _night_record_camera_shake_tween: Tween
var _blocked_aisle_events: Array[Node] = []
var _dirty_seat_events: Array[Node] = []
var _active_blocked_aisle_event: Node
var _active_dirty_seat_event: Node
var _blocked_aisle_activated: bool = false
var _dirty_seat_activated: bool = false
var _blocked_aisle_spawn_count: int = 0
var _dirty_seat_spawns_this_route: int = 0
var _maintenance_schedule_route_index: int = -1
var _service_seal_active: bool = false
var _day_blessing_award: Dictionary = {}
var _night_blessing_award: Dictionary = {}
var _night_assignment_attempts: int = 0
var _night_world_prepared: bool = false
var _terminal_station_waiting_for_night_transition: bool = false
var _night_transition_camera_return_requested: bool = false
var _debug_day_pass_override: bool = false
var _night_service_elapsed_seconds: float = 0.0
var _night_service_expired: bool = false
var _night_service_timeout_presented: bool = false
var _radar_scan_active: bool = false
var _swiftstep_active: bool = false
var _world_time_scale: float = 1.0

@onready var _train: TrainWorld = %Train
@onready var _player: ConductorPlayer = %Player
@onready var _passenger_container: Node2D = %Passengers
@onready var _hud: GameHUD = %HUD
# Avoid coupling main-scene parsing to the editor's global-class registration order.
@onready var _document_overlay: Variant = %DocumentOverlayUI
@onready var _guidebook_ui: Variant = %GuidebookUI
@onready var _day_intro_ui: DayIntroUI = %DayIntroUI
@onready var _station_stop_ui: StationStopCutsceneUI = %StationStopCutsceneUI
@onready var _shift_report_ui: ShiftReportUI = %ShiftReportUI
@onready var _night_transition_ui: NightTransitionCutsceneUI = %NightTransitionCutsceneUI
@onready var _night_puzzle_ui: NightPuzzleUI = %NightPuzzleUI
@onready var _night_soul_record_ui: Variant = %NightSoulRecordUI
@onready var _service_signature_ui: Variant = %ServiceSignatureUI
@onready var _pause_ui: PauseUI = %PauseUI
@onready var _blocked_aisle_ui: Control = %BlockedAislePuzzleUI
@onready var _clean_seat_ui: Control = %CleanSeatUI
@onready var _night_market_ui: Control = %NightMarketUI
@onready var _veil_note_reveal_ui: Variant = %VeilNoteRevealUI
@onready var _swiftstep_effect_ui: Variant = %SwiftstepEffectUI
@onready var _hint_ui: Variant = %HintUI
@onready var _market_tool_state: Node = %MarketToolState
@onready var _blocked_aisle_timer: Timer = %BlockedAisleTimer
@onready var _dirty_seat_timer: Timer = %DirtySeatTimer
@onready var _ambience: TrainAmbience = %TrainAmbience
@onready var _travel_background: TravelBackground = %TravelBackground
@onready var _travel_foreground: TravelForeground = %TravelForeground
@onready var _station_cinematic_view: StationCinematicView = %StationCinematicView
@onready var _train_occupants: Node2D = %TrainOccupants
@onready var _gameplay_camera: Camera2D = $GameplayWorld/TrainOccupants/PlayerSpawnPoint/Player/Camera2D
@onready var _cinematic_camera_anchor: Marker2D = $GameplayWorld/TrainOccupants/PlayerSpawnPoint/Player/CinematicCameraAnchor
@onready var _night_record_camera_offset: Marker2D = $GameplayWorld/TrainOccupants/PlayerSpawnPoint/Player/NightSoulRecordCameraOffset
@onready var _railroad_ui_layer: CanvasLayer = $RailroadUILayer
@onready var _sky_gradient: ColorRect = %NightSkyOverlay
@onready var _night_atmosphere: ColorRect = %NightAtmosphere
@onready var _bloom_rect: ColorRect = $BloomLayer/Bloom

var _bloom_material: ShaderMaterial

func _ready() -> void:
	_configure_bloom_material()
	_train_occupants_station_rest_position = _train_occupants.position
	_night_record_camera_rest_offset = _gameplay_camera.offset
	_night_record_camera_target_offset = _night_record_camera_rest_offset
	_connect_hud_runtime_signals()
	if day_route.size() < 2:
		push_error("Main/Day Route requires at least an opening and final station.")
		return
	if manifest_config == null:
		push_error("Main/Manifest Config must reference a DailyManifestConfig resource.")
		return
	_shift_checkpoint = ShiftProgress.load_checkpoint()
	if not _shift_checkpoint.is_empty() and not _shift_checkpoint.completed:
		day_number = int(_shift_checkpoint.day)
		_market_tool_state.call(&"restore_shift_inventory", _shift_checkpoint.inventory)
	else:
		_shift_checkpoint = {}
	_configure_daily_rng()
	manifest_config = manifest_config.create_daily_service(day_number, _daily_seed)
	_shift_checkpoint = ShiftProgress.make_checkpoint(day_number, _market_tool_state.call(&"get_snapshot"), _daily_seed)
	ShiftProgress.save_checkpoint(_shift_checkpoint)
	_choose_newspaper_case()
	_daily_manifest = DailyManifestGenerator.generate(
		passenger_identity_profiles,
		day_route,
		manifest_config,
		_daily_rng,
		_newspaper_case == NewspaperCase.MATCHING_PASSENGER_DEATH
	)
	if _daily_manifest.is_empty():
		push_error("The daily passenger manifest could not be generated.")
		return
	_validate_passenger_resource_constraints()
	_spawn_initial_passengers()
	_prepare_newspaper_edition()
	_debug_print_configured_anomaly_roster()
	_debug_print_active_anomaly_roster("INITIAL BOARDING")
	_collect_interactables(self)
	_configure_maintenance_events()
	_refresh_player_interactables()
	# Four daylight arrivals plus one final Night Service step occupy the five
	# 36-degree divisions of the semicircular clock.
	_hud.set_clock_route_stop_count(day_route.size())
	_hud.set_clock(int(_day_minutes), _day_station_clock_progress())
	_hud.set_next_stop(_next_day_station())
	_hud.set_clock_night_mode(false, false)
	_pause_ui.configure_service_info(manifest_config.service_train_number, manifest_config.service_date_text)
	_set_sky_cycle_progress(0.0)
	_travel_background.begin_route_leg(_route_index, true)
	_on_market_inventory_changed(_market_tool_state.call(&"get_snapshot"))
	_update_passenger_minimap()
	_set_passenger_ai_enabled(false)
	_active_modal = _day_intro_ui
	_day_intro_ui.play_intro(day_number)


func _connect_hud_runtime_signals() -> void:
	var market_tool_callback := Callable(self, &"_on_market_tool_requested")
	if not _hud.has_signal(&"market_tool_requested"):
		push_error("HUD is missing the market_tool_requested signal.")
		return
	if not _hud.is_connected(&"market_tool_requested", market_tool_callback):
		_hud.connect(&"market_tool_requested", market_tool_callback)
	var swiftstep_finished_callback := Callable(self, &"_on_swiftstep_effect_finished")
	if not _swiftstep_effect_ui.has_signal(&"effect_finished"):
		push_error("Swiftstep Effect UI is missing the effect_finished signal.")
	elif not _swiftstep_effect_ui.is_connected(&"effect_finished", swiftstep_finished_callback):
		_swiftstep_effect_ui.connect(&"effect_finished", swiftstep_finished_callback)
	var background_period_callback := Callable(self, &"_on_travel_background_period_changed")
	if not _travel_background.is_connected(&"period_changed", background_period_callback):
		_travel_background.connect(&"period_changed", background_period_callback)


func _on_travel_background_period_changed(display_cycle_progress: float) -> void:
	# The medallion represents the visible world period, not the gameplay state.
	# This lets it flip during the final daylight route as soon as NightSky is
	# revealed by the tunnel, before Night Service formally begins.
	var background_is_night: bool = is_equal_approx(display_cycle_progress, 1.0)
	_hud.set_clock_night_mode(background_is_night, true)


func _process(delta: float) -> void:
	_station_stop_ui.set_departure_blocked(_station_stop_ui.visible and _ambience.is_announcement_playing())
	_update_travel_foreground()
	var world_simulation_active: bool = _is_world_simulation_active()
	_set_passenger_ai_enabled(world_simulation_active and state in [GameState.DAY, GameState.SUNSET])
	if _guidebook_ui.visible:
		_refresh_guidebook_progress()
	_update_passenger_minimap()
	_update_carriage_indicator()
	_hud.set_debug_next_station_available(
		state in [GameState.DAY, GameState.SUNSET]
		and _has_next_day_station()
		and not _station_arrival_announced
		and _active_modal == null
		and not _radar_scan_active
	)
	if state == GameState.NIGHT:
		_update_night_service(delta, world_simulation_active)
		return
	if state != GameState.DAY and state != GameState.SUNSET:
		return
	# A radar scan suspends only route time. Every other gameplay system keeps
	# processing, so the remaining time to the next station is unchanged.
	if not world_simulation_active or _radar_scan_active:
		return

	if not _station_arrival_announced:
		_day_minutes = minf(_day_minutes + delta * _world_time_scale, _next_arrival_minutes())
		_travel_background.update_route_leg_remaining(
			maxf(_next_arrival_minutes() - _day_minutes, 0.0)
		)
	_update_day_route_presentation()

	if not _station_arrival_announced and _has_next_day_station() and _day_minutes >= _next_arrival_minutes():
		_announce_next_station()


func _update_day_route_presentation() -> void:
	var route_progress: float = clampf((_day_minutes - START_MINUTES) / maxf(_final_arrival_minutes() - START_MINUTES, 1.0), 0.0, 1.0)
	# Day service uses all but the final clock division. One complete route leg
	# contributes exactly 36 degrees; Night Service owns the remaining step.
	_hud.set_clock(int(_day_minutes), _day_travel_clock_progress(route_progress))
	var cycle_progress: float = route_progress * DAY_SERVICE_FINAL_CYCLE_PROGRESS
	var service_night_strength: float = smoothstep(
		SERVICE_NIGHT_START_PROGRESS,
		SERVICE_FULL_NIGHT_PROGRESS,
		cycle_progress
	)
	_train.set_night_strength(service_night_strength)
	_ambience.night_strength = service_night_strength
	_set_sky_cycle_progress(cycle_progress)
	_night_atmosphere.modulate.a = service_night_strength

	if state == GameState.DAY and cycle_progress >= SUNSET_STATE_PROGRESS:
		state = GameState.SUNSET
		_hud.notify("THE LAST LIGHT FADES BEYOND THE RAILS", 3.0)


func _on_debug_next_station_requested() -> void:
	if (
		not OS.is_debug_build()
		or state not in [GameState.DAY, GameState.SUNSET]
		or not _has_next_day_station()
		or _station_arrival_announced
		or _active_modal != null
		or _radar_scan_active
	):
		return
	_day_minutes = _next_arrival_minutes()
	_update_day_route_presentation()
	_announce_next_station()

func _update_travel_foreground() -> void:
	if _station_stop_ui.visible:
		_travel_background.set_motion_strength(_station_cutscene_motion_strength)
		_travel_foreground.set_motion_strength(_station_cutscene_motion_strength)
		return
	# In-game overlays leave the scenery running; only pause and the opening
	# intro suspend it. Station stops still own the train's motion.
	var scenery_active: bool = _active_modal not in [_pause_ui, _day_intro_ui]
	var is_traveling: bool = scenery_active and state in [GameState.DAY, GameState.SUNSET, GameState.NIGHT_TRANSITION, GameState.NIGHT]
	if state in [GameState.DAY, GameState.SUNSET]:
		is_traveling = is_traveling and not _station_arrival_announced
	_travel_background.set_traveling(is_traveling)
	_travel_foreground.set_traveling(is_traveling)


func _announce_next_station() -> void:
	if not _has_next_day_station() or _station_arrival_announced:
		return
	if _active_modal in [_document_overlay, _guidebook_ui] or _is_maintenance_minigame_active():
		_active_modal.call(&"request_close")
	_station_arrival_announced = true
	_process_station_arrival()

func _has_next_day_station() -> bool:
	return _route_index < day_route.size() - 1

func _current_day_station() -> String:
	return day_route[clampi(_route_index, 0, day_route.size() - 1)]

func _next_day_station() -> String:
	return day_route[clampi(_route_index + 1, 0, day_route.size() - 1)]

func _next_arrival_minutes() -> float:
	var arrival: float = START_MINUTES
	for leg: int in range(mini(_route_index + 1, day_route.size() - 1)):
		arrival += _get_station_travel_seconds(leg)
	return arrival

func _final_arrival_minutes() -> float:
	var arrival: float = START_MINUTES
	for leg: int in range(day_route.size() - 1):
		arrival += _get_station_travel_seconds(leg)
	return arrival

func _get_station_travel_seconds(leg: int) -> float:
	if station_travel_durations_seconds.is_empty():
		return 120.0
	return maxf(5.0, station_travel_durations_seconds[clampi(leg, 0, station_travel_durations_seconds.size() - 1)])


func _day_station_clock_progress() -> float:
	var total_clock_steps: int = maxi(day_route.size(), 1)
	return clampf(float(_route_index) / float(total_clock_steps), 0.0, 1.0)


func _day_travel_clock_progress(route_progress: float) -> float:
	var total_clock_steps: int = maxi(day_route.size(), 1)
	var daylight_steps: int = maxi(day_route.size() - 1, 0)
	return clampf(route_progress, 0.0, 1.0) * float(daylight_steps) / float(total_clock_steps)


func _night_service_clock_progress() -> float:
	var duration: float = maxf(night_service_duration_seconds, 0.001)
	var night_ratio: float = clampf(_night_service_elapsed_seconds / duration, 0.0, 1.0)
	return lerpf(_day_travel_clock_progress(1.0), 1.0, night_ratio)


func _update_night_service(delta: float, world_simulation_active: bool) -> void:
	if _night_service_expired:
		_present_night_service_timeout()
		return
	if not world_simulation_active:
		return
	_night_service_elapsed_seconds = minf(
		_night_service_elapsed_seconds + delta * _world_time_scale,
		night_service_duration_seconds
	)
	_hud.set_clock_progress(_night_service_clock_progress())
	if _night_service_elapsed_seconds < night_service_duration_seconds:
		return
	_night_service_expired = true
	_hud.notify("Night service complete\nFinalize the departure assignments", 3.5)
	_present_night_service_timeout()


func _present_night_service_timeout() -> void:
	if (
		_night_service_timeout_presented
		or _active_modal != null
		or _night_statement_active
		or state != GameState.NIGHT
	):
		return
	_night_service_timeout_presented = true
	_open_night_puzzle()

func _set_sky_cycle_progress(value: float) -> void:
	var clamped_progress: float = clampf(value, 0.0, 1.0)
	_train.set_day_cycle_progress(clamped_progress)
	_station_cinematic_view.set_cycle_progress(clamped_progress)
	_set_bloom_cycle_progress(clamped_progress)
	var sky_material := _sky_gradient.material as ShaderMaterial
	if sky_material != null:
		sky_material.set_shader_parameter(&"cycle_progress", clamped_progress)


func _configure_bloom_material() -> void:
	var shared_material := _bloom_rect.material as ShaderMaterial
	if shared_material == null:
		return
	# Gameplay changes bloom throughout the route, so keep its material isolated
	# from the main-menu bloom that uses the same authored base resource.
	_bloom_material = shared_material.duplicate() as ShaderMaterial
	_bloom_rect.material = _bloom_material


func _set_bloom_cycle_progress(cycle_progress: float) -> void:
	if _bloom_material == null:
		return
	var sunset_blend: float = smoothstep(
		BLOOM_SUNSET_BLEND_START_PROGRESS,
		SUNSET_STATE_PROGRESS,
		cycle_progress
	)
	var daylight_intensity: float = lerpf(
		morning_bloom_intensity,
		sunset_bloom_intensity,
		sunset_blend
	)
	var night_blend: float = smoothstep(
		SERVICE_NIGHT_START_PROGRESS,
		SERVICE_FULL_NIGHT_PROGRESS,
		cycle_progress
	)
	var bloom_intensity: float = lerpf(
		daylight_intensity,
		night_bloom_intensity,
		night_blend
	)
	_bloom_material.set_shader_parameter(&"intensity", bloom_intensity)


func _input(event: InputEvent) -> void:
	# Tab is also Godot's default UI focus-navigation key. Handle this global UI
	# shortcut before focused Control nodes consume it, while still respecting
	# gameplay modal ownership.
	if not event.is_action_pressed(&"guidebook"):
		return
	if event is InputEventKey and event.echo:
		return
	if _night_statement_active or _service_seal_active:
		return
	if state == GameState.NIGHT_PUZZLE and _night_puzzle_ui.visible:
		_night_puzzle_ui.request_close()
		get_viewport().set_input_as_handled()
		return
	if not _guidebook_ui.visible and (
		_active_modal != null
		or state not in [GameState.DAY, GameState.SUNSET, GameState.NIGHT]
	):
		return
	_toggle_guidebook()
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _night_statement_active:
		if event.is_action_pressed(&"interact"):
			_night_soul_record_ui.call(&"request_close")
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"ui_cancel"):
			_open_pause()
			get_viewport().set_input_as_handled()
		return
	var market_shortcut: int = _market_item_shortcut(event)
	if market_shortcut > 0:
		if (
			not _service_seal_active
			and _active_modal == null
			and state in [GameState.DAY, GameState.SUNSET, GameState.NIGHT]
		):
			_hud.request_market_item(market_shortcut)
		get_viewport().set_input_as_handled()
		return
	if (
		event.is_action_pressed(&"use_radar")
		and not _service_seal_active
		and _active_modal == null
		and state in [GameState.DAY, GameState.SUNSET, GameState.NIGHT]
	):
		_use_carriage_radar()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _pause_ui.visible:
		_resume_from_pause()
	elif _day_intro_ui.visible:
		_day_intro_ui.skip_intro()
	elif _document_overlay.visible:
		if _document_overlay.is_showing_newspaper():
			_open_pause()
		else:
			_document_overlay.request_close()
	elif _guidebook_ui.visible:
		_guidebook_ui.request_close()
	elif _blocked_aisle_ui.visible:
		_open_pause()
	elif _clean_seat_ui.visible:
		_open_pause()
	elif _station_stop_ui.visible:
		_open_pause()
	elif _night_transition_ui.visible:
		_night_transition_ui.skip_sequence()
	elif _night_soul_record_ui.visible:
		_open_pause()
	elif _night_puzzle_ui.visible:
		_open_pause()
	elif state not in [GameState.OPENING, GameState.SHIFT_REPORT, GameState.MARKET, GameState.COMPLETE]:
		_open_pause()
	get_viewport().set_input_as_handled()


func _market_item_shortcut(event: InputEvent) -> int:
	var key_event := event as InputEventKey
	if key_event != null and key_event.echo:
		return 0
	if event.is_action_pressed(&"use_market_item_1"):
		return 1
	if event.is_action_pressed(&"use_market_item_2"):
		return 2
	if event.is_action_pressed(&"use_market_item_3"):
		return 3
	return 0


func _spawn_initial_passengers() -> void:
	var dead_count: int = 0
	var boarding_index: int = 0
	for data: PassengerData in _daily_manifest:
		if not data.initially_on_train:
			continue
		if _active_passenger_count() >= manifest_config.initial_passenger_count:
			push_warning("Passenger roster exceeds the configured opening capacity; extra entries were skipped.")
			break
		if data.is_dead and dead_count >= manifest_config.deceased_passenger_count:
			push_warning("Night roster exceeds the configured deceased-passenger count; %s was skipped." % data.passenger_name)
			continue
		var carriage: int = clampi(data.current_carriage, 1, manifest_config.passenger_carriage_count)
		var seat_slot: Marker2D = _find_station_boarding_seat(carriage)
		if seat_slot == null:
			push_warning("No unoccupied station-accessible passenger seat is available; %s was skipped." % data.passenger_name)
			continue
		data.current_carriage = _train.get_passenger_carriage_number_at_world_x(seat_slot.global_position.x)
		var passenger: Passenger = _spawn_passenger(data, seat_slot)
		if passenger == null:
			continue
		_stage_passenger_for_boarding(passenger, boarding_index)
		boarding_index += 1
		if data.is_dead:
			dead_count += 1
	if _active_passenger_count() != manifest_config.initial_passenger_count:
		push_warning("The opening roster does not match Daily Manifest Config/Initial Passenger Count.")
	_validate_active_passenger_constraints("initial boarding")

func _configure_daily_rng() -> void:
	if not _shift_checkpoint.is_empty():
		_daily_seed = int(_shift_checkpoint.seed)
		_daily_rng.seed = _daily_seed
	elif manifest_config.use_random_seed:
		_daily_rng.randomize()
		_daily_seed = _daily_rng.seed
	else:
		_daily_seed = manifest_config.debug_seed
		_daily_rng.seed = _daily_seed
	if debug_print_anomaly_roster:
		print("[DAILY MANIFEST] seed=%d" % _daily_seed)

func _choose_newspaper_case() -> void:
	match newspaper_edition_mode:
		NewspaperEditionMode.FORCE_NON_DEATH:
			_newspaper_case = NewspaperCase.NON_DEATH_NEWS
		NewspaperEditionMode.FORCE_DEATH:
			_newspaper_case = NewspaperCase.MATCHING_PASSENGER_DEATH
		_:
			_newspaper_case = (
				NewspaperCase.MATCHING_PASSENGER_DEATH
				if manifest_config.should_guarantee_newspaper_anomaly(day_number)
				else _roll_random_newspaper_case()
			)

func _roll_random_newspaper_case() -> NewspaperCase:
	var non_death_weight: float = maxf(0.0, manifest_config.non_death_news_weight)
	var matching_death_weight: float = maxf(0.0, manifest_config.matching_death_news_weight)
	var total_weight: float = non_death_weight + matching_death_weight
	if total_weight <= 0.0:
		push_warning("All newspaper case weights are zero; using the non-death edition.")
		return NewspaperCase.NON_DEATH_NEWS
	var roll: float = _daily_rng.randf() * total_weight
	if roll < non_death_weight:
		return NewspaperCase.NON_DEATH_NEWS
	return NewspaperCase.MATCHING_PASSENGER_DEATH

func _prepare_newspaper_edition() -> void:
	_document_overlay.choose_random_newspaper_visual(_daily_rng)
	_document_overlay.configure_newspaper_portrait(_choose_random_newspaper_portrait())
	var excluded_passenger_names: PackedStringArray = _get_generated_passenger_names()
	var shared_name_pool: PackedStringArray = manifest_config.get_all_passenger_names()
	if _newspaper_case == NewspaperCase.MATCHING_PASSENGER_DEATH:
		var subject: PassengerData = _find_newspaper_subject(_daily_rng)
		if subject != null:
			_newspaper_subject_name = subject.passenger_name
			_document_overlay.configure_newspaper_portrait(subject.id_photo)
			_newspaper_document = _document_overlay.compose_matching_death_newspaper(subject, day_route[0], _daily_rng)
			return
		push_error("Death newspaper requires an anomaly aboard; using ordinary news because the manifest has no matching subject.")
		_newspaper_case = NewspaperCase.NON_DEATH_NEWS

	_newspaper_subject_name = _document_overlay.get_random_outside_subject(
		_daily_rng,
		shared_name_pool,
		excluded_passenger_names,
		"non-death newspaper"
	)
	_newspaper_document = _document_overlay.compose_non_death_newspaper(_newspaper_subject_name, day_route[0], _daily_rng)


func _choose_random_newspaper_portrait() -> Texture2D:
	var candidates: Array[Texture2D] = []
	for profile: PassengerIdentityProfile in passenger_identity_profiles:
		if profile != null and profile.id_photo != null:
			candidates.append(profile.id_photo)
	if candidates.is_empty():
		push_warning("No passenger portrait is available for the newspaper photograph.")
		return null
	return candidates[_daily_rng.randi_range(0, candidates.size() - 1)]

func _find_newspaper_subject(rng: RandomNumberGenerator) -> PassengerData:
	var candidates: Array[PassengerData] = []
	for data: PassengerData in _daily_manifest:
		if data.is_dead and data.initially_on_train and data.anomaly_type == String(manifest_config.newspaper_anomaly_type):
			candidates.append(data)
	if candidates.is_empty():
		return null
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func _get_generated_passenger_names() -> PackedStringArray:
	var result := PackedStringArray()
	for data: PassengerData in _daily_manifest:
		for configured_name: String in [data.passenger_name, data.short_name]:
			var normalized_name: String = configured_name.strip_edges().to_lower()
			if not normalized_name.is_empty() and not result.has(normalized_name):
				result.append(normalized_name)
	return result

func _spawn_passenger(data: PassengerData, seat_slot: Marker2D) -> Passenger:
	if seat_slot == null or not is_instance_valid(seat_slot):
		push_error("Passenger %s cannot spawn without a valid scene-authored seat." % data.passenger_name)
		return null
	var current_occupant := _seat_occupant_by_slot.get(seat_slot) as Passenger
	if _is_active_passenger(current_occupant):
		push_error("Seat %s is already occupied; %s was not spawned." % [seat_slot.name, data.passenger_name])
		return null
	if not _can_add_passenger_without_trait_overflow(data):
		push_warning("%s was skipped because an anomaly trait already has %d active passengers." % [data.passenger_name, manifest_config.max_passengers_per_anomaly_trait])
		return null
	var configured_scene: PackedScene = passenger_scene
	if data.identity_profile != null and data.identity_profile.passenger_scene != null:
		configured_scene = data.identity_profile.passenger_scene
	if configured_scene == null:
		push_error("Passenger %s has no configured passenger scene or fallback scene." % data.passenger_name)
		return null
	var passenger := configured_scene.instantiate() as Passenger
	if passenger == null:
		push_error("The configured scene for %s does not instantiate Passenger." % data.passenger_name)
		return null
	passenger.name = data.short_name
	passenger.data = data
	passenger.position = _passenger_container.to_local(seat_slot.global_position)
	passenger.documents_requested.connect(_on_passenger_documents_requested)
	_passenger_container.add_child(passenger)
	passenger.set_world_time_scale(_world_time_scale)
	_passengers.append(passenger)
	_seat_occupant_by_slot[seat_slot] = passenger
	_seat_slot_by_passenger[passenger] = seat_slot
	passenger.configure_seat_navigation(passenger.position, _get_passenger_activity_positions(), _get_passenger_carriage_ranges())
	return passenger

func _stage_passenger_for_boarding(passenger: Passenger, actor_index: int) -> void:
	if not _is_active_passenger(passenger):
		return
	var door_markers: Dictionary = _train.get_passenger_door_markers()
	var carriage_markers: Array = door_markers.get(passenger.get_runtime_carriage(), [])
	if carriage_markers.is_empty():
		push_warning("Passenger carriage %d has no scene-authored boarding marker." % passenger.get_runtime_carriage())
		passenger.randomize_initial_activity()
		return
	var door_marker := carriage_markers[actor_index % carriage_markers.size()] as Marker2D
	if not is_instance_valid(door_marker):
		push_warning("Passenger carriage %d has an invalid boarding marker." % passenger.get_runtime_carriage())
		passenger.randomize_initial_activity()
		return
	passenger.stage_boarding(_passenger_container.to_local(door_marker.global_position))
	_boarding_passengers.append(passenger)

func _finish_staged_boarding() -> void:
	for passenger: Passenger in _boarding_passengers:
		if _is_active_passenger(passenger):
			passenger.finish_boarding()
	_boarding_passengers.clear()

func _find_available_seat(carriage: int) -> Marker2D:
	var available_seats: Array[Marker2D] = []
	var comfortably_spaced_seats: Array[Marker2D] = []
	for seat_slot: Marker2D in _train.get_passenger_seat_slots(carriage):
		if _is_seat_blocked_by_maintenance(seat_slot) or Passenger.is_stop_reserved_for_interaction(get_tree(), seat_slot.global_position):
			continue
		var occupant := _seat_occupant_by_slot.get(seat_slot) as Passenger
		if not _is_active_passenger(occupant):
			_seat_occupant_by_slot.erase(seat_slot)
			available_seats.append(seat_slot)
	if available_seats.is_empty():
		return null
	for seat_slot: Marker2D in available_seats:
		if _has_enough_space_from_occupied_seats(seat_slot):
			comfortably_spaced_seats.append(seat_slot)
	if comfortably_spaced_seats.is_empty():
		return null
	return comfortably_spaced_seats[_daily_rng.randi_range(0, comfortably_spaced_seats.size() - 1)]


func _find_station_boarding_seat(preferred_carriage: int) -> Marker2D:
	var preferred_seat: Marker2D = _find_available_seat(preferred_carriage)
	if preferred_seat != null:
		return preferred_seat
	var fallback_carriages: Array[int] = []
	for carriage: int in range(1, manifest_config.passenger_carriage_count + 1):
		if carriage != preferred_carriage:
			fallback_carriages.append(carriage)
	for index: int in range(fallback_carriages.size() - 1, 0, -1):
		var swap_index: int = _daily_rng.randi_range(0, index)
		var held_carriage: int = fallback_carriages[index]
		fallback_carriages[index] = fallback_carriages[swap_index]
		fallback_carriages[swap_index] = held_carriage
	for carriage: int in fallback_carriages:
		var fallback_seat: Marker2D = _find_available_seat(carriage)
		if fallback_seat != null:
			return fallback_seat
	return null

func _has_enough_space_from_occupied_seats(candidate: Marker2D) -> bool:
	var candidate_position: Vector2 = _passenger_container.to_local(candidate.global_position)
	for occupied_value: Variant in _seat_occupant_by_slot.keys():
		var occupied_slot := occupied_value as Marker2D
		var occupant := _seat_occupant_by_slot.get(occupied_slot) as Passenger
		if not is_instance_valid(occupied_slot) or not _is_active_passenger(occupant):
			continue
		if absf(candidate.global_position.x - occupied_slot.global_position.x) < minimum_passenger_seat_spacing:
			return false
	for passenger: Passenger in _passengers:
		if not _is_active_passenger(passenger):
			continue
		if absf(candidate_position.x - passenger.get_navigation_target_position().x) < minimum_passenger_seat_spacing:
			return false
	return true

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
		if int(trait_counts.get(anomaly_key, 0)) >= manifest_config.max_passengers_per_anomaly_trait:
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
	var deceased_count: int = 0
	var wrong_train_boarder_count: int = 0
	var observed_ticket_numbers: Dictionary = {}
	var observed_identity_numbers: Dictionary = {}
	var service_train_number: String = manifest_config.service_train_number.strip_edges()
	var service_date: String = manifest_config.service_date_text.strip_edges()
	var service_day_code: String = manifest_config.ticket_day_code.strip_edges()
	for data: PassengerData in _daily_manifest:
		if data.is_dead:
			deceased_count += 1
		var traits: Array[StringName] = data.get_anomaly_traits(day_route)
		var is_anomalous: bool = data.anomaly_type != "none" or not traits.is_empty()
		if data.is_dead != is_anomalous:
			push_error("Manifest invariant failed for %s: anomaly passengers and night passengers must be the same roster." % data.passenger_name)
		if data.is_dead and traits.is_empty():
			push_error("Generated deceased passenger %s has no anomaly evidence." % data.passenger_name)
		if not data.is_dead and not traits.is_empty():
			push_error("Generated living passenger %s incorrectly has anomaly evidence: %s." % [data.passenger_name, str(traits)])
		if not data.is_dead:
			var origin_index: int = day_route.find(data.origin_station)
			var destination_index: int = day_route.find(data.destination_station)
			if origin_index < 0 or destination_index <= origin_index:
				push_error("Generated living passenger %s has an invalid route: %s -> %s." % [data.passenger_name, data.origin_station, data.destination_station])
		if data.ticket_number.is_empty():
			push_error("Generated passenger %s has no ticket number." % data.passenger_name)
		elif observed_ticket_numbers.has(data.ticket_number):
			push_error("Generated ticket number %s is assigned to more than one passenger." % data.ticket_number)
		else:
			observed_ticket_numbers[data.ticket_number] = data
		if data.identity_number.is_empty():
			push_error("Generated passenger %s has no identity number." % data.passenger_name)
		elif observed_identity_numbers.has(data.identity_number):
			push_error("Identity number %s is assigned to more than one passenger." % data.identity_number)
		else:
			observed_identity_numbers[data.identity_number] = data
		if not data.ticket_number.begins_with("%s-%s-" % [data.ticket_day_code, data.ticket_train_number]):
			push_error("Ticket %s does not match its printed day/train fields." % data.ticket_number)
		if data.anomaly_type == "portrait_mismatch":
			if data.id_photo == data.identity_profile.id_photo or data.id_photo_owner == data.passenger_name:
				push_error("Portrait-mismatch passenger %s still carries their own ID portrait." % data.passenger_name)
		elif data.id_photo != data.identity_profile.id_photo or data.id_photo_owner != data.passenger_name:
			push_error("Regular ID portrait for %s no longer matches its identity profile." % data.passenger_name)
		if data.anomaly_type == "time_invalid_ticket":
			if data.ticket_service_date == service_date or data.ticket_day_code == service_day_code:
				push_error("Time-invalid ticket for %s still matches the active service day." % data.passenger_name)
		elif data.ticket_service_date != service_date or data.ticket_day_code != service_day_code:
			push_error("Regular ticket for %s carries an invalid service date." % data.passenger_name)
		if data.is_wrong_train_boarder():
			wrong_train_boarder_count += 1
			var origin_index: int = day_route.find(data.origin_station)
			var expected_immediate_station: String = day_route[origin_index + 1] if origin_index >= 0 and origin_index + 1 < day_route.size() else ""
			if data.is_dead:
				push_error("Wrong-train boarder %s must remain a living operational case, not a night passenger." % data.passenger_name)
			if data.ticket_train_number == service_train_number:
				push_error("Wrong-train boarder %s carries the active service number." % data.passenger_name)
			if data.required_dropoff_station != expected_immediate_station:
				push_error("Wrong-train boarder %s must leave at the first stop after boarding." % data.passenger_name)
		elif data.ticket_issue_type != PassengerData.TICKET_ISSUE_NONE:
			push_error("Passenger %s has an unsupported ticket issue: %s." % [data.passenger_name, String(data.ticket_issue_type)])
		elif data.ticket_train_number != service_train_number:
			push_error("Regular passenger %s carries train number %s instead of %s." % [data.passenger_name, data.ticket_train_number, service_train_number])
		for anomaly_key: StringName in traits:
			trait_counts[anomaly_key] = int(trait_counts.get(anomaly_key, 0)) + 1
	if deceased_count != manifest_config.deceased_passenger_count:
		push_error("Generated manifest contains %d deceased passengers; Daily Manifest Config expects %d." % [deceased_count, manifest_config.deceased_passenger_count])
	if wrong_train_boarder_count != manifest_config.wrong_train_boarder_count:
		push_error("Generated manifest contains %d wrong-train boarders; Daily Manifest Config expects %d." % [wrong_train_boarder_count, manifest_config.wrong_train_boarder_count])
	for anomaly_key: StringName in trait_counts:
		var count: int = int(trait_counts[anomaly_key])
		if count > manifest_config.max_passengers_per_anomaly_trait:
			push_error("Passenger resources contain %d instances of anomaly trait '%s'; the configured maximum is %d." % [count, anomaly_key, manifest_config.max_passengers_per_anomaly_trait])

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
		if count > manifest_config.max_passengers_per_anomaly_trait:
			push_error("%s: anomaly trait '%s' is used by %d active passengers." % [context, anomaly_key, count])

func _debug_print_configured_anomaly_roster() -> void:
	if not debug_print_anomaly_roster:
		return
	var anomaly_rows := PackedStringArray()
	var wrong_train_rows := PackedStringArray()
	for data: PassengerData in _daily_manifest:
		var traits: Array[StringName] = data.get_anomaly_traits(day_route)
		if not traits.is_empty() or data.is_dead:
			anomaly_rows.append(_format_anomaly_debug_row(data, traits))
		if data.is_wrong_train_boarder():
			wrong_train_rows.append(_format_wrong_train_debug_row(data))
	print("\n========== ANOMALY DEBUG: CONFIGURED DAY ROSTER (%d) ==========" % anomaly_rows.size())
	for debug_line: String in anomaly_rows:
		print(debug_line)
	print("[NEWSPAPER] %s: %s" % [_newspaper_case_debug_label(), _newspaper_subject_name])
	print("[TICKET DEBUG] ACTIVE SERVICE %s | DATE %s | WRONG-TRAIN BOARDERS (%d)" % [manifest_config.service_train_number, manifest_config.service_date_text, wrong_train_rows.size()])
	for debug_line: String in wrong_train_rows:
		print(debug_line)
	print("===============================================================\n")

func _newspaper_case_debug_label() -> String:
	match _newspaper_case:
		NewspaperCase.NON_DEATH_NEWS:
			return "NON-DEATH NEWS / NOT AN ANOMALY CLUE"
		NewspaperCase.MATCHING_PASSENGER_DEATH:
			return "MATCHING DEATH / ANOMALY + NIGHT PASSENGER"
		_:
			return "UNKNOWN CASE"

func _debug_print_active_anomaly_roster(context: String) -> void:
	if not debug_print_anomaly_roster:
		return
	var anomaly_rows := PackedStringArray()
	var wrong_train_rows := PackedStringArray()
	for passenger: Passenger in _passengers:
		if not _is_active_passenger(passenger):
			continue
		var data: PassengerData = passenger.data
		var traits: Array[StringName] = data.get_anomaly_traits(day_route)
		if not traits.is_empty() or data.is_dead:
			anomaly_rows.append(_format_anomaly_debug_row(data, traits))
		if data.is_wrong_train_boarder():
			wrong_train_rows.append(_format_wrong_train_debug_row(data))
	print("[ANOMALY DEBUG] ACTIVE AFTER %s (%d)" % [context, anomaly_rows.size()])
	if anomaly_rows.is_empty():
		print("  - NONE")
	else:
		for debug_line: String in anomaly_rows:
			print(debug_line)
	print("[TICKET DEBUG] ACTIVE WRONG-TRAIN BOARDERS (%d)" % wrong_train_rows.size())
	if wrong_train_rows.is_empty():
		print("  - NONE")
	else:
		for debug_line: String in wrong_train_rows:
			print(debug_line)

func _format_anomaly_debug_row(data: PassengerData, traits: Array[StringName]) -> String:
	var trait_names := PackedStringArray()
	for anomaly_trait: StringName in traits:
		trait_names.append(String(anomaly_trait))
	var evidence: String = ""
	match data.anomaly_type:
		"portrait_mismatch":
			evidence = " | evidence=ID portrait belongs to %s" % data.id_photo_owner
		"time_invalid_ticket":
			evidence = " | evidence=service date %s / code %s" % [data.ticket_service_date, data.ticket_day_code]
	return "  - %s | traits=%s | deceased=%s | route=%s -> %s | coach=%d | boards=%s%s" % [
		data.passenger_name,
		", ".join(trait_names),
		str(data.is_dead),
		data.origin_station,
		data.destination_station,
		data.current_carriage,
		"DAY START" if data.initially_on_train else data.origin_station,
		evidence,
	]

func _format_wrong_train_debug_row(data: PassengerData) -> String:
	return "  - %s | ticket_train=%s | active_train=%s | printed_destination=%s | required_dropoff=%s | boards=%s" % [
		data.passenger_name,
		data.ticket_train_number,
		manifest_config.service_train_number,
		data.destination_station,
		data.required_dropoff_station,
		"DAY START" if data.initially_on_train else data.origin_station,
	]

func _collect_interactables(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Interactable:
			var interactable := child as Interactable
			_interactables.append(interactable)
			if interactable is NewspaperInteractable:
				_newspaper = interactable as NewspaperInteractable
		_collect_interactables(child)


func _configure_maintenance_events() -> void:
	_blocked_aisle_events.clear()
	_dirty_seat_events.clear()
	for event: Node in get_tree().get_nodes_in_group(&"blocked_aisle_events"):
		if not is_ancestor_of(event):
			continue
		_blocked_aisle_events.append(event)
		var blocked_callback := Callable(self, &"_on_blocked_aisle_puzzle_requested")
		if not event.is_connected(&"puzzle_requested", blocked_callback):
			event.connect(&"puzzle_requested", blocked_callback)
	for event: Node in get_tree().get_nodes_in_group(&"dirty_seat_events"):
		if not is_ancestor_of(event):
			continue
		_dirty_seat_events.append(event)
		var cleaning_callback := Callable(self, &"_on_dirty_seat_cleaning_requested")
		if not event.is_connected(&"cleaning_requested", cleaning_callback):
			event.connect(&"cleaning_requested", cleaning_callback)
	_refresh_maintenance_trackers()


func _schedule_maintenance_events() -> void:
	_sync_maintenance_schedule_route()
	if not _blocked_aisle_enabled_for_level():
		_blocked_aisle_timer.stop()
	elif not _blocked_aisle_activated and not _blocked_aisle_events.is_empty() and _blocked_aisle_timer.is_stopped():
		_blocked_aisle_timer.start(_next_blocked_aisle_delay())
	if not _clean_seat_enabled_for_level():
		_dirty_seat_timer.stop()
	elif not _dirty_seat_activated and not _dirty_seat_events.is_empty() and _dirty_seat_timer.is_stopped():
		var clean_delay: float = _next_dirty_seat_delay()
		if clean_delay > 0.0:
			_dirty_seat_timer.start(clean_delay)


func _sync_maintenance_schedule_route() -> void:
	if _maintenance_schedule_route_index == _route_index:
		return
	_maintenance_schedule_route_index = _route_index
	_dirty_seat_spawns_this_route = 0
	_dirty_seat_timer.stop()


func _next_blocked_aisle_delay() -> float:
	if day_number == 2:
		if _blocked_aisle_spawn_count == 0:
			return level_two_blocked_first_delay_seconds
		return level_two_blocked_repeat_delay_seconds
	return _random_delay(blocked_aisle_delay_range_seconds)


func _next_dirty_seat_delay() -> float:
	if day_number != 3:
		return _random_delay(dirty_seat_delay_range_seconds)
	if _route_index == 0:
		if _dirty_seat_spawns_this_route == 0:
			return level_three_clean_first_delay_seconds
		if _dirty_seat_spawns_this_route == 1:
			return level_three_clean_second_delay_seconds
		return -1.0
	if _route_index != 1 or _dirty_seat_spawns_this_route > 0:
		return -1.0
	var route_duration: float = _get_station_travel_seconds(_route_index)
	var maximum_clearance: float = maxf(route_duration * 0.5 - 0.1, 0.1)
	var clearance: float = minf(clean_seat_route_edge_clearance_seconds, maximum_clearance)
	return _daily_rng.randf_range(clearance, maxf(clearance, route_duration - clearance))


func _random_delay(delay_range: Vector2) -> float:
	var minimum_delay: float = minf(delay_range.x, delay_range.y)
	var maximum_delay: float = maxf(delay_range.x, delay_range.y)
	return _daily_rng.randf_range(maxf(minimum_delay, 0.1), maxf(maximum_delay, 0.1))


func _on_blocked_aisle_timer_timeout() -> void:
	if not _blocked_aisle_enabled_for_level():
		_blocked_aisle_timer.stop()
		return
	if state not in [GameState.DAY, GameState.SUNSET]:
		return
	if _blocked_aisle_activated:
		if day_number == 2:
			_blocked_aisle_timer.start(1.0)
		return
	if _station_stop_ui.visible:
		_blocked_aisle_timer.start(1.0)
		return
	var safe_candidates: Array[Node] = []
	for event: Node in _blocked_aisle_events:
		var world_event := event as Node2D
		if not is_instance_valid(world_event):
			continue
		if _maintenance_events_overlap(event, _active_dirty_seat_event, _player.global_position.x):
			continue
		safe_candidates.append(event)
	var distant_candidates: Array[Node] = []
	for event: Node in safe_candidates:
		var world_event := event as Node2D
		if world_event.global_position.distance_to(_player.global_position) > 190.0:
			distant_candidates.append(event)
	var candidates: Array[Node] = distant_candidates if not distant_candidates.is_empty() else safe_candidates
	if candidates.is_empty():
		_blocked_aisle_timer.start(2.0)
		return
	_active_blocked_aisle_event = candidates[_daily_rng.randi_range(0, candidates.size() - 1)]
	_active_blocked_aisle_event.call(&"set_event_active", true, _player.global_position.x)
	var blocked_connector := _active_blocked_aisle_event as Node2D
	if is_instance_valid(blocked_connector):
		_train.set_blocked_connector_effect(_player.global_position.x, blocked_connector.global_position.x)
	_blocked_aisle_activated = true
	_blocked_aisle_spawn_count += 1
	if day_number == 2:
		_blocked_aisle_timer.start(level_two_blocked_repeat_delay_seconds)
	_hud.notify("LUGGAGE IS BLOCKING A COACH CONNECTOR", 3.5)
	_refresh_player_interactables()
	_refresh_maintenance_trackers()


func _on_dirty_seat_timer_timeout() -> void:
	if not _clean_seat_enabled_for_level():
		_dirty_seat_timer.stop()
		return
	if state not in [GameState.DAY, GameState.SUNSET]:
		return
	if _dirty_seat_activated:
		if day_number == 3:
			_dirty_seat_timer.start(1.0)
		return
	if _active_modal != null:
		_dirty_seat_timer.start(1.0)
		return
	var vacant_candidates: Array[Node] = []
	for event: Node in _dirty_seat_events:
		if not is_instance_valid(event):
			continue
		if event.has_method(&"can_spawn_random_event") and not bool(event.call(&"can_spawn_random_event")):
			continue
		var seat_marker := event.call(&"get_seat_marker") as Marker2D
		var occupant := _seat_occupant_by_slot.get(seat_marker) as Passenger
		if (
			is_instance_valid(seat_marker)
			and not _is_active_passenger(occupant)
			and not _maintenance_events_overlap(event, _active_blocked_aisle_event)
		):
			vacant_candidates.append(event)
	if vacant_candidates.is_empty():
		_dirty_seat_timer.start(2.0)
		return
	_active_dirty_seat_event = vacant_candidates[_daily_rng.randi_range(0, vacant_candidates.size() - 1)]
	_active_dirty_seat_event.call(&"set_event_active", true)
	_dirty_seat_activated = true
	_dirty_seat_spawns_this_route += 1
	if day_number == 3 and _route_index == 0 and _dirty_seat_spawns_this_route == 1:
		_dirty_seat_timer.start(level_three_clean_second_delay_seconds)
	_hud.notify("A PASSENGER SEAT NEEDS CLEANING", 3.5)
	_clear_dropoff_assignments_for_dirty_seat()
	_set_service_sealed(true)
	_refresh_maintenance_trackers()


func _clear_dropoff_assignments_for_dirty_seat() -> void:
	if is_instance_valid(_inspected_passenger):
		_document_overlay.configure_stamp_lock(true)


func _on_blocked_aisle_puzzle_requested(event: Node) -> void:
	if not _blocked_aisle_enabled_for_level():
		return
	if _active_modal != null or state not in [GameState.DAY, GameState.SUNSET, GameState.NIGHT]:
		return
	_active_modal = _blocked_aisle_ui
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_blocked_aisle_ui.call(&"open_puzzle", event)


func _on_dirty_seat_cleaning_requested(event: Node) -> void:
	if not _clean_seat_enabled_for_level():
		return
	if _active_modal != null or state not in [GameState.DAY, GameState.SUNSET]:
		return
	_active_modal = _clean_seat_ui
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_clean_seat_ui.call(&"open_cleaning", event)


func _on_maintenance_minigame_closed() -> void:
	_active_modal = null
	_set_player_control_for_state()


func _on_maintenance_minigame_completed(event: Node) -> void:
	if is_instance_valid(event) and event.has_method(&"mark_solved"):
		event.call(&"mark_solved")
	if event == _active_dirty_seat_event:
		_active_dirty_seat_event = null
		if day_number == 3:
			_dirty_seat_activated = false
		if is_instance_valid(_document_overlay):
			_document_overlay.configure_stamp_lock(false)
		_set_service_sealed(false)
	else:
		if event == _active_blocked_aisle_event:
			_active_blocked_aisle_event = null
			if day_number == 2:
				_blocked_aisle_activated = false
			_train.clear_blocked_connector_effect()
	_refresh_player_interactables()
	_refresh_maintenance_trackers()
	_active_modal = null
	_set_player_control_for_state()
	_schedule_maintenance_events()


func _refresh_maintenance_trackers() -> void:
	var tracker_entries: Array[Dictionary] = []
	if (
		is_instance_valid(_active_blocked_aisle_event)
		and _nearby_interactable != _active_blocked_aisle_event
		and not bool(_active_blocked_aisle_event.call(&"is_resolved"))
	):
		tracker_entries.append({
			"target": _active_blocked_aisle_event.call(&"get_tracker_anchor") as Node2D,
			"icon": _active_blocked_aisle_event.call(&"get_tracker_icon") as Texture2D,
		})
	if (
		is_instance_valid(_active_dirty_seat_event)
		and _nearby_interactable != _active_dirty_seat_event
		and not bool(_active_dirty_seat_event.call(&"is_resolved"))
	):
		tracker_entries.append({
			"target": _active_dirty_seat_event.call(&"get_tracker_anchor") as Node2D,
			"icon": _active_dirty_seat_event.call(&"get_tracker_icon") as Texture2D,
		})
	_hud.set_maintenance_targets(tracker_entries)


func _set_service_sealed(value: bool, immediate: bool = false) -> void:
	if value == _service_seal_active and not immediate:
		return
	_service_seal_active = value
	_hud.set_service_sealed(value)
	_refresh_player_interactables(immediate)
	_refresh_nearby_interactable_prompt()


func _refresh_player_interactables(immediate: bool = false) -> void:
	if not is_instance_valid(_player):
		return
	var available_interactables: Array[Interactable] = []
	for interactable: Interactable in _interactables:
		if not is_instance_valid(interactable):
			continue
		var is_allowed: bool = not _service_seal_active or _is_seal_allowed_interactable(interactable)
		interactable.set_interaction_locked(not is_allowed, immediate)
		# Locked passengers remain proximity targets so they can explain the
		# maintenance block from their own dialogue anchor. The input handler below
		# still prevents their documents from opening until the seat is clean.
		if is_allowed or interactable is Passenger:
			available_interactables.append(interactable)
	_player.set_interactables(available_interactables)


func _is_seal_allowed_interactable(interactable: Interactable) -> bool:
	if not is_instance_valid(interactable):
		return false
	return interactable == _active_dirty_seat_event or interactable == _active_blocked_aisle_event

func _on_interaction_pressed(interactable: Interactable) -> void:
	if _service_seal_active and not _is_seal_allowed_interactable(interactable):
		return
	interactable.interact()

func _on_nearby_interactable_changed(interactable: Interactable) -> void:
	_nearby_interactable = interactable
	_refresh_nearby_interactable_prompt()
	_refresh_maintenance_trackers()


func _refresh_nearby_interactable_prompt() -> void:
	if not is_instance_valid(_hud):
		return
	var interactable: Interactable = _nearby_interactable
	_hud.set_prompt(
		_get_nearby_interactable_prompt(interactable),
		_get_interactable_prompt_anchor(interactable)
	)


func _get_nearby_interactable_prompt(interactable: Interactable) -> String:
	if interactable == null:
		return ""
	if (
		_service_seal_active
		and is_instance_valid(_active_dirty_seat_event)
		and interactable is Passenger
	):
		return dirty_seat_passenger_blocked_text
	return interactable.get_prompt()

func _get_interactable_prompt_anchor(interactable: Interactable) -> Node2D:
	if interactable == null:
		return null
	if interactable is Passenger:
		return (interactable as Passenger).get_dialogue_anchor()
	return interactable.get_prompt_anchor()

func _on_passenger_documents_requested(passenger: Passenger) -> void:
	if passenger.departed:
		return
	if state == GameState.NIGHT:
		_on_night_passenger_interacted(passenger)
		return
	_open_passenger_documents(passenger)

func _open_passenger_documents(passenger: Passenger) -> void:
	passenger.documents_checked = true
	_inspected_passenger = passenger
	_inspected_passenger.set_inspection_paused(true)
	_active_modal = _document_overlay
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_document_overlay.show_passenger(passenger.data)
	if state in [GameState.DAY, GameState.SUNSET] and _has_next_day_station() and not _station_exchange_processed:
		_document_overlay.configure_station_assignment(not passenger.data.stamped_station.is_empty())
		_document_overlay.configure_stamp_lock(_is_dropoff_locked())

func _on_night_passenger_interacted(passenger: Passenger) -> void:
	if _night_statement_active or passenger.data == null or not passenger.data.is_dead:
		return
	var puzzle: DeparturePuzzleData = _get_departure_puzzle()
	if puzzle == null:
		push_error("The configured departure puzzle resource is invalid.")
		return
	var passenger_name: String = passenger.data.short_name
	var statement: String = puzzle.get_statement_for_passenger(passenger_name)
	if statement.is_empty():
		_hud.notify(missing_night_statement_text, 2.0)
		return
	GameSFX.play(&"ghost_whisper", -10.0, 1.0, 0.07, 0.35)
	_night_statement_active = true
	_inspected_passenger = passenger
	_inspected_passenger.set_inspection_paused(true)
	_active_modal = _night_soul_record_ui
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_focus_night_record_camera()
	_night_soul_record_ui.call(
		&"open_record",
		passenger.data,
		puzzle,
		_collected_departure_statements.has(passenger_name)
	)

func _close_night_statement_dialogue() -> void:
	if not _night_statement_active:
		return
	if _night_soul_record_ui.visible:
		_night_soul_record_ui.hide()
	_restore_night_record_camera()
	_night_statement_active = false
	if is_instance_valid(_inspected_passenger):
		_inspected_passenger.set_inspection_paused(false)
	_inspected_passenger = null
	if _active_modal == _night_soul_record_ui:
		_active_modal = null
	_hud.set_prompt("")
	_set_player_control_for_state()


func _on_night_statement_recorded(passenger_name: String, statement: String) -> void:
	if passenger_name.is_empty() or statement.is_empty():
		return
	if _collected_departure_statements.has(passenger_name):
		return
	_collected_departure_statements[passenger_name] = statement
	_night_puzzle_ui.refresh_collected_statements(_collected_departure_statements)


func _on_night_statement_feedback_requested(succeeded: bool) -> void:
	# Correct statements use the Soul Record's green confirmation flash. Camera
	# shake is reserved for rejected sentences so success remains comfortable.
	if not succeeded:
		_shake_night_record_camera(16.0)


func _on_night_soul_record_closed() -> void:
	_close_night_statement_dialogue()


func _on_night_soul_record_closing() -> void:
	_restore_night_record_camera()


func _focus_night_record_camera() -> void:
	_tween_night_record_camera_to(_night_record_camera_offset.position)


func _restore_night_record_camera() -> void:
	_tween_night_record_camera_to(_night_record_camera_rest_offset)


func _tween_night_record_camera_to(target_offset: Vector2) -> void:
	if (
		target_offset.is_equal_approx(_night_record_camera_target_offset)
		and is_instance_valid(_night_record_camera_tween)
		and _night_record_camera_tween.is_valid()
	):
		return
	_night_record_camera_target_offset = target_offset
	if is_instance_valid(_night_record_camera_shake_tween) and _night_record_camera_shake_tween.is_valid():
		_night_record_camera_shake_tween.kill()
	if is_instance_valid(_night_record_camera_tween) and _night_record_camera_tween.is_valid():
		_night_record_camera_tween.kill()
	_night_record_camera_tween = create_tween()
	_night_record_camera_tween.tween_property(
		_gameplay_camera,
		^"offset",
		target_offset,
		night_record_camera_shift_seconds
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _shake_night_record_camera(strength: float) -> void:
	if not is_instance_valid(_gameplay_camera):
		return
	if is_instance_valid(_night_record_camera_tween) and _night_record_camera_tween.is_valid():
		_night_record_camera_tween.kill()
	if is_instance_valid(_night_record_camera_shake_tween) and _night_record_camera_shake_tween.is_valid():
		_night_record_camera_shake_tween.kill()
	var base_offset: Vector2 = _night_record_camera_target_offset
	var shake_directions := PackedVector2Array([
		Vector2(-1.0, 0.25),
		Vector2(0.8, -0.45),
		Vector2(-0.55, 0.4),
		Vector2(0.32, -0.2),
	])
	_night_record_camera_shake_tween = create_tween()
	for direction: Vector2 in shake_directions:
		_night_record_camera_shake_tween.tween_property(
			_gameplay_camera,
			^"offset",
			base_offset + direction * strength,
			0.045
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_night_record_camera_shake_tween.tween_property(
		_gameplay_camera,
		^"offset",
		base_offset,
		0.07
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_station_assignment_toggled(passenger_name: String, should_assign: bool) -> void:
	# Legacy/testing compatibility. The player-facing UI now applies a specific,
	# permanent station stamp through _on_station_stamp_applied().
	if state not in [GameState.DAY, GameState.SUNSET] or not _has_next_day_station() or _station_exchange_processed:
		_hud.notify("THE CURRENT STATION SERVICE RECORD IS ALREADY SEALED", 2.0)
		return
	var passenger: Passenger = _find_active_passenger_by_name(passenger_name)
	if passenger == null:
		_hud.notify("THIS PASSENGER IS NO LONGER ABOARD", 2.0)
		return
	var canonical_name: String = passenger.data.passenger_name
	var assignment_index: int = _station_assignment.find(canonical_name)
	if should_assign and _is_dropoff_locked():
		_document_overlay.configure_station_assignment(false)
		_document_overlay.configure_stamp_lock(true)
		return
	if should_assign:
		if assignment_index < 0:
			_station_assignment.append(canonical_name)
		passenger.data.stamped_station = _next_day_station()
		if passenger.data.stamp_ticket_position.is_zero_approx():
			passenger.data.stamp_ticket_position = Vector2(502.0, 152.0)
		if passenger.data.is_dead:
			_record_incorrect_anomaly(passenger.data, _next_day_station())
	else:
		if assignment_index >= 0:
			_station_assignment.remove_at(assignment_index)
		passenger.data.stamped_station = ""
		passenger.data.stamp_ticket_position = Vector2.ZERO
	_document_overlay.configure_station_assignment(_station_assignment.has(canonical_name), true)


func _on_station_stamp_applied(passenger_name: String, station_name: String, ticket_position: Vector2) -> void:
	if state not in [GameState.DAY, GameState.SUNSET] or _station_exchange_processed:
		_hud.notify("THE CURRENT STATION SERVICE RECORD IS ALREADY SEALED", 2.0)
		return
	var passenger: Passenger = _find_active_passenger_by_name(passenger_name)
	if passenger == null:
		_hud.notify("THIS PASSENGER IS NO LONGER ABOARD", 2.0)
		return
	if _is_dropoff_locked() or not day_route.has(station_name):
		_document_overlay.configure_stamp_lock(_is_dropoff_locked())
		return
	var canonical_name: String = passenger.data.passenger_name
	# Ink is permanent. Ignore duplicate drops even if input arrives twice in the
	# same frame at the end of the drag animation.
	if _station_assignment.has(canonical_name) or not passenger.data.stamped_station.is_empty():
		return
	passenger.data.stamped_station = station_name
	passenger.data.stamp_ticket_position = ticket_position
	_station_assignment.append(canonical_name)
	if passenger.data.is_dead:
		_record_incorrect_anomaly(passenger.data, station_name)
	_refresh_guidebook_progress()

func _on_newspaper_read() -> void:
	_newspaper_read = true
	_active_modal = _document_overlay
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_document_overlay.show_newspaper(_newspaper_document)

func _process_station_arrival() -> void:
	if _station_exchange_processed or not _station_arrival_announced or not _has_next_day_station():
		return
	var arrival_station: String = _next_day_station()
	var is_terminal_arrival: bool = _route_index == day_route.size() - 2
	_station_exchange_processed = true

	var departing: Array[Passenger] = []
	for assigned_name: String in _station_assignment:
		var assigned_passenger: Passenger = _find_active_passenger_by_name(assigned_name)
		if (
			assigned_passenger != null
			and assigned_passenger.data.is_dead
			and assigned_passenger.data.stamped_station == arrival_station
		):
			_record_incorrect_anomaly(assigned_passenger.data, arrival_station)
	if is_terminal_arrival:
		# The final configured stop ends daylight service: every living passenger leaves automatically.
		for passenger: Passenger in _passengers:
			if _is_active_passenger(passenger) and not passenger.data.is_dead:
				departing.append(passenger)
	else:
		for assigned_name: String in _station_assignment:
			var assigned_passenger: Passenger = _find_active_passenger_by_name(assigned_name)
			# Deceased passengers cannot actually leave during daylight. They remain for night service.
			if (
				assigned_passenger != null
				and not assigned_passenger.data.is_dead
				and (
					assigned_passenger.data.stamped_station == arrival_station
					or assigned_passenger.data.stamped_station.is_empty()
				)
				and not _is_dropoff_locked()
				and not departing.has(assigned_passenger)
			):
				departing.append(assigned_passenger)

	var available_boarders: Array[PassengerData] = []
	if not is_terminal_arrival:
		for data: PassengerData in _daily_manifest:
			if not data.initially_on_train and data.origin_station == arrival_station:
				available_boarders.append(data)

	var boarded: int = 0
	var departing_actors: Array[Dictionary] = []
	var boarding_actors: Array[Dictionary] = []
	for departing_passenger: Passenger in departing:
		_release_passenger_seat(departing_passenger)
		departing_actors.append(_passenger_cutscene_actor(departing_passenger))
		var required_dropoff_station: String = departing_passenger.data.get_required_day_dropoff_station()
		if required_dropoff_station == arrival_station:
			_correct_drop_offs += 1
		else:
			_wrong_drop_offs += 1
			_penalty_log.append("%s: left at %s; expected %s  (−%d Blessings)" % [
				departing_passenger.data.passenger_name, arrival_station, required_dropoff_station,
				int(_market_tool_state.get("blessings_per_wrong_dropoff")),
		])
		departing_passenger.depart_train()

	# The transition preview may be requested before later-station anomalies have
	# boarded. Once the terminal exchange has freed the living passengers' seats,
	# restore those authored anomalies so the night roster remains complete.
	if is_terminal_arrival and _debug_day_pass_override:
		_ensure_complete_debug_night_roster()

	# Station boarding is capacity-based and independent from drop-offs. A player
	# who keeps all eight opening passengers can still receive later boarders,
	# but the active roster can never exceed the configured onboard maximum.
	var available_capacity: int = maxi(
		0,
		manifest_config.maximum_onboard_passenger_count - _active_passenger_count()
	)
	while not is_terminal_arrival and boarded < available_capacity and not available_boarders.is_empty():
		var boarder_index: int = _find_next_station_boarder(available_boarders)
		if boarder_index < 0:
			break
		var boarder_data: PassengerData = available_boarders[boarder_index]
		available_boarders.remove_at(boarder_index)
		var boarding_seat: Marker2D = _find_station_boarding_seat(boarder_data.current_carriage)
		if boarding_seat == null:
			break
		var boarding_carriage: int = _train.get_passenger_carriage_number_at_world_x(boarding_seat.global_position.x)
		boarder_data.current_carriage = boarding_carriage
		var boarder: Passenger = _spawn_passenger(boarder_data, boarding_seat)
		if boarder == null:
			continue
		_stage_passenger_for_boarding(boarder, boarded)
		_interactables.append(boarder)
		boarding_actors.append(_passenger_cutscene_actor(boarder))
		boarded += 1

	var exchange_context: String = "terminal exchange" if is_terminal_arrival else "%s station exchange" % arrival_station
	_validate_active_passenger_constraints(exchange_context)
	_debug_print_active_anomaly_roster(exchange_context.to_upper())
	_refresh_player_interactables()
	_start_station_stop_cutscene(arrival_station, departing_actors, boarding_actors, is_terminal_arrival)

func _start_station_stop_cutscene(station_name: String, departing_actors: Array[Dictionary], boarding_actors: Array[Dictionary], terminal_arrival: bool = false) -> void:
	_station_cutscene_context = &"terminal_exchange" if terminal_arrival else &"station_exchange"
	_station_cutscene_timeline_complete = false
	_station_camera_return_complete = false
	# The station owns the entire background during its cinematic. This immediate
	# cleanup also covers debug skips that jump past the normal tunnel exit lead.
	_travel_background.set_tunnel_active(false, true)
	_ambience.begin_station_sequence()
	_active_modal = _station_stop_ui
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_hud.set_day_hud_visible(false)
	_hud.set_cutscene_hidden(true)
	_set_passenger_ai_enabled(false)
	_hide_gameplay_actors_for_station_cutscene()
	_set_station_foreground_hidden(true)
	var stop_timeline: Vector3 = (
		_station_stop_ui.get_terminal_timeline()
		if terminal_arrival
		else _station_stop_ui.get_stop_timeline()
	)
	_train.show_exterior_body(stop_timeline.x, stop_timeline.y, stop_timeline.z)
	_station_cinematic_view.begin(
		_gameplay_camera,
		station_name,
		_cinematic_camera_anchor
	)
	_station_stop_ui.set_station_crowd_layout(_station_cinematic_view.get_station_crowd_layout())
	if terminal_arrival:
		_station_stop_ui.play_terminal(
			departing_actors,
			_station_cutscene_door_markers(),
			_station_ambient_cutscene_actors(departing_actors)
		)
	else:
		var excluded_exchange_actors: Array = departing_actors + boarding_actors
		_station_stop_ui.play_stop(
			station_name,
			departing_actors,
			boarding_actors,
			_station_cutscene_door_markers(),
			_station_cutscene_door_rest_positions(),
			_station_ambient_cutscene_actors(excluded_exchange_actors)
		)


func _station_ambient_cutscene_actors(excluded_actors: Array = []) -> Array[Dictionary]:
	# Reuse identities that are not present in this shot. Previously departed
	# passengers may appear later as ordinary commuters, keeping every platform
	# populated without cloning someone who is aboard, boarding, or disembarking.
	var result: Array[Dictionary] = []
	var excluded_names: Dictionary = {}
	for actor_data: Dictionary in excluded_actors:
		excluded_names[String(actor_data.get("name", ""))] = true
	var active_data_ids: Dictionary = {}
	for passenger: Passenger in _passengers:
		if _is_active_passenger(passenger) and passenger.data != null:
			active_data_ids[passenger.data.get_instance_id()] = true
	for data: PassengerData in _daily_manifest:
		if (
			data == null
			or active_data_ids.has(data.get_instance_id())
			or excluded_names.has(data.passenger_name)
		):
			continue
		var actor_data: Dictionary = _passenger_data_cutscene_actor(data)
		if not actor_data.is_empty():
			result.append(actor_data)
	return result


func _passenger_data_cutscene_actor(data: PassengerData) -> Dictionary:
	var configured_scene: PackedScene = passenger_scene
	if data.identity_profile != null and data.identity_profile.passenger_scene != null:
		configured_scene = data.identity_profile.passenger_scene
	if configured_scene == null:
		return {}
	var preview := configured_scene.instantiate() as Passenger
	if preview == null:
		return {}
	preview.data = data
	preview.process_mode = Node.PROCESS_MODE_DISABLED
	preview.hide()
	_passenger_container.add_child(preview)
	var actor_data: Dictionary = preview.get_station_cutscene_visual()
	actor_data.merge({
		"name": data.passenger_name,
		"carriage": data.current_carriage,
		# A platform extra has no gameplay handoff. Zero prevents it from ever
		# being resolved as one of the real boarding Passenger nodes.
		"runtime_actor_id": 0,
	}, true)
	_passenger_container.remove_child(preview)
	preview.free()
	return actor_data


func _station_cutscene_door_markers() -> Dictionary:
	var markers: Dictionary = _train.get_passenger_door_markers()
	markers.erase(station_sign_blocked_carriage)
	return markers


func _station_cutscene_door_rest_positions() -> Dictionary:
	var positions: Dictionary = _train.get_passenger_door_station_rest_positions()
	positions.erase(station_sign_blocked_carriage)
	return positions


func _hide_gameplay_actors_for_station_cutscene() -> void:
	if _station_gameplay_actors_hidden:
		return
	# TrainOccupants follows the same station offset as Cars. Physics stays off so
	# the hidden MC cannot react to moving floor collision during the cutscene.
	_player.velocity = Vector2.ZERO
	_player.set_physics_process(false)
	_player.hide()
	# Keep the passenger layer alive beneath the train exterior. Staged boarders
	# become visible one by one at the doorway and continue walking inside the
	# coach, while passengers already aboard remain visible through its openings.
	_passenger_container.show()
	_station_gameplay_actors_hidden = true


func _set_station_foreground_hidden(value: bool) -> void:
	if value == _station_foreground_hidden:
		return
	_station_foreground_hidden = value
	_travel_foreground.set_station_hidden(value)
	if value:
		_station_railroad_was_visible = _railroad_ui_layer.visible
		_railroad_ui_layer.hide()
	else:
		_railroad_ui_layer.visible = _station_railroad_was_visible


func _restore_gameplay_actors_after_station_cutscene() -> void:
	# Normal gameplay always owns these visuals after a station sequence. Do not
	# restore a stale pre-cutscene flag, which could leave the MC hidden forever.
	if not _station_gameplay_actors_hidden:
		_player.show()
		_passenger_container.show()
		return
	# TrainOccupants follows the exterior train during the cinematic. The player
	# stayed still in local space while physics was disabled, so restoring the
	# old global coordinate here would counteract that parent motion and cause a
	# visible final camera correction as gameplay takes over.
	_player.velocity = Vector2.ZERO
	_player.set_physics_process(true)
	_player.show()
	_passenger_container.show()
	_station_gameplay_actors_hidden = false

func _on_day_intro_finished() -> void:
	if state != GameState.OPENING:
		return
	var boarding_actors: Array[Dictionary] = []
	for passenger: Passenger in _passengers:
		if _is_active_passenger(passenger) and passenger.data.origin_station == day_route[0]:
			boarding_actors.append(_passenger_cutscene_actor(passenger))
	_station_cutscene_context = &"opening"
	_station_cutscene_timeline_complete = false
	_station_camera_return_complete = false
	_ambience.begin_station_sequence()
	_active_modal = _station_stop_ui
	_hud.set_cutscene_hidden(true)
	_hide_gameplay_actors_for_station_cutscene()
	_set_station_foreground_hidden(true)
	var opening_timeline: Vector3 = _station_stop_ui.get_opening_timeline()
	_train.show_exterior_body(opening_timeline.x, opening_timeline.y, opening_timeline.z)
	_station_cinematic_view.begin(_gameplay_camera, day_route[0], _cinematic_camera_anchor)
	_station_stop_ui.set_station_crowd_layout(_station_cinematic_view.get_station_crowd_layout())
	_station_stop_ui.play_opening(
		day_route[0],
		boarding_actors,
		_station_cutscene_door_markers(),
		_station_cutscene_door_rest_positions(),
		_station_ambient_cutscene_actors(boarding_actors)
	)

func _on_station_cutscene_timeline_changed(elapsed: float) -> void:
	_train.set_exterior_sequence_elapsed(elapsed)
	_train.set_station_arrival_progress(_station_stop_ui.get_arrival_progress())
	_train.set_station_departure_progress(_station_stop_ui.get_departure_progress())
	_station_cinematic_view.update_arrival(elapsed, _station_stop_ui.get_active_arrival_end())
	_station_stop_ui.set_world_camera_scale(_station_cinematic_view.get_active_camera_scale())
	_station_stop_ui.set_station_environment_alpha(
		_station_cinematic_view.get_station_environment_alpha()
	)


func _on_station_cutscene_camera_return_started() -> void:
	_station_cinematic_view.return_to_gameplay()


func _on_station_cutscene_skip_requested() -> void:
	_ambience.skip_station_sequence()
	if _station_cutscene_context == &"terminal_exchange":
		# The terminal skip lands on the stopped wide shot used by the paycheck.
		_station_cutscene_timeline_complete = true
		_try_complete_station_cutscene()
		return
	# Other station skips land on the exact gameplay composition on this frame.
	_station_cinematic_view.skip_to_gameplay()


func _on_station_cinematic_camera_handoff_finished() -> void:
	_station_camera_return_complete = true
	_station_stop_ui.confirm_camera_return_complete()
	if state == GameState.NIGHT_TRANSITION:
		_night_transition_ui.notify_camera_return_completed()
	_try_complete_station_cutscene()


func _on_station_cutscene_timeline_completed() -> void:
	_station_cutscene_timeline_complete = true
	_try_complete_station_cutscene()


func _on_train_exterior_fade_out_finished() -> void:
	_try_complete_station_cutscene()


func _try_complete_station_cutscene() -> void:
	if _station_cutscene_context == &"terminal_exchange":
		if _station_cutscene_timeline_complete and _station_stop_ui.visible:
			_station_stop_ui.complete_sequence(false)
		return
	if (
		_station_cutscene_timeline_complete
		and _station_camera_return_complete
		and _station_stop_ui.visible
		and _train.is_station_departure_complete()
	):
		_station_stop_ui.complete_sequence()

func _on_station_cutscene_train_motion_changed(strength: float) -> void:
	_station_cutscene_motion_strength = clampf(strength, 0.0, 1.0)
	_train.set_motion_strength(_station_cutscene_motion_strength)
	_travel_background.set_motion_strength(_station_cutscene_motion_strength)
	_travel_foreground.set_motion_strength(_station_cutscene_motion_strength)
	_ambience.motion_strength = _station_cutscene_motion_strength
	_station_stop_ui.set_departure_blocked(_ambience.is_announcement_playing())

func _on_station_cutscene_boarding_actor_entered(actor_id: int, _door_screen_position: Vector2) -> void:
	for passenger: Passenger in _boarding_passengers:
		if not is_instance_valid(passenger) or passenger.get_instance_id() != actor_id:
			continue
		if _is_active_passenger(passenger):
			# The cutscene actor carries this Passenger node's instance ID. Handoff
			# therefore reveals the exact NPC that walked in from the platform,
			# independent of animation order or a missing door marker.
			passenger.finish_boarding()
		return
	push_warning("Station boarding handoff could not find runtime passenger %d." % actor_id)

func _on_station_stop_finished() -> void:
	var finished_context: StringName = _station_cutscene_context
	_station_cutscene_context = &""
	_station_cutscene_timeline_complete = false
	_station_camera_return_complete = false
	_ambience.end_station_sequence()
	if finished_context == &"terminal_exchange":
		# Preserve the stopped exterior train and wide station camera beneath the
		# paycheck. Continue resumes this exact shot into the veil transition.
		_finish_staged_boarding()
		if _active_modal == _station_stop_ui:
			_active_modal = null
		_route_index += 1
		_hud.set_clock_progress(_day_station_clock_progress(), true)
		_terminal_station_waiting_for_night_transition = true
		_train.set_station_arrival_progress(1.0)
		_train.set_station_departure_progress(0.0)
		_set_train_stopped_for_night_transition()
		_hud.set_cutscene_hidden(true)
		_travel_background.set_tunnel_active(false, true)
		_update_passenger_minimap()
		_finalize_day_shift()
		return
	_train.hide_exterior_body()
	_station_cinematic_view.finish()
	_set_station_foreground_hidden(false)
	_restore_gameplay_actors_after_station_cutscene()
	_finish_staged_boarding()
	_hud.set_cutscene_hidden(false)
	if _active_modal == _station_stop_ui:
		_active_modal = null
	if finished_context == &"opening":
		state = GameState.DAY
		_hud.set_day_hud_visible(true)
		_hud.show_route_briefing()
		_update_passenger_minimap()
		_set_passenger_ai_enabled(true)
		if _show_level_start_hint_if_needed():
			return
		_set_player_control_for_state()
		_schedule_maintenance_events()
		return
	_route_index += 1
	_hud.set_clock_progress(_day_station_clock_progress(), true)
	if not _has_next_day_station():
		_travel_background.set_tunnel_active(false, true)
		_update_passenger_minimap()
		_finalize_day_shift()
		return
	_travel_background.begin_route_leg(_route_index)
	_hud.set_next_stop(_next_day_station())
	_station_arrival_announced = false
	_station_exchange_processed = false
	if state in [GameState.DAY, GameState.SUNSET]:
		_hud.set_day_hud_visible(true)
		_hud.show_route_briefing()
	_update_passenger_minimap()
	_set_player_control_for_state()
	_schedule_maintenance_events()


func _on_train_station_travel_offset_changed(offset: Vector2) -> void:
	_train_occupants.position = _train_occupants_station_rest_position + offset
	_station_cinematic_view.sync_follow_target()

func _passenger_cutscene_actor(passenger: Passenger) -> Dictionary:
	var actor_data: Dictionary = passenger.get_station_cutscene_visual()
	actor_data.merge({
		"name": passenger.data.passenger_name,
		"carriage": passenger.get_runtime_carriage(),
		"runtime_actor_id": passenger.get_instance_id(),
	}, true)
	return actor_data

func _find_next_station_boarder(boarders: Array[PassengerData]) -> int:
	# Board scheduled anomalies first so available capacity preserves the night roster.
	for i: int in range(boarders.size()):
		if boarders[i].is_dead and _can_add_passenger_without_trait_overflow(boarders[i]):
			return i
	for i: int in range(boarders.size()):
		if _can_add_passenger_without_trait_overflow(boarders[i]):
			return i
	return -1

func _open_guidebook() -> void:
	_active_modal = _guidebook_ui
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_guidebook_ui.open_guidebook(
		day_number,
		manifest_config.service_train_number,
		manifest_config.service_date_text,
		manifest_config.ticket_day_code,
		day_route,
		_newspaper_document if _newspaper_read else "",
		_route_index,
		_get_day_pass_target()
	)
	_refresh_guidebook_progress()


func _refresh_guidebook_progress() -> void:
	var earnings: Dictionary = _market_tool_state.call(
		&"preview_day_blessings",
		_correct_drop_offs,
		_wrong_drop_offs,
		_incorrectly_stamped_anomalies.size(),
		_get_day_pass_target()
	)
	var boarded_today: int = 0
	var aboard: int = 0
	var stamped_aboard: int = 0
	for passenger: Passenger in _passengers:
		if not is_instance_valid(passenger) or passenger.boarding_staged:
			continue
		# Departed passengers remain in this shift's roster and cumulative total.
		boarded_today += 1
		if passenger.departed:
			continue
		aboard += 1
		if _station_assignment.has(passenger.data.passenger_name):
			stamped_aboard += 1
	_guidebook_ui.update_shift_progress(_route_index, int(earnings.net_earnings), aboard, boarded_today, stamped_aboard)


func _toggle_guidebook() -> void:
	if _guidebook_ui.visible:
		_guidebook_ui.request_close()
	elif (
		not _service_seal_active
		and _active_modal == null
		and state in [GameState.DAY, GameState.SUNSET, GameState.NIGHT]
	):
		_open_guidebook()


func _on_guidebook_requested() -> void:
	_toggle_guidebook()


func _on_debug_night_requested() -> void:
	if not OS.is_debug_build() or state not in [GameState.DAY, GameState.SUNSET] or _active_modal != null:
		return
	_clear_day_distractions_for_debug()
	_debug_day_pass_override = true
	_route_index = maxi(day_route.size() - 2, 0)
	_day_minutes = _final_arrival_minutes()
	_station_assignment.clear()
	_station_arrival_announced = true
	_station_exchange_processed = false
	_shift_report_finalized = false
	_process_station_arrival()
	_refresh_player_interactables(true)
	_update_passenger_minimap()


func _jump_directly_to_debug_night() -> void:
	_prepare_debug_night_roster()
	_route_index = maxi(day_route.size() - 1, 0)
	_day_minutes = _final_arrival_minutes()
	_station_assignment.clear()
	_station_arrival_announced = false
	_station_exchange_processed = true
	_enter_night()
	_refresh_player_interactables(true)
	_update_passenger_minimap()


func _prepare_debug_night_roster() -> void:
	_clear_day_distractions_for_debug()

	# A direct jump has no terminal exchange to remove ordinary passengers.
	for passenger: Passenger in _passengers:
		if _is_active_passenger(passenger) and not passenger.data.is_dead:
			_release_passenger_seat(passenger)
			passenger.depart_train()
	_ensure_complete_debug_night_roster()
	_set_passenger_ai_enabled(false)


func _clear_day_distractions_for_debug() -> void:
	_blocked_aisle_timer.stop()
	_dirty_seat_timer.stop()
	_radar_scan_active = false
	_hud.set_radar_active(false)
	_train.clear_radar_anomaly_signals(true)
	for event: Node in _blocked_aisle_events:
		if is_instance_valid(event):
			event.call(&"set_event_active", false)
	for event: Node in _dirty_seat_events:
		if is_instance_valid(event):
			event.call(&"set_event_active", false)
	_active_blocked_aisle_event = null
	_active_dirty_seat_event = null
	_train.clear_blocked_connector_effect(true)
	_hud.set_maintenance_targets([])
	_set_service_sealed(false, true)
	_finish_staged_boarding()



func _ensure_complete_debug_night_roster() -> void:
	# Some anomalies are scheduled to board at later stations. Add them now so
	# this shortcut always opens the complete authored night case.
	for data: PassengerData in _daily_manifest:
		if not data.is_dead or _find_active_passenger_by_name(data.passenger_name) != null:
			continue
		var seat_slot: Marker2D = _find_station_boarding_seat(data.current_carriage)
		if seat_slot == null:
			push_warning("Debug Night Shift could not find a seat for %s." % data.passenger_name)
			continue
		data.current_carriage = _train.get_passenger_carriage_number_at_world_x(seat_slot.global_position.x)
		var passenger: Passenger = _spawn_passenger(data, seat_slot)
		if passenger == null:
			continue
		passenger.randomize_initial_activity()
		_interactables.append(passenger)


func _on_market_tool_requested(tool_id: StringName) -> void:
	if (
		_service_seal_active
		or _active_modal != null
		or state not in [GameState.DAY, GameState.SUNSET, GameState.NIGHT]
	):
		return
	match tool_id:
		TOOL_VEIL_NOTE:
			if state != GameState.NIGHT:
				_hud.notify("VEIL NOTE CAN ONLY BE OPENED DURING NIGHT SHIFT", 2.5)
			else:
				_use_veil_note()
		TOOL_RADAR_CHARGE:
			if not _radar_scan_active:
				_use_carriage_radar()
		TOOL_SWIFTSTEP:
			_use_swiftstep()

func _on_modal_closed() -> void:
	if is_instance_valid(_inspected_passenger):
		_inspected_passenger.set_inspection_paused(false)
	_inspected_passenger = null
	# A newspaper may still be descending after the station sequence has begun.
	if _active_modal not in [_document_overlay, _guidebook_ui]:
		return
	_active_modal = null
	_set_player_control_for_state()

func _open_pause() -> void:
	if _pause_ui.visible:
		return
	_modal_before_pause = _active_modal
	_active_modal = _pause_ui
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_pause_ui.set_night_mode(state == GameState.NIGHT)
	_pause_ui.open_pause()
	get_tree().paused = true

func _resume_from_pause() -> void:
	get_tree().paused = false
	_pause_ui.hide()
	_active_modal = _modal_before_pause if is_instance_valid(_modal_before_pause) and _modal_before_pause.visible else null
	_modal_before_pause = null
	_set_player_control_for_state()

func _normalize_name(value: String) -> String:
	return " ".join(value.strip_edges().to_lower().split(" ", false))

func _finalize_day_shift() -> void:
	if _shift_report_finalized:
		return
	_shift_report_finalized = true
	_train.clear_blocked_connector_effect(true)
	_retained_anomalies = 0
	for data: PassengerData in _get_dead_passenger_data():
		if not _incorrectly_stamped_anomalies.has(data.passenger_name):
			_retained_anomalies += 1
	_set_train_stopped_for_night_transition()
	state = GameState.SHIFT_REPORT
	_set_service_sealed(false)
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_hud.set_day_hud_visible(false)
	_day_blessing_award = _market_tool_state.call(
		&"award_day_blessings",
		_correct_drop_offs,
		_wrong_drop_offs,
		_incorrectly_stamped_anomalies.size(),
		_get_day_pass_target()
	)
	if _debug_day_pass_override:
		# This temporary route exists to preview the terminal-to-night cutscene.
		# Preserve the real paycheck figures while bypassing its pass gate.
		_day_blessing_award["passed"] = true
		_day_blessing_award["debug_pass_override"] = true
	_active_modal = _shift_report_ui
	_shift_report_ui.open_report(day_number, _retained_anomalies, _get_dead_passenger_data().size(), _penalty_log, _day_blessing_award)

func _get_day_pass_target() -> int:
	if day_pass_targets.is_empty():
		return 100
	return maxi(0, day_pass_targets[clampi(day_number - 1, 0, day_pass_targets.size() - 1)])

func _on_shift_report_continue() -> void:
	if state == GameState.COMPLETE:
		_continue_after_night_paycheck()
		return
	if state != GameState.SHIFT_REPORT:
		return
	if not bool(_day_blessing_award.get("passed", false)):
		_restart_game()
		return
	_shift_report_ui.hide()
	_debug_day_pass_override = false
	_start_night_transition()


func _start_night_transition() -> void:
	state = GameState.NIGHT_TRANSITION
	_night_transition_camera_return_requested = false
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_hud.set_cutscene_hidden(true)
	_active_modal = _night_transition_ui
	_resume_train_for_night()
	_night_transition_ui.play_transition()


func _on_night_transition_timeline_changed(_elapsed: float) -> void:
	if state != GameState.NIGHT_TRANSITION or not _terminal_station_waiting_for_night_transition:
		return
	_train.set_station_arrival_progress(1.0)
	_train.set_station_departure_progress(
		_night_transition_ui.get_station_departure_progress()
	)
	_station_cinematic_view.set_transition_environment_alpha(
		_night_transition_ui.get_station_environment_alpha()
	)


func _on_night_transition_departure_follow_requested() -> void:
	if state != GameState.NIGHT_TRANSITION or not _terminal_station_waiting_for_night_transition:
		return
	_station_cinematic_view.begin_departure_follow()


func _on_night_transition_camera_return_requested() -> void:
	if state != GameState.NIGHT_TRANSITION or _night_transition_camera_return_requested:
		return
	_night_transition_camera_return_requested = true
	_station_camera_return_complete = false
	_station_cinematic_view.return_to_gameplay()
	# Debug previews and isolated test routes can enter the transition without a
	# stopped station camera beneath them. In that case there is no exterior
	# handoff to await, so let the staged transition continue immediately.
	if not _station_cinematic_view.has_active_camera_handoff():
		_station_camera_return_complete = true
		_night_transition_ui.notify_camera_return_completed()


func _on_night_transition_veil_crossed() -> void:
	_prepare_night_world()


func _on_night_transition_whiteout_reached() -> void:
	if state != GameState.NIGHT_TRANSITION:
		return
	# The market belongs inside the whiteout. The player never sees the night
	# world swap; it is prepared behind the veil while the market is open.
	_open_night_market()


func _on_night_transition_finished() -> void:
	if state != GameState.NIGHT_TRANSITION:
		return
	_active_modal = null
	_finish_terminal_night_transition_world()
	_enter_night(false, false)
	_hud.set_cutscene_hidden(false)
	_hud.notify(night_shift_instruction, 5.0)
	_set_player_control_for_state()


func _finish_terminal_night_transition_world() -> void:
	if not _terminal_station_waiting_for_night_transition:
		return
	if not _station_camera_return_complete:
		_station_cinematic_view.skip_to_gameplay()
	_train.hide_exterior_body()
	_station_cinematic_view.finish()
	_set_station_foreground_hidden(false)
	_restore_gameplay_actors_after_station_cutscene()
	_finish_staged_boarding()
	_terminal_station_waiting_for_night_transition = false
	_update_passenger_minimap()


func _open_night_market() -> void:
	# The market appears while the transition is still a full white screen. This
	# keeps the world conversion and camera handoff hidden behind the veil.
	state = GameState.MARKET
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_active_modal = _night_market_ui
	_night_market_ui.call(
		&"open_market",
		_market_tool_state.call(&"get_snapshot"),
		_day_blessing_award
	)


func _on_market_purchase_requested(tool_id: StringName) -> void:
	if state != GameState.MARKET:
		return
	var result: Dictionary = _market_tool_state.call(&"purchase", tool_id)
	_night_market_ui.call(
		&"show_purchase_result",
		result,
		_market_tool_state.call(&"get_snapshot")
	)


func _on_night_market_continue() -> void:
	if state != GameState.MARKET:
		return
	# Market fog clears back to the frozen white transition. Hold there briefly,
	# then let the cutscene reveal the prepared night carriage and camera.
	state = GameState.NIGHT_TRANSITION
	_active_modal = _night_transition_ui
	_night_market_ui.call(&"release_transition_fog")
	var fog_release_seconds: float = maxf(
		float(_night_market_ui.get("transition_fog_release_duration")),
		0.05
	)
	await get_tree().create_timer(fog_release_seconds, false).timeout
	if state != GameState.NIGHT_TRANSITION:
		return
	_night_transition_ui.resume_after_market()


func _on_market_inventory_changed(snapshot: Dictionary) -> void:
	_hud.set_market_tool_inventory(snapshot)
	if is_instance_valid(_night_market_ui) and _night_market_ui.visible:
		_night_market_ui.call(&"set_snapshot", snapshot)


func _use_veil_note() -> void:
	var snapshot: Dictionary = _market_tool_state.call(&"get_snapshot")
	if int(snapshot.get("veil_notes", 0)) <= 0:
		_hud.notify("NO VEIL NOTE REMAINS", 2.5)
		return
	if not _collected_veil_note_statement.is_empty():
		_hud.notify("THIS NIGHT'S VEIL NOTE HAS ALREADY BEEN RECORDED", 2.5)
		return
	var puzzle: DeparturePuzzleData = _get_departure_puzzle()
	if puzzle == null:
		_hud.notify("THE VEIL NOTE CANNOT FIND THIS NIGHT'S PATH", 2.5)
		return
	var extra_statement: String = puzzle.get_veil_note_statement()
	if extra_statement.is_empty():
		_hud.notify("THE VEIL NOTE IS BLANK", 2.5)
		return
	if not bool(_market_tool_state.call(&"consume_veil_note")):
		return
	GameSFX.play(&"paper_rustle", -5.0, 1.0, 0.025, 0.15)
	_collected_veil_note_statement = extra_statement
	_night_puzzle_ui.set_veil_note_statement(_collected_veil_note_statement)
	_active_modal = _veil_note_reveal_ui
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	var target_position: Vector2 = _hud.get_night_ledger_button_center()
	if not bool(_veil_note_reveal_ui.call(&"play_reveal", extra_statement, target_position)):
		_active_modal = null
		_set_player_control_for_state()


func _on_veil_note_reveal_finished() -> void:
	if _active_modal == _veil_note_reveal_ui:
		_active_modal = null
	_set_player_control_for_state()


func _use_swiftstep() -> void:
	var snapshot: Dictionary = _market_tool_state.call(&"get_snapshot")
	var swift_charges: int = int(snapshot.get("swift_charges", 0))
	if swift_charges <= 0:
		_hud.notify("NO SWIFTSTEP SOLES OWNED", 2.5)
		return
	if _swiftstep_active:
		_hud.notify("SWIFTSTEP IS ALREADY BENDING TIME", 2.0)
		return
	if not bool(_market_tool_state.call(&"consume_swift_charge")):
		return
	_swiftstep_active = true
	GameSFX.play(&"time_warp", -5.0, 1.0, 0.02, 0.3)
	_hud.set_swiftstep_active(true)
	var next_time_scale: float = float(_swiftstep_effect_ui.call(&"activate", _player))
	_set_world_time_scale(next_time_scale)
	_hud.notify(
		"SWIFTSTEP SOLES ACTIVE\nTHE WORLD YIELDS FOR 15 SECONDS",
		2.75
	)


func _on_swiftstep_effect_finished() -> void:
	_set_world_time_scale(1.0)
	_swiftstep_active = false
	_hud.set_swiftstep_active(false)


func _set_world_time_scale(value: float) -> void:
	var previous_scale: float = _world_time_scale
	_world_time_scale = clampf(value, 0.05, 1.0)
	_train.set_world_time_scale(_world_time_scale)
	_travel_background.set_world_time_scale(_world_time_scale)
	_travel_foreground.set_world_time_scale(_world_time_scale)
	_ambience.set_world_time_scale(_world_time_scale)
	for passenger: Passenger in _passengers:
		if is_instance_valid(passenger):
			passenger.set_world_time_scale(_world_time_scale)
	_rescale_running_timer(_blocked_aisle_timer, previous_scale, _world_time_scale)
	_rescale_running_timer(_dirty_seat_timer, previous_scale, _world_time_scale)


func _rescale_running_timer(timer: Timer, previous_scale: float, next_scale: float) -> void:
	if not is_instance_valid(timer) or timer.is_stopped():
		return
	var world_seconds_remaining: float = timer.time_left * maxf(previous_scale, 0.05)
	timer.start(world_seconds_remaining / maxf(next_scale, 0.05))


func _use_carriage_radar() -> void:
	if _radar_scan_active:
		return
	var carriage_number: int = _train.get_passenger_carriage_number_at_world_x(_player.global_position.x)
	if carriage_number <= 0:
		_hud.notify("RADAR REQUIRES A PASSENGER COACH", 2.5)
		return
	if not _train.can_play_radar_scan(carriage_number):
		_hud.notify("RADAR ARRAY IS UNAVAILABLE IN THIS COACH", 2.5)
		return
	var snapshot: Dictionary = _market_tool_state.call(&"get_snapshot")
	if int(snapshot.get("radar_charges", 0)) <= 0:
		_hud.notify("NO RADAR CHARGES REMAINING", 3.0)
		return
	if not bool(_market_tool_state.call(&"consume_radar_charge")):
		return
	# Radar only reports whether this coach contains an anomaly. It never marks,
	# outlines, or identifies the passenger responsible for the signal.
	var anomaly_detected: bool = _carriage_has_anomaly(carriage_number)
	var radar_origin: Vector2 = _player.get_radar_origin_world_position()
	_radar_scan_active = true
	GameSFX.play(&"radar_ping", -4.0, 1.0, 0.015, 0.3)
	_hud.set_radar_active(true)

	_train.clear_radar_anomaly_signals()
	_train.play_radar_scan(carriage_number, radar_scan_seconds, radar_origin)
	await get_tree().create_timer(radar_scan_seconds, false).timeout
	if not _radar_scan_active:
		return
	if anomaly_detected:
		_train.show_radar_anomaly_signal(carriage_number, radar_anomaly_light_seconds)

	# This timer follows the normal pause state, so opening the pause menu also
	# pauses the radar phase along with the rest of gameplay.
	await get_tree().create_timer(radar_result_reveal_seconds, false).timeout

	_radar_scan_active = false
	_hud.set_radar_active(false)


func _carriage_has_anomaly(carriage_number: int) -> bool:
	for passenger: Passenger in _passengers:
		if (
			_is_active_passenger(passenger)
			and passenger.get_runtime_carriage() == carriage_number
			and passenger.data != null
			and passenger.data.is_dead
		):
			return true
	return false

func _enter_night(enable_controls: bool = true, show_instruction: bool = true) -> void:
	_prepare_night_world()
	state = GameState.NIGHT
	_night_service_elapsed_seconds = 0.0
	_night_service_expired = false
	_night_service_timeout_presented = false
	_resume_train_for_night()
	_hud.set_night_walk_mode()
	# Night Service owns the final 36-degree division. It fills continuously over
	# the three-minute service window instead of jumping straight to 180 degrees.
	_hud.set_clock_progress(_night_service_clock_progress())
	_pause_ui.set_night_mode(true)
	if show_instruction:
		_hud.notify(night_shift_instruction, 5.0)
	if enable_controls:
		_set_player_control_for_state()
	else:
		_player.movement_enabled = false
		_player.interaction_enabled = false


func _prepare_night_world() -> void:
	if _night_world_prepared:
		return
	var puzzle_template := puzzle_resource as DeparturePuzzleData
	if puzzle_template == null:
		push_error("The configured departure puzzle resource is invalid.")
		return
	_night_world_prepared = true
	_night_assignment_attempts = 0
	_runtime_puzzle = puzzle_template.create_runtime(
		_get_dead_passenger_data(),
		_daily_rng,
		day_number
	)
	_collected_departure_statements.clear()
	_collected_veil_note_statement = ""
	_train.set_night_strength(1.0)
	_ambience.night_strength = 1.0
	_travel_background.set_tunnel_active(false, true)
	_travel_background.show_night_background()
	_set_sky_cycle_progress(1.0)
	_night_atmosphere.modulate.a = 1.0
	for passenger: Passenger in _passengers:
		if _is_active_passenger(passenger):
			passenger.set_night_mode(true)

func _set_train_stopped_for_night_transition() -> void:
	_station_cutscene_motion_strength = 0.0
	_train.set_motion_strength(0.0)
	_travel_background.set_motion_strength(0.0)
	_travel_foreground.set_motion_strength(0.0)
	_ambience.pause_train_travel()

func _resume_train_for_night() -> void:
	_station_cutscene_motion_strength = 1.0
	_train.set_motion_strength(1.0)
	_travel_background.set_motion_strength(1.0)
	_travel_foreground.set_motion_strength(1.0)
	_ambience.resume_train_travel()

func _open_night_puzzle() -> void:
	state = GameState.NIGHT_PUZZLE
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_active_modal = _night_puzzle_ui
	_night_puzzle_ui.open_puzzle(
		_get_dead_passenger_data(),
		_get_departure_puzzle(),
		_collected_departure_statements,
		_collected_veil_note_statement
	)


func _on_service_action_requested() -> void:
	if _active_modal != null or _service_seal_active:
		return
	if state == GameState.NIGHT:
		_open_night_puzzle()
		return
	if (
		state in [GameState.DAY, GameState.SUNSET]
		and _has_next_day_station()
		and not _station_arrival_announced
		and not _radar_scan_active
	):
		_open_service_signature()


func _open_service_signature() -> void:
	_active_modal = _service_signature_ui
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_service_signature_ui.open_signature(
		_current_day_station(),
		_next_day_station(),
		_route_index
	)


func _on_service_signature_closed() -> void:
	if _active_modal != _service_signature_ui:
		return
	_active_modal = null
	_set_player_control_for_state()


func _on_service_signature_rejected() -> void:
	if _active_modal != _service_signature_ui:
		return
	_shake_night_record_camera(11.0)


func _on_service_signed() -> void:
	if _active_modal != _service_signature_ui or state not in [GameState.DAY, GameState.SUNSET]:
		return
	_active_modal = null
	if not _has_next_day_station() or _station_arrival_announced:
		_set_player_control_for_state()
		return
	_day_minutes = _next_arrival_minutes()
	_update_day_route_presentation()
	_announce_next_station()

func _close_night_puzzle() -> void:
	_night_puzzle_ui.hide()
	_active_modal = null
	state = GameState.NIGHT
	_set_player_control_for_state()

func _on_departures_confirmed(assignments: Dictionary) -> void:
	var puzzle: DeparturePuzzleData = _get_departure_puzzle()
	if puzzle == null:
		_night_puzzle_ui.show_error("The night assignment manifest is unavailable.")
		return
	_night_assignment_attempts += 1
	var station_results: Dictionary = {}
	for station: String in puzzle.night_stations:
		var expected_passengers: Array[String] = puzzle.get_expected_passengers_for_station(station)
		var assigned_passengers: Array[String] = _night_passengers_assigned_to(
			assignments, station
		)
		expected_passengers.sort()
		assigned_passengers.sort()
		station_results[station] = assigned_passengers == expected_passengers
	_night_puzzle_ui.play_validation(station_results, _night_assignment_attempts)


func _on_night_validation_finished(succeeded: bool, attempt_count: int) -> void:
	if state != GameState.NIGHT_PUZZLE:
		return
	if not succeeded:
		# A rejected station path restarts the playable night investigation.
		# The generated case stays the same, while its statements and placements
		# must be recovered again. The attempt counter intentionally persists.
		_collected_departure_statements.clear()
		_night_puzzle_ui.hide()
		_active_modal = null
		state = GameState.NIGHT
		_night_service_elapsed_seconds = 0.0
		_night_service_expired = false
		_night_service_timeout_presented = false
		_hud.set_clock_progress(_night_service_clock_progress(), true)
		_set_player_control_for_state()
		return
	var puzzle: DeparturePuzzleData = _get_departure_puzzle()
	if puzzle == null:
		_night_puzzle_ui.show_error("The night assignment manifest is unavailable.")
		return
	_night_service_elapsed_seconds = night_service_duration_seconds
	_night_service_expired = true
	_hud.set_clock_progress(1.0, true)
	var correct_count: int = puzzle.get_assignment_count()
	_night_blessing_award = _market_tool_state.call(
		&"award_night_blessings",
		correct_count,
		attempt_count
	)
	_hud.set_service_action_mode(true, false)
	_night_puzzle_ui.hide()
	_active_modal = _shift_report_ui
	state = GameState.COMPLETE
	var snapshot: Dictionary = _market_tool_state.call(&"get_snapshot")
	_shift_report_ui.open_night_report(
		day_number,
		correct_count,
		_night_blessing_award,
		int(snapshot.get("blessings", 0))
	)
	_save_night_completion()


func _night_assignment_contains(
	assignments: Dictionary,
	station_name: String,
	passenger_name: String
) -> bool:
	if passenger_name.is_empty():
		return false
	var assigned: Variant = assignments.get(station_name, [])
	if assigned is Array:
		return (assigned as Array).has(passenger_name)
	# Compatibility with older tests and any currently open pre-stack board.
	return str(assigned) == passenger_name


func _night_passengers_assigned_to(assignments: Dictionary, station_name: String) -> Array[String]:
	var result: Array[String] = []
	var assigned: Variant = assignments.get(station_name, [])
	if assigned is Array:
		for passenger_value: Variant in assigned:
			var passenger_name: String = str(passenger_value)
			if not passenger_name.is_empty() and not result.has(passenger_name):
				result.append(passenger_name)
	else:
		var legacy_name: String = str(assigned)
		if not legacy_name.is_empty():
			result.append(legacy_name)
	return result

func _get_departure_puzzle() -> DeparturePuzzleData:
	return _runtime_puzzle if _runtime_puzzle != null else puzzle_resource as DeparturePuzzleData

func _record_incorrect_anomaly(data: PassengerData, station: String) -> void:
	if _incorrectly_stamped_anomalies.has(data.passenger_name):
		return
	_incorrectly_stamped_anomalies[data.passenger_name] = true
	_penalty_log.append("%s: anomaly assigned to %s; remains aboard  (−%d Blessings)" % [
		data.passenger_name, station, int(_market_tool_state.get("blessings_per_incorrect_anomaly")),
	])


func _set_player_control_for_state() -> void:
	var can_walk: bool = (
		_active_modal == null
		and not _night_statement_active
		and state in [GameState.DAY, GameState.SUNSET, GameState.NIGHT]
	)
	_player.movement_enabled = can_walk
	_player.interaction_enabled = can_walk
	_hud.set_prompt(
		_get_nearby_interactable_prompt(_nearby_interactable) if can_walk else "",
		_get_interactable_prompt_anchor(_nearby_interactable) if can_walk else null
	)

func _update_carriage_indicator() -> void:
	if not is_instance_valid(_player):
		return
	var carriage_number: int = _train.get_nearest_carriage_number_at_world_x(_player.global_position.x)
	_hud.set_current_carriage_number(carriage_number)

func _update_passenger_minimap() -> void:
	var counts_by_carriage: Dictionary = {}
	for passenger: Passenger in _passengers:
		if not _is_active_passenger(passenger):
			continue
		var carriage_number: int = passenger.get_runtime_carriage()
		counts_by_carriage[carriage_number] = int(counts_by_carriage.get(carriage_number, 0)) + 1
	_hud.set_passenger_counts_by_carriage(counts_by_carriage)

func _set_passenger_ai_enabled(value: bool) -> void:
	for passenger: Passenger in _passengers:
		passenger.set_ai_enabled(value and passenger != _inspected_passenger)

func _is_passenger_inspection_active() -> bool:
	return (
		_active_modal == _document_overlay
		and is_instance_valid(_document_overlay)
		and bool(_document_overlay.call(&"is_showing_passenger_documents"))
	)

func _is_world_simulation_active() -> bool:
	return not get_tree().paused and _active_modal not in [
		_pause_ui,
		_day_intro_ui,
		_station_stop_ui,
		_service_signature_ui,
		_hint_ui,
	]


func _is_newspaper_active() -> bool:
	return (
		_active_modal == _document_overlay
		and is_instance_valid(_document_overlay)
		and bool(_document_overlay.call(&"is_showing_newspaper"))
	)


func _is_maintenance_minigame_active() -> bool:
	return _active_modal in [_blocked_aisle_ui, _clean_seat_ui]


func _maintenance_minigames_enabled() -> bool:
	return _blocked_aisle_enabled_for_level() or _clean_seat_enabled_for_level()


func _blocked_aisle_enabled_for_level() -> bool:
	# Level 2 introduces luggage repacking. It returns alongside cleaning from
	# level 4 onward, after each task has had a turn to be learned on its own.
	return day_number == 2 or day_number >= 4


func _clean_seat_enabled_for_level() -> bool:
	# Cleaning is introduced alone in level 3, then combines with repacking.
	return day_number >= 3


func _show_level_start_hint_if_needed() -> bool:
	if not is_instance_valid(_hint_ui):
		return false
	var hint_id: StringName = &""
	if day_number == 2:
		hint_id = &"blocked_aisle"
	elif day_number == 3:
		hint_id = &"clean_the_seat"
	if hint_id.is_empty():
		return false
	_active_modal = _hint_ui
	_player.movement_enabled = false
	_player.interaction_enabled = false
	_hud.set_prompt("")
	_hint_ui.call(&"show_hint", hint_id)
	return true


func _on_level_start_hint_dismissed() -> void:
	if _active_modal != _hint_ui:
		return
	_active_modal = null
	if state in [GameState.DAY, GameState.SUNSET]:
		_set_player_control_for_state()
		_schedule_maintenance_events()


func _is_dropoff_locked() -> bool:
	return is_instance_valid(_active_dirty_seat_event)


func _is_seat_blocked_by_maintenance(seat_marker: Marker2D) -> bool:
	if not is_instance_valid(_active_dirty_seat_event):
		return false
	return _active_dirty_seat_event.call(&"get_seat_marker") == seat_marker


func _maintenance_events_overlap(candidate: Node, active_event: Node, observer_global_x: float = NAN) -> bool:
	if not is_instance_valid(candidate) or not is_instance_valid(active_event):
		return false
	if not candidate.has_method(&"get_maintenance_bounds") or not active_event.has_method(&"get_maintenance_bounds"):
		return false
	var candidate_bounds: Rect2 = candidate.call(&"get_maintenance_bounds", observer_global_x) as Rect2
	var active_bounds: Rect2 = active_event.call(&"get_maintenance_bounds") as Rect2
	if candidate_bounds.size == Vector2.ZERO or active_bounds.size == Vector2.ZERO:
		return false
	return candidate_bounds.grow(maintenance_event_clearance).intersects(active_bounds, true)

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
		if _is_active_passenger(passenger) and passenger.data.is_dead:
			result.append(passenger.data)
	return result

func _save_night_completion() -> void:
	if state != GameState.COMPLETE or _progress_advanced:
		return
	var next_checkpoint: Dictionary = ShiftProgress.make_checkpoint(
		mini(day_number + 1, ShiftProgress.DAY_COUNT),
		_market_tool_state.call(&"get_snapshot"), ShiftProgress.new_seed()
	)
	next_checkpoint.completed = day_number >= ShiftProgress.DAY_COUNT
	_progress_advanced = ShiftProgress.save_checkpoint(next_checkpoint)


func _continue_after_night_paycheck() -> void:
	if not _progress_advanced:
		_save_night_completion()
		if not _progress_advanced:
			return
	if day_number >= ShiftProgress.DAY_COUNT:
		_return_to_main_menu()
	else:
		get_tree().reload_current_scene()


func _restart_game() -> void:
	if ShiftProgress.save_checkpoint(_shift_checkpoint):
		get_tree().paused = false
		get_tree().reload_current_scene()

func _return_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
