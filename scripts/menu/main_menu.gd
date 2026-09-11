class_name MainMenu
extends Control
## Entry screen for the prototype. Settings reuse the in-game ticket UI.

const ShiftProgress = preload("res://scripts/systems/shift_progress.gd")
const DEFAULT_MANIFEST: DailyManifestConfig = preload("res://data/daily_manifest_config.tres")
const INTRO_SCENE_PATH := "res://scenes/ui/intro_cutscene.tscn"
const GAME_SCENE_PATH := "res://scenes/main/main.tscn"
const INTRO_TRANSITION_DURATION_SCALE: float = 1.35

@export_category("Hand Grip Motion")
@export_range(0.0, 4.0, 0.05) var hand_grip_sway_degrees: float = 1.15
@export_range(0.0, 5.0, 0.05) var hand_grip_vibration_pixels: float = 0.85
@export_range(0.1, 5.0, 0.05) var hand_grip_sway_speed: float = 1.35
@export_range(0.0, 2.0, 0.05) var mc_sway_degrees: float = 0.25
@export_range(0.0, 5.0, 0.05) var mc_vibration_pixels: float = 0.65

@export_category("Logo Motion")
@export_range(0.0, 4.0, 0.05) var logo_float_pixels: float = 1.6
@export_range(0.0, 2.0, 0.05) var logo_sway_degrees: float = 0.28
@export_range(0.1, 3.0, 0.05) var logo_sway_speed: float = 0.72
@export_range(0.1, 1.2, 0.05) var logo_intro_duration: float = 0.58
@export_range(1.0, 1.12, 0.01) var logo_select_scale: float = 1.035

@export_category("Menu Audio")
@export_range(-40.0, -10.0, 0.5) var train_sfx_volume_db: float = -24.0
@export_range(0.0, 4.0, 0.05) var train_sfx_fade_seconds: float = 1.2

@onready var _settings_ui: PauseUI = %SettingsUI
@onready var _start_button: Button = %StartButton
@onready var _continue_button: Button = %ContinueButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _loading_screen: LoadingScreenUI = %LoadingScreenUI
@onready var _loading_transition_animation: AnimationPlayer = %LoadingTransitionAnimation
@onready var _train_sfx: AudioStreamPlayer = %TrainSfx
@onready var _hand_grip: TextureRect = $HandGrip
@onready var _mc: TextureRect = $MC
@onready var _title_root: Control = %TitleRoot
@onready var _title_reaction: Control = %TitleReaction
@onready var _title_idle: Control = %TitleIdle
@onready var _logo_echo_cyan: TextureRect = %LogoEchoCyan
@onready var _logo_echo_pink: TextureRect = %LogoEchoPink
var _transitioning: bool = false
var _hand_grip_origin: Vector2
var _mc_origin: Vector2
var _hand_grip_time: float = 0.0
var _title_motion_time: float = 0.0
var _title_idle_origin: Vector2
var _cyan_echo_origin: Vector2
var _pink_echo_origin: Vector2
var _title_intro_tween: Tween
var _title_reaction_tween: Tween
var _title_kick_direction: float = 1.0

func _ready() -> void:
	_hand_grip_origin = _hand_grip.position
	_mc_origin = _mc.position
	_title_idle_origin = _title_idle.position
	_cyan_echo_origin = _logo_echo_cyan.position
	_pink_echo_origin = _logo_echo_pink.position
	_setup_mirrored_button_art(_continue_button)
	_setup_mirrored_button_art(_quit_button)
	_start_train_sfx()
	_settings_ui.configure_menu_settings_mode(true)
	_settings_ui.set_night_mode(false)
	_settings_ui.configure_service_info(DEFAULT_MANIFEST.service_train_number, DEFAULT_MANIFEST.service_date_text)
	var checkpoint: Dictionary = ShiftProgress.load_checkpoint()
	var can_continue: bool = not checkpoint.is_empty() and not bool(checkpoint.get("completed", false))
	_continue_button.disabled = not can_continue
	_continue_button.text = "CONTINUE — DAY %d" % int(checkpoint.day) if can_continue else "CONTINUE"
	_refresh_mirrored_button_art(_continue_button)
	_refresh_mirrored_button_art(_quit_button)
	if can_continue:
		_continue_button.grab_focus()
	else:
		_start_button.grab_focus()
	_setup_title_feedback()
	_play_title_intro()


