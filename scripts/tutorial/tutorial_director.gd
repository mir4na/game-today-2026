@tool
class_name TutorialDirector
extends Control
## Interactive onboarding layer that teaches the current game systems in-place.

signal tutorial_finished

enum Step {
	INACTIVE,
	INTRO,
	MOVEMENT,
	HUD_MINIMAP,
	HUD_CLOCK,
	BLESSINGS,
	PASSENGER,
	DOCUMENTS,
	STAMP_CLOSE,
	ANOMALY,
	GUIDEBOOK_PROMPT,
	GUIDEBOOK,
	NEWSPAPER_PROMPT,
	NEWSPAPER,
	SIGNATURE_PROMPT,
	SIGNATURE,
	DAY_SERVICE,
	NIGHT_MARKET,
	NIGHT_WALK,
	NIGHT_RECORD,
	NIGHT_PAYOUT,
	NIGHT_MAP,
	DONE,
}

@export_range(0.5, 10.0, 0.1) var movement_required_seconds: float = 3.0
@export var movement_prompt: String = "Walk for 3 seconds with A / D or the Arrow Keys. I only need to see that you can move before the real work begins."
@export var intro_dialogue_pages: PackedStringArray = PackedStringArray([
	"Hello. I am the Inspector assigned to this train.",
	"You died before reaching your job interview. The railway is offering you a second chance.",
	"You will work here as an intern conductor. During the day, inspect passengers and decide who should leave at each station.",
	"At night, guide the souls who remain to the station where they belong. Do your work well, and this second chance is yours to keep.",
])
@export var passenger_prompt: String = "Walk to a passenger and inspect their documents with E. Their body, ID, ticket, route, and destination all matter."
@export var document_prompt: String = "Compare the passenger with their ID and ticket: portrait, name, service date, train number, and destination. Stamp ordinary passengers only when their stop is next; keep suspicious passengers aboard for Night Service."
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
@export_category("Typewriter")
@export_range(20.0, 240.0, 5.0) var typewriter_characters_per_second: float = 90.0
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
@export_node_path("Marker2D") var movement_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Movement")
@export_node_path("Marker2D") var hud_minimap_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/HudMinimap")
@export_node_path("Marker2D") var hud_clock_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/HudClock")
@export_node_path("Marker2D") var blessings_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Blessings")
@export_node_path("Marker2D") var passenger_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Passenger")
@export_node_path("Marker2D") var documents_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Documents")
@export_node_path("Marker2D") var anomaly_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Anomaly")
@export_node_path("Marker2D") var guidebook_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Guidebook")
@export_node_path("Marker2D") var newspaper_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Newspaper")
@export_node_path("Marker2D") var signature_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Signature")
@export_node_path("Marker2D") var day_service_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/DayService")
@export_node_path("Marker2D") var night_market_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/NightMarket")
@export_node_path("Marker2D") var night_walk_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/NightWalk")
@export_node_path("Marker2D") var night_record_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/NightRecord")
@export_node_path("Marker2D") var night_payout_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/NightPayout")
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
var _spotlight_searching: bool = false
var _spotlight_search_time: float = 0.0
var _portrait_base_scale: Vector2 = Vector2.ONE
var _portrait_rest_scale: Vector2 = Vector2.ONE
var _tail_base_scale: Vector2 = Vector2(-0.9, -0.9)
var _panel_base_scale: Vector2 = Vector2.ONE
var _dock_rest_scale: Vector2 = Vector2.ONE
var _intro_token: int = 0
var _intro_page_index: int = 0
var _typewriter_running: bool = false
var _typewriter_characters: float = 0.0

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Engine.is_editor_hint():
		return
	_portrait_base_scale = _angel_portrait_frame.scale
	_portrait_rest_scale = _portrait_base_scale
	_tail_base_scale = _bubble_tail.scale
	_panel_base_scale = _panel.scale
	_prepare_spotlight_material()
	hide()
	_continue_button.pressed.connect(_advance_from_continue)
	_reset_visuals()
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
	if _main.has_method(&"set_tutorial_route_time_paused"):
		_main.call(&"set_tutorial_route_time_paused", true)
	show()
	_start_intro()


