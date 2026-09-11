@tool
class_name TutorialDirector
extends Control
## Interactive onboarding layer that teaches the current game systems in-place.

const ShiftProgress = preload("res://scripts/systems/shift_progress.gd")
const GAME_SCENE_PATH := "res://scenes/main/main.tscn"

signal tutorial_finished

enum Step {
	INACTIVE,
	INTRO,
	MOVEMENT_INTRO,
	MOVEMENT,
	MOVEMENT_SUCCESS,
	HUD_INTRO,
	HUD_MINIMAP,
	HUD_CLOCK,
	BLESSINGS,
	PASSENGER_REVEAL,
	PASSENGER_INTRO,
	PASSENGER_PROMPT,
	PASSENGER,
	DOCUMENTS,
	PRESS_Q,
	DOCUMENT_TICKET,
	STAMP_GUIDE,
	STAMP_RETRY,
	NICE_WORK,
	STAMP_CLOSE,
	ANOMALY,
	ANOMALY_INTRO,
	GUIDEBOOK_PROMPT,
	GUIDEBOOK,
	GUIDEBOOK_TODAY,
	GUIDEBOOK_RULES,
	GUIDEBOOK_ANOMALY,
	NEWSPAPER_PROMPT,
	NEWSPAPER,
	SIGNATURE_PROMPT,
	SIGNATURE,
	DAY_SERVICE,
	NIGHT_MARKET,
	NIGHT_WELCOME,
	NIGHT_TASK,
	NIGHT_INSPECT,
	NIGHT_RECORD_INTRO,
	NIGHT_RECORD_FIND,
	NIGHT_RECORD_CLICK,
	NIGHT_LEDGER_SAVED,
	NIGHT_LEDGER_PROMPT,
	NIGHT_MAP_INTRO,
	NIGHT_MAP_ASSIGN,
	NIGHT_MAP_RETRY,
	NIGHT_COMPLETE,
	EXAM_INTRO,
	EXAM_BRIEF,
	EXAM_ACTIVE,
	EXAM_SUCCESS,
	EXAM_SIGN_INTRO,
	EXAM_SIGN,
	EXAM_TRAVEL,
	PAYCHECK,
	DONE,
}

@export_range(0.5, 10.0, 0.1) var movement_required_seconds: float = 3.0
@export var movement_intro_prompt: String = "Before we begin, let us make sure you can move around the carriage."
@export var movement_prompt: String = "Try walking with A / D or the Arrow Keys. Keep moving for 3 seconds."
@export var movement_success_prompt: String = "Good. You are ready to move around the train."
@export var intro_dialogue_pages: PackedStringArray = PackedStringArray([
	"Hello. I am the Inspector assigned to this train.",
	"You died before reaching your job interview. The railway is offering you a second chance.",
	"You will work here as an intern conductor. During the day, inspect passengers and decide who should leave at each station.",
	"At night, guide the souls who remain to the station where they belong. Do your work well, and this second chance is yours to keep.",
])
@export var passenger_prompt: String = "Walk to a passenger and inspect their documents with E. Their body, ID, ticket, route, and destination all matter."
@export var document_prompt: String = "Compare the passenger with their ID and ticket: portrait, name, service date, and destination. Stamp ordinary passengers only when their stop is next; keep suspicious passengers aboard for Night Service."
@export var guidebook_prompt: String = "Open the Guidebook from the lower-left button or press Tab. Today's Service shows the target, Rules explains scoring, and Anomaly Signs identifies suspicious evidence."
@export var newspaper_prompt: String = "Find and read the morning newspaper. Some anomalies are only proven by the report, especially passengers who should already be dead."
@export var signature_prompt: String = "When you are confident this route segment is done, use the service button below the Guidebook and trace the mark. In day shift it signs off the route; at night the same button opens the station path."
@export var night_prompt: String = "At night, inspect remaining souls and find their hidden Departure Statements. Click the exact sentence to add that soul to the ledger, then assign it on the station path."
@export var clean_coach_prompt: String = "This tutorial starts in a clean, empty coach so you can learn the controls safely. In a real shift, passengers will board after the opening station sequence; inspect them, stamp ordinary tickets, and keep anomalies aboard for Night Service."
@export var use_empty_coach_flow: bool = true
@export_category("Angel Intro")
@export_range(0.1, 1.5, 0.05) var angel_reveal_seconds: float = 0.4
@export_range(0.0, 3.0, 0.05) var angel_hold_seconds: float = 0.75
@export_range(0.0, 5.0, 0.1) var spotlight_search_seconds: float = 2.0
@export_category("Toony Dialogue")
@export_range(0.1, 1.0, 0.05) var bubble_pop_seconds: float = 0.42
@export_category("HUD Reveal")
@export_range(0.0, 2.0, 0.05) var hud_intro_hold_seconds: float = 0.75
@export_range(0.0, 2.0, 0.05) var minimap_reveal_hold_seconds: float = 0.5
@export_range(0.1, 2.0, 0.05) var minimap_spotlight_zoom_seconds: float = 0.6
@export_range(0.05, 0.5, 0.01) var minimap_spotlight_radius: float = 0.24
@export_range(0.0, 2.0, 0.05) var hud_feature_hold_seconds: float = 0.75
@export_range(0.1, 2.0, 0.05) var hud_feature_spotlight_zoom_seconds: float = 0.6
@export_range(0.05, 0.5, 0.01) var clock_spotlight_radius: float = 0.24
@export_range(0.05, 0.5, 0.01) var blessings_spotlight_radius: float = 0.18
@export_range(0.05, 0.5, 0.01) var stamp_button_spotlight_radius: float = 0.12
@export_range(0.1, 1.0, 0.05) var stamp_spotlight_zoom_seconds: float = 0.5
@export_range(0.1, 0.6, 0.01) var guidebook_section_spotlight_radius: float = 0.35
@export_range(8.0, 320.0, 1.0) var vanish_jump_height_pixels: float = 120.0
@export_range(0.2, 1.5, 0.05) var vanish_duration_seconds: float = 0.6
@export_category("Stamp Exam")
@export_range(30.0, 300.0, 5.0) var exam_duration_seconds: float = 120.0
@export_range(0.05, 0.5, 0.01) var exam_button_spotlight_radius: float = 0.14
@export var exam_passenger_names: PackedStringArray = PackedStringArray([
	"Abby", "Reff", "Ratta", "Denta", "Mecca",
])
@export var exam_anomaly_names: PackedStringArray = PackedStringArray(["Abby", "Mecca"])
@export_category("Night Service Lesson")
@export var night_prefilled_soul_name: String = "Abby"
@export var night_inspection_soul_name: String = "Mecca"
@export_range(0.5, 4.0, 0.1) var night_statement_transfer_wait_seconds: float = 2.5
@export_category("Passenger Reveal")
@export var tutorial_passenger_profile: PassengerIdentityProfile
@export_range(1, 4, 1) var tutorial_passenger_carriage: int = 2
@export_range(0, 11, 1) var tutorial_passenger_seat_index: int = 5
@export_range(0.0, 2.0, 0.05) var passenger_spawn_hold_seconds: float = 0.5
@export_range(0.1, 2.0, 0.05) var passenger_camera_move_seconds: float = 1.2
@export_range(0.1, 1.5, 0.05) var passenger_spawn_animation_seconds: float = 0.55
@export_range(8.0, 160.0, 1.0) var passenger_spawn_jump_height: float = 54.0
@export var passenger_intro_prompt: String = "This is a passenger. Hmm, I feel like I have seen this person before."
@export var passenger_inspect_prompt: String = "Walk over and press E to inspect this passenger. Start with their face, then check their papers."
@export var anomaly_intro_dialogue_pages: PackedStringArray = PackedStringArray([
	"Not every passenger on this train is alive. Some of them died before they boarded — yet here they stand, riding alongside the living.",
	"Your job is not just to stamp tickets. **Identify** anyone who does not belong. If something feels wrong — the shadow, the face, the date — do not stamp them. Keep them aboard for Night Service.",
])
@export_range(0.0, 24.0, 0.5) var inspect_pointer_bob_distance: float = 7.0
@export_range(0.5, 5.0, 0.1) var inspect_pointer_bob_speed: float = 2.5
@export_category("Typewriter")
@export_range(20.0, 240.0, 5.0) var typewriter_characters_per_second: float = 90.0
@export_category("Skip Tutorial")
@export_range(0.6, 4.0, 0.1) var hold_to_skip_seconds: float = 1.5
@export_category("Editor Preview")
@export var preview_step: Step = Step.INACTIVE:
	set(value):
		preview_step = value
		if Engine.is_editor_hint() and is_node_ready():
			_preview_step_in_editor()
@export_category("Spotlight")
@export_range(0.01, 0.6, 0.005) var spotlight_radius: float = 0.125
@export_range(0.001, 0.5, 0.005) var spotlight_softness: float = 0.115
@export_range(-240.0, 240.0, 1.0) var spotlight_player_vertical_offset: float = -72.0
@export_range(0.0, 0.4, 0.01) var spotlight_inner_alpha: float = 0.0
@export_range(0.0, 1.0, 0.01) var continue_step_dim_alpha: float = 0.62
@export_range(0.0, 1.0, 0.01) var wait_step_dim_alpha: float = 0.52
@export_range(0.0, 1.0, 0.01) var movement_step_dim_alpha: float = 0.42
@export_category("Dialogue Markers")
@export_node_path("Marker2D") var default_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Default")
@export_node_path("Marker2D") var intro_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Intro")
@export_node_path("Marker2D") var movement_intro_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/MovementIntro")
@export_node_path("Marker2D") var movement_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Movement")
@export_node_path("Marker2D") var movement_success_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/MovementSuccess")
@export_node_path("Marker2D") var hud_intro_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/HudIntro")
@export_node_path("Marker2D") var hud_minimap_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/HudMinimap")
@export_node_path("Marker2D") var hud_clock_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/HudClock")
@export_node_path("Marker2D") var blessings_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Blessings")
@export_node_path("Marker2D") var passenger_intro_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/PassengerIntro")
@export_node_path("Marker2D") var passenger_prompt_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/PassengerPrompt")
@export_node_path("Marker2D") var passenger_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Passenger")
@export_node_path("Marker2D") var passenger_pointer_offset_path: NodePath = NodePath("WorldPointerSettings/PassengerOffset")
@export_node_path("Marker2D") var documents_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Documents")
@export_node_path("Marker2D") var anomaly_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Anomaly")
@export_node_path("Marker2D") var guidebook_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Guidebook")
@export_node_path("Marker2D") var newspaper_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Newspaper")
@export_node_path("Marker2D") var signature_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Signature")
@export_node_path("Marker2D") var day_service_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/DayService")
@export_node_path("Marker2D") var night_market_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/NightMarket")
@export_node_path("Marker2D") var night_walk_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/NightWalk")
@export_node_path("Marker2D") var night_record_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/NightRecord")
@export_node_path("Marker2D") var night_ledger_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/NightLedger")
@export_node_path("Marker2D") var night_map_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/NightMap")

