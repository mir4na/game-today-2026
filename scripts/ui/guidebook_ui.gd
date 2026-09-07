class_name GuidebookUI
extends Control
## Scene-authored conductor guidebook. Scripts only populate daily runtime data.

signal closed

@export_category("Dynamic Copy")
@export_multiline var today_document_template: String
@export var completed_service_text: String
@export_category("Guide Sections")
@export_multiline var procedure_document: String
@export_category("Scene Motion")
@export_range(1.0, 1.2, 0.01) var button_hover_scale: float = 1.07
@export_range(0.05, 0.4, 0.01) var button_hover_duration: float = 0.12
@export_range(0.15, 0.8, 0.01) var page_rustle_duration: float = 0.42
@export_range(0.0, 0.15, 0.005) var paper_rustle_stagger: float = 0.035

var _day_number: int = 1
var _pass_target: int = 0
var _net_earnings: int = 0
var _passenger_count: int = 0
var _boarded_today: int = 0
var _stamped_aboard: int = 0
var _service_train_number: String = ""
var _service_date: String = ""
var _service_day_code: String = ""
var _route_stations: PackedStringArray = PackedStringArray()
var _route_index: int = 0
var _active_section: int = -1
var _scene_motion_ready: bool = false
var _motion_bases: Dictionary = {}
var _hover_tweens: Dictionary = {}
var _hovered_targets: Dictionary = {}
var _section_tween: Tween

@onready var _page_title: Label = %PageTitle
@onready var _content: RichTextLabel = %Content
@onready var _today_button: Button = %TodayButton
@onready var _procedure_button: Button = %ProcedureButton
@onready var _anomaly_list: Control = %AnomalyList
@onready var _anomalies_button: Button = %AnomaliesButton
@onready var _today_tab: Control = %TodayTab
@onready var _rules_tab: Control = %RulesTab
@onready var _anomaly_tab: Control = %AnomalyTab
@onready var _page: Control = %Page
@onready var _clip: Control = %Clip
@onready var _next_page: Control = %NextPage
@onready var _next_page_button: Button = %NextPageButton
@onready var _close_button: Button = %CloseButton
@onready var _paper_nodes: Array[Control] = [%PinkTall, %YellowSheet, %BlueSheet, %PinkWide, %Ribbon]

const SECTION_TODAY: int = 0
const SECTION_ANOMALIES: int = 1
const SECTION_RULES: int = 2


func _ready() -> void:
	call_deferred(&"_setup_scene_motion")


func open_guidebook(
	day_number: int,
	service_train_number: String,
	service_date: String,
	service_day_code: String,
	route_stations: PackedStringArray,
	_collected_newspaper: String,
	route_index: int,
	pass_target: int
) -> void:
	_day_number = maxi(1, day_number)
	_pass_target = maxi(0, pass_target)
	_service_train_number = service_train_number
	_service_date = service_date
	_service_day_code = service_day_code
	_route_stations = route_stations.duplicate()
	_route_index = clampi(route_index, 0, maxi(0, _route_stations.size() - 1))
	show()
	_active_section = -1
	_show_today()
	_today_button.grab_focus()


func request_close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func update_shift_progress(route_index: int, net_earnings: int, passenger_count: int, boarded_today: int, stamped_aboard: int) -> void:
	var next_route_index: int = clampi(route_index, 0, maxi(0, _route_stations.size() - 1))
	if _route_index == next_route_index and _net_earnings == net_earnings and _passenger_count == passenger_count and _boarded_today == boarded_today and _stamped_aboard == stamped_aboard:
		return
	_route_index = next_route_index
	_net_earnings = net_earnings
	_passenger_count = maxi(0, passenger_count)
	_boarded_today = maxi(0, boarded_today)
	_stamped_aboard = maxi(0, stamped_aboard)
	if visible and _active_section == SECTION_TODAY:
		_show_today()


