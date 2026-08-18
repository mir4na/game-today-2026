class_name DeparturePuzzleData
extends Resource
## Defines which deceased passenger must leave at each stop of the night train.

@export var night_stations: PackedStringArray = PackedStringArray()
@export_multiline var night_stop_clues: String = ""
@export var correct_passenger_by_station: Dictionary = {}
