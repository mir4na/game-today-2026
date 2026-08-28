class_name LoadingScreenUI
extends Control
## Threaded scene loader presented between the main menu and the day intro.

@export_category("Loading Target")
@export_file("*.tscn") var target_scene_path: String
@export_range(0.0, 5.0, 0.05) var minimum_display_seconds: float = 0.9
@export_range(10.0, 300.0, 1.0) var bar_fill_speed: float = 135.0
@export_category("Scene Copy")
@export var loading_status_text: String = "PREPARING THE DAY SERVICE"
@export var ready_status_text: String = "SHIFT READY"
@export var failed_status_text: String = "THE SHIFT COULD NOT BE LOADED"
@export var progress_text_template: String = "%d%%"

var _elapsed: float = 0.0
var _displayed_progress: float = 0.0
var _target_progress: float = 0.0
var _load_complete: bool = false
var _changing_scene: bool = false

@onready var _status_label: Label = %StatusLabel
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _progress_label: Label = %ProgressLabel


func _ready() -> void:
	_progress_bar.value = 0.0
	_progress_label.text = progress_text_template % 0
	_status_label.text = loading_status_text
	if target_scene_path.is_empty():
		_fail_loading("LoadingScreenUI/Target Scene Path is empty in the Inspector.")
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


func _process(delta: float) -> void:
	if _changing_scene:
		return
	_elapsed += delta
	var load_progress: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(
		target_scene_path,
		load_progress
	)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not load_progress.is_empty():
				_target_progress = maxf(
					_target_progress,
					clampf(float(load_progress[0]) * 100.0, 0.0, 99.0)
				)
		ResourceLoader.THREAD_LOAD_LOADED:
			_load_complete = true
			_target_progress = 100.0
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_fail_loading("Threaded loading failed for %s." % target_scene_path)
			return

	_displayed_progress = move_toward(
		_displayed_progress,
		_target_progress,
		bar_fill_speed * delta
	)
	_progress_bar.value = _displayed_progress
	_progress_label.text = progress_text_template % int(round(_displayed_progress))
	if _load_complete and _displayed_progress >= 99.9:
		_status_label.text = ready_status_text
		if _elapsed >= minimum_display_seconds:
			_open_loaded_scene()


func _open_loaded_scene() -> void:
	_changing_scene = true
	var loaded_scene := ResourceLoader.load_threaded_get(target_scene_path) as PackedScene
	if loaded_scene == null:
		_changing_scene = false
		_fail_loading("The loaded resource is not a PackedScene: %s" % target_scene_path)
		return
	var change_error: Error = get_tree().change_scene_to_packed(loaded_scene)
	if change_error != OK:
		_changing_scene = false
		_fail_loading(
			"Could not open loaded scene %s: %s"
			% [target_scene_path, error_string(change_error)]
		)


func _fail_loading(message: String) -> void:
	set_process(false)
	_status_label.text = failed_status_text
	_progress_label.text = "--"
	push_error(message)