func finish_tutorial() -> void:
	if _step == Step.DONE:
		return
	_step = Step.DONE
	_intro_token += 1
	_spotlight_control = null
	_spotlight_searching = false
	_stop_typewriter()
	_set_tutorial_hud_visible(true)
	if _main != null and _main.has_method(&"set_tutorial_route_time_paused"):
		_main.call(&"set_tutorial_route_time_paused", false)
	if _main != null and _main.has_method(&"_set_player_control_for_state"):
		_main.call(&"_set_player_control_for_state")
	else:
		_set_controls(true, true)
	_reset_visuals()
	hide()
	tutorial_finished.emit()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _spotlight_searching:
		_spotlight_search_time += delta
	_update_spotlight()
	_update_typewriter(delta)
	if _step != Step.MOVEMENT:
		return
	var walking := absf(Input.get_axis(&"move_left", &"move_right")) > 0.1
	if walking:
		_walk_time = minf(_walk_time + delta, movement_required_seconds)
	_progress_label.text = "%.1f / %.1f seconds" % [_walk_time, movement_required_seconds]
	if _walk_time >= movement_required_seconds:
		_show_continue_step(
			Step.HUD_MINIMAP,
			"Train Minimap",
			"The minimap shows each carriage and the passengers inside it. Use it to find remaining passengers quickly, especially near the end of a route.",
			"Click Continue to see the journey clock."
		)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _waiting_for_continue:
		return
	if event.is_action_pressed(&"ui_accept"):
		_advance_from_continue()
		get_viewport().set_input_as_handled()


func _reset_visuals() -> void:
	_intro_token += 1
	_spotlight_control = null
	_spotlight_searching = false
	_stop_typewriter()
	_set_spotlight_shade(0.0)
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


func _start_movement() -> void:
	_step = Step.MOVEMENT
	_spotlight_control = null
	_waiting_for_continue = false
	_walk_time = 0.0
	_set_controls(true, false)
	_set_panel("The Inspector", movement_prompt, "Move until the timer is full.", false)
	_set_spotlight_shade(movement_step_dim_alpha)
	_progress_label.show()
	_progress_label.text = "0.0 / %.1f seconds" % movement_required_seconds


func _show_continue_step(step: Step, speaker: String, body: String, hint: String = "") -> void:
	_step = step
	if step in [Step.HUD_MINIMAP, Step.HUD_CLOCK, Step.BLESSINGS]:
		_set_tutorial_hud_visible(true)
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
		_shade_material.set_shader_parameter(&"spotlight_radius", spotlight_radius)
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
	if _spotlight_searching:
		center = _spotlight_search_center(viewport_size)
	elif is_instance_valid(_spotlight_control) and _spotlight_control.visible:
		center = _spotlight_control.get_global_rect().get_center()
	elif is_instance_valid(_player):
		center = _player.get_global_transform_with_canvas().origin + Vector2(0.0, spotlight_player_vertical_offset)
	center.x = clampf(center.x, 0.0, viewport_size.x)
	center.y = clampf(center.y, 0.0, viewport_size.y)
	_shade_material.set_shader_parameter(&"spotlight_center", center / viewport_size)
	_shade_material.set_shader_parameter(&"viewport_aspect", viewport_size.x / viewport_size.y)
	_shade_material.set_shader_parameter(&"dim_alpha", _shade_alpha)
	_shade_material.set_shader_parameter(&"spotlight_radius", spotlight_radius)
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
		Step.MOVEMENT:
			return movement_dialogue_marker_path
		Step.HUD_MINIMAP:
			return hud_minimap_dialogue_marker_path
		Step.HUD_CLOCK:
			return hud_clock_dialogue_marker_path
		Step.BLESSINGS:
			return blessings_dialogue_marker_path
		Step.PASSENGER:
			return passenger_dialogue_marker_path
		Step.DOCUMENTS, Step.STAMP_CLOSE:
			return documents_dialogue_marker_path
		Step.ANOMALY:
			return anomaly_dialogue_marker_path
		Step.GUIDEBOOK_PROMPT, Step.GUIDEBOOK:
			return guidebook_dialogue_marker_path
		Step.NEWSPAPER_PROMPT, Step.NEWSPAPER:
			return newspaper_dialogue_marker_path
		Step.SIGNATURE_PROMPT, Step.SIGNATURE:
			return signature_dialogue_marker_path
		Step.DAY_SERVICE:
			return day_service_dialogue_marker_path
		Step.NIGHT_MARKET:
			return night_market_dialogue_marker_path
		Step.NIGHT_WALK:
			return night_walk_dialogue_marker_path
		Step.NIGHT_RECORD:
			return night_record_dialogue_marker_path
		Step.NIGHT_PAYOUT:
			return night_payout_dialogue_marker_path
		Step.NIGHT_MAP:
			return night_map_dialogue_marker_path
		_:
			return default_dialogue_marker_path


