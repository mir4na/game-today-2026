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
	PASSENGER,
	DOCUMENTS,
	STAMP_CLOSE,
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
	NIGHT_MAP,
	DONE,
}

@export_range(0.5, 10.0, 0.1) var movement_required_seconds: float = 3.0
@export var movement_prompt: String = "Walk for 3 seconds with A / D or the Arrow Keys. I only need to see that you can move before the real work begins."
@export var intro_text: String = "You died before your job interview, but you have been given a second chance. Work as an intern conductor on this train. During the day you decide who should leave; at night you resolve the souls that remain."
@export var passenger_prompt: String = "Walk to a passenger and inspect their documents with E. Their body, ID, ticket, route, and destination all matter."
@export var document_prompt: String = "Compare the passenger with their ID and ticket: portrait, name, service date, train number, and destination. Stamp ordinary passengers only when their stop is next. Keep suspicious passengers aboard for Night Service."
@export var guidebook_prompt: String = "Open the Guidebook from the lower-left button or press Tab. Today's Service shows your target. Rules explains scoring. Anomaly Signs shows who should stay aboard for Night Service."
@export var newspaper_prompt: String = "Find and read the morning newspaper. Some anomalies are only proven by the report, especially passengers who should already be dead."
@export var signature_prompt: String = "When you are confident this route segment is done, use the service button above the Guidebook and trace the mark. In day shift it signs off the route; at night the same button opens the station path."
@export var night_prompt: String = "At night, inspect remaining souls and find their hidden Departure Statements. The ledger starts empty; only the exact sentence you click is saved. Then use those statements to assign each soul to the station path."
@export var clean_coach_prompt: String = "This tutorial starts in a clean, empty coach so you can learn the controls safely. In a real shift, passengers will board after the opening station sequence; inspect them, stamp ordinary tickets, and keep anomalies aboard for Night Service."
@export var use_empty_coach_flow: bool = true
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
@export_node_path("Marker2D") var passenger_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Passenger")
@export_node_path("Marker2D") var documents_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Documents")
@export_node_path("Marker2D") var guidebook_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Guidebook")
@export_node_path("Marker2D") var newspaper_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Newspaper")
@export_node_path("Marker2D") var signature_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/Signature")
@export_node_path("Marker2D") var day_service_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/DayService")
@export_node_path("Marker2D") var night_market_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/NightMarket")
@export_node_path("Marker2D") var night_walk_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/NightWalk")
@export_node_path("Marker2D") var night_record_dialogue_marker_path: NodePath = NodePath("DialogueMarkers/NightRecord")
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

@onready var _shade: ColorRect = %Shade
@onready var _dialogue_dock: Control = %DialogueDock
@onready var _panel: Control = %Panel
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _body_label: Label = %BodyLabel
@onready var _hint_label: Label = %HintLabel
@onready var _continue_row: Control = %ContinueRow
@onready var _continue_button: Button = %ContinueButton
@onready var _progress_label: Label = %ProgressLabel
@onready var _arrow_label: Label = %ArrowLabel


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prepare_spotlight_material()
	_continue_button.pressed.connect(_advance_from_continue)
	_reset_visuals()


func start(main_node: Node) -> void:
	_main = main_node
	_player = _main.get_node_or_null("GameplayWorld/TrainOccupants/PlayerSpawnPoint/Player") as ConductorPlayer
	_hud = _main.get_node_or_null("HUD") as GameHUD
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
	_update_spotlight()
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
	_set_spotlight_shade(0.0)
	_dialogue_dock.hide()
	_panel.hide()
	_arrow_label.hide()
	_progress_label.hide()
	if is_instance_valid(_continue_row):
		_continue_row.hide()
	_hint_label.text = ""
	_waiting_for_continue = false


func _start_intro() -> void:
	_set_controls(false, false)
	_show_continue_step(
		Step.INTRO,
		"The Angel",
		intro_text,
		""
	)


func _start_movement() -> void:
	_step = Step.MOVEMENT
	_waiting_for_continue = false
	_walk_time = 0.0
	_set_controls(true, false)
	_set_panel("The Angel", movement_prompt, "Move until the timer is full.", false)
	_set_spotlight_shade(movement_step_dim_alpha)
	_progress_label.show()
	_progress_label.text = "0.0 / %.1f seconds" % movement_required_seconds


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
	if is_instance_valid(_player):
		center = _player.get_global_transform_with_canvas().origin + Vector2(0.0, spotlight_player_vertical_offset)
	center.x = clampf(center.x, 0.0, viewport_size.x)
	center.y = clampf(center.y, 0.0, viewport_size.y)
	_shade_material.set_shader_parameter(&"spotlight_center", center / viewport_size)
	_shade_material.set_shader_parameter(&"viewport_aspect", viewport_size.x / viewport_size.y)
	_shade_material.set_shader_parameter(&"dim_alpha", _shade_alpha)
	_shade_material.set_shader_parameter(&"spotlight_radius", spotlight_radius)
	_shade_material.set_shader_parameter(&"spotlight_softness", spotlight_softness)
	_shade_material.set_shader_parameter(&"inner_alpha", spotlight_inner_alpha)


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
		Step.PASSENGER:
			return passenger_dialogue_marker_path
		Step.DOCUMENTS, Step.STAMP_CLOSE:
			return documents_dialogue_marker_path
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
		Step.NIGHT_MAP:
			return night_map_dialogue_marker_path
		_:
			return default_dialogue_marker_path


