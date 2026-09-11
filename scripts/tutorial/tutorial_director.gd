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
@export var movement_prompt: String = "Walk for 3 seconds with A / D or the Arrow Keys."
@export var intro_text: String = "You died before your job interview, but you have been given a second chance. Work as an intern conductor on this train, and do the job well."
@export var passenger_prompt: String = "Walk to a passenger and inspect their documents with E."
@export var document_prompt: String = "Compare the passenger, ID, ticket date, train number, and destination before stamping."
@export var guidebook_prompt: String = "Open the Guidebook from the lower-left button or press Tab. It explains today's service and rules."
@export var newspaper_prompt: String = "Find and read the morning newspaper. Some anomalies are revealed by what the paper reports."
@export var signature_prompt: String = "When you are confident this route segment is done, use the service button above the Guidebook and trace the mark to continue."
@export var night_prompt: String = "At night, inspect remaining souls, find their hidden Departure Statements, then use the station path button to assign them."

var _main: Node
var _player: ConductorPlayer
var _hud: GameHUD
var _step: Step = Step.INACTIVE
var _walk_time: float = 0.0
var _waiting_for_continue: bool = false
var _event_log: Array[StringName] = []
var _last_event_payload: Variant

@onready var _shade: ColorRect = %Shade
@onready var _panel: PanelContainer = %Panel
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _body_label: Label = %BodyLabel
@onready var _hint_label: Label = %HintLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _progress_label: Label = %ProgressLabel
@onready var _arrow_label: Label = %ArrowLabel


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
			"The minimap shows each carriage and the passengers inside it. Use it when you need to find remaining passengers quickly.",
			"Click Continue to see the journey clock."
		)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _waiting_for_continue:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
		_advance_from_continue()
		get_viewport().set_input_as_handled()


func _reset_visuals() -> void:
	_shade.modulate.a = 0.0
	_panel.hide()
	_arrow_label.hide()
	_progress_label.hide()
	_hint_label.text = ""
	_waiting_for_continue = false


func _start_intro() -> void:
	_set_controls(false, false)
	_show_continue_step(
		Step.INTRO,
		"The Angel",
		intro_text,
		"Press E, Space, or click Continue."
	)


func _start_movement() -> void:
	_step = Step.MOVEMENT
	_waiting_for_continue = false
	_walk_time = 0.0
	_set_controls(true, false)
	_set_panel("The Angel", movement_prompt, "Move until the timer is full.", false)
	_shade.modulate.a = 0.18
	_progress_label.show()
	_progress_label.text = "0.0 / %.1f seconds" % movement_required_seconds


func _show_continue_step(step: Step, speaker: String, body: String, hint: String = "") -> void:
	_step = step
	_waiting_for_continue = true
	_set_controls(false, false)
	_set_panel(speaker, body, hint, true)
	_shade.modulate.a = 0.28
	_progress_label.hide()


func _show_wait_step(step: Step, speaker: String, body: String, hint: String = "") -> void:
	_step = step
	_waiting_for_continue = false
	_set_panel(speaker, body, hint, false)
	_shade.modulate.a = 0.12
	_progress_label.hide()


