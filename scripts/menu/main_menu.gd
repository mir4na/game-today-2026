class_name MainMenu
extends Control
## Entry screen for the prototype, with persistent audio and display settings.

const SETTINGS_PATH: String = "user://where_do_you_belong_settings.cfg"
const SETTINGS_VERSION: int = 3
const DEFAULT_FULLSCREEN: bool = true
const ShiftProgress = preload("res://scripts/systems/shift_progress.gd")

@export_category("Scene Configuration")
@export var volume_value_template: String = "%d%%"
@export var default_volume: float = 80.0
@export var default_fullscreen: bool = DEFAULT_FULLSCREEN
@export var default_vsync: bool = true

@export_category("Hand Grip Motion")
@export_range(0.0, 4.0, 0.05) var hand_grip_sway_degrees: float = 1.15
@export_range(0.0, 5.0, 0.05) var hand_grip_vibration_pixels: float = 0.85
@export_range(0.1, 5.0, 0.05) var hand_grip_sway_speed: float = 1.35
@export_range(0.0, 2.0, 0.05) var mc_sway_degrees: float = 0.25
@export_range(0.0, 5.0, 0.05) var mc_vibration_pixels: float = 0.65

@onready var _menu_panel: PanelContainer = %MenuPanel
@onready var _settings_panel: PanelContainer = %SettingsPanel
@onready var _start_button: Button = %StartButton
@onready var _continue_button: Button = %ContinueButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _volume_value: Label = %VolumeValue
@onready var _display_mode: OptionButton = %DisplayMode
@onready var _vsync_toggle: CheckButton = %VsyncToggle
@onready var _settings_back_button: Button = %SettingsBackButton
@onready var _loading_screen: LoadingScreenUI = %LoadingScreenUI
@onready var _loading_transition_animation: AnimationPlayer = %LoadingTransitionAnimation
@onready var _hand_grip: TextureRect = $HandGrip
@onready var _mc: TextureRect = $MC
var _transitioning: bool = false
var _hand_grip_origin: Vector2
var _mc_origin: Vector2
var _hand_grip_time: float = 0.0

func _ready() -> void:
	_hand_grip_origin = _hand_grip.position
	_mc_origin = _mc.position
	_setup_mirrored_button_art(_continue_button)
	_setup_mirrored_button_art(_quit_button)
	_load_settings()
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

func _process(delta: float) -> void:
	_hand_grip_time += delta
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and _settings_panel.visible:
		_save_and_close_settings()
		get_viewport().set_input_as_handled()

func _show_settings() -> void:
	_menu_panel.visible = false
	_settings_panel.visible = true
	_volume_slider.grab_focus()

func _save_and_close_settings() -> void:
	_save_settings()
	_settings_panel.visible = false
	_menu_panel.visible = true
	_settings_button.grab_focus()

func _start_game() -> void:
	if _transitioning:
		return
	if ShiftProgress.start_new_run().is_empty():
		push_error("A new run could not be saved. Please try again.")
		return
	_open_game()

func _continue_game() -> void:
	if _transitioning:
		return
	var checkpoint: Dictionary = ShiftProgress.load_checkpoint()
	if checkpoint.is_empty() or bool(checkpoint.get("completed", false)):
		return
	_open_game()

func _open_game() -> void:
	if not is_instance_valid(_loading_screen):
		push_error("MainMenu/LoadingScreenUI scene instance is missing.")
		return
	_transitioning = true
	_set_menu_buttons_disabled(true)
	_loading_screen.begin_loading()
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

func _on_volume_changed(value: float) -> void:
	_volume_value.text = volume_value_template % int(value)
	var master_bus: int = AudioServer.get_bus_index(&"Master")
	if master_bus < 0:
		return
	AudioServer.set_bus_mute(master_bus, value <= 0.0)
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(value / 100.0, 0.001)))

func _on_display_mode_selected(index: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if index == 1 else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func _on_vsync_toggled(enabled: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)

func _load_settings() -> void:
	var config := ConfigFile.new()
	var volume: float = default_volume
	var fullscreen: bool = default_fullscreen
	var vsync: bool = default_vsync
	if config.load(SETTINGS_PATH) == OK:
		volume = float(config.get_value("audio", "master_volume", volume))
		var settings_version: int = int(config.get_value("meta", "version", 1))
		# Version 2 changes first-run and legacy installs to fullscreen by default.
		if settings_version >= SETTINGS_VERSION:
			fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))
		vsync = bool(config.get_value("display", "vsync", vsync))
	_volume_slider.set_value_no_signal(volume)
	_display_mode.select(1 if fullscreen else 0)
	_vsync_toggle.set_pressed_no_signal(vsync)
	_on_volume_changed(volume)
	_on_display_mode_selected(_display_mode.selected)
	_on_vsync_toggled(vsync)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("meta", "version", SETTINGS_VERSION)
	config.set_value("audio", "master_volume", _volume_slider.value)
	config.set_value("display", "fullscreen", _display_mode.selected == 1)
	config.set_value("display", "vsync", _vsync_toggle.button_pressed)
	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save settings: %s" % error_string(error))
