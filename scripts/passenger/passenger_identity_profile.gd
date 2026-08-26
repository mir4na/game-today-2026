class_name PassengerIdentityProfile
extends Resource
## Designer-authored identity bundle used as an immutable source for daily passengers.
##
## Keep the name, portrait, personal details, and visual identity together here.
## Daily routes, tickets, behavior, and anomaly roles belong to PassengerData instead.

@export_category("Identity")
@export var passenger_name: String = "Unnamed"
@export var short_name: String = "Unnamed"
@export_range(0, 150, 1) var age: int = 30
@export var occupation: String = "Unknown"
@export var body_color: Color = Color("8eb7c8")

@export_category("Passenger Scene")
@export var passenger_scene: PackedScene

@export_category("Identification Card")
@export var id_photo: Texture2D
@export var identity_number: String = ""
@export var birth_place: String = ""
@export var date_of_birth: String = ""

func get_lookup_name() -> String:
	var preferred_name: String = short_name.strip_edges()
	if preferred_name.is_empty():
		preferred_name = passenger_name.strip_edges()
	return preferred_name.to_lower()

func is_valid_identity() -> bool:
	return not passenger_name.strip_edges().is_empty() and not get_lookup_name().is_empty()
