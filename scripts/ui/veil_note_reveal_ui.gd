class_name VeilNoteRevealUI
extends Control
## Scene-authored reveal used when the player opens a Veil Note at night.

signal reveal_finished

@export_category("Reveal Timing")
@export_range(0.1, 1.5, 0.05) var rise_seconds: float = 0.45
@export_range(1, 12, 1) var shake_steps: int = 7
@export_range(0.02, 0.15, 0.01) var shake_step_seconds: float = 0.045
@export_range(0.1, 0.8, 0.05) var flash_seconds: float = 0.24
@export_range(10.0, 100.0, 1.0) var typewriter_characters_per_second: float = 42.0
@export_range(0.0, 4.0, 0.05) var statement_hold_seconds: float = 2.0
@export_range(0.1, 1.5, 0.05) var particle_flight_seconds: float = 0.62
@export_category("Motion")
@export_range(1.0, 30.0, 1.0) var shake_distance: float = 11.0
@export_range(0.0, 12.0, 0.5) var shake_degrees: float = 4.5
@export_range(20.0, 180.0, 5.0) var particle_burst_radius: float = 88.0

@onready var _veil: ColorRect = %Veil
@onready var _white_flash: ColorRect = %WhiteFlash
@onready var _item_anchor: Control = %ItemAnchor
@onready var _statement_group: Control = %StatementGroup
@onready var _statement_label: Label = %StatementLabel
@onready var _particles: Array[Polygon2D] = [
	%Particle1,
	%Particle2,
	%Particle3,
	%Particle4,
	%Particle5,
	%Particle6,
	%Particle7,
	%Particle8,
	%Particle9,
	%Particle10,
	%Particle11,
	%Particle12,
]

var _item_rest_position: Vector2
var _statement_rest_position: Vector2
var _active: bool = false


func _ready() -> void:
	_item_rest_position = _item_anchor.position
	_statement_rest_position = _statement_group.position
	hide()
	_reset_presentation()


func play_reveal(statement: String, target_global_position: Vector2) -> bool:
	if _active or statement.strip_edges().is_empty():
		return false
	_active = true
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_reset_presentation()
	_statement_label.text = statement.strip_edges()
	_statement_label.visible_characters = 0
	_run_reveal(target_global_position)
	return true


