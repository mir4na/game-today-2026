extends Control
## Screen-space pointer for a scene-authored maintenance event target.

@export_category("Screen Placement")
@export var screen_edge_margin: Vector2 = Vector2(54.0, 54.0)
@export var on_screen_offset: Vector2 = Vector2(0.0, -58.0)
@export_range(-240.0, 240.0, 1.0) var off_screen_lane_offset: float = 0.0
@export_category("Motion")
@export_range(0.0, 12.0, 0.1) var pulse_speed: float = 4.0
@export_range(0.0, 0.25, 0.01) var pulse_amount: float = 0.08
@export_category("Scene Nodes")
@export_node_path("TextureRect") var pointer_path: NodePath
@export_node_path("Label") var label_path: NodePath

@onready var _pointer: TextureRect = get_node_or_null(pointer_path) as TextureRect
@onready var _label: Label = get_node_or_null(label_path) as Label

var _target: Node2D
var _pulse_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func _process(delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(_target) or not _target.is_inside_tree():
		clear_target()
		return
	_pulse_time += delta
	_update_screen_position()
	var pulse: float = 1.0 + sin(_pulse_time * pulse_speed) * pulse_amount
	scale = Vector2.ONE * pulse


func set_target(target: Node2D, tracker_text: String) -> void:
	if not is_instance_valid(target):
		clear_target()
		return
	_target = target
	_pulse_time = 0.0
	if is_instance_valid(_label):
		_label.text = tracker_text
	show()
	_update_screen_position()


func clear_target() -> void:
	_target = null
	scale = Vector2.ONE
	hide()


func _update_screen_position() -> void:
	if not is_instance_valid(_target):
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var target_screen_position: Vector2 = _target.get_global_transform_with_canvas().origin
	var effective_margin := Vector2(
		maxf(screen_edge_margin.x, size.x * 0.5 + 12.0),
		maxf(screen_edge_margin.y, size.y * 0.5 + 12.0)
	)
	var safe_screen_rect := Rect2(effective_margin, viewport_size - effective_margin * 2.0)
	var target_is_on_screen: bool = safe_screen_rect.has_point(target_screen_position)
	var tracker_center: Vector2
	var pointer_rotation: float = 0.0
	if target_is_on_screen:
		tracker_center = target_screen_position + on_screen_offset
	else:
		var viewport_center: Vector2 = viewport_size * 0.5
		var direction: Vector2 = (target_screen_position - viewport_center).normalized()
		tracker_center = Vector2(
			clampf(target_screen_position.x, effective_margin.x, viewport_size.x - effective_margin.x),
			clampf(target_screen_position.y, effective_margin.y, viewport_size.y - effective_margin.y)
		)
		tracker_center += direction.orthogonal() * off_screen_lane_offset
		# dialogue_pointer.png points downward at zero rotation.
		pointer_rotation = direction.angle() - PI * 0.5
	tracker_center.x = clampf(tracker_center.x, effective_margin.x, viewport_size.x - effective_margin.x)
	tracker_center.y = clampf(tracker_center.y, effective_margin.y, viewport_size.y - effective_margin.y)
	position = tracker_center - size * 0.5
	pivot_offset = size * 0.5
	if is_instance_valid(_pointer):
		_pointer.pivot_offset = _pointer.size * 0.5
		_pointer.rotation = pointer_rotation