func _start_train_sfx() -> void:
	var ogg_stream := _train_sfx.stream as AudioStreamOggVorbis
	if ogg_stream:
		ogg_stream = ogg_stream.duplicate() as AudioStreamOggVorbis
		ogg_stream.loop = true
		_train_sfx.stream = ogg_stream
	_train_sfx.volume_db = train_sfx_volume_db
	if DisplayServer.get_name() == "headless":
		return
	if train_sfx_fade_seconds <= 0.0:
		_train_sfx.play(0.0)
		return
	_train_sfx.volume_db = -40.0
	_train_sfx.play(0.0)
	create_tween().tween_property(_train_sfx, ^"volume_db", train_sfx_volume_db, train_sfx_fade_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	_hand_grip_time += delta
	_title_motion_time += delta
	var sway: float = sin(_hand_grip_time * hand_grip_sway_speed)
	var secondary_sway: float = sin(_hand_grip_time * hand_grip_sway_speed * 0.47 + 0.8)
	var vibration_x: float = sin(_hand_grip_time * 18.0) * hand_grip_vibration_pixels
	var vibration_y: float = sin(_hand_grip_time * 23.0 + 1.7) * hand_grip_vibration_pixels * 0.55
	_hand_grip.rotation = deg_to_rad((sway + secondary_sway * 0.32) * hand_grip_sway_degrees)
	_hand_grip.position = _hand_grip_origin + Vector2(vibration_x, vibration_y)
	var mc_vibration_x: float = sin(_hand_grip_time * 18.0) * mc_vibration_pixels
	var mc_vibration_y: float = sin(_hand_grip_time * 23.0 + 1.7) * mc_vibration_pixels * 0.55
	_mc.rotation = deg_to_rad((sway + secondary_sway * 0.32) * mc_sway_degrees)
	_mc.position = _mc_origin + Vector2(mc_vibration_x, mc_vibration_y)
	_update_title_motion()


func _update_title_motion() -> void:
	var phase: float = _title_motion_time * logo_sway_speed
	_title_idle.position = _title_idle_origin + Vector2(
		sin(phase * 1.37) * logo_float_pixels * 0.42,
		cos(phase) * logo_float_pixels
	)
	_title_idle.rotation = deg_to_rad(sin(phase * 0.83) * logo_sway_degrees)
	# The colored print layers drift by less than a pixel so the logo feels alive
	# without turning into a constant glitch effect.
	_logo_echo_cyan.position = _cyan_echo_origin + Vector2(sin(phase * 1.9) * 0.55, cos(phase * 1.3) * 0.25)
	_logo_echo_pink.position = _pink_echo_origin + Vector2(cos(phase * 1.7) * 0.5, sin(phase * 1.2) * 0.28)


func _setup_title_feedback() -> void:
	for button: Button in [_start_button, _continue_button, _settings_button, _quit_button]:
		button.focus_entered.connect(_kick_title)
		button.mouse_entered.connect(_kick_title)


func _play_title_intro() -> void:
	_title_root.modulate.a = 0.0
	_title_reaction.scale = Vector2.ONE * 0.82
	_title_reaction.rotation = deg_to_rad(-2.4)
	_title_intro_tween = create_tween().set_parallel(true)
	_title_intro_tween.tween_property(_title_root, ^"modulate:a", 1.0, logo_intro_duration * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_title_intro_tween.tween_property(_title_reaction, ^"scale", Vector2.ONE, logo_intro_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_title_intro_tween.tween_property(_title_reaction, ^"rotation", 0.0, logo_intro_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _kick_title() -> void:
	if _transitioning or (_title_intro_tween and _title_intro_tween.is_running()):
		return
	if _title_reaction_tween and _title_reaction_tween.is_valid():
		_title_reaction_tween.kill()
	_title_kick_direction *= -1.0
	_title_reaction.scale = Vector2.ONE
	_title_reaction.rotation = 0.0
	_title_reaction_tween = create_tween().set_parallel(true)
	_title_reaction_tween.tween_property(_title_reaction, ^"scale", Vector2.ONE * logo_select_scale, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_title_reaction_tween.tween_property(_title_reaction, ^"rotation", deg_to_rad(0.55 * _title_kick_direction), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_title_reaction_tween.chain().tween_property(_title_reaction, ^"scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_title_reaction_tween.parallel().tween_property(_title_reaction, ^"rotation", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _show_settings() -> void:
	_settings_ui.open_pause()

func _close_settings() -> void:
	_settings_ui.hide()
	_settings_button.grab_focus()

func _start_game() -> void:
	if _transitioning:
		return
	if ShiftProgress.start_new_run().is_empty():
		push_error("A new run could not be saved. Please try again.")
		return
	_open_game(INTRO_SCENE_PATH, INTRO_TRANSITION_DURATION_SCALE)

func _continue_game() -> void:
	if _transitioning:
		return
	var checkpoint: Dictionary = ShiftProgress.load_checkpoint()
	if checkpoint.is_empty() or bool(checkpoint.get("completed", false)):
		return
	_open_game(GAME_SCENE_PATH)

func _open_game(
	target_scene_path: String = GAME_SCENE_PATH,
	transition_duration_scale: float = 1.0
) -> void:
	if not is_instance_valid(_loading_screen):
		push_error("MainMenu/LoadingScreenUI scene instance is missing.")
		return
	_transitioning = true
	if _title_intro_tween and _title_intro_tween.is_valid():
		_title_intro_tween.kill()
	if _title_reaction_tween and _title_reaction_tween.is_valid():
		_title_reaction_tween.kill()
	_title_root.modulate.a = 1.0
	_title_reaction.scale = Vector2.ONE
	_title_reaction.rotation = 0.0
	_set_menu_buttons_disabled(true)
	_loading_screen.begin_loading(target_scene_path, transition_duration_scale)
	if _loading_transition_animation.has_animation(&"loading_transition"):
		_loading_transition_animation.play(&"loading_transition")

func _quit_game() -> void:
	# Shift progress already lives in user:// and must survive application exit.
	# Only _start_game() replaces it with a fresh Day 1 checkpoint.
	get_tree().quit()

func _set_menu_buttons_disabled(value: bool) -> void:
	_start_button.disabled = value
	_continue_button.disabled = value
	_settings_button.disabled = value
	_quit_button.disabled = value
	_refresh_mirrored_button_art(_continue_button)
	_refresh_mirrored_button_art(_quit_button)

func _setup_mirrored_button_art(button: Button) -> void:
	button.mouse_entered.connect(_refresh_mirrored_button_art.bind(button))
	button.mouse_exited.connect(_refresh_mirrored_button_art.bind(button))
	button.focus_entered.connect(_refresh_mirrored_button_art.bind(button))
	button.focus_exited.connect(_refresh_mirrored_button_art.bind(button))
	button.button_down.connect(_set_mirrored_button_art_state.bind(button, &"pressed"))
	button.button_up.connect(_refresh_mirrored_button_art.bind(button))

func _refresh_mirrored_button_art(button: Button) -> void:
	var state: StringName = &"normal"
	if button.disabled:
		state = &"disabled"
	elif button.is_hovered():
		state = &"hover"
	_set_mirrored_button_art_state(button, state)

func _set_mirrored_button_art_state(button: Button, state: StringName) -> void:
	var art := button.get_node_or_null("MirroredButtonArt") as TextureRect
	if art == null:
		return
	var source_style := _start_button.get_theme_stylebox(state)
	if source_style is StyleBoxTexture:
		art.self_modulate = source_style.modulate_color