var _main: Node
var _player: ConductorPlayer
var _hud: GameHUD
var _step: Step = Step.INACTIVE
var _walk_time: float = 0.0
var _waiting_for_continue: bool = false
var _event_log: Array[StringName] = []
var _last_event_payload: Variant
var _dialogue_tween: Tween
var _shade_material: ShaderMaterial
var _shade_alpha: float = 0.0
var _spotlight_control: Control
var _spotlight_world_target: Node2D
var _spotlight_searching: bool = false
var _spotlight_search_time: float = 0.0
var _spotlight_override_active: bool = false
var _spotlight_override_center: Vector2 = Vector2(0.5, 0.5)
var _current_spotlight_radius: float = 0.125
var _hud_reveal_token: int = 0
var _passenger_reveal_token: int = 0
var _tutorial_passenger: Passenger
var _exam_passengers: Array[Passenger] = []
var _exam_time_remaining: float = 0.0
var _exam_running: bool = false
var _passenger_pointer_target: Node2D
var _passenger_pointer_time: float = 0.0
var _portrait_base_scale: Vector2 = Vector2.ONE
var _portrait_rest_scale: Vector2 = Vector2.ONE
var _tail_base_scale: Vector2 = Vector2(-0.9, -0.9)
var _panel_base_scale: Vector2 = Vector2.ONE
var _dock_rest_scale: Vector2 = Vector2.ONE
var _intro_token: int = 0
var _intro_page_index: int = 0
var _anomaly_intro_page_index: int = 0
var _typewriter_running: bool = false
var _typewriter_characters: float = 0.0
var _skip_holding: bool = false
var _skip_elapsed: float = 0.0
var _skip_transitioning: bool = false
var _night_lesson_token: int = 0
var _night_prefilled_name: String = ""
var _night_target_name: String = ""

@onready var _shade: ColorRect = %Shade
@onready var _dialogue_dock: Control = %DialogueDock
@onready var _angel_portrait_frame: Control = %AngelPortraitFrame
@onready var _bubble_tail: TextureRect = %BubbleTail
@onready var _panel: Control = %Panel
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _body_label: Label = %BodyLabel
@onready var _hint_label: Label = %HintLabel
@onready var _continue_row: Control = %ContinueRow
@onready var _continue_button: Button = %ContinueButton
@onready var _progress_label: Label = %ProgressLabel
@onready var _arrow_label: Label = %ArrowLabel
@onready var _dialogue_frames: Control = %DialogueFrames
@onready var _passenger_pointer_offset: Marker2D = get_node_or_null(passenger_pointer_offset_path) as Marker2D
@onready var _skip_prompt: Control = %SkipPrompt
@onready var _skip_hold_ring: IntroHoldRing = %SkipHoldRing
@onready var _loading_screen: LoadingScreenUI = %LoadingScreenUI


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Engine.is_editor_hint():
		return
	_portrait_base_scale = _angel_portrait_frame.scale
	_portrait_rest_scale = _portrait_base_scale
	_tail_base_scale = _bubble_tail.scale
	_panel_base_scale = _panel.scale
	_current_spotlight_radius = spotlight_radius
	_prepare_spotlight_material()
	hide()
	_continue_button.pressed.connect(_advance_from_continue)
	_skip_prompt.gui_input.connect(_on_skip_prompt_gui_input)
	_reset_visuals()
	_skip_prompt.hide()
	# Frames stay visible in the editor as layout guides; only the game hides them.
	if is_instance_valid(_dialogue_frames):
		_dialogue_frames.hide()


func start(main_node: Node) -> void:
	_main = main_node
	_player = _main.get_node_or_null("GameplayWorld/TrainOccupants/PlayerSpawnPoint/Player") as ConductorPlayer
	_hud = _main.get_node_or_null("HUD") as GameHUD
	_set_tutorial_hud_visible(false)
	if _main.has_signal(&"tutorial_event"):
		var callback := Callable(self, &"_on_main_tutorial_event")
		if not _main.is_connected(&"tutorial_event", callback):
			_main.connect(&"tutorial_event", callback)
	var guidebook := _main.get_node_or_null("%GuidebookUI")
	if guidebook != null and guidebook.has_signal(&"section_shown"):
		var section_callback := Callable(self, &"_on_guidebook_section_shown")
		if not guidebook.is_connected(&"section_shown", section_callback):
			guidebook.connect(&"section_shown", section_callback)
	var overlay := _main.get_node_or_null("%DocumentOverlayUI")
	if overlay != null and overlay.has_signal(&"ticket_face_shown"):
		var ticket_callback := Callable(self, &"_on_ticket_face_shown")
		if not overlay.is_connected(&"ticket_face_shown", ticket_callback):
			overlay.connect(&"ticket_face_shown", ticket_callback)
	if _main.has_method(&"set_tutorial_route_time_paused"):
		_main.call(&"set_tutorial_route_time_paused", true)
	show()
	_skip_elapsed = 0.0
	_skip_holding = false
	_skip_transitioning = false
	_skip_hold_ring.progress = 0.0
	_skip_prompt.show()
	_start_intro()


func finish_tutorial() -> void:
	if _step == Step.DONE:
		return
	_step = Step.DONE
	_intro_token += 1
	_hud_reveal_token += 1
	_passenger_reveal_token += 1
	_spotlight_control = null
	_spotlight_world_target = null
	_passenger_pointer_target = null
	_spotlight_searching = false
	_spotlight_override_active = false
	_stop_typewriter()
	_set_tutorial_hud_visible(true)
	if _main != null and _main.has_method(&"set_tutorial_route_time_paused"):
		_main.call(&"set_tutorial_route_time_paused", false)
	if _main != null and _main.has_method(&"_set_player_control_for_state"):
		_main.call(&"_set_player_control_for_state")
	else:
		_set_controls(true, true)
	_reset_visuals()
	tutorial_finished.emit()
	_start_day_one()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_skip_hold(delta)
	if _skip_transitioning:
		return
	if _spotlight_searching:
		_spotlight_search_time += delta
	_update_spotlight()
	_update_passenger_pointer(delta)
	_update_typewriter(delta)
	if _exam_running:
		_update_exam_timer(delta)
	if _step != Step.MOVEMENT:
		return
	var walking := absf(Input.get_axis(&"move_left", &"move_right")) > 0.1
	if walking:
		_walk_time = minf(_walk_time + delta, movement_required_seconds)
	_progress_label.text = "%.1f / %.1f seconds" % [_walk_time, movement_required_seconds]
	if _walk_time >= movement_required_seconds:
		_show_continue_step(
			Step.MOVEMENT_SUCCESS,
			"The Inspector",
			movement_success_prompt,
			""
		)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not visible or _skip_transitioning:
		return
	if event.is_action_pressed(&"ui_cancel"):
		_begin_skip_hold()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released(&"ui_cancel"):
		_cancel_skip_hold()
		get_viewport().set_input_as_handled()
		return
	# A pointer hold starts only inside SkipPrompt, but release is observed
	# globally so leaving the prompt can never complete the skip by accident.
	var mouse_button := event as InputEventMouseButton
	if _skip_holding and mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
		_cancel_skip_hold()
		get_viewport().set_input_as_handled()
		return
	var touch := event as InputEventScreenTouch
	if _skip_holding and touch != null and not touch.pressed:
		_cancel_skip_hold()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _skip_transitioning:
		return
	if not _waiting_for_continue:
		return
	if event.is_action_pressed(&"ui_accept"):
		_advance_from_continue()
		get_viewport().set_input_as_handled()


func _on_skip_prompt_gui_input(event: InputEvent) -> void:
	if _skip_transitioning:
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		if mouse_button.pressed:
			_begin_skip_hold()
		else:
			_cancel_skip_hold()
		_skip_prompt.accept_event()
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_begin_skip_hold()
		else:
			_cancel_skip_hold()
		_skip_prompt.accept_event()


func _begin_skip_hold() -> void:
	_skip_holding = true
	_skip_elapsed = 0.0
	_skip_hold_ring.progress = 0.0


func _cancel_skip_hold() -> void:
	if _skip_transitioning:
		return
	_skip_holding = false
	_skip_elapsed = 0.0
	_skip_hold_ring.progress = 0.0


func _update_skip_hold(delta: float) -> void:
	if not _skip_holding or _skip_transitioning:
		return
	_skip_elapsed = minf(_skip_elapsed + delta, hold_to_skip_seconds)
	_skip_hold_ring.progress = _skip_elapsed / maxf(hold_to_skip_seconds, 0.001)
	if _skip_elapsed >= hold_to_skip_seconds:
		_start_day_one()


func _start_day_one() -> void:
	if _skip_transitioning:
		return
	_skip_transitioning = true
	_skip_holding = false
	_skip_hold_ring.progress = 1.0
	_skip_prompt.hide()
	_set_controls(false, false)
	_stop_typewriter()
	_intro_token += 1
	_hud_reveal_token += 1
	_passenger_reveal_token += 1
	var run_context := get_node_or_null("/root/RunContext")
	if run_context != null and run_context.has_method(&"request_standard_game"):
		run_context.call(&"request_standard_game")
	if ShiftProgress.start_new_run().is_empty():
		_skip_transitioning = false
		_skip_hold_ring.progress = 0.0
		_skip_prompt.show()
		push_error("Tutorial could not reset the run to Day 1.")
		return
	if not is_instance_valid(_loading_screen):
		_skip_transitioning = false
		_skip_hold_ring.progress = 0.0
		_skip_prompt.show()
		push_error("TutorialDirector/LoadingScreenUI scene instance is missing.")
		return
	_loading_screen.begin_loading(GAME_SCENE_PATH, 1.0, true)


func _reset_visuals() -> void:
	_intro_token += 1
	_hud_reveal_token += 1
	_passenger_reveal_token += 1
	_night_lesson_token += 1
	_spotlight_control = null
	_spotlight_world_target = null
	_passenger_pointer_target = null
	_spotlight_searching = false
	_spotlight_override_active = false
	_current_spotlight_radius = spotlight_radius
	_stop_typewriter()
	_set_spotlight_shade(0.0)
	_set_night_map_input_blocked(false)
	_dialogue_dock.hide()
	_panel.hide()
	_bubble_tail.hide()
	_arrow_label.hide()
	_progress_label.hide()
	if is_instance_valid(_continue_row):
		_continue_row.hide()
	_hint_label.text = ""
	_waiting_for_continue = false


