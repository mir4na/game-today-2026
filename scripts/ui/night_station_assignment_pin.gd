class_name NightStationAssignmentPin
extends Control
## One assigned soul on a station path. The portrait placeholder stays in this
## scene so its framing can be adjusted independently from the map layout.

@export_category("Toony Motion")
@export_range(0.05, 1.0, 0.01) var appear_seconds: float = 0.24
@export_range(0.0, 12.0, 0.5) var idle_bob_distance: float = 3.0
@export_range(0.5, 4.0, 0.05) var idle_cycle_seconds: float = 1.7
@export_range(0.0, 8.0, 0.25) var idle_tilt_degrees: float = 2.0

@onready var _character_placeholder: NightCharacterPortrait = %CharacterPlaceholder
@onready var _visual_root: Control = %VisualRoot

var _appear_tween: Tween
var _idle_tween: Tween


func configure(passenger_name: String, portrait: Texture2D) -> void:
	_character_placeholder.set_character_artwork(portrait)
	tooltip_text = passenger_name
	_play_appear_animation()


func _play_appear_animation() -> void:
	if is_instance_valid(_appear_tween) and _appear_tween.is_valid():
		_appear_tween.kill()
	if is_instance_valid(_idle_tween) and _idle_tween.is_valid():
		_idle_tween.kill()
	_visual_root.pivot_offset = size * 0.5
	_visual_root.position = Vector2.ZERO
	_visual_root.scale = Vector2(0.28, 0.28)
	_visual_root.rotation = deg_to_rad(-12.0)
	_visual_root.modulate.a = 0.0
	_appear_tween = create_tween().set_parallel(true)
	_appear_tween.tween_property(
		_visual_root, ^"scale", Vector2(1.14, 1.14), appear_seconds * 0.72
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_appear_tween.tween_property(
		_visual_root, ^"rotation", deg_to_rad(3.0), appear_seconds * 0.72
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_appear_tween.tween_property(
		_visual_root, ^"modulate:a", 1.0, appear_seconds * 0.42
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_appear_tween.chain().tween_property(
		_visual_root, ^"scale", Vector2.ONE, appear_seconds * 0.28
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_appear_tween.parallel().tween_property(
		_visual_root, ^"rotation", 0.0, appear_seconds * 0.28
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_appear_tween.finished.connect(_start_idle_animation)


func _start_idle_animation() -> void:
	if not is_instance_valid(_visual_root):
		return
	_visual_root.position = Vector2.ZERO
	_visual_root.rotation = 0.0
	var half_cycle: float = maxf(idle_cycle_seconds * 0.5, 0.05)
	var tilt: float = deg_to_rad(idle_tilt_degrees)
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(
		_visual_root, ^"position:y", -idle_bob_distance, half_cycle
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.parallel().tween_property(
		_visual_root, ^"rotation", tilt, half_cycle
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(
		_visual_root, ^"position:y", 0.0, half_cycle
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.parallel().tween_property(
		_visual_root, ^"rotation", -tilt, half_cycle
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
