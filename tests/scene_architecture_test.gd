extends SceneTree
## Guards the scene-first UI contract: scripts bind behavior, scenes own static nodes.

const FORBIDDEN_STATIC_NODE_PATTERNS: PackedStringArray = [
	"Control.new(",
	"ColorRect.new(",
	"CenterContainer.new(",
	"MarginContainer.new(",
	"HBoxContainer.new(",
	"VBoxContainer.new(",
	"GridContainer.new(",
	"PanelContainer.new(",
	"Button.new(",
	"CheckButton.new(",
	"OptionButton.new(",
	"HSlider.new(",
	"ProgressBar.new(",
	"Label.new(",
	"RichTextLabel.new(",
	"LineEdit.new(",
	"HSeparator.new(",
	"Node2D.new(",
	"Area2D.new(",
	"CharacterBody2D.new(",
	"Sprite2D.new(",
	"AnimatedSprite2D.new(",
	"Polygon2D.new(",
	"Line2D.new(",
	"AudioStreamPlayer.new(",
	"AnimationPlayer.new(",
	"Camera2D.new(",
	"CollisionShape2D.new(",
	"func _draw()",
	"preload(\"res://scenes/",
	"set_anchors_and_offsets_preset(",
	"add_theme_",
	"custom_minimum_size =",
	"mouse_filter =",
	"focus_neighbor_",
	"z_index =",
	"z_as_relative =",
	"volume_db =",
	"autoplay =",
]
const PRESENTATION_ONLY_PATTERNS: PackedStringArray = [
	"add_child(",
	"_build_ui",
	"_build_hud",
]
const ALLOWED_RUNTIME_ADD_CHILD: String = "_passenger_container.add_child(passenger)"
const ALLOWED_RUNTIME_CONNECT: String = "passenger.inspection_requested.connect(_on_passenger_inspection)"
var _scene_sources: String = ""

func _init() -> void:
	_collect_scene_sources("res://scenes")
	_check_directory("res://scripts")
	print("SCENE_ARCHITECTURE_TEST: PASS")
	quit()

func _check_directory(path: String) -> void:
	var directory := DirAccess.open(path)
	assert(directory != null, "Could not inspect presentation directory: %s" % path)
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if directory.current_is_dir():
			_check_directory(path.path_join(entry))
		elif entry.ends_with(".gd"):
			_check_script(path.path_join(entry))
		entry = directory.get_next()
	directory.list_dir_end()

func _collect_scene_sources(path: String) -> void:
	var directory := DirAccess.open(path)
	assert(directory != null, "Could not inspect scene directory: %s" % path)
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var entry_path: String = path.path_join(entry)
		if directory.current_is_dir():
			_collect_scene_sources(entry_path)
		elif entry.ends_with(".tscn"):
			_scene_sources += FileAccess.get_file_as_string(entry_path)
		entry = directory.get_next()
	directory.list_dir_end()

func _check_script(path: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	assert(not source.is_empty(), "Could not read presentation script: %s" % path)
	var is_data_script: bool = "extends Resource" in source or "extends RefCounted" in source
	var is_abstract_base: bool = path == "res://scripts/interactables/interactable.gd"
	if not is_data_script and not is_abstract_base:
		assert('path="%s"' % path in _scene_sources, "%s is a Node script without a scene attachment" % path)
	for pattern: String in FORBIDDEN_STATIC_NODE_PATTERNS:
		assert(not pattern in source, "%s contains script-built UI pattern: %s" % [path, pattern])
	if path.begins_with("res://scripts/menu/") or path.begins_with("res://scripts/ui/"):
		for pattern: String in PRESENTATION_ONLY_PATTERNS:
			assert(not pattern in source, "%s contains script-built presentation pattern: %s" % [path, pattern])
	for line: String in source.split("\n"):
		if "add_child(" in line:
			assert(line.strip_edges() == ALLOWED_RUNTIME_ADD_CHILD, "%s adds a runtime node without the approved passenger-scene path: %s" % [path, line.strip_edges()])
		if ".connect(" in line:
			assert(line.strip_edges() == ALLOWED_RUNTIME_CONNECT, "%s connects a static scene signal in code instead of the Inspector: %s" % [path, line.strip_edges()])