func _dialogue_frame_name_for_step(step: Step) -> StringName:
	match step:
		Step.INTRO:
			return &"Intro"
		Step.MOVEMENT:
			return &"Movement"
		Step.HUD_MINIMAP:
			return &"HudMinimap"
		Step.HUD_CLOCK:
			return &"HudClock"
		Step.BLESSINGS:
			return &"Blessings"
		Step.PASSENGER:
			return &"Passenger"
		Step.DOCUMENTS, Step.STAMP_CLOSE:
			return &"Documents"
		Step.ANOMALY:
			return &"Anomaly"
		Step.GUIDEBOOK_PROMPT, Step.GUIDEBOOK:
			return &"Guidebook"
		Step.NEWSPAPER_PROMPT, Step.NEWSPAPER:
			return &"Newspaper"
		Step.SIGNATURE_PROMPT, Step.SIGNATURE:
			return &"Signature"
		Step.DAY_SERVICE:
			return &"DayService"
		Step.NIGHT_MARKET:
			return &"NightMarket"
		Step.NIGHT_WALK:
			return &"NightWalk"
		Step.NIGHT_RECORD:
			return &"NightRecord"
		Step.NIGHT_PAYOUT:
			return &"NightPayout"
		Step.NIGHT_MAP:
			return &"NightMap"
		_:
			return &"Default"


func _place_dialogue_at_frame(step: Step, allow_marker_fallback: bool = true) -> void:
	if not is_instance_valid(_dialogue_dock):
		return
	var marker_path: NodePath = _get_dialogue_marker_path_for_step(step)
	var marker := get_node_or_null(marker_path) as Marker2D
	if marker == null:
		marker = get_node_or_null(default_dialogue_marker_path) as Marker2D
	if is_instance_valid(_dialogue_frames):
		var frame := _dialogue_frames.get_node_or_null(String(_dialogue_frame_name_for_step(step))) as Control
		if frame != null:
			# The marker owns placement. The optional frame only authors the
			# bubble size plus the portrait and tail pose for this beat.
			_dialogue_dock.size = frame.size
			_dialogue_dock.scale = frame.scale
			_dock_rest_scale = frame.scale
			_pose_portrait_and_tail(frame)
			if marker != null:
				_dialogue_dock.global_position = marker.global_position
			else:
				_dialogue_dock.global_position = frame.global_position
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
			_bubble_tail.scale = _tail_base_scale * tail_spot.scale
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
		Step.MOVEMENT:
			return ["The Inspector", movement_prompt, "Move until the timer is full."]
		Step.HUD_MINIMAP:
			return ["Train Minimap", "The minimap shows each carriage and the passengers inside it. Use it to find remaining passengers quickly, especially near the end of a route.", "Click Continue to see the journey clock."]
		Step.HUD_CLOCK:
			return ["Journey Clock", "The clock tracks the route. The HUD shows this day's Blessings over the target threshold; daytime Blessings reset each day, but your savings continue into the market.", "Correct drop-offs build Blessings. Wrong stamps cost Blessings."]
		Step.BLESSINGS:
			return ["Day Blessings", "Each day has a Blessings target: correct drop-offs pay +30, while mistakes reduce it. Ordinary passengers leave during the day; suspicious ones stay aboard for the night.", ""]
		Step.PASSENGER:
			return ["First Inspection", passenger_prompt, "Look for the [E] prompt above passengers."]
		Step.DOCUMENTS:
			return ["Passenger Documents", document_prompt, "Click Continue after you have checked the papers."]
		Step.STAMP_CLOSE:
			return ["Stamping", "Drag the station stamp onto the ticket only when the passenger should leave at that station. If they look anomalous, keep them aboard for tonight instead.", "After stamping, close the documents with the X button or Esc."]
		Step.ANOMALY:
			return ["Keep Aboard", "Some passengers are already dead, so never stamp them. Keep them aboard until Night Service can guide them.", ""]
		Step.GUIDEBOOK_PROMPT:
			return ["Guidebook", guidebook_prompt, "Click the Guidebook or press Tab."]
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
			return ["Night Market", "Spend saved Blessings on Veil Note, Radar, or Swiftstep. Each item has limited stock.", "Click Begin when ready."]
		Step.NIGHT_WALK:
			return ["Night Service", night_prompt, "Inspect each remaining soul. Read carefully and click the one sentence that belongs in the ledger."]
		Step.NIGHT_RECORD:
			return ["Statement Found", "Correct hidden text is pulled letter by letter into the ledger. That soul portrait becomes readable, and you can drag it on the station path.", "Continue after you understand the ledger entry."]
		Step.NIGHT_PAYOUT:
			return ["Night Paycheck", "Each released soul pays +100 Blessings. The first attempt is free; every retry costs −100, with a minimum reward of 0.", ""]
		Step.NIGHT_MAP:
			return ["Station Path", "This is the night station path. Use the exact statements in the ledger to place each soul; station pins appear only after you assign someone.", "Complete the assignment to finish the tutorial. Correct souls release Blessings; retries cut the payout after the first attempt."]
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
	_hint_label.text = str(copy[2])
	_progress_label.hide()
	if is_instance_valid(_continue_row):
		_continue_row.show()
	_continue_button.show()
	_place_dialogue_at_frame(preview_step)
	_dialogue_dock.show()
	_panel.show()


