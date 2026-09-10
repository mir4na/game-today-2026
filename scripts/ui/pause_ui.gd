class_name PauseUI
extends Control
## Ticket-shaped pause and settings menu with persistent display/audio options.

signal resume_requested
signal restart_requested
signal main_menu_requested

const SETTINGS_PATH: String = "user://where_do_you_belong_settings.cfg"
const SETTINGS_VERSION: int = 3
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]
const DAY_INK: Color = Color("353540")
const NIGHT_INK: Color = Color("f4e49e")
const NIGHT_BUTTON_TINT: Color = Color("c9b7dc")

@export_category("Ticket Animation")
@export_range(0.1, 0.8, 0.01) var open_duration: float = 0.34
@export_range(0.1, 0.8, 0.01) var close_duration: float = 0.24
@export_range(0.5, 1.0, 0.01) var opening_scale: float = 0.82
@export_range(0.0, 8.0, 0.1) var opening_rotation_degrees: float = 2.2

var _fullscreen: bool = true
var _vsync: bool = true
var _resolution_index: int = 2
var _master_volume: int = 80
var _sfx_volume: int = 80
var _music_volume: int = 70
var _announcement_volume: int = 85
var _ambience_volume: int = 70
var _closing: bool = false
var _ticket_rest_position: Vector2
var _ticket_rest_scale: Vector2
var _menu_tween: Tween
var _action_tweens: Dictionary = {}
var _night_mode: bool = false
var _menu_settings_mode: bool = false

@onready var _shade: ColorRect = %Shade
@onready var _ticket: Control = %Ticket
@onready var _ticket_artwork: TextureRect = %TicketArtwork
@onready var _options_title: TextureRect = %OptionsTitle
@onready var _train_number_label: Label = %TrainNumber
@onready var _service_date_label: Label = %ServiceDate
@onready var _resume_button: Button = %ResumeButton
@onready var _restart_button: Button = %RestartButton
@onready var _main_menu_button: Button = %MainMenuButton
@onready var _selectors: Dictionary = {
	&"display": %DisplayModeOption,
	&"resolution": %ResolutionOption,
	&"vsync": %VsyncOption,
	&"master": %MasterVolumeOption,
	&"sfx": %SfxVolumeOption,
	&"music": %MusicVolumeOption,
	&"announcement": %AnnouncementVolumeOption,
	&"ambience": %AmbienceVolumeOption,
}


func _ready() -> void:
	_ticket_rest_position = _ticket.position
	_ticket_rest_scale = _ticket.scale
	_ticket.pivot_offset = _ticket.size * 0.5
	_connect_option_selectors()
	_load_settings()
	_refresh_option_values()
	_apply_all_settings()
	_apply_time_palette()
	_apply_context_mode()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_with_action(&"resume")


func configure_service_info(train_number: String, service_date: String) -> void:
	var clean_number: String = train_number.strip_edges()
	var clean_date: String = service_date.strip_edges()
	_train_number_label.text = "Train %s" % (clean_number if not clean_number.is_empty() else "—")
	_service_date_label.text = clean_date if not clean_date.is_empty() else "—"


func open_pause() -> void:
	_closing = false
	show()
	_refresh_option_values()
	_play_open_animation()
	(%DisplayModeOption as PauseOptionSelector).focus_first()


func set_night_mode(enabled: bool) -> void:
	_night_mode = enabled
	if is_node_ready():
		_apply_time_palette()


func configure_menu_settings_mode(enabled: bool) -> void:
	_menu_settings_mode = enabled
	if is_node_ready():
		_apply_context_mode()


func _apply_context_mode() -> void:
	var enabled: bool = _menu_settings_mode
	_resume_button.visible = not enabled
	_restart_button.visible = not enabled
	_main_menu_button.text = "Back" if enabled else "Main menu"


