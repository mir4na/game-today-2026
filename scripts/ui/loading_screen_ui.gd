class_name LoadingScreenUI
extends Control
## Transparent loading presenter that keeps the current menu frame on screen.

@export_category("Loading Target")
@export_file("*.tscn") var target_scene_path: String
@export_range(0.0, 5.0, 0.05) var minimum_display_seconds: float = 1.15
@export_category("Typewriter")
@export_range(0.01, 0.3, 0.005) var typewriter_seconds_per_character: float = 0.075
@export var loading_text: String = "Loading..."
@export var failed_text: String = "Loading failed"
@export_category("Scene Animation")
@export var fade_to_black_animation: StringName = &"fade_to_black"
@export var fade_from_black_animation: StringName = &"fade_from_black"

var _started: bool = false
var _elapsed: float = 0.0
var _load_complete: bool = false
var _changing_scene: bool = false
var _transition_duration_scale: float = 1.0
var _fade_to_black_before_loading: bool = false

@onready var _loading_label: Label = %LoadingLabel
@onready var _mc_walk: AnimatedSprite2D = %MCWalk
@onready var _transition_animation: AnimationPlayer = %TransitionAnimation
@onready var _loading_content: Control = $BottomLeft


func _ready() -> void:
	hide()
	set_process(false)
	_reset_presentation()


func begin_loading(
	override_target_scene_path: String = "",
	transition_duration_scale: float = 1.0,
	fade_to_black_before_loading: bool = false
) -> void:
	if _started:
		return
	if not override_target_scene_path.is_empty():
		target_scene_path = override_target_scene_path
	_transition_duration_scale = maxf(transition_duration_scale, 0.01)
	_fade_to_black_before_loading = fade_to_black_before_loading
	_started = true
	_elapsed = 0.0
	_load_complete = false
	_changing_scene = false
	_reset_presentation()
	if _fade_to_black_before_loading:
		_loading_content.hide()
	show()
	_mc_walk.play(&"walk")
	if target_scene_path.is_empty():
		_loading_content.show()
		_fail_loading("LoadingScreenUI/Target Scene Path is empty in the Inspector.")
		return
	if _fade_to_black_before_loading:
		_reveal_loading_after_black_cover()
		return
	_request_threaded_load()


func _reveal_loading_after_black_cover() -> void:
	await _play_transition(fade_to_black_animation)
	if not is_inside_tree() or not _started:
		return
	_loading_content.show()
	_request_threaded_load()


func _request_threaded_load() -> void:
	var existing_status := ResourceLoader.load_threaded_get_status(target_scene_path)
	if existing_status == ResourceLoader.THREAD_LOAD_LOADED:
		_load_complete = true
		set_process(true)
		return
	if existing_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		set_process(true)
		return
	var request_error: Error = ResourceLoader.load_threaded_request(
		target_scene_path,
		"PackedScene",
		true
	)
	if request_error != OK:
		_fail_loading(
			"Could not begin threaded loading for %s: %s"
			% [target_scene_path, error_string(request_error)]
		)
		return
	set_process(true)


func _process(delta: float) -> void:
	if not _started or _changing_scene:
		return
	_elapsed += delta
	_update_typewriter()
	var load_progress: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(
		target_scene_path,
		load_progress
	)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			pass
		ResourceLoader.THREAD_LOAD_LOADED:
			_load_complete = true
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_fail_loading("Threaded loading failed for %s." % target_scene_path)
			return
	if (
		_load_complete
		and _elapsed >= minimum_display_seconds
		and _loading_label.visible_characters >= loading_text.length()
	):
		_open_loaded_scene()


func _reset_presentation() -> void:
	_loading_label.text = loading_text
	_loading_label.visible_characters = 0
	_loading_content.show()
	if _transition_animation.has_animation(&"RESET"):
		_transition_animation.play(&"RESET")
		_transition_animation.advance(0.0)


func _update_typewriter() -> void:
	var character_count: int = mini(
		int(floor(_elapsed / maxf(typewriter_seconds_per_character, 0.001))) + 1,
		loading_text.length()
	)
	_loading_label.visible_characters = character_count


func _open_loaded_scene() -> void:
	_changing_scene = true
	set_process(false)
	var loaded_scene := ResourceLoader.load_threaded_get(target_scene_path) as PackedScene
	if loaded_scene == null:
		_changing_scene = false
		_fail_loading("The loaded resource is not a PackedScene: %s" % target_scene_path)
		return
	var next_scene: Node = loaded_scene.instantiate()
	if next_scene == null:
		_changing_scene = false
		_fail_loading("The loaded scene could not be instantiated: %s" % target_scene_path)
		return
	if not _fade_to_black_before_loading:
		await _play_transition(fade_to_black_animation)
	var tree := get_tree()
	var previous_scene: Node = tree.current_scene
	if previous_scene == null:
		previous_scene = get_parent()
	var transition_host: Node = self
	if get_parent() is CanvasLayer and get_parent().get_parent() == previous_scene:
		transition_host = get_parent()
	# Keep the loaded gameplay still while the scene-authored black cover moves
	# above it. This also prevents its timers from advancing during the reveal.
	next_scene.process_mode = Node.PROCESS_MODE_DISABLED
	tree.root.add_child(next_scene)
	transition_host.reparent(tree.root)
	tree.current_scene = next_scene
	if is_instance_valid(previous_scene):
		previous_scene.queue_free()
	await tree.process_frame
	await _play_transition(fade_from_black_animation)
	tree.paused = false
	if is_instance_valid(next_scene):
		next_scene.process_mode = Node.PROCESS_MODE_INHERIT
	transition_host.queue_free()


func _play_transition(animation_name: StringName) -> void:
	if not _transition_animation.has_animation(animation_name):
		return
	_transition_animation.speed_scale = 1.0 / _transition_duration_scale
	_transition_animation.play(animation_name)
	await _transition_animation.animation_finished
	_transition_animation.speed_scale = 1.0


func _fail_loading(message: String) -> void:
	set_process(false)
	_loading_label.text = failed_text
	_loading_label.visible_characters = -1
	push_error(message)
