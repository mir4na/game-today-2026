extends SceneTree
## Verifies that station boarders exist on the platform before their walk begins.


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE
	root.add_child(camera)
	camera.enabled = true
	var train := load("res://scenes/train/train.tscn").instantiate() as TrainWorld
	var station_ui := load("res://scenes/ui/station_stop_cutscene_ui.tscn").instantiate() as StationStopCutsceneUI
	root.add_child(train)
	root.add_child(station_ui)
	await process_frame

	train.show_exterior_body(15.0, 6.0, 11.0)
	var waiting_positions: Dictionary = train.get_passenger_door_station_rest_positions()
	assert(not waiting_positions.is_empty(), "Train must expose stopped door positions for platform staging.")
	var carriage_number: int = int(waiting_positions.keys()[0])
	var first_position: Vector2 = waiting_positions[carriage_number][0]
	train.set_station_arrival_progress(0.5)
	var moved_train_positions: Dictionary = train.get_passenger_door_station_rest_positions()
	assert(first_position.is_equal_approx(moved_train_positions[carriage_number][0]), "Waiting anchors must remain fixed while the train arrives.")

	var actor: Dictionary = {
		"name": "Waiting boarder",
		"carriage": carriage_number,
		"texture": load("res://assets/ui/PauseMenu/SelectLeft.png"),
		"visual_position": Vector2.ZERO,
		"visual_scale": Vector2.ONE,
		"faces_left": true,
	}
	station_ui.play_opening(
		"Test station",
		[actor],
		train.get_passenger_door_markers(),
		waiting_positions,
		[]
	)
	station_ui.set_process(false)
	var waiting_actor := station_ui.get_node("ActorSlots/Actor0") as Node2D
	assert(waiting_actor.visible, "A boarder must be visible before boarding_start_time.")
	assert(station_ui.opening_boarding_start_time > 0.0, "The visibility check must occur before walking begins.")
	var zoomed_in_actor_scale: float = waiting_actor.scale.x
	camera.zoom = Vector2.ONE * station_ui.station_reference_camera_zoom
	station_ui.call(&"_update_visuals")
	var zoomed_out_actor_scale: float = waiting_actor.scale.x
	assert(zoomed_in_actor_scale > zoomed_out_actor_scale, "Boarders must shrink with the station camera zoom-out.")
	assert(is_equal_approx(zoomed_out_actor_scale, station_ui.zoomed_out_actor_scale), "The wide shot must use the authored actor scale.")
	print("PASS: station boarders wait from the opening frame and scale with camera zoom.")
	quit()