func _apply_time_palette() -> void:
	var strength: float = 1.0 if _night_mode else 0.0
	var artwork_material := _ticket_artwork.material as ShaderMaterial
	if artwork_material:
		artwork_material.set_shader_parameter(&"night_strength", strength)
	var title_material := _options_title.material as ShaderMaterial
	if title_material:
		title_material.set_shader_parameter(&"night_strength", strength)
	for selector_node: Variant in _selectors.values():
		var selector := selector_node as PauseOptionSelector
		if is_instance_valid(selector):
			selector.set_night_mode(_night_mode)
	var info_color: Color = NIGHT_INK if _night_mode else DAY_INK
	_train_number_label.add_theme_color_override(&"font_color", info_color)
	_service_date_label.add_theme_color_override(&"font_color", info_color)
	var button_tint: Color = NIGHT_BUTTON_TINT if _night_mode else Color.WHITE
	_resume_button.self_modulate = button_tint
	_restart_button.self_modulate = button_tint
	_main_menu_button.self_modulate = button_tint


func _connect_option_selectors() -> void:
	for key: StringName in _selectors:
		var selector := _selectors[key] as PauseOptionSelector
		if is_instance_valid(selector):
			selector.step_requested.connect(_on_option_step.bind(key))
			selector.slider_value_changed.connect(_on_option_slider_changed.bind(key))


func _on_option_step(direction: int, key: StringName) -> void:
	match key:
		&"display":
			_fullscreen = not _fullscreen
		&"resolution":
			_resolution_index = wrapi(_resolution_index + direction, 0, RESOLUTIONS.size())
		&"vsync":
			_vsync = not _vsync
		&"master":
			_master_volume = clampi(_master_volume + direction * 10, 0, 100)
		&"sfx":
			_sfx_volume = clampi(_sfx_volume + direction * 10, 0, 100)
		&"music":
			_music_volume = clampi(_music_volume + direction * 10, 0, 100)
		&"announcement":
			_announcement_volume = clampi(_announcement_volume + direction * 10, 0, 100)
		&"ambience":
			_ambience_volume = clampi(_ambience_volume + direction * 10, 0, 100)
	_apply_option(key)
	_refresh_option_values()
	_save_settings()


func _on_option_slider_changed(value: int, key: StringName) -> void:
	match key:
		&"master":
			_master_volume = value
		&"sfx":
			_sfx_volume = value
		&"music":
			_music_volume = value
		&"announcement":
			_announcement_volume = value
		&"ambience":
			_ambience_volume = value
		_:
			return
	_apply_option(key)
	_save_settings()


func _refresh_option_values() -> void:
	_set_selector_value(&"display", "Fullscreen" if _fullscreen else "Windowed")
	var resolution: Vector2i = RESOLUTIONS[_resolution_index]
	_set_selector_value(&"resolution", "%d × %d" % [resolution.x, resolution.y])
	_set_selector_value(&"vsync", "On" if _vsync else "Off")
	_set_selector_slider(&"master", _master_volume)
	_set_selector_slider(&"sfx", _sfx_volume)
	_set_selector_slider(&"music", _music_volume)
	_set_selector_slider(&"announcement", _announcement_volume)
	_set_selector_slider(&"ambience", _ambience_volume)


func _set_selector_value(key: StringName, value: String) -> void:
	var selector := _selectors.get(key) as PauseOptionSelector
	if is_instance_valid(selector):
		selector.set_value_text(value)


func _set_selector_slider(key: StringName, value: int) -> void:
	var selector := _selectors.get(key) as PauseOptionSelector
	if is_instance_valid(selector):
		selector.set_slider_value(value)


func _apply_all_settings() -> void:
	_apply_display_settings()
	_set_bus_volume(&"Master", _master_volume)
	_set_bus_volume(&"SFX", _sfx_volume)
	_set_bus_volume(&"Music", _music_volume)
	_set_bus_volume(&"Announcement", _announcement_volume)
	_set_bus_volume(&"Ambience", _ambience_volume)


func _apply_option(key: StringName) -> void:
	match key:
		&"display", &"resolution", &"vsync":
			_apply_display_settings()
		&"master":
			_set_bus_volume(&"Master", _master_volume)
		&"sfx":
			_set_bus_volume(&"SFX", _sfx_volume)
		&"music":
			_set_bus_volume(&"Music", _music_volume)
		&"announcement":
			_set_bus_volume(&"Announcement", _announcement_volume)
		&"ambience":
			_set_bus_volume(&"Ambience", _ambience_volume)


