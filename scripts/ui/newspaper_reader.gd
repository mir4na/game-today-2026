class_name NewspaperReader
extends Control
## Scene-authored newspaper reader with multiple visual editions.

signal close_requested

@export_category("Scene Variants")
@export var variant_paths: Array[NodePath] = []
@export var headline_paths: Array[NodePath] = []
@export var primary_body_paths: Array[NodePath] = []
@export var secondary_headline_paths: Array[NodePath] = []
@export var secondary_body_paths: Array[NodePath] = []
@export var portrait_paths: Array[NodePath] = []

var _variants: Array[Control] = []
var _portraits: Array[Sprite2D] = []
var _selected_variant: int = 0
var _portrait_texture: Texture2D


func _ready() -> void:
	_resolve_scene_variants()
	set_variant(_selected_variant)


func get_variant_count() -> int:
	return _variants.size()


func choose_random_variant(rng: RandomNumberGenerator) -> void:
	var count: int = get_variant_count()
	if count <= 0:
		push_warning("Newspaper Reader has no Inspector-configured visual variants.")
		return
	set_variant(rng.randi_range(0, count - 1))


func set_variant(index: int) -> void:
	var count: int = get_variant_count()
	if count <= 0:
		return
	_selected_variant = clampi(index, 0, count - 1)
	for variant_index: int in range(_variants.size()):
		_variants[variant_index].visible = variant_index == _selected_variant


func set_content(headline: String, primary_body: String, secondary_headline: String, secondary_body: String) -> void:
	_set_plain_text(headline_paths, headline)
	_set_rich_text(primary_body_paths, primary_body)
	_set_plain_text(secondary_headline_paths, secondary_headline)
	_set_rich_text(secondary_body_paths, secondary_body)


func set_portrait(texture: Texture2D) -> void:
	_portrait_texture = texture
	for portrait: Sprite2D in _portraits:
		portrait.texture = _portrait_texture
		portrait.visible = _portrait_texture != null


func _resolve_scene_variants() -> void:
	_variants.clear()
	_portraits.clear()
	for path: NodePath in variant_paths:
		var variant := get_node_or_null(path) as Control
		if is_instance_valid(variant):
			_variants.append(variant)
	for path: NodePath in portrait_paths:
		var portrait := get_node_or_null(path) as Sprite2D
		if is_instance_valid(portrait):
			_portraits.append(portrait)
	if _portrait_texture != null:
		set_portrait(_portrait_texture)
	else:
		for portrait: Sprite2D in _portraits:
			portrait.visible = portrait.texture != null


func _set_plain_text(paths: Array[NodePath], value: String) -> void:
	for path: NodePath in paths:
		if path.is_empty():
			continue
		var label := get_node_or_null(path) as Label
		if is_instance_valid(label):
			label.text = value


func _set_rich_text(paths: Array[NodePath], value: String) -> void:
	for path: NodePath in paths:
		if path.is_empty():
			continue
		var label := get_node_or_null(path) as RichTextLabel
		if is_instance_valid(label):
			label.text = value


func _on_close_button_pressed() -> void:
	close_requested.emit()
