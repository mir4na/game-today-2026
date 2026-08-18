class_name FurnaceInteractable
extends Interactable

signal coal_added(amount: float)

@export var refill_amount: float = 16.0

func interact() -> void:
	coal_added.emit(refill_amount)
