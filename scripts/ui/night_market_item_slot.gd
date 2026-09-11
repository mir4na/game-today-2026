class_name NightMarketItemSlot
extends Control
## Scene-authored HUD slot for one tool purchased from the Night Market.

signal tool_requested(tool_id: StringName)

@export var tool_id: StringName
@export var item_name: String = "Night Market item"
@export var short_name: String = "ITEM"
@export var amount_template: String = "×%d"
@export_range(1.0, 1.2, 0.01) var hover_scale: float = 1.08
@export_range(0.05, 0.3, 0.01) var hover_duration: float = 0.12

@onready var _button: Button = %ItemButton
@onready var _amount_label: Label = %AmountLabel
@onready var _name_label: Label = %NameLabel

var _owned_amount: int = 0
var _interaction_locked: bool = false
var _hover_tween: Tween


func _ready() -> void:
	pivot_offset = size * 0.5
	_button.tooltip_text = item_name
	_name_label.text = short_name
	_button.mouse_entered.connect(_set_hovered.bind(true))
	_button.mouse_exited.connect(_set_hovered.bind(false))
	_refresh_presentation()


func set_owned_amount(value: int) -> void:
	_owned_amount = maxi(0, value)
	_refresh_presentation()


func get_owned_amount() -> int:
	return _owned_amount


func set_interaction_locked(value: bool) -> void:
	_interaction_locked = value
	_refresh_presentation()


func set_item_tooltip(value: String) -> void:
	_button.tooltip_text = value


func request_use() -> bool:
	if not visible or _owned_amount <= 0 or _interaction_locked:
		return false
	_pulse()
	tool_requested.emit(tool_id)
	return true


func _refresh_presentation() -> void:
	if not is_node_ready():
		return
	# Slots always stay on the HUD so shortcut hints remain visible;
	# empty stock simply reads ×0 with interaction disabled.
	_amount_label.text = amount_template % _owned_amount
	_button.disabled = _interaction_locked or _owned_amount <= 0
	# Keep the authored item artwork untouched even while interaction is locked.
	# Availability is already communicated by the amount label and the lock.
	self_modulate = Color.WHITE


func _set_hovered(value: bool) -> void:
	if _button.disabled:
		value = false
	if is_instance_valid(_hover_tween) and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(
		self,
		^"scale",
		Vector2.ONE * (hover_scale if value else 1.0),
		hover_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pulse() -> void:
	if is_instance_valid(_hover_tween) and _hover_tween.is_valid():
		_hover_tween.kill()
	scale = Vector2.ONE * 0.92
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, ^"scale", Vector2.ONE, hover_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_item_button_pressed() -> void:
	request_use()