func _run_reveal(target_global_position: Vector2) -> void:

	var rise_tween: Tween = create_tween().set_parallel(true)
	rise_tween.tween_property(
		_item_anchor,
		^"position",
		_item_rest_position,
		rise_seconds
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise_tween.tween_property(_item_anchor, ^"modulate:a", 1.0, rise_seconds * 0.55)
	rise_tween.tween_property(
		_item_anchor,
		^"scale",
		Vector2.ONE,
		rise_seconds
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await rise_tween.finished
	if not is_inside_tree():
		return

	await _shake_note()
	await _play_white_burst()
	if not is_inside_tree():
		return
	_statement_group.show()
	var typewriter_seconds: float = maxf(
		0.2,
		float(_statement_label.text.length()) / typewriter_characters_per_second
	)
	var statement_tween: Tween = create_tween().set_parallel(true)
	statement_tween.tween_property(
		_statement_label,
		^"visible_characters",
		_statement_label.text.length(),
		typewriter_seconds
	)
	statement_tween.tween_property(
		_statement_group,
		^"modulate:a",
		1.0,
		minf(0.22, typewriter_seconds)
	)
	await statement_tween.finished
	if statement_hold_seconds > 0.0:
		await get_tree().create_timer(statement_hold_seconds).timeout
	if not is_inside_tree():
		return

	await _fly_into_ledger(target_global_position)
	_finish_reveal()


func is_revealing() -> bool:
	return _active


func _reset_presentation() -> void:
	_item_anchor.position = _item_rest_position + Vector2(0.0, 420.0)
	_item_anchor.rotation = 0.0
	_item_anchor.scale = Vector2(0.72, 0.72)
	_item_anchor.modulate.a = 0.0
	_statement_group.hide()
	_statement_group.position = _statement_rest_position
	_statement_group.scale = Vector2.ONE
	_statement_group.rotation = 0.0
	_statement_group.pivot_offset = _statement_group.size * 0.5
	_statement_group.modulate.a = 0.0
	_white_flash.modulate.a = 0.0
	_veil.modulate.a = 0.0
	for particle: Polygon2D in _particles:
		particle.hide()
		particle.scale = Vector2.ONE
		particle.modulate.a = 0.0


func _shake_note() -> void:
	var shake_tween: Tween = create_tween()
	for step: int in range(shake_steps):
		var direction: float = -1.0 if step % 2 == 0 else 1.0
		var strength: float = 1.0 - float(step) / float(maxi(1, shake_steps)) * 0.45
		shake_tween.tween_property(
			_item_anchor,
			^"position:x",
			_item_rest_position.x + direction * shake_distance * strength,
			shake_step_seconds
		).set_trans(Tween.TRANS_SINE)
		shake_tween.parallel().tween_property(
			_item_anchor,
			^"rotation",
			deg_to_rad(-direction * shake_degrees * strength),
			shake_step_seconds
		)
	shake_tween.tween_property(
		_item_anchor, ^"position", _item_rest_position, shake_step_seconds
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	shake_tween.parallel().tween_property(
		_item_anchor, ^"rotation", 0.0, shake_step_seconds
	)
	await shake_tween.finished


func _play_white_burst() -> void:
	var inverse_transform: Transform2D = get_global_transform().affine_inverse()
	var burst_center: Vector2 = inverse_transform * _item_anchor.get_global_rect().get_center()
	for index: int in range(_particles.size()):
		var particle: Polygon2D = _particles[index]
		var angle: float = TAU * float(index) / float(_particles.size()) + 0.18
		var radius: float = particle_burst_radius * (0.72 + float(index % 3) * 0.16)
		particle.position = burst_center
		particle.rotation = angle
		particle.scale = Vector2(0.22, 0.22)
		particle.modulate.a = 1.0
		particle.show()
		var particle_tween: Tween = create_tween().set_parallel(true)
		particle_tween.tween_property(
			particle,
			^"position",
			burst_center + Vector2.from_angle(angle) * radius,
			flash_seconds
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		particle_tween.tween_property(
			particle, ^"scale", Vector2(1.15, 1.15), flash_seconds * 0.72
		)
		particle_tween.tween_property(
			particle, ^"modulate:a", 0.0, flash_seconds * 0.55
		).set_delay(flash_seconds * 0.45)

	var impact_tween: Tween = create_tween().set_parallel(true)
	impact_tween.tween_property(
		_white_flash, ^"modulate:a", 0.84, flash_seconds * 0.32
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	impact_tween.tween_property(
		_veil, ^"modulate:a", 1.0, flash_seconds * 0.5
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	impact_tween.tween_property(
		_item_anchor, ^"scale", Vector2(1.18, 1.18), flash_seconds * 0.32
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await impact_tween.finished

	var release_tween: Tween = create_tween().set_parallel(true)
	release_tween.tween_property(
		_white_flash, ^"modulate:a", 0.0, flash_seconds * 0.68
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	release_tween.tween_property(
		_item_anchor, ^"scale", Vector2(0.42, 0.42), flash_seconds * 0.68
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	release_tween.tween_property(
		_item_anchor, ^"modulate:a", 0.0, flash_seconds * 0.54
	).set_delay(flash_seconds * 0.14)
	await release_tween.finished
	for particle: Polygon2D in _particles:
		particle.hide()


func _fly_into_ledger(target_global_position: Vector2) -> void:
	var inverse_transform: Transform2D = get_global_transform().affine_inverse()
	var start: Vector2 = inverse_transform * _statement_group.get_global_rect().get_center()
	var target: Vector2 = inverse_transform * target_global_position
	_statement_group.pivot_offset = _statement_group.size * 0.5
	var statement_target_position: Vector2 = target - _statement_group.size * 0.5
	var statement_tween: Tween = create_tween().set_parallel(true)
	statement_tween.tween_property(
		_statement_group,
		^"position",
		statement_target_position,
		particle_flight_seconds
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	statement_tween.tween_property(
		_statement_group,
		^"scale",
		Vector2(0.06, 0.06),
		particle_flight_seconds
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	statement_tween.tween_property(
		_statement_group, ^"modulate:a", 0.0, particle_flight_seconds * 0.36
	).set_delay(particle_flight_seconds * 0.64)

	var burst_seconds: float = 0.18
	for index: int in range(_particles.size()):
		var particle: Polygon2D = _particles[index]
		var angle: float = TAU * float(index) / float(_particles.size()) + 0.22
		var radius: float = particle_burst_radius * (0.72 + float(index % 3) * 0.14)
		var burst_position: Vector2 = start + Vector2.from_angle(angle) * radius
		var target_jitter := Vector2(float((index % 3) - 1) * 7.0, float((index % 4) - 2) * 5.0)
		particle.position = start
		particle.rotation = angle
		particle.scale = Vector2(0.35, 0.35)
		particle.modulate.a = 1.0
		particle.show()
		var particle_tween: Tween = create_tween()
		particle_tween.tween_property(
			particle, ^"position", burst_position, burst_seconds
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		particle_tween.parallel().tween_property(
			particle, ^"scale", Vector2(1.0, 1.0), burst_seconds
		)
		particle_tween.tween_property(
			particle,
			^"position",
			target + target_jitter,
			particle_flight_seconds + float(index) * 0.012
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		particle_tween.parallel().tween_property(
			particle, ^"scale", Vector2(0.18, 0.18), particle_flight_seconds
		)
		particle_tween.parallel().tween_property(
			particle, ^"modulate:a", 0.0, particle_flight_seconds
		).set_delay(particle_flight_seconds * 0.58)
	await get_tree().create_timer(
		burst_seconds + particle_flight_seconds + float(_particles.size()) * 0.012
	).timeout


func _finish_reveal() -> void:
	_active = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	reveal_finished.emit()
