extends Interactable
## A quiet night-only watcher that provides an in-world entrance to the ledger.

signal consulted

@export_category("Watcher Motion")
@export_range(0.0, 12.0, 0.5) var hover_height: float = 4.0
@export_range(0.1, 4.0, 0.05) var hover_speed: float = 1.15
@export_range(0.0, 0.5, 0.01) var aura_pulse_amount: float = 0.12

var _hover_phase: float = 0.0
var _visual_rest_position: Vector2
var _aura_rest_scale: Vector2
var _night_mode: bool = false

@onready var _visual: CanvasGroup = %WatcherVisual
@onready var _aura: Sprite2D = %Aura
@onready var _shadow: Polygon2D = %Shadow


func _ready() -> void:
	super._ready()
	_visual_rest_position = _visual.position
	_aura_rest_scale = _aura.scale
	set_shift_active(false)


func _process(delta: float) -> void:
	if not visible:
		return
	_hover_phase = fmod(_hover_phase + delta * hover_speed, TAU)
	var lift: float = sin(_hover_phase) * hover_height
	_visual.position = _visual_rest_position + Vector2(0.0, lift)
	var pulse: float = 1.0 + sin(_hover_phase * 0.85) * aura_pulse_amount
	_aura.scale = _aura_rest_scale * pulse
	_shadow.modulate.a = 0.22 - lift * 0.008


func set_shift_active(value: bool, night_mode: bool = false) -> void:
	_night_mode = night_mode
	visible = value
	enabled = value
	if is_node_ready():
		prompt_text = "Consult the watcher" if _night_mode else "Report completed service"
		_visual.modulate = Color(0.76, 0.88, 1.0, 0.9) if _night_mode else Color(1.0, 0.9, 0.58, 0.72)
		_aura.modulate = Color(0.34, 0.66, 1.0, 0.9) if _night_mode else Color(1.0, 0.68, 0.12, 0.92)
		passive_outline_color = Color(0.38, 0.72, 1.0, 0.82) if _night_mode else Color(1.0, 0.77, 0.24, 0.86)
		if not value:
			_visual.position = _visual_rest_position
			_aura.scale = _aura_rest_scale
		refresh_interaction_outline()


func set_night_active(value: bool) -> void:
	set_shift_active(value, true)


func interact() -> void:
	if not can_interact():
		return
	consulted.emit()
