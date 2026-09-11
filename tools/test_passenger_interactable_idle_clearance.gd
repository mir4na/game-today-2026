extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)

	var obstacle := Interactable.new()
	var obstacle_collision := CollisionShape2D.new()
	var obstacle_shape := RectangleShape2D.new()
	obstacle_shape.size = Vector2(140.0, 180.0)
	obstacle_collision.shape = obstacle_shape
	obstacle.add_child(obstacle_collision)
	world.add_child(obstacle)

	var npc: Passenger = load("res://scenes/passengers/passenger.tscn").instantiate()
	npc.data = PassengerData.new()
	npc.data.ai_behavior = "still"
	world.add_child(npc)
	npc.configure_seat_navigation(
		Vector2.ZERO,
		PackedVector2Array([Vector2(240.0, 0.0)]),
		{1: Vector2(-400.0, 400.0)}
	)
	npc.position = Vector2.ZERO
	npc._ai_target_position = npc.position
	npc._ai_walking = false
	npc._process(0.1)
	_check(npc._ai_walking, "An idle NPC walks away from any overlapping Interactable collision.")
	_check(npc._ai_target_position != Vector2.ZERO, "The obstructed NPC receives a clear destination.")

	# Interactable clearance only affects stopping. An NPC already walking may
	# cross the collision and validates the destination again when it arrives.
	npc.position = Vector2(-240.0, 0.0)
	npc._ai_target_position = Vector2(240.0, 0.0)
	npc._ai_walking = true
	for step: int in 30:
		npc._advance_ai_movement(0.1)
	_check(npc.position.x > 0.0, "A walking NPC may pass through an Interactable collision.")

	# Ordinary bodies such as the MC are deliberately absent from the group and
	# therefore do not prevent an NPC from idling.
	obstacle.enabled = false
	var player_body := CharacterBody2D.new()
	var player_collision := CollisionShape2D.new()
	player_collision.shape = obstacle_shape.duplicate()
	player_body.add_child(player_collision)
	world.add_child(player_body)
	npc.position = Vector2.ZERO
	npc._ai_target_position = Vector2.ZERO
	npc._ai_walking = false
	_check(npc._is_stop_position_available(npc.position), "The MC collision does not block NPC idle placement.")

	world.free()
	if failures == 0:
		print("PASS: idle NPCs leave Interactable collisions, walkers may cross them, and MC collisions are ignored.")
	quit(1 if failures else 0)
