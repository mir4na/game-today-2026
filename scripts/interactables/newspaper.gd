class_name NewspaperInteractable
extends Interactable

signal newspaper_read

@export_category("Passenger Standing Clearance")
## Half-extents around the rack where NPCs may pass but cannot stop.
@export var passenger_stop_clearance: Vector2 = Vector2(160.0, 180.0)

func is_passenger_stop_blocked(world_position: Vector2) -> bool:
	var local_point: Vector2 = to_local(world_position)
	return absf(local_point.x) < passenger_stop_clearance.x and absf(local_point.y) < passenger_stop_clearance.y

func interact() -> void:
	newspaper_read.emit()
