extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var rack: NewspaperInteractable = load("res://scenes/interactables/newspaper.tscn").instantiate()
	world.add_child(rack)
	rack.position = Vector2(450, 114)
	var inspected: Passenger = load("res://scenes/passengers/passenger.tscn").instantiate()
	var other: Passenger = load("res://scenes/passengers/passenger.tscn").instantiate()
	for npc: Passenger in [inspected, other]:
		npc.data = PassengerData.new()
		world.add_child(npc)
		npc.set_process(false)
		npc.position = Vector2(450, 0)
	inspected.configure_seat_navigation(Vector2(60, 0), PackedVector2Array([Vector2(250, 0), Vector2(700, 0), Vector2(860, 0)]), {1: Vector2(0, 960)})
	other.configure_seat_navigation(Vector2(860, 0), PackedVector2Array([Vector2(250, 0), Vector2(700, 0)]), {1: Vector2(0, 960)})
	inspected._boarding_handoff_active = true
	inspected._ai_walking = true
	inspected._ai_target_position = Vector2(700, 0)
	inspected.set_inspection_paused(true)
	for step: int in 40:
		inspected._process(0.1)
		other._process(0.1)
	check(inspected.position == Vector2(450, 0) and not inspected._ai_walking, "Inspected NPC remains idle inside rack and another NPC, even during boarding.")
	check(not other._stop_shapes_overlap(other.position, inspected, inspected.position), "Other NPC moves away from the inspected passenger.")
	inspected.set_inspection_paused(false)
	check(inspected._ai_walking, "Closing inspection resumes walking out of the rack.")
	for step: int in 60:
		inspected._process(0.1)
		other._process(0.1)
	check(not inspected._ai_walking and inspected._is_stop_position_available(inspected.position), "Resumed NPC stops clear of rack and other NPC.")
	# Collider edits must govern placement, not a separate hardcoded clearance.
	var collider: CollisionShape2D = rack.get_node("CollisionShape2D")
	collider.disabled = true
	check(not Passenger.is_stop_reserved_for_interaction(self, rack.global_position), "Disabled newspaper collider imposes no stopping restriction.")
	world.free()
	if failures == 0:
		print("PASS: inspection priority, boarding freeze, other NPC yields, post-inspection safe stop, collider-driven clearance.")
	quit(1 if failures else 0)