func _set_panel(speaker: String, body: String, hint: String, show_continue: bool) -> void:
	_place_dialogue_at_frame(_step)
	_speaker_label.text = speaker
	_hint_label.text = hint
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
			_start_movement()
		return
	_waiting_for_continue = false
	match _step:
		Step.HUD_MINIMAP:
			_show_continue_step(
				Step.HUD_CLOCK,
				"Journey Clock",
				"The clock tracks the route. The HUD shows this day's Blessings over the target threshold; daytime Blessings reset each day, but your savings continue into the market.",
				"Correct drop-offs build Blessings. Wrong stamps cost Blessings."
			)
		Step.HUD_CLOCK:
			_show_continue_step(
				Step.BLESSINGS,
				"Day Blessings",
				"Each day has a Blessings target: correct drop-offs pay +30, while mistakes reduce it. Ordinary passengers leave during the day; suspicious ones stay aboard for the night.",
				""
			)
		Step.BLESSINGS:
			if use_empty_coach_flow:
				_show_continue_step(
					Step.DAY_SERVICE,
					"Clean Coach",
					clean_coach_prompt,
					"Click Continue to finish this clean-start tutorial."
				)
			else:
				_set_controls(true, true)
				_show_wait_step(Step.PASSENGER, "First Inspection", passenger_prompt, "Look for the [E] prompt above passengers.")
		Step.ANOMALY:
			_set_controls(true, true)
			_show_wait_step(Step.GUIDEBOOK_PROMPT, "Guidebook", guidebook_prompt, "Click the Guidebook or press Tab.")
		Step.DOCUMENTS:
			_set_controls(false, false)
			_show_wait_step(Step.STAMP_CLOSE, "Stamping", "Drag the station stamp onto the ticket only when the passenger should leave at that station. If they look anomalous, keep them aboard for tonight instead.", "After stamping, close the documents with the X button or Esc.")
		Step.GUIDEBOOK:
			_show_wait_step(Step.GUIDEBOOK, "Guidebook", "Close the Guidebook when you are ready. Next, check the newspaper because some evidence never appears on the ticket.", "Use the X button, Esc, or Tab to close it.")
		Step.NEWSPAPER:
			_show_wait_step(Step.NEWSPAPER, "Morning Paper", "Close the newspaper when you are ready. If the paper proves a passenger is anomalous, leave them unstamped and keep them aboard.", "Use the X button or Esc to close it.")
		Step.SIGNATURE:
			_show_wait_step(Step.SIGNATURE, "Service Sign-Off", "Now trace the mark. A valid signature confirms this route segment and fast-forwards to the next station.", "A failed trace shakes the screen; try again.")
		Step.NIGHT_MARKET:
			_show_wait_step(Step.NIGHT_WALK, "Night Service", night_prompt, "Use the map button below the Guidebook when your statements are ready.")
		Step.NIGHT_RECORD:
			_set_controls(true, true)
			_show_wait_step(Step.NIGHT_PAYOUT, "Night Paycheck", "Each released soul pays +100 Blessings. The first attempt is free; every retry costs −100, with a minimum reward of 0.", "")
		Step.NIGHT_PAYOUT:
			_show_continue_step(
				Step.NIGHT_MAP,
				"Station Path",
				"This is the night station path. Use the exact statements in the ledger to place each soul; station pins appear only after you assign someone.",
				"Complete the assignment to finish the tutorial. Correct souls release Blessings; retries cut the payout after the first attempt."
			)
		Step.DAY_SERVICE:
			finish_tutorial()
		Step.NIGHT_PAYOUT:
			_show_continue_step(
				Step.NIGHT_MAP,
				"Station Path",
				"This is the night station path. Use the exact statements in the ledger to place each soul; station pins appear only after you assign someone.",
				"Complete the assignment to finish the tutorial. Correct souls release Blessings; retries cut the payout after the first attempt."
			)
		Step.NIGHT_MAP:
			finish_tutorial()
		_:
			pass