func _show_today() -> void:
	var current_station: String = _station_at(_route_index)
	var next_station: String = completed_service_text
	if _route_index + 1 < _route_stations.size():
		next_station = _route_stations[_route_index + 1]
	_set_section(
		_today_button,
		"Today's Service",
		today_document_template % [
			_day_number,
			_service_date,
			_service_train_number,
			_pass_target,
			_net_earnings,
			maxi(0, _pass_target - _net_earnings),
			_boarded_today,
			_passenger_count,
			_stamped_aboard,
			_route_index,
			maxi(0, _route_stations.size() - 1),
			_service_day_code,
			current_station,
			next_station,
			_format_route(),
		]
	)


func _show_procedure() -> void:
	_set_section(_procedure_button, "Rules", procedure_document)


func _show_anomalies() -> void:
	_set_section(_anomalies_button, "Anomaly List", "")
	_content.hide()
	_anomaly_list.show()


func _set_section(active_button: Button, title: String, document: String) -> void:
	var next_section: int = SECTION_RULES
	if active_button == _today_button:
		next_section = SECTION_TODAY
	elif active_button == _anomalies_button:
		next_section = SECTION_ANOMALIES
	var section_changed: bool = next_section != _active_section
	_active_section = next_section
	_update_tab_presentation()
	_content.show()
	_anomaly_list.hide()
	_page_title.text = title
	_content.text = document
	if section_changed:
		_play_section_rustle()


func _section_buttons() -> Array[Button]:
	return [_today_button, _procedure_button, _anomalies_button]


func _show_next_section() -> void:
	match _active_section:
		SECTION_TODAY:
			_show_anomalies()
		SECTION_ANOMALIES:
			_show_procedure()
		_:
			_show_today()


func _update_tab_presentation() -> void:
	_set_tab_active(_today_tab, _active_section == SECTION_TODAY)
	_set_tab_active(_anomaly_tab, _active_section == SECTION_ANOMALIES)
	_set_tab_active(_rules_tab, _active_section == SECTION_RULES)


func _set_tab_active(tab: Control, active: bool) -> void:
	if not is_instance_valid(tab):
		return
	var base_position: Vector2 = Vector2(0.0, tab.position.y)
	if _motion_bases.has(tab):
		base_position = _motion_bases[tab]["position"]
	tab.modulate = Color.WHITE if active else Color(0.72, 0.72, 0.72, 0.92)
	tab.position = base_position + (Vector2(-8.0, 0.0) if active else Vector2.ZERO)
	if active:
		_stop_hover_tween(tab)
		_hovered_targets.erase(tab)
		tab.scale = Vector2.ONE


func _setup_scene_motion() -> void:
	if _scene_motion_ready or not is_inside_tree():
		return
	for node: Control in _rustle_nodes():
		_capture_motion_base(node)
	for tab: Control in [_today_tab, _anomaly_tab, _rules_tab]:
		_capture_motion_base(tab)
	_register_hover(_today_button, _today_tab)
	_register_hover(_anomalies_button, _anomaly_tab)
	_register_hover(_procedure_button, _rules_tab)
	_register_hover(_close_button, _close_button)
	_register_hover(_next_page_button, _next_page)
	_scene_motion_ready = true
	_update_tab_presentation()


func _rustle_nodes() -> Array[Control]:
	var nodes: Array[Control] = [_page, _clip, _next_page]
	nodes.append_array(_paper_nodes)
	return nodes


func _capture_motion_base(node: Control) -> void:
	_motion_bases[node] = {
		"position": node.position,
		"rotation": node.rotation,
		"scale": node.scale,
		"modulate": node.modulate,
	}


func _restore_motion_base(node: Control) -> void:
	if not _motion_bases.has(node):
		return
	var base: Dictionary = _motion_bases[node]
	node.position = base["position"]
	node.rotation = float(base["rotation"])
	node.scale = base["scale"]
	node.modulate = base["modulate"]