func _apply_display_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if _vsync else DisplayServer.VSYNC_DISABLED)
	if not _fullscreen:
		var target_size: Vector2i = RESOLUTIONS[_resolution_index]
		DisplayServer.window_set_size(target_size)
		var screen_size: Vector2i = DisplayServer.screen_get_size()
		DisplayServer.window_set_position((screen_size - target_size) / 2)


func _set_bus_volume(bus_name: StringName, percentage: int) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, bus_name)
	var linear_volume: float = clampf(float(percentage) / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, percentage <= 0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(linear_volume, 0.001)))


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	_fullscreen = bool(config.get_value("display", "fullscreen", _fullscreen))
	_vsync = bool(config.get_value("display", "vsync", _vsync))
	_resolution_index = clampi(int(config.get_value("display", "resolution_index", _resolution_index)), 0, RESOLUTIONS.size() - 1)
	_master_volume = clampi(int(config.get_value("audio", "master_volume", _master_volume)), 0, 100)
	_sfx_volume = clampi(int(config.get_value("audio", "sfx_volume", _sfx_volume)), 0, 100)
	_music_volume = clampi(int(config.get_value("audio", "music_volume", _music_volume)), 0, 100)
	_announcement_volume = clampi(int(config.get_value("audio", "announcement_volume", _announcement_volume)), 0, 100)
	_ambience_volume = clampi(int(config.get_value("audio", "ambience_volume", _ambience_volume)), 0, 100)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("meta", "version", SETTINGS_VERSION)
	config.set_value("display", "fullscreen", _fullscreen)
	config.set_value("display", "vsync", _vsync)
	config.set_value("display", "resolution_index", _resolution_index)
	config.set_value("audio", "master_volume", _master_volume)
	config.set_value("audio", "sfx_volume", _sfx_volume)
	config.set_value("audio", "music_volume", _music_volume)
	config.set_value("audio", "announcement_volume", _announcement_volume)
	config.set_value("audio", "ambience_volume", _ambience_volume)
	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save pause settings: %s" % error_string(error))


func _play_open_animation() -> void:
	if _menu_tween and _menu_tween.is_valid():
		_menu_tween.kill()
	_ticket.position = _ticket_rest_position + Vector2(0.0, 28.0)
	_ticket.scale = _ticket_rest_scale * opening_scale
	_ticket.rotation = deg_to_rad(-opening_rotation_degrees)
	_ticket.modulate.a = 0.0
	_shade.modulate.a = 0.0
	_menu_tween = create_tween().set_parallel(true)
	_menu_tween.tween_property(_shade, ^"modulate:a", 1.0, open_duration * 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_menu_tween.tween_property(_ticket, ^"position", _ticket_rest_position, open_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_menu_tween.tween_property(_ticket, ^"scale", _ticket_rest_scale, open_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_menu_tween.tween_property(_ticket, ^"rotation", 0.0, open_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_menu_tween.tween_property(_ticket, ^"modulate:a", 1.0, open_duration * 0.58).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _close_with_action(action: StringName) -> void:
	if _closing:
		return
	_closing = true
	if _menu_tween and _menu_tween.is_valid():
		_menu_tween.kill()
	_menu_tween = create_tween().set_parallel(true)
	_menu_tween.tween_property(_shade, ^"modulate:a", 0.0, close_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_menu_tween.tween_property(_ticket, ^"position", _ticket_rest_position + Vector2(0.0, 22.0), close_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_menu_tween.tween_property(_ticket, ^"scale", _ticket_rest_scale * 0.91, close_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_menu_tween.tween_property(_ticket, ^"rotation", deg_to_rad(opening_rotation_degrees * 0.65), close_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_menu_tween.tween_property(_ticket, ^"modulate:a", 0.0, close_duration * 0.82).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _menu_tween.finished
	match action:
		&"restart":
			restart_requested.emit()
		&"main_menu":
			main_menu_requested.emit()
		_:
			resume_requested.emit()


func _on_restart_button_pressed() -> void:
	_close_with_action(&"restart")


func _on_resume_button_pressed() -> void:
	_close_with_action(&"resume")


func _on_main_menu_button_pressed() -> void:
	_close_with_action(&"main_menu")
