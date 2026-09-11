class_name IntroCutscene
extends Control
## First-run story cards. Introbackground remains beneath every page so each
## click briefly reveals the blank card before the next illustration fades in.

const GAME_SCENE_PATH := "res://scenes/main/main.tscn"
const INTRO_PAGES: Array[Texture2D] = [
	preload("res://assets/Cutscene/Intro/Intro/Intro1.png"),
	preload("res://assets/Cutscene/Intro/Intro/Intro2.png"),
	preload("res://assets/Cutscene/Intro/Intro/Intro3.png"),
	preload("res://assets/Cutscene/Intro/Intro/Intro4.png"),
	preload("res://assets/Cutscene/Intro/Intro/Intro5.png"),
	preload("res://assets/Cutscene/Intro/Intro/Intro6.png"),
	preload("res://assets/Cutscene/Intro/Intro/Intro7.png"),
	preload("res://assets/Cutscene/Intro/Intro/Intro8.png"),
	preload("res://assets/Cutscene/Intro/Intro/Intro9.png"),
	preload("res://assets/Cutscene/Intro/Intro/Intro10.png"),
]

@export_category("Music")
@export var music_track: StringName = &"intro"
@export var music_loops: bool = true
@export_category("Page Transition")
@export_range(0.1, 1.0, 0.01) var opening_fade_duration: float = 0.45
@export_range(0.1, 2.4, 0.01) var page_fade_duration: float = 0.9
@export_range(0.1, 1.0, 0.01) var closing_fade_duration: float = 0.48
@export var preload_gameplay_during_intro: bool = true
@export_category("Interaction")
@export_range(0.6, 4.0, 0.1) var hold_to_skip_seconds: float = 1.5
@export_range(1.0, 10.0, 0.25) var continue_hint_delay_seconds: float = 4.0

var _page_index: int = 0
var _transitioning: bool = false
var _finishing: bool = false
var _holding: bool = false
var _hold_completed: bool = false
var _hold_elapsed: float = 0.0
var _idle_elapsed: float = 0.0
var _page_tween: Tween

@onready var _background: TextureRect = %IntroBackground
@onready var _current_page: TextureRect = %CurrentPage
@onready var _next_page: TextureRect = %NextPage
@onready var _fade_cover: ColorRect = %FadeCover
@onready var _prompt_label: Label = %PromptLabel
@onready var _hold_ring: IntroHoldRing = %HoldRing
@onready var _loading_screen: LoadingScreenUI = %LoadingScreenUI


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var music_manager := get_node_or_null("/root/MusicManager")
	if music_manager != null and music_manager.has_method(&"play"):
		music_manager.call(&"play", music_track, music_loops)
	_current_page.texture = INTRO_PAGES[0]
	_current_page.modulate.a = 0.0
	_next_page.modulate.a = 0.0
	_fade_cover.modulate.a = 1.0
	_set_hold_prompt(0.0)
	if preload_gameplay_during_intro:
		ResourceLoader.load_threaded_request(GAME_SCENE_PATH, "PackedScene", true)
	var opening := create_tween().set_parallel(true)
	opening.tween_property(_fade_cover, ^"modulate:a", 0.0, opening_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	opening.tween_property(_current_page, ^"modulate:a", 1.0, opening_fade_duration * 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _finishing:
		return
	if _holding:
		_hold_elapsed = minf(_hold_elapsed + delta, hold_to_skip_seconds)
		_set_hold_prompt(_hold_elapsed / maxf(hold_to_skip_seconds, 0.001))
		if _hold_elapsed >= hold_to_skip_seconds:
			_hold_completed = true
			_holding = false
			_finish_intro()
		return
	_idle_elapsed += delta
	if _idle_elapsed >= continue_hint_delay_seconds:
		_set_continue_prompt()


func _input(event: InputEvent) -> void:
	if _finishing:
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		_handle_pointer_hold(mouse_button.pressed)
		get_viewport().set_input_as_handled()
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		_handle_pointer_hold(touch.pressed)
		get_viewport().set_input_as_handled()


func _handle_pointer_hold(pressed: bool) -> void:
	if pressed:
		_holding = true
		_hold_completed = false
		_hold_elapsed = 0.0
		_idle_elapsed = 0.0
		_set_hold_prompt(0.0)
		return
	var should_advance: bool = _holding and not _hold_completed
	_holding = false
	_hold_elapsed = 0.0
	_idle_elapsed = 0.0
	_set_hold_prompt(0.0)
	if should_advance:
		_advance_page()


func _advance_page() -> void:
	if _transitioning or _finishing:
		return
	if _page_index >= INTRO_PAGES.size() - 1:
		_finish_intro()
		return
	_transitioning = true
	_idle_elapsed = 0.0
	var next_index := _page_index + 1
	_next_page.texture = INTRO_PAGES[next_index]
	_next_page.modulate.a = 0.0
	if is_instance_valid(_page_tween):
		_page_tween.kill()
	_page_tween = create_tween()
	# Fade the illustrated page away first, exposing Introbackground. The next
	# page only starts after that, making the blank card a readable transition.
	_page_tween.tween_property(_current_page, ^"modulate:a", 0.0, page_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_page_tween.tween_property(_next_page, ^"modulate:a", 1.0, page_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_page_tween.tween_callback(_complete_page_change.bind(next_index))


func _complete_page_change(next_index: int) -> void:
	_page_index = next_index
	_current_page.texture = _next_page.texture
	_current_page.modulate.a = 1.0
	_next_page.texture = null
	_next_page.modulate.a = 0.0
	_transitioning = false


func _set_hold_prompt(progress: float) -> void:
	_hold_ring.show()
	_hold_ring.progress = progress
	_prompt_label.text = "Hold to skip"


func _set_continue_prompt() -> void:
	# This shares one slot with hold-to-skip instead of stacking another hint.
	_hold_ring.hide()
	_prompt_label.text = "Click to continue"


func _finish_intro() -> void:
	if _finishing:
		return
	_finishing = true
	_transitioning = true
	_holding = false
	_hold_ring.hide()
	_prompt_label.hide()
	if is_instance_valid(_page_tween):
		_page_tween.kill()
	var closing := create_tween().set_parallel(true)
	closing.tween_property(_current_page, ^"modulate:a", 0.0, closing_fade_duration * 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	closing.tween_property(_fade_cover, ^"modulate:a", 1.0, closing_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await closing.finished
	_open_game_scene()


func _open_game_scene() -> void:
	if not is_instance_valid(_loading_screen):
		push_error("IntroCutscene/LoadingScreenUI scene instance is missing.")
		_finishing = false
		return
	# A new run always continues into the interactive tutorial. Continue from
	# the main menu bypasses this scene and therefore remains normal gameplay.
	var run_context := get_node_or_null("/root/RunContext")
	if run_context != null and run_context.has_method(&"request_tutorial"):
		run_context.call(&"request_tutorial")
	_loading_screen.begin_loading(GAME_SCENE_PATH)
