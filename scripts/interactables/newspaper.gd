class_name NewspaperInteractable
extends Interactable

signal newspaper_read

func is_passenger_stop_blocked(world_position: Vector2, passenger_shape: Shape2D = null, passenger_transform: Transform2D = Transform2D.IDENTITY) -> bool:
	var collider := get_node("CollisionShape2D") as CollisionShape2D
	if collider.disabled or collider.shape == null:
		return false
	if passenger_shape == null:
		var default_shape := RectangleShape2D.new()
		default_shape.size = Vector2(110, 170)
		passenger_shape = default_shape
		passenger_transform.origin = world_position
	return passenger_shape.collide(passenger_transform, collider.shape, collider.global_transform)

func interact() -> void:
	newspaper_read.emit()