func _play_section_rustle() -> void:
	if not _scene_motion_ready:
		return
	if is_instance_valid(_section_tween):
		_section_tween.kill()
	for node: Control in _rustle_nodes():
		_restore_motion_base(node)

	var direction: float = -1.0 if _active_section % 2 == 0 else 1.0
	var page_base: Dictionary = _motion_bases[_page]
	_page.position = page_base["position"] + Vector2(20.0 * direction, 5.0)
	_page.rotation = float(page_base["rotation"]) + 0.012 * direction
	_page.scale = Vector2(0.985, 1.012) * Vector2(page_base["scale"])
	_page.modulate.a = 0.32

	var paper_offsets: Array[Vector2] = [
		Vector2(-14.0, 8.0), Vector2(11.0, -7.0), Vector2(15.0, 7.0),
		Vector2(-12.0, -8.0), Vector2(0.0, 13.0),
	]
	var paper_rotations: PackedFloat32Array = PackedFloat32Array([-0.035, 0.028, -0.024, 0.032, -0.055])
	for index: int in range(_paper_nodes.size()):
		var paper: Control = _paper_nodes[index]
		var base: Dictionary = _motion_bases[paper]
		paper.position = base["position"] + paper_offsets[index] * direction
		paper.rotation = float(base["rotation"]) + paper_rotations[index] * direction

	var clip_base: Dictionary = _motion_bases[_clip]
	_clip.position = clip_base["position"] + Vector2(0.0, -12.0)
	_clip.rotation = float(clip_base["rotation"]) - 0.08 * direction
	var next_base: Dictionary = _motion_bases[_next_page]
	_next_page.scale = Vector2(next_base["scale"]) * 0.82
	_next_page.rotation = float(next_base["rotation"]) + 0.06 * direction

	_section_tween = create_tween().set_parallel(true)
	_section_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_to_motion_base(_page, 0.0)
	for index: int in range(_paper_nodes.size()):
		_tween_to_motion_base(_paper_nodes[index], float(index) * paper_rustle_stagger)
	_tween_to_motion_base(_clip, paper_rustle_stagger * 1.5)
	_tween_to_motion_base(_next_page, paper_rustle_stagger * 3.0)


func _tween_to_motion_base(node: Control, delay: float) -> void:
	var base: Dictionary = _motion_bases[node]
	var resting_scale: Vector2 = base["scale"]
	if _hovered_targets.has(node):
		resting_scale *= button_hover_scale
	_section_tween.tween_property(node, ^"position", base["position"], page_rustle_duration).set_delay(delay)
	_section_tween.tween_property(node, ^"rotation", base["rotation"], page_rustle_duration).set_delay(delay)
	_section_tween.tween_property(node, ^"scale", resting_scale, page_rustle_duration).set_delay(delay)
	_section_tween.tween_property(node, ^"modulate", base["modulate"], page_rustle_duration * 0.72).set_delay(delay)


func _register_hover(button: Button, target: Control) -> void:
	button.mouse_entered.connect(_animate_button_hover.bind(target, true))
	button.mouse_exited.connect(_animate_button_hover.bind(target, false))
	button.focus_entered.connect(_animate_button_hover.bind(target, true))
	button.focus_exited.connect(_animate_button_hover.bind(target, false))


func _animate_button_hover(target: Control, hovered: bool) -> void:
	if not is_instance_valid(target):
		return
	if hovered:
		_hovered_targets[target] = true
	else:
		_hovered_targets.erase(target)
	_stop_hover_tween(target)
	var base_scale: Vector2 = Vector2.ONE
	if _motion_bases.has(target):
		base_scale = _motion_bases[target]["scale"]
	var target_scale: Vector2 = base_scale * (button_hover_scale if hovered else 1.0)
	var tween: Tween = create_tween()
	_hover_tweens[target] = tween
	tween.tween_property(target, ^"scale", target_scale, button_hover_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _stop_hover_tween(target: Control) -> void:
	var previous: Tween = _hover_tweens.get(target) as Tween
	if is_instance_valid(previous):
		previous.kill()
	_hover_tweens.erase(target)


func _station_at(index: int) -> String:
	if _route_stations.is_empty():
		return "UNAVAILABLE"
	return _route_stations[clampi(index, 0, _route_stations.size() - 1)]


func _format_route() -> String:
	var parts := PackedStringArray()
	for index: int in range(_route_stations.size()):
		var station: String = _route_stations[index]
		if index < _route_index:
			parts.append("[color=#8d8371]%s[/color]" % station)
		elif index == _route_index:
			parts.append("[color=#7d382d][b][ %s ][/b][/color]" % station)
		else:
			parts.append("[color=#332b23]%s[/color]" % station)
	return "  →  ".join(parts)
