@tool
extends HBoxContainer
## Assign Photo on each entry in guidebook_ui.tscn; the empty frame is automatic.

@export var heading: String = "ANOMALY":
	set(value):
		heading = value
		_refresh()
@export_multiline var description: String = "":
	set(value):
		description = value
		_refresh()
@export var photo: Texture2D:
	set(value):
		photo = value
		_refresh()

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	if not is_node_ready():
		return
	$Text/Heading.text = heading
	$Text/Description.text = description
	$PhotoFrame/Photo.texture = photo
	$PhotoFrame/Placeholder.visible = photo == null
