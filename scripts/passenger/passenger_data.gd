class_name PassengerData
extends Resource
## One generated passenger for the current shift.
##
## Identity values are copied as one coherent bundle from PassengerIdentityProfile.
## Everything else is assigned at runtime by DailyManifestGenerator.

const TICKET_ISSUE_NONE: StringName = &"none"
const TICKET_ISSUE_WRONG_TRAIN_BOARDER: StringName = &"wrong_train_boarder"

var identity_profile: PassengerIdentityProfile
var passenger_name: String = "Unnamed"
var short_name: String = "Unnamed"
var age: int = 30
var occupation: String = "Unknown"
var body_color: Color = Color("8eb7c8")
var id_photo: Texture2D
var id_photo_owner: String = ""
var identity_number: String = ""
var birth_place: String = ""
var date_of_birth: String = ""

var origin_station: String = ""
var destination_station: String = ""
var ticket_owner: String = ""
var ticket_number: String = ""
var ticket_train_number: String = ""
var ticket_service_date: String = ""
var ticket_day_code: String = ""
var ticket_issue_type: StringName = TICKET_ISSUE_NONE
var required_dropoff_station: String = ""
var is_dead: bool = false
var anomaly_type: String = "none"
var current_carriage: int = 1
var initially_on_train: bool = false
var ai_behavior: String = "still"
var ai_interval_seconds: float = 15.0

static func create_from_identity(profile: PassengerIdentityProfile) -> PassengerData:
	if profile == null or not profile.is_valid_identity():
		return null
	var data := PassengerData.new()
	data.resource_local_to_scene = true
	data.identity_profile = profile
	data.passenger_name = profile.passenger_name.strip_edges()
	data.short_name = profile.short_name.strip_edges()
	if data.short_name.is_empty():
		data.short_name = data.passenger_name
	data.age = profile.age
	data.occupation = profile.occupation
	data.body_color = profile.body_color
	data.id_photo = profile.id_photo
	data.id_photo_owner = data.passenger_name
	data.identity_number = profile.identity_number
	data.birth_place = profile.birth_place
	data.date_of_birth = profile.date_of_birth
	return data

func get_anomaly_traits(route_stations: PackedStringArray) -> Array[StringName]:
	var traits: Array[StringName] = []
	if anomaly_type != "none":
		traits.append(StringName(anomaly_type))
	if not route_stations.has(destination_station) and not traits.has(&"unlisted_destination"):
		traits.append(&"unlisted_destination")
	return traits

func is_wrong_train_boarder() -> bool:
	return ticket_issue_type == TICKET_ISSUE_WRONG_TRAIN_BOARDER

func get_required_day_dropoff_station() -> String:
	if is_wrong_train_boarder() and not required_dropoff_station.is_empty():
		return required_dropoff_station
	return destination_station