func _on_main_tutorial_event(event_name: StringName, payload: Variant = null) -> void:
	_event_log.append(event_name)
	_last_event_payload = payload
	match event_name:
		&"passenger_documents_opened":
			if _step == Step.PASSENGER:
				_show_continue_step(Step.DOCUMENTS, "Passenger Documents", document_prompt, "Click Continue after you have checked the papers.")
		&"ticket_stamped":
			if _step in [Step.DOCUMENTS, Step.STAMP_CLOSE]:
				_show_wait_step(Step.STAMP_CLOSE, "Ticket Stamped", "Good. The ink is permanent, so only stamp when the papers, person, and route all agree.", "Close the document view to continue.")
		&"document_closed":
			if _step == Step.STAMP_CLOSE:
				_show_continue_step(Step.ANOMALY, "Keep Aboard", "Some passengers are already dead, so never stamp them. Keep them aboard until Night Service can guide them.", "")
			elif _step == Step.NEWSPAPER:
				_set_controls(true, true)
				_show_wait_step(Step.SIGNATURE_PROMPT, "Sign Off", signature_prompt, "Use the service button below the Guidebook.")
		&"guidebook_opened":
			if _step == Step.GUIDEBOOK_PROMPT:
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
			if _step in [Step.SIGNATURE_PROMPT, Step.SIGNATURE]:
				_show_wait_step(Step.DAY_SERVICE, "Route Continues", "The train will move to the next station. Keep checking passengers, documents, and evidence until the final station ends daylight service.", "The tutorial will return for Night Market and Night Service.")
		&"night_market_opened":
			_show_continue_step(Step.NIGHT_MARKET, "Night Market", "Spend saved Blessings on Veil Note, Radar, or Swiftstep. Each item has limited stock.", "Click Begin when ready.")
		&"night_started":
			if _step in [Step.DAY_SERVICE, Step.NIGHT_MARKET, Step.NIGHT_WALK]:
				_show_wait_step(Step.NIGHT_WALK, "Night Service", night_prompt, "Inspect each remaining soul. Read carefully and click the one sentence that belongs in the ledger.")
		&"night_statement_recorded":
			if _step in [Step.NIGHT_WALK, Step.NIGHT_RECORD]:
				_show_continue_step(Step.NIGHT_RECORD, "Statement Found", "Correct hidden text is pulled letter by letter into the ledger. That soul portrait becomes readable, and you can drag it on the station path.", "Continue after you understand the ledger entry.")
		&"night_puzzle_opened":
			if _step in [Step.NIGHT_WALK, Step.NIGHT_RECORD, Step.NIGHT_PAYOUT, Step.NIGHT_MAP]:
				_show_continue_step(Step.NIGHT_PAYOUT, "Night Paycheck", "Each released soul pays +100 Blessings. The first attempt is free; every retry costs −100, with a minimum reward of 0.", "")


func _set_controls(can_move: bool, can_interact: bool) -> void:
	if is_instance_valid(_player):
		_player.movement_enabled = can_move
		_player.interaction_enabled = can_interact


func _set_tutorial_hud_visible(value: bool) -> void:
	if not is_instance_valid(_hud):
		return
	_hud.visible = value
