class_name NewspaperInteractable
extends Interactable

signal newspaper_read

func interact() -> void:
	newspaper_read.emit()
