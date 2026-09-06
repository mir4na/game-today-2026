class_name StationCinematicView
extends Node2D
## Owns the temporary wide station framing without changing the gameplay camera setup.

@export_category("Arrival Framing")
@export_range(0.1, 4.0, 0.05) var zoom_out_start_seconds: float = 0.65
@export_range(0.0, 2.0, 0.05) var full_frame_lead_seconds: float = 0.35
@export var target_zoom: Vector2 = Vector2(0.428571, 0.428571)
@export_range(0.1, 2.0, 0.05) var return_duration: float = 0.75
@export_category("Time Of Day Tint")
@export_range(0.0, 1.0, 0.01) var afternoon_start: float = 0.25
@export_range(0.0, 1.0, 0.01) var sunset_start: float = 0.56
@export_range(0.0, 1.0, 0.01) var night_start: float = 0.82
@export var sunrise_tint: Color = Color(1.0, 0.96, 0.88, 1.0)
@export var afternoon_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var sunset_tint: Color = Color(1.0, 0.78, 0.62, 1.0)
@export var night_tint: Color = Color(0.46, 0.58, 0.78, 1.0)

var _source_camera: Camera2D
var _gameplay_center: Vector2
var _gameplay_zoom: Vector2
var _arrival_start_center: Vector2
var _arrival_start_zoom: Vector2
var _active: bool = false
var _returning: bool = false
var _return_tween: Tween

@onready var _station_backdrop: Node2D = %StationBackdrop
@onready var _station_sign_layer: CanvasLayer = %StationSignLayer
@onready var _station_sign: Node2D = %StationSign
@onready var _station_name_label: Label = %StationName
@onready var _frame_target: Marker2D = %FrameTarget
@onready var _station_camera: Camera2D = %StationCamera


func set_cycle_progress(value: float) -> void:
	var progress: float = clampf(value, 0.0, 1.0)
	var tint: Color = sunrise_tint
	if progress >= night_start:
		tint = night_tint
	elif progress >= sunset_start:
		tint = sunset_tint
	elif progress >= afternoon_start:
		tint = afternoon_tint
	tint.a = 1.0
	_station_backdrop.modulate = tint
	_station_sign.modulate = tint


func begin(source_camera: Camera2D, station_name: String) -> void:
	if not is_instance_valid(source_camera):
		push_error("StationCinematicView requires a valid gameplay Camera2D.")
		return
	if _return_tween and _return_tween.is_valid():
		_return_tween.kill()
	_source_camera = source_camera
	_gameplay_center = _source_camera.get_screen_center_position()
	_gameplay_zoom = _source_camera.zoom
	# Open directly on the foreground station sign, then reveal the complete
	# station through the authored arrival zoom-out.
	_arrival_start_center = _station_sign.global_position
	_arrival_start_zoom = _gameplay_zoom
	_station_camera.global_position = _arrival_start_center
	_station_camera.zoom = _arrival_start_zoom
	var display_name: String = station_name.strip_edges().to_upper()
	_station_name_label.text = display_name if not display_name.is_empty() else "STATION"
	# Keep the station fully opaque before switching cameras so it appears instantly.
	_station_backdrop.modulate.a = 1.0
	_station_backdrop.show()
	_station_sign.modulate.a = 1.0
	_station_sign_layer.show()
	_returning = false
	_active = true
	_station_camera.enabled = true
	_source_camera.enabled = false


func update_arrival(elapsed: float, arrival_end: float) -> void:
	if not _active or _returning:
		return
	var frame_end: float = maxf(arrival_end - full_frame_lead_seconds, zoom_out_start_seconds + 0.01)
	var progress: float = clampf(inverse_lerp(zoom_out_start_seconds, frame_end, elapsed), 0.0, 1.0)
	var eased_progress: float = _smoothstep(progress)
	_station_camera.global_position = _arrival_start_center.lerp(_frame_target.global_position, eased_progress)
	_station_camera.zoom = _arrival_start_zoom.lerp(target_zoom, eased_progress)


func return_to_gameplay() -> void:
	if not _active or _returning:
		return
	_returning = true
	if _return_tween and _return_tween.is_valid():
		_return_tween.kill()
	_return_tween = create_tween().set_parallel(true)
	_return_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_return_tween.tween_property(_station_camera, "global_position", _gameplay_center, return_duration)
	_return_tween.tween_property(_station_camera, "zoom", _gameplay_zoom, return_duration)
	_return_tween.chain().tween_callback(_restore_gameplay_camera)


func finish() -> void:
	if _return_tween and _return_tween.is_valid():
		_return_tween.kill()
	_restore_gameplay_camera()


func _restore_gameplay_camera() -> void:
	if is_instance_valid(_source_camera):
		_source_camera.enabled = true
		_source_camera.reset_smoothing()
	_station_camera.enabled = false
	_station_backdrop.hide()
	_station_sign_layer.hide()
	_station_backdrop.modulate.a = 1.0
	_active = false
	_returning = false


func _smoothstep(value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)