func _place_dialogue_at_marker(marker_path: NodePath) -> void:
	if not is_instance_valid(_dialogue_dock):
		return
	var marker := get_node_or_null(marker_path) as Marker2D
	if marker == null:
		marker = get_node_or_null(default_dialogue_marker_path) as Marker2D
	if marker == null:
		push_warning("TutorialDirector has no valid dialogue marker for %s." % marker_path)
		return
	_dialogue_dock.global_position = marker.global_position


func _set_panel(speaker: String, body: String, hint: String, show_continue: bool) -> void:
	_place_dialogue_at_marker(_get_dialogue_marker_path_for_step(_step))
	_speaker_label.text = speaker
	_body_label.text = body
	_hint_label.text = hint
	if is_instance_valid(_continue_row):
		_continue_row.visible = show_continue
	_continue_button.visible = show_continue
	_dialogue_dock.show()
	_panel.show()
	_panel.pivot_offset = _panel.size * 0.5
	_play_dialogue_pop()
	if is_inside_tree():
		GameSFX.play(&"button_hover", -18.0, 1.0, 0.02, 0.05)


func _play_dialogue_pop() -> void:
	if not is_inside_tree() or not is_instance_valid(_dialogue_dock):
		return
	if is_instance_valid(_dialogue_tween) and _dialogue_tween.is_valid():
		_dialogue_tween.kill()
	_dialogue_dock.modulate.a = 0.0
	_dialogue_dock.pivot_offset = Vector2.ZERO
	_dialogue_dock.scale = Vector2(0.985, 0.985)
	_dialogue_tween = create_tween().set_parallel(true)
	_dialogue_tween.tween_property(_dialogue_dock, ^"modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_dialogue_tween.tween_property(_dialogue_dock, ^"scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _advance_from_continue() -> void:
	if not _waiting_for_continue:
		return
	_waiting_for_continue = false
	match _step:
		Step.INTRO:
			_start_movement()
		Step.HUD_MINIMAP:
			_show_continue_step(
				Step.HUD_CLOCK,
				"Journey Clock",
				"The clock tracks the route. The HUD shows this day's Blessings over the target threshold; daytime Blessings reset each day, but your savings continue into the market.",
				"Correct drop-offs build Blessings. Wrong stamps cost Blessings."
			)
		Step.HUD_CLOCK:
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
			_show_wait_step(Step.NIGHT_WALK, "Night Service", night_prompt, "Use the map button above the Guidebook when your statements are ready.")
		Step.NIGHT_RECORD:
			_set_controls(true, true)
			_show_wait_step(Step.NIGHT_MAP, "Station Path", "Drag each recovered soul from the ledger to a station. There are always four stations; a station can receive more than one soul, and another station may stay empty.", "Finalize only when every found soul is assigned. The first attempt is free; retries reduce the night payout.")
		Step.DAY_SERVICE:
			finish_tutorial()
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
				_set_controls(true, true)
				_show_wait_step(Step.GUIDEBOOK_PROMPT, "Guidebook", guidebook_prompt, "Click the Guidebook or press Tab.")
			elif _step == Step.NEWSPAPER:
				_set_controls(true, true)
				_show_wait_step(Step.SIGNATURE_PROMPT, "Sign Off", signature_prompt, "Use the service button above the Guidebook.")
		&"guidebook_opened":
			if _step == Step.GUIDEBOOK_PROMPT:
				_show_continue_step(Step.GUIDEBOOK, "Guidebook", "Today’s Service shows the current target and route totals. Rules explains Blessings and penalties. Anomaly Signs shows suspicious evidence to keep aboard for Night Service.", "Close the Guidebook after reading.")
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
			_show_continue_step(Step.NIGHT_MARKET, "Night Market", "Blessings carry into the Night Market. Veil Note reveals one extra statement, Radar scans coaches, and Swiftstep triples your walking speed for 10 seconds. Item stocks are limited.", "Click Begin when you are ready.")
		&"night_started":
			if _step in [Step.DAY_SERVICE, Step.NIGHT_MARKET, Step.NIGHT_WALK]:
				_show_wait_step(Step.NIGHT_WALK, "Night Service", night_prompt, "Inspect each remaining soul. Read carefully and click the one sentence that belongs in the ledger.")
		&"night_statement_recorded":
			if _step in [Step.NIGHT_WALK, Step.NIGHT_RECORD]:
				_show_continue_step(Step.NIGHT_RECORD, "Statement Found", "Correct hidden text is pulled letter by letter into the ledger. That soul portrait becomes readable, and you can drag it on the station path.", "Continue after you understand the ledger entry.")
		&"night_puzzle_opened":
			if _step in [Step.NIGHT_WALK, Step.NIGHT_RECORD, Step.NIGHT_MAP]:
				_show_continue_step(Step.NIGHT_MAP, "Station Path", "This is the night station path. Use the exact statements in the ledger to place each soul; station pins appear only after you assign someone.", "Complete the assignment to finish the tutorial. Correct souls release Blessings; retries cut the payout after the first attempt.")


func _set_controls(can_move: bool, can_interact: bool) -> void:
	if is_instance_valid(_player):
		_player.movement_enabled = can_move
		_player.interaction_enabled = can_interact