func _start_intro() -> void:
	_set_controls(false, false)
	_intro_page_index = 0
	_intro_token += 1
	var token: int = _intro_token
	# Spotlight finds the Angel circle first. The bubble dialog only opens
	# after the circle has been on screen for the authored hold beat.
	# The dock takes its Intro frame (rect, portrait, tail) up front, so the
	# spotlight and the bubble start exactly where the scene arranges them.
	_place_dialogue_at_frame(Step.INTRO)
	# Preserve the scale authored on DialogueFrames/Intro/PortraitSpot. The
	# reveal starts at zero, then returns to this exact scene value.
	var intro_portrait_scale: Vector2 = _portrait_rest_scale
	_spotlight_control = _angel_portrait_frame
	_set_spotlight_shade(continue_step_dim_alpha)
	_spotlight_searching = spotlight_search_seconds > 0.0
	_spotlight_search_time = 0.0
	_bubble_tail.hide()
	_dialogue_dock.show()
	_panel.hide()
	_arrow_label.hide()
	_progress_label.hide()
	if is_instance_valid(_continue_row):
		_continue_row.hide()
	_hint_label.text = ""
	_waiting_for_continue = false
	_angel_portrait_frame.show()
	_angel_portrait_frame.pivot_offset = _angel_portrait_frame.size * 0.5
	_angel_portrait_frame.scale = intro_portrait_scale
	_angel_portrait_frame.modulate.a = 0.0
	if _spotlight_searching:
		while _spotlight_search_time < spotlight_search_seconds:
			await get_tree().process_frame
			if token != _intro_token or _step == Step.DONE or not is_inside_tree():
				return
		_spotlight_searching = false
	# The portrait only fades into the spotlight. The toony squash/stretch is
	# reserved for the speech bubble and never changes scene-authored portrait
	# scale or placement.
	var reveal := create_tween()
	reveal.tween_property(_angel_portrait_frame, ^"modulate:a", 1.0, angel_reveal_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_inside_tree():
		GameSFX.play(&"magic_shimmer", -14.0, 1.1, 0.05, 0.1)
	await reveal.finished
	if token != _intro_token or _step == Step.DONE or not is_inside_tree():
		return
	if angel_hold_seconds > 0.0:
		await get_tree().create_timer(angel_hold_seconds).timeout
	if token != _intro_token or _step == Step.DONE or not is_inside_tree():
		return
	# Keep the shade active for the briefing, but expose the player through
	# the shader once the Inspector's reveal beat has finished. Dialogue and
	# the other tutorial UI remain above Shade and therefore stay undimmed.
	_spotlight_control = null
	_update_spotlight()
	_show_intro_page()


func _show_intro_page() -> void:
	var body: String = "Hello. I am the Inspector assigned to this train."
	if not intro_dialogue_pages.is_empty():
		_intro_page_index = clampi(_intro_page_index, 0, intro_dialogue_pages.size() - 1)
		body = intro_dialogue_pages[_intro_page_index]
	_show_continue_step(Step.INTRO, "The Inspector", body, "")


func _start_movement_intro() -> void:
	_show_continue_step(
		Step.MOVEMENT_INTRO,
		"The Inspector",
		movement_intro_prompt,
		""
	)


func _start_movement() -> void:
	_step = Step.MOVEMENT
	_spotlight_control = null
	_waiting_for_continue = false
	_walk_time = 0.0
	_set_controls(true, false)
	# The bubble stays up while walking so the instruction remains readable.
	_show_wait_step(Step.MOVEMENT, "The Inspector", movement_prompt, "")
	_set_spotlight_shade(movement_step_dim_alpha)


func _hide_dialogue_for_task() -> void:
	_stop_typewriter()
	_waiting_for_continue = false
	_dialogue_dock.hide()
	_panel.hide()
	_bubble_tail.hide()
	_progress_label.hide()
	if is_instance_valid(_continue_row):
		_continue_row.hide()


func _show_continue_step(step: Step, speaker: String, body: String, hint: String = "") -> void:
	_step = step
	_waiting_for_continue = true
	_set_controls(false, false)
	_set_panel(speaker, body, hint, true)
	_set_spotlight_shade(continue_step_dim_alpha)
	_progress_label.hide()


func _show_wait_step(step: Step, speaker: String, body: String, hint: String = "") -> void:
	_step = step
	_waiting_for_continue = false
	_set_panel(speaker, body, hint, false)
	_set_spotlight_shade(wait_step_dim_alpha)
	_progress_label.hide()


func _begin_minimap_reveal() -> void:
	_hud_reveal_token += 1
	var token: int = _hud_reveal_token
	_waiting_for_continue = false
	_set_controls(false, false)
	_dialogue_dock.hide()
	_spotlight_control = null
	_spotlight_override_active = false
	_current_spotlight_radius = spotlight_radius
	_set_spotlight_shade(continue_step_dim_alpha)
	if hud_intro_hold_seconds > 0.0:
		await get_tree().create_timer(hud_intro_hold_seconds).timeout
	if token != _hud_reveal_token or _step != Step.HUD_INTRO or not is_inside_tree():
		return
	if is_instance_valid(_hud) and _hud.has_method(&"show_tutorial_minimap_only"):
		_hud.call(&"show_tutorial_minimap_only")
	if minimap_reveal_hold_seconds > 0.0:
		await get_tree().create_timer(minimap_reveal_hold_seconds).timeout
	if token != _hud_reveal_token or _step != Step.HUD_INTRO or not is_inside_tree():
		return
	var minimap_focus: Control
	if is_instance_valid(_hud) and _hud.has_method(&"get_tutorial_minimap_focus_control"):
		minimap_focus = _hud.call(&"get_tutorial_minimap_focus_control") as Control
	if is_instance_valid(minimap_focus):
		await _animate_spotlight_to_control(
			minimap_focus,
			minimap_spotlight_radius,
			minimap_spotlight_zoom_seconds
		)
	if token != _hud_reveal_token or _step != Step.HUD_INTRO or not is_inside_tree():
		return
	_show_continue_step(
		Step.HUD_MINIMAP,
		"Train Minimap",
		"The minimap shows each carriage and its passengers. Use it to find people quickly.",
		""
	)


func _begin_clock_reveal() -> void:
	_hud_reveal_token += 1
	var token: int = _hud_reveal_token
	_waiting_for_continue = false
	_dialogue_dock.hide()
	if hud_feature_hold_seconds > 0.0:
		await get_tree().create_timer(hud_feature_hold_seconds).timeout
	if token != _hud_reveal_token or _step != Step.HUD_MINIMAP or not is_inside_tree():
		return
	if is_instance_valid(_hud) and _hud.has_method(&"reveal_tutorial_clock"):
		_hud.call(&"reveal_tutorial_clock")
	var clock_focus: Control
	if is_instance_valid(_hud) and _hud.has_method(&"get_tutorial_clock_focus_control"):
		clock_focus = _hud.call(&"get_tutorial_clock_focus_control") as Control
	if is_instance_valid(clock_focus):
		await _animate_spotlight_to_control(
			clock_focus,
			clock_spotlight_radius,
			hud_feature_spotlight_zoom_seconds
		)
	if token != _hud_reveal_token or _step != Step.HUD_MINIMAP or not is_inside_tree():
		return
	_show_continue_step(
		Step.HUD_CLOCK,
		"Journey Clock",
		"Next, we have the clock. You have one full turn to finish your work on each route.",
		""
	)


func _begin_blessings_reveal() -> void:
	_hud_reveal_token += 1
	var token: int = _hud_reveal_token
	_waiting_for_continue = false
	_dialogue_dock.hide()
	if hud_feature_hold_seconds > 0.0:
		await get_tree().create_timer(hud_feature_hold_seconds).timeout
	if token != _hud_reveal_token or _step != Step.HUD_CLOCK or not is_inside_tree():
		return
	if is_instance_valid(_hud) and _hud.has_method(&"reveal_tutorial_blessings"):
		_hud.call(&"reveal_tutorial_blessings")
	var blessings_focus: Control
	if is_instance_valid(_hud) and _hud.has_method(&"get_tutorial_blessings_focus_control"):
		blessings_focus = _hud.call(&"get_tutorial_blessings_focus_control") as Control
	if is_instance_valid(blessings_focus):
		await _animate_spotlight_to_control(
			blessings_focus,
			blessings_spotlight_radius,
			hud_feature_spotlight_zoom_seconds
		)
	if token != _hud_reveal_token or _step != Step.HUD_CLOCK or not is_inside_tree():
		return
	_show_continue_step(
		Step.BLESSINGS,
		"Daily Blessings",
		"You need enough to pass each day of your internship. The left number is what you earned, while the right number is the required target.",
		""
	)


func _begin_passenger_reveal() -> void:
	_passenger_reveal_token += 1
	var token: int = _passenger_reveal_token
	_step = Step.PASSENGER_REVEAL
	_hide_dialogue_for_task()
	_set_controls(false, false)
	_spotlight_control = null
	_spotlight_world_target = null
	_current_spotlight_radius = spotlight_radius
	_set_spotlight_shade(continue_step_dim_alpha)
	if passenger_spawn_hold_seconds > 0.0:
		await get_tree().create_timer(passenger_spawn_hold_seconds).timeout
	if token != _passenger_reveal_token or _step != Step.PASSENGER_REVEAL or not is_inside_tree():
		return
	if _main == null or not _main.has_method(&"spawn_tutorial_passenger"):
		push_error("TutorialDirector requires Main.spawn_tutorial_passenger().")
		return
	_tutorial_passenger = _main.call(
		&"spawn_tutorial_passenger",
		tutorial_passenger_profile,
		tutorial_passenger_carriage,
		tutorial_passenger_seat_index
	) as Passenger
	if not is_instance_valid(_tutorial_passenger):
		push_error("TutorialDirector could not spawn its configured passenger.")
		return
	# The tutorial passenger is always Goat, whatever identity was staged.
	_tutorial_passenger.data.passenger_name = "Goat"
	_tutorial_passenger.data.short_name = "Goat"
	_tutorial_passenger.name = "Goat"
	_tutorial_passenger.set_ai_enabled(false)
	_tutorial_passenger.enabled = true
	var passenger_anchor: Node2D = _tutorial_passenger.get_dialogue_anchor()
	_spotlight_world_target = passenger_anchor
	# The camera glides first. Only after it arrives does the passenger spawn.
	if _main.has_method(&"focus_tutorial_camera"):
		var arrival_tween: Tween = _main.call(
			&"focus_tutorial_camera",
			passenger_anchor,
			passenger_camera_move_seconds
		) as Tween
		if is_instance_valid(arrival_tween):
			await arrival_tween.finished
	if token != _passenger_reveal_token or not is_instance_valid(_tutorial_passenger):
		return
	var rest_position: Vector2 = _tutorial_passenger.position
	var rest_scale: Vector2 = _tutorial_passenger.scale
	_tutorial_passenger.position = rest_position + Vector2(0.0, passenger_spawn_jump_height * 0.65)
	_tutorial_passenger.scale = rest_scale * Vector2(0.72, 0.22)
	_tutorial_passenger.modulate.a = 0.0
	_tutorial_passenger.show()
	var jump_duration: float = maxf(passenger_spawn_animation_seconds, 0.1)
	var rise := create_tween().set_parallel(true)
	rise.tween_property(
		_tutorial_passenger,
		^"position",
		rest_position - Vector2(0.0, passenger_spawn_jump_height),
		jump_duration * 0.56
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rise.tween_property(
		_tutorial_passenger,
		^"scale",
		rest_scale * Vector2(1.12, 0.9),
		jump_duration * 0.56
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_property(_tutorial_passenger, ^"modulate:a", 1.0, jump_duration * 0.28)
	await rise.finished
	if token != _passenger_reveal_token or not is_instance_valid(_tutorial_passenger):
		return
	var land := create_tween().set_parallel(true)
	land.tween_property(
		_tutorial_passenger,
		^"position",
		rest_position,
		jump_duration * 0.44
	).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	land.tween_property(
		_tutorial_passenger,
		^"scale",
		rest_scale,
		jump_duration * 0.44
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await land.finished
	if token != _passenger_reveal_token or _step != Step.PASSENGER_REVEAL or not is_inside_tree():
		return
	_show_continue_step(
		Step.PASSENGER_INTRO,
		"The Inspector",
		passenger_intro_prompt,
		""
	)


func _begin_passenger_inspection_task() -> void:
	_passenger_reveal_token += 1
	var token: int = _passenger_reveal_token
	_step = Step.PASSENGER
	_hide_dialogue_for_task()
	_set_controls(false, false)
	_spotlight_control = null
	_spotlight_world_target = null
	_set_spotlight_shade(0.0)
	_passenger_pointer_target = (
		_tutorial_passenger.get_dialogue_anchor()
		if is_instance_valid(_tutorial_passenger)
		else null
	)
	_passenger_pointer_time = 0.0
	_arrow_label.visible = is_instance_valid(_passenger_pointer_target)
	if _main != null and _main.has_method(&"restore_tutorial_camera"):
		_main.call(&"restore_tutorial_camera", passenger_camera_move_seconds)
	if passenger_camera_move_seconds > 0.0:
		await get_tree().create_timer(passenger_camera_move_seconds).timeout
	if token != _passenger_reveal_token or _step != Step.PASSENGER or not is_inside_tree():
		return
	_set_controls(true, true)


func _update_passenger_pointer(delta: float) -> void:
	if not _arrow_label.visible or not is_instance_valid(_passenger_pointer_target):
		return
	_passenger_pointer_time += delta
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var target_screen: Vector2 = _passenger_pointer_target.get_global_transform_with_canvas().origin
	var authored_offset: Vector2 = (
		_passenger_pointer_offset.position
		if is_instance_valid(_passenger_pointer_offset)
		else Vector2(0.0, -140.0)
	)
	var bob := Vector2(0.0, sin(_passenger_pointer_time * inspect_pointer_bob_speed * TAU) * inspect_pointer_bob_distance)
	var desired_center: Vector2 = target_screen + authored_offset + bob
	var margin := Vector2(
		maxf(_arrow_label.size.x * 0.5 + 18.0, 48.0),
		maxf(_arrow_label.size.y * 0.5 + 18.0, 48.0)
	)
	var clamped_center := Vector2(
		clampf(desired_center.x, margin.x, viewport_size.x - margin.x),
		clampf(desired_center.y, margin.y, viewport_size.y - margin.y)
	)
	_arrow_label.global_position = clamped_center - _arrow_label.size * 0.5
	if clamped_center.distance_to(desired_center) > 1.0:
		_arrow_label.rotation = (desired_center - clamped_center).angle() - PI * 0.5
	else:
		_arrow_label.rotation = 0.0

## Stamp exam: five souls board in front of the player, three ordinary and
## two anomalies. Two minutes, then the exam restarts on failure.
func _start_exam() -> void:
	if _exam_passengers.is_empty():
		var group: Array = []
		if _main != null and _main.has_method(&"spawn_tutorial_exam_group"):
			group = _main.call(
				&"spawn_tutorial_exam_group",
				exam_passenger_names,
				exam_anomaly_names
			)
		for passenger: Passenger in group:
			if is_instance_valid(passenger):
				_exam_passengers.append(passenger)
		_animate_exam_group_spawn()
	_restart_tutorial_exam()


func _restart_tutorial_exam() -> void:
	if _main != null and _main.has_method(&"reset_tutorial_exam_group"):
		_main.call(&"reset_tutorial_exam_group", _exam_passengers)
	elif _main != null and _main.has_method(&"_on_station_assignment_toggled"):
		for passenger: Passenger in _exam_passengers:
			if (
				is_instance_valid(passenger)
				and passenger.data != null
				and not passenger.data.stamped_station.is_empty()
			):
				_main.call(
					&"_on_station_assignment_toggled",
					passenger.data.passenger_name,
					false
				)
	_exam_time_remaining = exam_duration_seconds
	_exam_running = false
	if is_instance_valid(_hud) and _hud.has_method(&"set_clock_progress"):
		_hud.call(&"set_clock_progress", 0.0)
	_progress_label.hide()
	_show_continue_step(
		Step.EXAM_INTRO,
		"The Inspector",
		"Good. Now I will test how thorough you are. Five souls will board in front of you.",
		""
	)


func _animate_exam_group_spawn() -> void:
	for index: int in range(_exam_passengers.size()):
		var passenger: Passenger = _exam_passengers[index]
		if not is_instance_valid(passenger):
			continue
		var rest_position: Vector2 = passenger.position
		var rest_scale: Vector2 = passenger.scale
		passenger.position = rest_position + Vector2(0.0, 34.0)
		passenger.scale = rest_scale * Vector2(0.72, 0.18)
		passenger.modulate.a = 0.0
		var delay: float = float(index) * 0.07
		var pop := create_tween().set_parallel(true)
		pop.tween_property(passenger, ^"position", rest_position, 0.45).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(passenger, ^"scale", rest_scale, 0.45).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(passenger, ^"modulate:a", 1.0, 0.18).set_delay(delay)


func _begin_exam_brief() -> void:
	_exam_running = false
	_show_continue_step(
		Step.EXAM_BRIEF,
		"Stamp Test",
		"Stamp every passenger except the anomalies; two of these five souls are not what they seem. You have 2 minutes—one full clock turn.",
		""
	)


func _begin_exam_task() -> void:
	_exam_time_remaining = exam_duration_seconds
	_exam_running = true
	_step = Step.EXAM_ACTIVE
	_hide_dialogue_for_task()
	if _main != null and _main.has_method(&"release_tutorial_modal"):
		_main.call(&"release_tutorial_modal")
	if is_instance_valid(_hud) and _hud.has_method(&"set_clock_progress"):
		_hud.call(&"set_clock_progress", 0.0)
	_set_controls(true, true)


func _update_exam_timer(delta: float) -> void:
	if _step != Step.EXAM_ACTIVE:
		return
	_exam_time_remaining = maxf(0.0, _exam_time_remaining - delta)
	if is_instance_valid(_hud) and _hud.has_method(&"set_clock_progress"):
		_hud.call(&"set_clock_progress", 1.0 - _exam_time_remaining / maxf(exam_duration_seconds, 0.001))
	_update_exam_timer_label()
	if _exam_time_remaining <= 0.0:
		_restart_tutorial_exam()


func _update_exam_timer_label() -> void:
	if not is_instance_valid(_progress_label):
		return
	var total_seconds: int = maxi(0, int(ceil(_exam_time_remaining)))
	_progress_label.text = "TIME LEFT %d:%02d" % [total_seconds / 60, total_seconds % 60]


func _on_exam_stamp(payload: Variant) -> void:
	if _step != Step.EXAM_ACTIVE or not _exam_running:
		return
	var station: String = str((payload as Dictionary).get("station", "")) if payload is Dictionary else ""
	var offender: Passenger = null
	var correct_count: int = 0
	for passenger: Passenger in _exam_passengers:
		if not is_instance_valid(passenger) or passenger.data == null:
			continue
		if passenger.data.stamped_station.is_empty():
			continue
		if passenger.data.anomaly_type != "none":
			offender = passenger
			break
		if passenger.data.stamped_station == passenger.data.destination_station:
			correct_count += 1
		else:
			offender = passenger
			break
	if offender != null:
		if _main != null and _main.has_method(&"shake_tutorial_camera"):
			_main.call(&"shake_tutorial_camera")
		_restart_tutorial_exam()
		return
	var ordinary_total: int = 0
	for passenger: Passenger in _exam_passengers:
		if (
			is_instance_valid(passenger)
			and passenger.data != null
			and passenger.data.anomaly_type == "none"
		):
			ordinary_total += 1
	if ordinary_total > 0 and correct_count >= ordinary_total:
		_exam_running = false
		_progress_label.hide()
		_show_continue_step(
			Step.EXAM_SUCCESS,
			"The Inspector",
			"Good job. You are now 50 percent ready to begin your internship.",
			""
		)


func _enter_exam_sign_intro() -> void:
	if _main != null and _main.has_method(&"release_tutorial_modal"):
		_main.call(&"release_tutorial_modal")
	if is_instance_valid(_hud) and _hud.has_method(&"set_service_action_mode"):
		_hud.call(&"set_service_action_mode", false, true)
	var service_button := _hud.get_node_or_null("%ServiceActionButton") as Control if is_instance_valid(_hud) else null
	if service_button != null:
		service_button.visible = true
		service_button.modulate.a = 0.0
		var fade := create_tween()
		fade.tween_property(service_button, ^"modulate:a", 1.0, 0.5)
	_show_continue_step(
		Step.EXAM_SIGN_INTRO,
		"Sign Service",
		"I know many workers finish their assignments early, so I prepared this for you.",
		""
	)


func _enter_exam_sign() -> void:
	_show_continue_step(
		Step.EXAM_SIGN,
		"Sign Service",
		"When you finish a route with time to spare, press Sign Service to fast-forward. Then follow the pattern.",
		""
	)
	_spotlight_service_button()


func _spotlight_service_button() -> void:
	if not is_instance_valid(_hud):
		return
	var service_button := _hud.get_node_or_null("%ServiceActionButton") as Control
	if not is_instance_valid(service_button):
		return
	_animate_spotlight_to_control(service_button, exam_button_spotlight_radius, stamp_spotlight_zoom_seconds)

## Stamp lesson entry: ticket face-up plus a spotlight on Goat's correct stamp.
func _enter_stamp_guide() -> void:
	_show_wait_step(
		Step.STAMP_GUIDE,
		"Stamping",
		"Drag a correct stamp onto Goat's ticket.",
		""
	)
	if _main != null and _main.has_method(&"show_tutorial_ticket"):
		_main.call(&"show_tutorial_ticket")
	_spotlight_tutorial_stamp()


func _spotlight_tutorial_stamp() -> void:
	if _main == null or not _main.has_method(&"get_tutorial_stamp_button"):
		return
	var destination: String = ""
	if is_instance_valid(_tutorial_passenger) and _tutorial_passenger.data != null:
		destination = _tutorial_passenger.data.destination_station
	if destination.is_empty():
		return
	var button := _main.call(&"get_tutorial_stamp_button", destination) as Control
	if not is_instance_valid(button):
		return
	_animate_spotlight_to_control(button, stamp_button_spotlight_radius, stamp_spotlight_zoom_seconds)


func _on_ticket_face_shown() -> void:
	if _step != Step.PRESS_Q:
		return
	var overlay := _main.get_node_or_null("%DocumentOverlayUI") if _main != null else null
	if overlay != null and overlay.has_method(&"set_tutorial_locks"):
		overlay.call(&"set_tutorial_locks", true, true)
	_show_continue_step(
		Step.DOCUMENT_TICKET,
		"Ticket",
		"This is the ticket. Check the service date and destination. Goat must leave at the next stop.",
		""
	)


func _validate_tutorial_stamp(payload: Variant) -> void:
	if not is_instance_valid(_tutorial_passenger) or _tutorial_passenger.data == null:
		return
	var expected: String = _tutorial_passenger.data.destination_station
	var station: String = str((payload as Dictionary).get("station", "")) if payload is Dictionary else ""
	if not station.is_empty() and station == expected:
		var overlay := _main.get_node_or_null("%DocumentOverlayUI") if _main != null else null
		if overlay != null and overlay.has_method(&"request_close"):
			overlay.call(&"request_close")
		_show_continue_step(
			Step.NICE_WORK,
			"Nice Work",
			"Correct stamp. Goat leaves at the right stop. Watch closely...",
			""
		)
		return
	if _main != null and _main.has_method(&"shake_tutorial_camera"):
		_main.call(&"shake_tutorial_camera")
	if _main != null and _main.has_method(&"_on_station_assignment_toggled"):
		_main.call(
			&"_on_station_assignment_toggled",
			_tutorial_passenger.data.passenger_name,
			false
		)
	_show_wait_step(
		Step.STAMP_RETRY,
		"Wrong Stamp",
		"That is the wrong station. The stamp is removed. Read the destination again, then drag a correct stamp onto Goat's ticket.",
		""
	)
	_spotlight_tutorial_stamp()


## Jump-teleport vanish, then the anomaly briefing.
func _vanish_tutorial_passenger() -> void:
	_passenger_reveal_token += 1
	var token: int = _passenger_reveal_token
	if not is_instance_valid(_tutorial_passenger):
		_anomaly_intro_page_index = 0
		_show_anomaly_intro_page()
		return
	var target: Passenger = _tutorial_passenger
	_tutorial_passenger = null
	_passenger_pointer_target = null
	_arrow_label.hide()
	var rest_position: Vector2 = target.position
	var rest_scale: Vector2 = target.scale
	var vanish := create_tween().set_parallel(true)
	vanish.tween_property(
		target, ^"position", rest_position + Vector2(0.0, -vanish_jump_height_pixels), vanish_duration_seconds * 0.45
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	vanish.tween_property(
		target, ^"scale", rest_scale * Vector2(1.12, 0.82), vanish_duration_seconds * 0.45
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	vanish.tween_property(target, ^"modulate:a", 0.0, vanish_duration_seconds * 0.8)
	vanish.tween_property(target, ^"scale", Vector2.ZERO, vanish_duration_seconds * 0.55).set_delay(vanish_duration_seconds * 0.45)
	await vanish.finished
	if token != _passenger_reveal_token or _step != Step.NICE_WORK or not is_inside_tree():
		return
	if _main != null and _main.has_method(&"remove_tutorial_passenger"):
		_main.call(&"remove_tutorial_passenger", target)
	_anomaly_intro_page_index = 0
	_show_anomaly_intro_page()


func _show_anomaly_intro_page() -> void:
	var body: String = "Not every passenger on this train is alive. Some of them died before they boarded — yet here they stand, riding alongside the living."
	if not anomaly_intro_dialogue_pages.is_empty():
		_anomaly_intro_page_index = clampi(_anomaly_intro_page_index, 0, anomaly_intro_dialogue_pages.size() - 1)
		body = anomaly_intro_dialogue_pages[_anomaly_intro_page_index]
	_show_continue_step(Step.ANOMALY_INTRO, "Be Careful", body, "")


func _begin_guidebook_button_reveal() -> void:
	_hud_reveal_token += 1
	var token: int = _hud_reveal_token
	_waiting_for_continue = false
	_dialogue_dock.hide()
	if hud_feature_hold_seconds > 0.0:
		await get_tree().create_timer(hud_feature_hold_seconds).timeout
	if token != _hud_reveal_token or _step != Step.ANOMALY_INTRO or not is_inside_tree():
		return
	if is_instance_valid(_hud) and _hud.has_method(&"reveal_tutorial_guidebook_button"):
		_hud.call(&"reveal_tutorial_guidebook_button")
	var guidebook_focus: Control
	if is_instance_valid(_hud) and _hud.has_method(&"get_tutorial_guidebook_focus_control"):
		guidebook_focus = _hud.call(&"get_tutorial_guidebook_focus_control") as Control
	if is_instance_valid(guidebook_focus):
		await _animate_spotlight_to_control(
			guidebook_focus,
			blessings_spotlight_radius,
			hud_feature_spotlight_zoom_seconds
		)
	if token != _hud_reveal_token or _step != Step.ANOMALY_INTRO or not is_inside_tree():
		return
	_show_wait_step(
		Step.GUIDEBOOK_PROMPT,
		"Guidebook",
		"This is your Guidebook. **Press Tab** or **click the Guidebook button** to open it. Start with the Anomaly Signs — they tell you what to look for.",
		""
	)
	_set_controls(true, true)


func _switch_guidebook_section(section: int) -> void:
	var guidebook := _main.get_node_or_null("%GuidebookUI") as GuidebookUI if _main != null else null
	if is_instance_valid(guidebook) and guidebook.has_method(&"show_section"):
		guidebook.call(&"show_section", section)


func _close_guidebook_and_proceed() -> void:
	_set_guidebook_tabs_locked(false)
	var guidebook := _main.get_node_or_null("%GuidebookUI") as GuidebookUI if _main != null else null
	if is_instance_valid(guidebook) and guidebook.has_method(&"request_close"):
		guidebook.call(&"request_close")
	_start_exam()


func _set_guidebook_tabs_locked(locked: bool) -> void:
	var guidebook := _main.get_node_or_null("%GuidebookUI") as GuidebookUI if _main != null else null
	if is_instance_valid(guidebook) and guidebook.has_method(&"set_tabs_locked"):
		guidebook.call(&"set_tabs_locked", locked)


func _spotlight_guidebook_section(section_node_name: String) -> void:
	if _main == null:
		return
	var guidebook := _main.get_node_or_null("%GuidebookUI") as Control
	if guidebook == null:
		return
	var section := guidebook.get_node_or_null("%" + section_node_name) as Control
	if not is_instance_valid(section):
		return
	_animate_spotlight_to_control(section, guidebook_section_spotlight_radius, stamp_spotlight_zoom_seconds)


func _show_guidebook_today() -> void:
	_show_continue_step(
		Step.GUIDEBOOK_TODAY,
		"Guidebook",
		"This is the Guidebook. Check the Today page every day. It shows your route, your target, and your progress.",
		""
	)
	_spotlight_guidebook_section("TodayLayout")


func _show_guidebook_rules() -> void:
	_show_continue_step(
		Step.GUIDEBOOK_RULES,
		"Rules",
		"Confused about what to do? Read the Rules. It tells you exactly how scoring and penalties work.",
		""
	)
	_spotlight_guidebook_section("RulesLayout")


func _show_guidebook_anomaly() -> void:
	_show_continue_step(
		Step.GUIDEBOOK_ANOMALY,
		"Anomaly Signs",
		"This is the important part. IDENTIFY every passenger. If anyone matches one of these signs, do NOT stamp them. Close the book when you are done.",
		""
	)
	_spotlight_guidebook_section("AnomalyList")


func _on_guidebook_section_shown(_section: int) -> void:
	# Section changes during tutorial are driven entirely by _advance_from_continue.
	# We do not react to section_shown here to avoid double-triggering dialogs.
	pass


func _animate_spotlight_to_control(target: Control, target_radius: float, duration: float) -> void:
	if not is_instance_valid(target) or _shade_material == null:
		return
	_update_spotlight()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var start_center: Vector2 = _shade_material.get_shader_parameter(&"spotlight_center")
	var target_center: Vector2 = target.get_global_rect().get_center() / viewport_size
	var start_radius: float = _current_spotlight_radius
	_spotlight_override_center = start_center
	_spotlight_override_active = true
	var focus_tween := create_tween().set_parallel(true)
	focus_tween.tween_method(
		func(value: Vector2) -> void: _spotlight_override_center = value,
		start_center,
		target_center,
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	focus_tween.tween_method(
		func(value: float) -> void: _current_spotlight_radius = value,
		start_radius,
		target_radius,
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await focus_tween.finished
	_spotlight_control = target
	_spotlight_override_active = false
	_current_spotlight_radius = target_radius
	_update_spotlight()


func _prepare_spotlight_material() -> void:
	_shade_material = _shade.material as ShaderMaterial
	if _shade_material != null:
		_shade_material = _shade_material.duplicate() as ShaderMaterial
		_shade.material = _shade_material
	_update_spotlight()


func _set_spotlight_shade(alpha: float) -> void:
	_shade_alpha = clampf(alpha, 0.0, 1.0)
	if _shade_material != null:
		_shade.modulate = Color.WHITE
		_shade_material.set_shader_parameter(&"dim_alpha", _shade_alpha)
		_shade_material.set_shader_parameter(&"spotlight_radius", _current_spotlight_radius)
		_shade_material.set_shader_parameter(&"spotlight_softness", spotlight_softness)
		_shade_material.set_shader_parameter(&"inner_alpha", spotlight_inner_alpha)
	else:
		_shade.modulate.a = _shade_alpha
	_update_spotlight()


func _update_spotlight() -> void:
	if _shade_material == null or not is_inside_tree():
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var center: Vector2 = viewport_size * 0.5
	if _spotlight_override_active:
		center = _spotlight_override_center * viewport_size
	elif _spotlight_searching:
		center = _spotlight_search_center(viewport_size)
	elif is_instance_valid(_spotlight_control) and _spotlight_control.visible:
		center = _spotlight_control.get_global_rect().get_center()
	elif is_instance_valid(_spotlight_world_target) and _spotlight_world_target.visible:
		center = _spotlight_world_target.get_global_transform_with_canvas().origin
	elif is_instance_valid(_player):
		center = _player.get_global_transform_with_canvas().origin + Vector2(0.0, spotlight_player_vertical_offset)
	center.x = clampf(center.x, 0.0, viewport_size.x)
	center.y = clampf(center.y, 0.0, viewport_size.y)
	_shade_material.set_shader_parameter(&"spotlight_center", center / viewport_size)
	_shade_material.set_shader_parameter(&"viewport_aspect", viewport_size.x / viewport_size.y)
	_shade_material.set_shader_parameter(&"dim_alpha", _shade_alpha)
	_shade_material.set_shader_parameter(&"spotlight_radius", _current_spotlight_radius)
	_shade_material.set_shader_parameter(&"spotlight_softness", spotlight_softness)
	_shade_material.set_shader_parameter(&"inner_alpha", spotlight_inner_alpha)


func _spotlight_search_center(viewport_size: Vector2) -> Vector2:
	# The light wanders the screen as if looking for the Angel, then eases
	# onto the portrait circle for the final stretch of the search.
	var wander := Vector2(
		viewport_size.x * (0.5 + 0.44 * sin(_spotlight_search_time * 2.1)),
		viewport_size.y * (0.5 + 0.30 * sin(_spotlight_search_time * 1.35 + 1.0))
	)
	var target: Vector2 = viewport_size * 0.5
	if is_instance_valid(_angel_portrait_frame):
		target = _angel_portrait_frame.get_global_rect().get_center()
	elif is_instance_valid(_player):
		target = _player.get_global_transform_with_canvas().origin
	var settle: float = clampf((_spotlight_search_time - maxf(spotlight_search_seconds - 0.45, 0.0)) / 0.45, 0.0, 1.0)
	settle = settle * settle * (3.0 - 2.0 * settle)
	return wander.lerp(target, settle)


func _get_dialogue_marker_path_for_step(step: Step) -> NodePath:
	match step:
		Step.INTRO:
			return intro_dialogue_marker_path
		Step.MOVEMENT_INTRO:
			return movement_intro_dialogue_marker_path
		Step.MOVEMENT:
			return movement_dialogue_marker_path
		Step.MOVEMENT_SUCCESS:
			return movement_success_dialogue_marker_path
		Step.HUD_INTRO:
			return hud_intro_dialogue_marker_path
		Step.HUD_MINIMAP:
			return hud_minimap_dialogue_marker_path
		Step.HUD_CLOCK:
			return hud_clock_dialogue_marker_path
		Step.BLESSINGS:
			return blessings_dialogue_marker_path
		Step.PASSENGER_REVEAL, Step.PASSENGER_INTRO:
			return passenger_intro_dialogue_marker_path
		Step.PASSENGER_PROMPT:
			return passenger_prompt_dialogue_marker_path
		Step.PASSENGER:
			return passenger_dialogue_marker_path
		Step.EXAM_INTRO, Step.EXAM_BRIEF, Step.EXAM_ACTIVE, Step.EXAM_SUCCESS:
			return passenger_dialogue_marker_path
		Step.DOCUMENTS, Step.STAMP_CLOSE:
			return documents_dialogue_marker_path
		Step.PRESS_Q:
			return documents_dialogue_marker_path
		Step.DOCUMENT_TICKET, Step.STAMP_GUIDE, Step.STAMP_RETRY, Step.NICE_WORK:
			return documents_dialogue_marker_path
		Step.ANOMALY:
			return anomaly_dialogue_marker_path
		Step.ANOMALY_INTRO:
			return anomaly_dialogue_marker_path
		Step.GUIDEBOOK_PROMPT, Step.GUIDEBOOK:
			return guidebook_dialogue_marker_path
		Step.GUIDEBOOK_TODAY, Step.GUIDEBOOK_RULES, Step.GUIDEBOOK_ANOMALY:
			return guidebook_dialogue_marker_path
		Step.NEWSPAPER_PROMPT, Step.NEWSPAPER:
			return newspaper_dialogue_marker_path
		Step.SIGNATURE_PROMPT, Step.SIGNATURE:
			return signature_dialogue_marker_path
		Step.EXAM_SIGN_INTRO, Step.EXAM_SIGN:
			return signature_dialogue_marker_path
		Step.EXAM_TRAVEL, Step.PAYCHECK:
			return day_service_dialogue_marker_path
		Step.DAY_SERVICE:
			return day_service_dialogue_marker_path
		Step.NIGHT_MARKET:
			return night_market_dialogue_marker_path
		Step.NIGHT_WELCOME, Step.NIGHT_TASK, Step.NIGHT_INSPECT:
			return night_walk_dialogue_marker_path
		Step.NIGHT_RECORD_INTRO, Step.NIGHT_RECORD_FIND, Step.NIGHT_RECORD_CLICK:
			return night_record_dialogue_marker_path
		Step.NIGHT_LEDGER_SAVED, Step.NIGHT_LEDGER_PROMPT:
			return night_ledger_dialogue_marker_path
		Step.NIGHT_MAP_INTRO, Step.NIGHT_MAP_ASSIGN, Step.NIGHT_MAP_RETRY, Step.NIGHT_COMPLETE:
			return night_map_dialogue_marker_path
		_:
			return default_dialogue_marker_path


func _dialogue_frame_name_for_step(step: Step) -> StringName:
	match step:
		Step.INTRO:
			return &"Intro"
		Step.MOVEMENT_INTRO:
			return &"MovementIntro"
		Step.MOVEMENT:
			return &"Movement"
		Step.MOVEMENT_SUCCESS:
			return &"MovementSuccess"
		Step.HUD_INTRO:
			return &"HudIntro"
		Step.HUD_MINIMAP:
			return &"HudMinimap"
		Step.HUD_CLOCK:
			return &"HudClock"
		Step.BLESSINGS:
			return &"Blessings"
		Step.PASSENGER_REVEAL, Step.PASSENGER_INTRO:
			return &"PassengerIntro"
		Step.PASSENGER_PROMPT:
			return &"PassengerPrompt"
		Step.PASSENGER:
			return &"Passenger"
		Step.EXAM_INTRO, Step.EXAM_BRIEF, Step.EXAM_ACTIVE, Step.EXAM_SUCCESS:
			return &"Passenger"
		Step.DOCUMENTS, Step.STAMP_CLOSE:
			return &"Documents"
		Step.PRESS_Q:
			return &"Documents"
		Step.DOCUMENT_TICKET, Step.STAMP_GUIDE, Step.STAMP_RETRY, Step.NICE_WORK:
			return &"Documents"
		Step.ANOMALY:
			return &"Anomaly"
		Step.ANOMALY_INTRO:
			return &"Anomaly"
		Step.GUIDEBOOK_PROMPT, Step.GUIDEBOOK:
			return &"Guidebook"
		Step.GUIDEBOOK_TODAY, Step.GUIDEBOOK_RULES, Step.GUIDEBOOK_ANOMALY:
			return &"Guidebook"
		Step.NEWSPAPER_PROMPT, Step.NEWSPAPER:
			return &"Newspaper"
		Step.SIGNATURE_PROMPT, Step.SIGNATURE:
			return &"Signature"
		Step.EXAM_SIGN_INTRO, Step.EXAM_SIGN:
			return &"Signature"
		Step.DAY_SERVICE:
			return &"DayService"
		Step.EXAM_TRAVEL:
			return &"DayService"
		Step.PAYCHECK:
			return &"DayService"
		Step.NIGHT_MARKET:
			return &"NightMarket"
		Step.NIGHT_WELCOME, Step.NIGHT_TASK, Step.NIGHT_INSPECT:
			return &"NightWalk"
		Step.NIGHT_RECORD_INTRO, Step.NIGHT_RECORD_FIND, Step.NIGHT_RECORD_CLICK:
			return &"NightRecord"
		Step.NIGHT_LEDGER_SAVED, Step.NIGHT_LEDGER_PROMPT:
			return &"NightLedger"
		Step.NIGHT_MAP_INTRO, Step.NIGHT_MAP_ASSIGN, Step.NIGHT_MAP_RETRY, Step.NIGHT_COMPLETE:
			return &"NightMap"
		_:
			return &"Default"


func _place_dialogue_at_frame(step: Step, allow_marker_fallback: bool = true) -> void:
	if not is_instance_valid(_dialogue_dock):
		return
	if is_instance_valid(_dialogue_frames):
		var frame := _dialogue_frames.get_node_or_null(String(_dialogue_frame_name_for_step(step))) as Control
		if frame != null:
			# The frame owns everything: position, size, scale, and the
			# portrait/tail pose. Markers are only a fallback.
			_dialogue_dock.offset_left = frame.offset_left
			_dialogue_dock.offset_top = frame.offset_top
			_dialogue_dock.offset_right = frame.offset_right
			_dialogue_dock.offset_bottom = frame.offset_bottom
			_dialogue_dock.scale = frame.scale
			_dock_rest_scale = frame.scale
			_pose_portrait_and_tail(frame)
			return
	if allow_marker_fallback:
		_place_dialogue_at_frame_fallback(step)


## Portrait and tail follow optional per-frame spots. Without spots they
## keep the default top-right composition, sized from the bubble rect.
func _pose_portrait_and_tail(frame: Control) -> void:
	if is_instance_valid(_angel_portrait_frame):
		var portrait_spot := frame.get_node_or_null(^"PortraitSpot") as Control
		_angel_portrait_frame.anchor_left = 0.0
		_angel_portrait_frame.anchor_top = 0.0
		_angel_portrait_frame.anchor_right = 0.0
		_angel_portrait_frame.anchor_bottom = 0.0
		if portrait_spot != null:
			_angel_portrait_frame.offset_left = portrait_spot.offset_left
			_angel_portrait_frame.offset_top = portrait_spot.offset_top
			_angel_portrait_frame.offset_right = portrait_spot.offset_right
			_angel_portrait_frame.offset_bottom = portrait_spot.offset_bottom
			_angel_portrait_frame.scale = _portrait_base_scale * portrait_spot.scale
		else:
			var dock_width: float = _dialogue_dock.offset_right - _dialogue_dock.offset_left
			_angel_portrait_frame.offset_left = dock_width - 110.0
			_angel_portrait_frame.offset_top = -220.0
			_angel_portrait_frame.offset_right = dock_width + 64.0
			_angel_portrait_frame.offset_bottom = -46.0
			_angel_portrait_frame.scale = _portrait_base_scale
		_portrait_rest_scale = _angel_portrait_frame.scale
	if is_instance_valid(_bubble_tail):
		var tail_spot := frame.get_node_or_null(^"TailSpot") as Control
		_bubble_tail.anchor_left = 0.0
		_bubble_tail.anchor_top = 0.0
		_bubble_tail.anchor_right = 0.0
		_bubble_tail.anchor_bottom = 0.0
		if tail_spot != null:
			_bubble_tail.offset_left = tail_spot.offset_left
			_bubble_tail.offset_top = tail_spot.offset_top
			_bubble_tail.offset_right = tail_spot.offset_right
			_bubble_tail.offset_bottom = tail_spot.offset_bottom
			_bubble_tail.rotation = tail_spot.rotation
			# TailSpot is the complete scene-authored transform. Multiplying it by
			# the runtime tail's negative base scale flips the pointer in-game.
			_bubble_tail.scale = tail_spot.scale
		else:
			var dock_width: float = _dialogue_dock.offset_right - _dialogue_dock.offset_left
			_bubble_tail.offset_left = dock_width - 181.0
			_bubble_tail.offset_top = -133.0
			_bubble_tail.offset_right = dock_width - 98.0
			_bubble_tail.offset_bottom = -62.0
			_bubble_tail.rotation = 1.8027644
			_bubble_tail.scale = _tail_base_scale


func _place_dialogue_at_frame_fallback(step: Step) -> void:
	var marker_path: NodePath = _get_dialogue_marker_path_for_step(step)
	var marker := get_node_or_null(marker_path) as Marker2D
	if marker == null:
		marker = get_node_or_null(default_dialogue_marker_path) as Marker2D
	if marker == null:
		push_warning("TutorialDirector has no valid dialogue frame or marker.")
		return
	_dialogue_dock.global_position = marker.global_position
	_dock_rest_scale = Vector2.ONE


## Full dialogue copy per step, in one place. The editor preview reads
## from this table; runtime call sites pass the same strings.
func _step_copy(step: Step) -> Array:
	match step:
		Step.INTRO:
			var preview_intro: String = "Hello. I am the Inspector assigned to this train."
			if not intro_dialogue_pages.is_empty():
				preview_intro = intro_dialogue_pages[0]
			return ["The Inspector", preview_intro, ""]
		Step.MOVEMENT_INTRO:
			return ["The Inspector", movement_intro_prompt, ""]
		Step.MOVEMENT:
			return ["The Inspector", movement_prompt, "Move until the timer is full."]
		Step.MOVEMENT_SUCCESS:
			return ["The Inspector", movement_success_prompt, ""]
		Step.HUD_INTRO:
			return ["The Inspector", "Now, let me explain the tools you will use on this train.", ""]
		Step.HUD_MINIMAP:
			return ["Train Minimap", "The minimap shows each carriage and its passengers. Use it to find people quickly.", ""]
		Step.HUD_CLOCK:
			return ["Journey Clock", "Next, we have the clock. You have one full turn to finish your work on each route.", ""]
		Step.BLESSINGS:
			return ["Daily Blessings", "You need enough to pass each day of your internship. The left number is what you earned, while the right number is the required target.", ""]
		Step.PASSENGER_REVEAL, Step.PASSENGER_INTRO:
			return ["The Inspector", passenger_intro_prompt, ""]
		Step.PASSENGER_PROMPT:
			return ["The Inspector", passenger_inspect_prompt, ""]
		Step.PASSENGER:
			return ["First Inspection", passenger_prompt, ""]
		Step.DOCUMENTS:
			return ["Identity Card", "This is Goat's ID card. Look at the portrait, the name, and the CID number. The face on the card must match the passenger.", ""]
		Step.PRESS_Q:
			return ["Your Turn", "Now press Q to flip to the ticket.", ""]
		Step.DOCUMENT_TICKET:
			return ["Ticket", "This is the ticket. Check the service date and destination. Goat must leave at the next stop.", ""]
		Step.STAMP_GUIDE:
			return ["Stamping", "Drag a correct stamp onto Goat's ticket.", ""]
		Step.STAMP_RETRY:
			return ["Wrong Stamp", "That is the wrong station. The stamp is removed. Read the destination again, then drag a correct stamp onto Goat's ticket.", ""]
		Step.NICE_WORK:
			return ["Nice Work", "Correct stamp. Goat leaves at the right stop. Watch closely...", ""]
		Step.ANOMALY_INTRO:
			return ["Be Careful", "Not every passenger on this train is human. Look closely at everyone you inspect. Some hide in plain sight.", ""]
		Step.STAMP_CLOSE:
			return ["Stamping", "Drag the station stamp onto the ticket only when the passenger should leave at that station. If they look anomalous, keep them aboard for tonight instead.", "After stamping, close the documents with the X button or Esc."]
		Step.ANOMALY:
			return ["Keep Aboard", "Some passengers are already dead, so never stamp them. Keep them aboard until Night Service can guide them.", ""]
		Step.GUIDEBOOK_TODAY:
			return ["Guidebook", "This is the Guidebook. Check the Today page every day. It shows your route, your target, and your progress.", ""]
		Step.GUIDEBOOK_RULES:
			return ["Rules", "Confused about what to do? Read the Rules. It tells you exactly how scoring and penalties work.", ""]
		Step.GUIDEBOOK_ANOMALY:
			return ["Anomaly Signs", "This is the important part. IDENTIFY every passenger. If anyone matches one of these signs, do NOT stamp them. Close the book when you are done.", ""]
		Step.GUIDEBOOK:
			return ["Guidebook", "Today’s Service shows the target and route totals. Rules explains scoring, while Anomaly Signs shows suspicious evidence.", "Close the Guidebook after reading."]
		Step.NEWSPAPER_PROMPT:
			return ["Newspaper", newspaper_prompt, "Find the newspaper interactable in the carriage."]
		Step.NEWSPAPER:
			return ["Morning Paper", "The paper can confirm whether a passenger died before this route. If it names someone aboard as a death case, do not stamp them; keep that soul for Night Service.", "Close the newspaper after reading."]
		Step.SIGNATURE_PROMPT:
			return ["Sign Off", signature_prompt, "Use the service button below the Guidebook."]
		Step.SIGNATURE:
			return ["Service Sign-Off", "Trace the mark to confirm this segment is complete. Accepted signatures move the train ahead, so inspect first.", "A failed trace shakes the screen; try again."]
		Step.DAY_SERVICE:
			return ["Clean Coach", clean_coach_prompt, "Click Continue to finish this clean-start tutorial."]
		Step.NIGHT_MARKET:
			return ["Night Market", "This is the Night Market, where tools can make your internship easier. Purchases are disabled during training; press Begin when you are ready.", ""]
		Step.NIGHT_WELCOME:
			return ["Night Service", "Welcome to Night Service. The passengers left aboard are souls waiting for their final station.", ""]
		Step.NIGHT_TASK, Step.NIGHT_INSPECT:
			return ["Night Service", "One soul is already recorded in your ledger. Inspect the other soul to recover its clue.", ""]
		Step.NIGHT_RECORD_INTRO:
			return ["Soul Record", "This is a Soul Record. Its biography hides one Departure Statement.", ""]
		Step.NIGHT_RECORD_FIND, Step.NIGHT_RECORD_CLICK:
			return ["Hidden Statement", "The hidden statement is marked red for this lesson. Click that sentence to collect it.", ""]
		Step.NIGHT_LEDGER_SAVED, Step.NIGHT_LEDGER_PROMPT:
			return ["Ledger", "The statement is now stored in your ledger. Open the ledger button to view the station path.", ""]
		Step.NIGHT_MAP_INTRO, Step.NIGHT_MAP_RETRY:
			return ["Station Path", "This map shows the souls and their possible stations. Use both ledger clues to decide where each soul belongs.", ""]
		Step.NIGHT_MAP_ASSIGN:
			return ["Your Turn", "Drag each soul to its correct station, then press Finalize Assignments.", ""]
		Step.NIGHT_COMPLETE:
			return ["The Inspector", "Correct. You are ready to begin your internship.", ""]
		Step.EXAM_INTRO:
			return ["The Inspector", "Good. Now I will test how thorough you are. Five souls will board in front of you.", ""]
		Step.EXAM_BRIEF:
			return ["Stamp Test", "Stamp every passenger except the anomalies; two of these five souls are not what they seem. You have 2 minutes—one full clock turn.", ""]
		Step.EXAM_ACTIVE:
			return ["Stamp Test", "Stamp Reff, Ratta, and Denta before one clock turn ends. Leave Abby and Mecca unstamped.", ""]
		Step.EXAM_SUCCESS:
			return ["The Inspector", "Good job. You are now 50 percent ready to begin your internship.", ""]
		Step.EXAM_SIGN_INTRO:
			return ["Sign Service", "I know many workers finish their assignments early, so I prepared this for you.", ""]
		Step.EXAM_SIGN:
			return ["Sign Service", "When you finish a route with time to spare, press Sign Service to fast-forward. Then follow the pattern.", ""]
		Step.EXAM_TRAVEL:
			return ["The Inspector", "Hold on while the train moves.", ""]
		Step.PAYCHECK:
			return ["Paycheck", "This is your paycheck: correct work earns Blessings, which buy tools for harder shifts.", ""]
	return ["The Inspector", "Hello. I am the Inspector assigned to this train.", ""]


func _preview_step_in_editor() -> void:
	if preview_step == Step.INACTIVE or preview_step == Step.DONE:
		return
	if not is_instance_valid(_dialogue_dock) or not is_instance_valid(_panel):
		return
	var copy: Array = _step_copy(preview_step)
	_speaker_label.text = str(copy[0])
	_body_label.text = str(copy[1])
	_body_label.visible_characters = -1
	_hint_label.text = ""
	_hint_label.hide()
	_progress_label.hide()
	if is_instance_valid(_continue_row):
		_continue_row.show()
	_continue_button.show()
	_place_dialogue_at_frame(preview_step)
	_dialogue_dock.show()
	_panel.show()


func _set_panel(speaker: String, body: String, _hint: String, show_continue: bool) -> void:
	_place_dialogue_at_frame(_step)
	_speaker_label.text = speaker
	# Tutorial copy is limited to the main dialogue; the secondary hint row is
	# intentionally disabled for every beat.
	_hint_label.text = ""
	_hint_label.hide()
	if is_instance_valid(_continue_row):
		_continue_row.visible = show_continue
	_continue_button.visible = show_continue
	_dialogue_dock.show()
	# Initialize both parts while hidden so no frame can render the tail before
	# the bubble entrance starts.
	_panel.modulate.a = 0.0
	_bubble_tail.modulate.a = 0.0
	_bubble_tail.show()
	_panel.show()
	_panel.pivot_offset = _panel.size * 0.5
	_play_dialogue_pop()
	_start_typewriter(body)
	if is_inside_tree():
		GameSFX.play(&"button_hover", -18.0, 1.0, 0.02, 0.05)


func _start_typewriter(body: String) -> void:
	_stop_typewriter()
	_typewriter_characters = 0.0
	_body_label.text = body
	_body_label.visible_characters = 0
	var total_characters: int = _body_label.get_total_character_count()
	if total_characters <= 0:
		_body_label.visible_characters = -1
		return
	_typewriter_running = true
	GameSFX.start_loop(&"tutorial_typewriter", &"typewriter", -18.0, 1.0)


func _update_typewriter(delta: float) -> void:
	if not _typewriter_running or not is_instance_valid(_body_label):
		return
	_typewriter_characters = minf(
		float(_body_label.get_total_character_count()),
		_typewriter_characters + maxf(typewriter_characters_per_second, 1.0) * delta
	)
	_body_label.visible_characters = floori(_typewriter_characters)
	if _typewriter_characters >= float(_body_label.get_total_character_count()):
		_stop_typewriter()


func _complete_typewriter() -> bool:
	if not _typewriter_running:
		return false
	_body_label.visible_characters = -1
	_stop_typewriter()
	return true


func _stop_typewriter() -> void:
	_typewriter_running = false
	_typewriter_characters = 0.0
	GameSFX.stop_loop(&"tutorial_typewriter")


func _play_dialogue_pop() -> void:
	if not is_inside_tree() or not is_instance_valid(_panel):
		return
	if is_instance_valid(_dialogue_tween) and _dialogue_tween.is_valid():
		_dialogue_tween.kill()
	# Keep the scene-authored DialogueDock completely stable. Only the bubble
	# panel receives the toony entrance, so the portrait, its crop, and every
	# DialogueFrames scale remain identical between editor and runtime.
	_dialogue_dock.scale = _dock_rest_scale
	_dialogue_dock.rotation = 0.0
	_dialogue_dock.modulate = Color.WHITE
	_panel.modulate.a = 0.0
	_panel.pivot_offset = _panel.size * 0.5
	_panel.rotation = -0.035
	_panel.scale = _panel_base_scale * Vector2(1.28, 0.62)
	_bubble_tail.modulate.a = 0.0
	var pop_seconds: float = maxf(bubble_pop_seconds, 0.05)
	_dialogue_tween = create_tween()
	_dialogue_tween.set_parallel(true)
	_dialogue_tween.tween_property(_panel, ^"modulate:a", 1.0, pop_seconds * 0.35)
	_dialogue_tween.tween_property(_bubble_tail, ^"modulate:a", 1.0, pop_seconds * 0.35)
	_dialogue_tween.tween_property(_panel, ^"scale", _panel_base_scale * Vector2(0.92, 1.1), pop_seconds * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_dialogue_tween.tween_property(_panel, ^"rotation", 0.012, pop_seconds * 0.45)
	_dialogue_tween.chain().tween_property(_panel, ^"scale", _panel_base_scale * Vector2(1.02, 0.97), pop_seconds * 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_dialogue_tween.parallel().tween_property(_panel, ^"rotation", -0.006, pop_seconds * 0.25)
	_dialogue_tween.chain().tween_property(_panel, ^"scale", _panel_base_scale, pop_seconds * 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_dialogue_tween.parallel().tween_property(_panel, ^"rotation", 0.0, pop_seconds * 0.3)


func _advance_from_continue() -> void:
	if not _waiting_for_continue:
		return
	# First press finishes the typewriter; only the next press advances.
	if _complete_typewriter():
		return
	if _step == Step.INTRO:
		if _intro_page_index + 1 < intro_dialogue_pages.size():
			_intro_page_index += 1
			_show_intro_page()
		else:
			_waiting_for_continue = false
			_start_movement_intro()
		return
	_waiting_for_continue = false
	match _step:
		Step.MOVEMENT_INTRO:
			_start_movement()
		Step.MOVEMENT_SUCCESS:
			_show_continue_step(
				Step.HUD_INTRO,
				"The Inspector",
				"Now, let me explain the tools you will use on this train.",
				""
			)
		Step.HUD_INTRO:
			_begin_minimap_reveal()
		Step.HUD_MINIMAP:
			_begin_clock_reveal()
		Step.HUD_CLOCK:
			_begin_blessings_reveal()
		Step.BLESSINGS:
			_begin_passenger_reveal()
		Step.PASSENGER_INTRO:
			_passenger_pointer_target = (
				_tutorial_passenger.get_dialogue_anchor()
				if is_instance_valid(_tutorial_passenger)
				else null
			)
			_passenger_pointer_time = 0.0
			_arrow_label.visible = is_instance_valid(_passenger_pointer_target)
			_show_continue_step(
				Step.PASSENGER_PROMPT,
				"The Inspector",
				passenger_inspect_prompt,
				""
			)
		Step.PASSENGER_PROMPT:
			_begin_passenger_inspection_task()
		Step.EXAM_INTRO:
			_begin_exam_brief()
		Step.EXAM_BRIEF:
			_begin_exam_task()
		Step.EXAM_SUCCESS:
			_enter_exam_sign_intro()
		Step.EXAM_SIGN_INTRO:
			_enter_exam_sign()
		Step.EXAM_SIGN:
			_hide_dialogue_for_task()
			_set_spotlight_shade(0.0)
			_set_controls(true, true)
		Step.ANOMALY:
			_set_controls(true, true)
			_show_wait_step(Step.GUIDEBOOK_PROMPT, "Guidebook", guidebook_prompt, "Click the Guidebook or press Tab.")
		Step.DOCUMENTS:
			var overlay := _main.get_node_or_null("%DocumentOverlayUI") if _main != null else null
			if overlay != null and overlay.has_method(&"set_tutorial_locks"):
				overlay.call(&"set_tutorial_locks", true, true, true)
			_show_wait_step(
				Step.PRESS_Q,
				"Your Turn",
				"Now press Q to flip to the ticket.",
				""
			)
		Step.DOCUMENT_TICKET:
			_enter_stamp_guide()
		Step.NICE_WORK:
			_vanish_tutorial_passenger()
		Step.ANOMALY_INTRO:
			if _anomaly_intro_page_index + 1 < anomaly_intro_dialogue_pages.size():
				_anomaly_intro_page_index += 1
				_show_anomaly_intro_page()
			else:
				_begin_guidebook_button_reveal()
		Step.GUIDEBOOK:
			_switch_guidebook_section(GuidebookUI.SECTION_TODAY)
			_show_guidebook_today()
		Step.GUIDEBOOK_TODAY:
			_switch_guidebook_section(GuidebookUI.SECTION_RULES)
			_show_guidebook_rules()
		Step.GUIDEBOOK_RULES:
			_switch_guidebook_section(GuidebookUI.SECTION_ANOMALIES)
			_show_guidebook_anomaly()
		Step.GUIDEBOOK_ANOMALY:
			_close_guidebook_and_proceed()
		Step.NEWSPAPER:
			_show_wait_step(Step.NEWSPAPER, "Morning Paper", "Close the newspaper when you are ready. If the paper proves a passenger is anomalous, leave them unstamped and keep them aboard.", "Use the X button or Esc to close it.")
		Step.SIGNATURE:
			_show_wait_step(Step.SIGNATURE, "Service Sign-Off", "Now trace the mark. A valid signature confirms this route segment and fast-forwards to the next station.", "A failed trace shakes the screen; try again.")
		Step.NIGHT_MARKET:
			_hide_dialogue_for_task()
			_set_spotlight_shade(0.0)
		Step.NIGHT_WELCOME:
			_show_continue_step(
				Step.NIGHT_TASK,
				"Night Service",
				"Your task is to recover each soul's Departure Statement, then assign every soul to the correct station.",
				""
			)
		Step.NIGHT_TASK:
			_begin_night_inspection_task()
		Step.NIGHT_RECORD_INTRO:
			if _main != null and _main.has_method(&"set_tutorial_night_record_guidance"):
				_main.call(&"set_tutorial_night_record_guidance", true, true)
			_show_continue_step(
				Step.NIGHT_RECORD_FIND,
				"Hidden Statement",
				"One sentence in the biography is the soul's Departure Statement. It is marked red during this lesson.",
				""
			)
		Step.NIGHT_RECORD_FIND:
			_show_continue_step(
				Step.NIGHT_RECORD_CLICK,
				"Your Turn",
				"Click the red statement to send it into the ledger.",
				""
			)
		Step.NIGHT_RECORD_CLICK:
			_hide_dialogue_for_task()
			_set_spotlight_shade(0.0)
			if _main != null and _main.has_method(&"set_tutorial_night_record_guidance"):
				_main.call(&"set_tutorial_night_record_guidance", false, true)
		Step.NIGHT_LEDGER_SAVED:
			_begin_night_ledger_prompt()
		Step.NIGHT_MAP_INTRO, Step.NIGHT_MAP_RETRY:
			_set_night_map_input_blocked(true)
			_show_continue_step(
				Step.NIGHT_MAP_ASSIGN,
				"Your Turn",
				"Drag each soul to its correct station, then press Finalize Assignments.",
				""
			)
		Step.NIGHT_MAP_ASSIGN:
			_set_night_map_input_blocked(false)
			_hide_dialogue_for_task()
			_set_spotlight_shade(0.0)
		Step.NIGHT_COMPLETE:
			finish_tutorial()
		Step.DAY_SERVICE:
			finish_tutorial()
		Step.PAYCHECK:
			_hide_dialogue_for_task()
			if _main != null and _main.has_method(&"continue_tutorial_paycheck"):
				_main.call(&"continue_tutorial_paycheck")
		_:
			pass


func _begin_night_lesson() -> void:
	_night_lesson_token += 1
	_night_prefilled_name = night_prefilled_soul_name
	_night_target_name = night_inspection_soul_name
	_passenger_pointer_target = null
	var lesson: Dictionary = {}
	if _main != null and _main.has_method(&"prepare_tutorial_night_lesson"):
		lesson = _main.call(
			&"prepare_tutorial_night_lesson",
			night_prefilled_soul_name,
			night_inspection_soul_name
		)
	_night_prefilled_name = str(lesson.get("prefilled_name", _night_prefilled_name))
	_night_target_name = str(lesson.get("inspection_name", _night_target_name))
	var target := lesson.get("inspection_target") as Passenger
	if is_instance_valid(target):
		_passenger_pointer_target = target.get_dialogue_anchor()
	_show_continue_step(
		Step.NIGHT_WELCOME,
		"Night Service",
		"Welcome to Night Service. The passengers left aboard are souls waiting for their final station.",
		""
	)


func _begin_night_inspection_task() -> void:
	_step = Step.NIGHT_INSPECT
	_hide_dialogue_for_task()
	_set_spotlight_shade(0.0)
	_set_controls(true, true)
	_passenger_pointer_time = 0.0
	_arrow_label.visible = is_instance_valid(_passenger_pointer_target)


func _finish_night_statement_lesson() -> void:
	_night_lesson_token += 1
	var token: int = _night_lesson_token
	_set_controls(false, false)
	if _main != null and _main.has_method(&"set_tutorial_night_record_guidance"):
		_main.call(&"set_tutorial_night_record_guidance", true, false)
	if night_statement_transfer_wait_seconds > 0.0:
		await get_tree().create_timer(night_statement_transfer_wait_seconds).timeout
	if token != _night_lesson_token or not is_inside_tree():
		return
	if _main != null and _main.has_method(&"close_tutorial_night_record"):
		_main.call(&"close_tutorial_night_record")
	_show_continue_step(
		Step.NIGHT_LEDGER_SAVED,
		"Ledger",
		"The statement is now stored in your ledger. One other soul was already recorded for this lesson.",
		""
	)


func _begin_night_ledger_prompt() -> void:
	_set_night_map_input_blocked(false)
	_spotlight_world_target = null
	_spotlight_override_active = false
	_spotlight_control = null
	if is_instance_valid(_hud) and _hud.has_method(&"get_tutorial_service_action_focus_control"):
		_spotlight_control = _hud.call(&"get_tutorial_service_action_focus_control") as Control
	_show_wait_step(
		Step.NIGHT_LEDGER_PROMPT,
		"Ledger",
		"Open the highlighted ledger button to view the station path.",
		""
	)
	_set_controls(false, false)


func _set_night_map_input_blocked(value: bool) -> void:
	# Shade sits behind DialogueDock, so it blocks the board while leaving the
	# Inspector's Continue text clickable. The ledger prompt deliberately turns
	# this off so the highlighted HUD button can receive the click.
	if is_instance_valid(_shade):
		_shade.mouse_filter = (
			Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
		)


func _on_main_tutorial_event(event_name: StringName, payload: Variant = null) -> void:
	_event_log.append(event_name)
	_last_event_payload = payload
	match event_name:
		&"passenger_documents_opened":
			if _step == Step.PASSENGER:
				_passenger_pointer_target = null
				_arrow_label.hide()
				var overlay := _main.get_node_or_null("%DocumentOverlayUI") if _main != null else null
				if overlay != null and overlay.has_method(&"set_tutorial_locks"):
					overlay.call(&"set_tutorial_locks", true, true)
				_show_continue_step(Step.DOCUMENTS, "Identity Card", "This is Goat's ID card. Look at the portrait, the name, and the CID number. The face on the card must match the passenger.", "")
		&"ticket_stamped":
			if _step in [Step.DOCUMENTS, Step.DOCUMENT_TICKET, Step.STAMP_GUIDE, Step.STAMP_RETRY]:
				_validate_tutorial_stamp(payload)
			elif _step == Step.EXAM_ACTIVE:
				_on_exam_stamp(payload)
		&"document_closed":
			if _step == Step.STAMP_CLOSE:
				_show_continue_step(Step.ANOMALY, "Keep Aboard", "Some passengers are already dead, so never stamp them. Keep them aboard until Night Service can guide them.", "")
			elif _step == Step.NEWSPAPER:
				_set_controls(true, true)
				# Full HUD only returns here, when the service button lesson needs it.
				_set_tutorial_hud_visible(true)
				_show_wait_step(Step.SIGNATURE_PROMPT, "Sign Off", signature_prompt, "Use the service button below the Guidebook.")
		&"guidebook_opened":
			if _step == Step.GUIDEBOOK_PROMPT:
				_spotlight_control = null
				_spotlight_override_active = false
				_set_spotlight_shade(0.0)
				_set_guidebook_tabs_locked(true)
				_show_continue_step(Step.GUIDEBOOK, "Guidebook", "Today’s Service shows the target and route totals. Rules explains scoring, while Anomaly Signs shows suspicious evidence.", "Close the Guidebook after reading.")
		&"guidebook_closed":
			if _step == Step.GUIDEBOOK:
				_set_controls(true, true)
				_show_wait_step(Step.NEWSPAPER_PROMPT, "Newspaper", newspaper_prompt, "Find the newspaper interactable in the carriage.")
		&"newspaper_opened":
			if _step in [Step.NEWSPAPER_PROMPT, Step.GUIDEBOOK, Step.GUIDEBOOK_PROMPT]:
				_show_continue_step(Step.NEWSPAPER, "Morning Paper", "The paper can confirm whether a passenger died before this route. If it names someone aboard as a death case, do not stamp them; keep that soul for Night Service.", "Close the newspaper after reading.")
		&"service_signature_opened":
			if _step == Step.SIGNATURE_PROMPT:
				_show_continue_step(Step.SIGNATURE, "Service Sign-Off", "Trace the mark to confirm this segment is complete. Accepted signatures move the train ahead, so inspect first.", "A failed trace shakes the screen; try again.")
		&"service_signed":
			if _main != null and _main.has_method(&"set_tutorial_route_time_paused"):
				_main.call(&"set_tutorial_route_time_paused", false)
			if _step == Step.EXAM_SIGN:
				_step = Step.EXAM_TRAVEL
				_hide_dialogue_for_task()
			elif _step in [Step.SIGNATURE_PROMPT, Step.SIGNATURE]:
				_show_wait_step(Step.DAY_SERVICE, "Route Continues", "The train will move to the next station. Keep checking passengers, documents, and evidence until the final station ends daylight service.", "The tutorial will return for Night Market and Night Service.")
		&"station_arrival_finished":
			if _step == Step.EXAM_TRAVEL:
				if _main != null and _main.has_method(&"advance_tutorial_to_terminal_arrival"):
					_main.call(&"advance_tutorial_to_terminal_arrival")
		&"shift_report_opened":
			_show_continue_step(
				Step.PAYCHECK,
				"Paycheck",
				"This is your paycheck: correct work earns Blessings, which buy tools for harder shifts.",
				""
			)
		&"night_market_opened":
			_show_continue_step(Step.NIGHT_MARKET, "Night Market", "This is the Night Market, where tools can make your internship easier. Purchases are disabled during training; press Begin when you are ready.", "")
		&"night_started":
			if _step in [Step.DAY_SERVICE, Step.NIGHT_MARKET, Step.NIGHT_WELCOME]:
				_begin_night_lesson()
		&"night_record_opened":
			if _step == Step.NIGHT_INSPECT:
				var opened_data := payload as PassengerData
				if opened_data == null or _night_target_name.is_empty() or opened_data.short_name == _night_target_name:
					_passenger_pointer_target = null
					_arrow_label.hide()
					if _main != null and _main.has_method(&"set_tutorial_night_record_guidance"):
						_main.call(&"set_tutorial_night_record_guidance", true, false)
					_show_continue_step(
						Step.NIGHT_RECORD_INTRO,
						"Soul Record",
						"This is a Soul Record. Its biography hides one Departure Statement.",
						""
					)
		&"night_statement_recorded":
			if _step == Step.NIGHT_RECORD_CLICK:
				_finish_night_statement_lesson()
		&"night_puzzle_opened":
			if _step == Step.NIGHT_LEDGER_PROMPT:
				_set_night_map_input_blocked(true)
				_spotlight_control = null
				_spotlight_override_active = false
				_show_continue_step(
					Step.NIGHT_MAP_INTRO,
					"Station Path",
					"This map shows the souls and their possible stations. Use both ledger clues to decide where each soul belongs.",
					""
				)
		&"night_assignment_failed":
			if _step == Step.NIGHT_MAP_ASSIGN:
				_set_night_map_input_blocked(true)
				if _main != null and _main.has_method(&"retry_tutorial_night_assignment"):
					_main.call(&"retry_tutorial_night_assignment")
				_show_continue_step(
					Step.NIGHT_MAP_RETRY,
					"Ledger Checkpoint",
					"That route was not correct. Read both ledger clues again; the map will stay open while you retry.",
					""
				)
		&"night_assignment_succeeded":
			if _step == Step.NIGHT_MAP_ASSIGN:
				_set_night_map_input_blocked(true)
				_show_continue_step(
					Step.NIGHT_COMPLETE,
					"The Inspector",
					"Correct. You are ready to begin your internship.",
					""
				)


func _set_controls(can_move: bool, can_interact: bool) -> void:
	if is_instance_valid(_player):
		_player.movement_enabled = can_move
		_player.interaction_enabled = can_interact


func _set_tutorial_hud_visible(value: bool) -> void:
	if not is_instance_valid(_hud):
		return
	if value and _hud.has_method(&"restore_tutorial_hud_visibility"):
		_hud.call(&"restore_tutorial_hud_visibility")
	_hud.visible = value
