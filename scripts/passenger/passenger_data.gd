class_name PassengerData
extends Resource
## Designer-editable facts for one passenger. Visual nodes only project this data.

@export var passenger_name: String = "Unnamed"
@export var short_name: String = "Unnamed"
@export var age: int = 30
@export var occupation: String = "Unknown"
@export var origin_station: String = "Alderwick"
@export var destination_station: String = "Eastmere"
@export var ticket_owner: String = "Unnamed"
@export var is_dead: bool = false
@export_enum("none", "shadowless", "impossible_ticket", "age_mismatch", "newspaper_death") var anomaly_type: String = "none"
@export_range(1, 4, 1) var current_carriage: int = 1
@export var initially_on_train: bool = true
@export_enum("still", "wander", "carriage_roamer", "window_watcher", "restless") var ai_behavior: String = "still"
@export_range(4.0, 30.0, 1.0) var ai_interval_seconds: float = 15.0
@export var body_color: Color = Color("8eb7c8")

func get_anomaly_traits(route_stations: PackedStringArray) -> Array[StringName]:
	var traits: Array[StringName] = []
	if anomaly_type != "none":
		traits.append(StringName(anomaly_type))
	if not route_stations.has(destination_station):
		traits.append(&"unlisted_destination")
	return traits