func _set_panel(speaker: String, body: String, hint: String, show_continue: bool) -> void:
	_speaker_label.text = speaker
	_body_label.text = body
	_hint_label.text = hint
	_continue_button.visible = show_continue
	_panel.show()
	_panel.pivot_offset = _panel.size * 0.5
	if is_inside_tree():
		GameSFX.play(&"button_hover", -18.0, 1.0, 0.02, 0.05)


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
				"The clock tracks the route. Your day target is shown as current Blessings over the threshold for this day.",
				"Correct daylight drop-offs build the day's Blessings."
			)
		Step.HUD_CLOCK:
			_set_controls(true, true)
			_show_wait_step(Step.PASSENGER, "First Inspection", passenger_prompt, "Look for the [E] prompt above passengers.")
		Step.DOCUMENTS:
			_set_controls(false, false)
			_show_wait_step(Step.STAMP_CLOSE, "Stamping", "Drag the correct station stamp onto the ticket only when the passenger should leave at that station.", "After stamping, close the documents with the X button or Esc.")
		Step.GUIDEBOOK:
			_show_wait_step(Step.GUIDEBOOK, "Guidebook", "Close the Guidebook when you are ready. The next lesson is the newspaper clue.", "Use the X button, Esc, or Tab to close it.")
		Step.NEWSPAPER:
			_show_wait_step(Step.NEWSPAPER, "Morning Paper", "Close the newspaper when you are ready. Then you can sign off this route segment.", "Use the X button or Esc to close it.")
		Step.SIGNATURE:
			_show_wait_step(Step.SIGNATURE, "Service Sign-Off", "Now trace the mark. The route only advances after the signature is accepted.", "A failed trace shakes the screen; try again.")
		Step.NIGHT_MARKET:
			_show_wait_step(Step.NIGHT_WALK, "Night Service", night_prompt, "Use the map button above the Guidebook when your statements are ready.")
		Step.NIGHT_RECORD:
			_set_controls(true, true)
			_show_wait_step(Step.NIGHT_MAP, "Station Path", "Drag each recovered soul from the ledger to its station. Some stations can receive more than one soul, and some may remain empty.", "Finalize only when every found soul is assigned.")
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
				_show_wait_step(Step.STAMP_CLOSE, "Ticket Stamped", "Good. The ink is permanent, so only stamp when you are sure.", "Close the document view to continue.")
		&"document_closed":
			if _step == Step.STAMP_CLOSE:
				_set_controls(true, true)
				_show_wait_step(Step.GUIDEBOOK_PROMPT, "Guidebook", guidebook_prompt, "Click the Guidebook or press Tab.")
			elif _step == Step.NEWSPAPER:
				_set_controls(true, true)
				_show_wait_step(Step.SIGNATURE_PROMPT, "Sign Off", signature_prompt, "Use the service button above the Guidebook.")
		&"guidebook_opened":
			if _step == Step.GUIDEBOOK_PROMPT:
				_show_continue_step(Step.GUIDEBOOK, "Guidebook", "Today’s Service shows threshold progress. Rules explains scoring. Anomaly Signs shows what to keep aboard for night service.", "Close the Guidebook after reading.")
		&"guidebook_closed":
			if _step == Step.GUIDEBOOK:
				_set_controls(true, true)
				_show_wait_step(Step.NEWSPAPER_PROMPT, "Newspaper", newspaper_prompt, "Find the newspaper interactable in the carriage.")
		&"newspaper_opened":
			if _step in [Step.NEWSPAPER_PROMPT, Step.GUIDEBOOK, Step.GUIDEBOOK_PROMPT]:
				_show_continue_step(Step.NEWSPAPER, "Morning Paper", "The paper can confirm whether a passenger died before this route. If it names a passenger aboard, keep them for night service.", "Close the newspaper after reading.")
		&"service_signature_opened":
			if _step == Step.SIGNATURE_PROMPT:
				_show_continue_step(Step.SIGNATURE, "Service Sign-Off", "Trace the mark to confirm you are ready to continue to the next station.", "A failed trace shakes the screen; try again.")
		&"service_signed":
			if _main != null and _main.has_method(&"set_tutorial_route_time_paused"):
				_main.call(&"set_tutorial_route_time_paused", false)
			if _step in [Step.SIGNATURE_PROMPT, Step.SIGNATURE]:
				_show_wait_step(Step.DAY_SERVICE, "Route Continues", "The train will move to the next station. Keep inspecting until the final station ends daylight service.", "The tutorial will return for Night Market and Night Service.")
		&"night_market_opened":
			_show_continue_step(Step.NIGHT_MARKET, "Night Market", "Blessings carry into the Night Market. Veil Note reveals one extra clue, Radar scans coaches, and Swiftstep triples your walking speed for 10 seconds.", "Click Begin when you are ready.")
		&"night_started":
			if _step in [Step.DAY_SERVICE, Step.NIGHT_MARKET, Step.NIGHT_WALK]:
				_show_wait_step(Step.NIGHT_WALK, "Night Service", night_prompt, "Inspect each remaining soul to recover statements.")
		&"night_statement_recorded":
			if _step in [Step.NIGHT_WALK, Step.NIGHT_RECORD]:
				_show_continue_step(Step.NIGHT_RECORD, "Statement Found", "Correct hidden text is pulled into the ledger. The soul portrait turns readable once its statement is found.", "Continue after you understand the ledger entry.")
		&"night_puzzle_opened":
			if _step in [Step.NIGHT_WALK, Step.NIGHT_RECORD, Step.NIGHT_MAP]:
				_show_continue_step(Step.NIGHT_MAP, "Station Path", "This is the night station path. Use the exact statements in the ledger to place each soul.", "Complete the assignment to finish the tutorial.")


func _set_controls(can_move: bool, can_interact: bool) -> void:
	if is_instance_valid(_player):
		_player.movement_enabled = can_move
		_player.interaction_enabled = can_interact
