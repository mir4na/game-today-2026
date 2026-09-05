class_name MainMenu
extends Control
## Entry screen for the prototype, with persistent audio and display settings.

const SETTINGS_PATH: String = "user://where_do_you_belong_settings.cfg"
const SETTINGS_VERSION: int = 2
const DEFAULT_FULLSCREEN: bool = true
const ShiftProgress = preload("res://scripts/systems/shift_progress.gd")

@export_category("Scene Configuration")
@export var loading_screen_scene: PackedScene
@export var volume_value_template: String = "%d%%"
@export var default_volume: float = 80.0
@export var default_fullscreen: bool = DEFAULT_FULLSCREEN
@export var default_vsync: bool = true

@onready var _menu_panel: PanelContainer = %MenuPanel
@onready var _settings_panel: PanelContainer = %SettingsPanel
@onready var _start_button: Button = %StartButton
@onready var _continue_button: Button = %ContinueButton
@onready var _progress_hint: Label = %ProgressHint
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _volume_value: Label = %VolumeValue
@onready var _display_mode: OptionButton = %DisplayMode
@onready var _vsync_toggle: CheckButton = %VsyncToggle
@onready var _settings_back_button: Button = %SettingsBackButton
@onready var _fade: ColorRect = %Fade
var _transitioning: bool = false

func _ready() -> void:
	_load_settings()
	var checkpoint: Dictionary = ShiftProgress.load_checkpoint()
	var can_continue: bool = not checkpoint.is_empty() and not bool(checkpoint.get("completed", false))
	_continue_button.disabled = not can_continue
	_continue_button.text = "CONTINUE — DAY %d" % int(checkpoint.day) if can_continue else "CONTINUE"
	_progress_hint.text = "Continue resumes the start of your saved day.\nNew Game replaces the saved run." if can_continue else "Five days. One journey."
	if not checkpoint.is_empty() and bool(checkpoint.get("completed", false)):
		_progress_hint.text = "FIVE-DAY JOURNEY COMPLETE\nStart a new game to play again."
	if can_continue:
		_continue_button.grab_focus()
	else:
		_start_button.grab_focus()

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
	if loading_screen_scene == null:
		push_error("MainMenu/Loading Screen Scene is not configured in the Inspector.")
		return
	if not ShiftProgress.save_checkpoint(ShiftProgress.make_checkpoint(1, {}, ShiftProgress.new_seed())):
		_progress_hint.text = "Progress could not be saved. Please try again."
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
	if loading_screen_scene == null:
		push_error("MainMenu/Loading Screen Scene is not configured in the Inspector.")
		return
	_transitioning = true
	_set_menu_buttons_disabled(true)
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, 0.35)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_packed(loading_screen_scene))

func _quit_game() -> void:
	get_tree().quit()

func _set_menu_buttons_disabled(value: bool) -> void:
	_start_button.disabled = value
	_continue_button.disabled = value
	_settings_button.disabled = value
	_quit_button.disabled = value

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
	config.set_value("meta", "version", SETTINGS_VERSION)
	config.set_value("audio", "master_volume", _volume_slider.value)
	config.set_value("display", "fullscreen", _display_mode.selected == 1)
	config.set_value("display", "vsync", _vsync_toggle.button_pressed)
	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save settings: %s" % error_string(error))
