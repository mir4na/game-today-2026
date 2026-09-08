class_name PauseOptionSelector
extends PanelContainer

signal step_requested(direction: int)
signal slider_value_changed(value: int)

@export var option_label: String = "Option"
@export var uses_slider: bool = false

var _pulse_tween: Tween

@onready var _label: Label = %OptionLabel
@onready var _value: Label = %ValueLabel
@onready var _left_button: TextureButton = %LeftButton
@onready var _right_button: TextureButton = %RightButton
@onready var _discrete_selector: HBoxContainer = %DiscreteSelector
@onready var _slider: Control = %VolumeSlider


func _ready() -> void:
	_label.text = option_label
	_left_button.pressed.connect(_request_step.bind(-1))
	_right_button.pressed.connect(_request_step.bind(1))
	_slider.connect(&"value_changed", _on_slider_value_changed)
	_slider.mouse_entered.connect(_preview_slider_focus)
	_slider.focus_entered.connect(_preview_slider_focus)
	_discrete_selector.visible = not uses_slider
	_slider.visible = uses_slider
	pivot_offset = size * 0.5


func set_value_text(value: String) -> void:
	_value.text = value


func set_slider_value(value: int) -> void:
	_slider.call(&"set_value_no_signal", value)


func focus_first() -> void:
	if uses_slider:
		_slider.grab_focus()
	else:
		_left_button.grab_focus()


func pulse(direction: int) -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	pivot_offset = size * 0.5
	scale = Vector2.ONE
	rotation = 0.0
	_value.modulate.a = 0.55
	_value.position.x = float(direction) * 5.0
	_pulse_tween = create_tween().set_parallel(true)
	_pulse_tween.tween_property(self, ^"scale", Vector2.ONE * 1.045, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, ^"rotation", float(direction) * 0.012, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(_value, ^"modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(_value, ^"position:x", 0.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse_tween.chain().tween_property(self, ^"scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse_tween.parallel().tween_property(self, ^"rotation", 0.0, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _request_step(direction: int) -> void:
	pulse(direction)
	step_requested.emit(direction)


func _on_slider_value_changed(value: int) -> void:
	pulse(1)
	slider_value_changed.emit(value)


func _preview_slider_focus() -> void:
	_preview_control(_slider, 1.035)


func _preview_control(control: Control, target_scale: float) -> void:
	var tween := create_tween()
	control.pivot_offset = control.size * 0.5
	tween.tween_property(control, ^"scale", Vector2.ONE * target_scale, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, ^"scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
