extends SceneTree
## Verifies natural station entrances, platform alignment, and world-bound actors.


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
	var door_markers: Dictionary = train.get_passenger_door_markers()
	var waiting_positions: Dictionary = train.get_passenger_door_station_rest_positions()
	assert(not door_markers.is_empty(), "Train must expose scene-authored door markers.")
	assert(not waiting_positions.is_empty(), "Train must expose fixed platform door positions.")
	var carriage_number: int = int(door_markers.keys()[0])

	var actor: Dictionary = {
		"name": "Waiting boarder",
		"carriage": carriage_number,
		"texture": load("res://assets/ui/PauseMenu/SelectLeft.png"),
		"visual_position": Vector2.ZERO,
		"visual_scale": Vector2.ONE,
		"faces_left": true,
	}
	var ambient_actor: Dictionary = actor.duplicate(true)
	ambient_actor["name"] = "Platform pedestrian"
	ambient_actor["runtime_actor_id"] = 0
	station_ui.ambient_actor_count = 1
	station_ui.set_station_crowd_layout({
		"platform_baseline_y": 610.0,
		"left_entrance": Vector2(-520.0, 610.0),
		"right_entrance": Vector2(4320.0, 610.0),
		"bottom_entrance": Vector2(1900.0, 1480.0),
	})
	station_ui.play_opening(
		"Test station",
		[actor],
		door_markers,
		waiting_positions,
		[ambient_actor]
	)
	station_ui.set_process(false)
	var boarding_actor := station_ui.get_node("StationActorCanvas/ActorSlots/Actor0") as Node2D
	var platform_actor := station_ui.get_node("StationActorCanvas/ActorSlots/Actor1") as Node2D
	assert(not boarding_actor.visible, "A boarder must stay outside the station until its approach begins.")
	assert(platform_actor.visible, "A platform pedestrian must already be walking during train approach.")
	assert(platform_actor.position.y >= 550.0 and platform_actor.position.y <= 660.0, "Ambient feet must stay on the authored platform lanes.")
	var concourse_entry: Vector2 = station_ui._boarding_entry_position(
		Vector2(1800.0, 610.0),
		{"entry_route": 2}
	)
	assert(concourse_entry.is_equal_approx(Vector2(1800.0, 1480.0)), "The lower concourse route must originate outside the platform frame.")

	var local_actor_scale: float = platform_actor.scale.x
	assert(local_actor_scale >= 0.78 and local_actor_scale <= 1.0, "Ambient depth scaling must stay within its authored range.")
	var first_screen_position: Vector2 = platform_actor.get_global_transform_with_canvas().origin
	camera.position.x += 200.0
	await process_frame
	var moved_screen_position: Vector2 = platform_actor.get_global_transform_with_canvas().origin
	assert(moved_screen_position.x < first_screen_position.x - 190.0, "A platform pedestrian must stay in the station world when the camera leaves.")
	assert(is_equal_approx(platform_actor.scale.x, local_actor_scale), "Camera movement must not mutate the actor's local scale.")

	var boarding_profile: Dictionary = station_ui._boarding_motion_profiles[0]
	var entry_start: float = float(boarding_profile["entry_start_time"])
	var boarding_start: float = float(boarding_profile["start_time"])
	station_ui._elapsed = entry_start + 0.05
	station_ui.call(&"_update_visuals")
	assert(boarding_actor.visible, "A boarder must enter through an offscreen station entrance.")
	assert(boarding_actor.position.y >= 598.0, "A boarder may approach from below, but must never float above the platform.")
	station_ui._elapsed = boarding_start - 0.001
	station_ui.call(&"_update_visuals")
	var position_before_boarding: Vector2 = boarding_actor.position
	# The train reaches its station-rest anchors before the boarding cue.
	train.set_station_arrival_progress(1.0)
	station_ui._elapsed = boarding_start
	station_ui.call(&"_update_visuals")
	assert(boarding_actor.visible, "A boarder must remain visible when the door approach begins.")
	assert(boarding_actor.position.distance_to(position_before_boarding) < 4.0, "Entrance and boarding paths must meet without a visual pop.")

	# A passenger who has stepped onto the platform must remain in the pedestrian
	# flow instead of holding a walking frame at their final doorway position.
	station_ui.play_stop("Test station", [actor], [], door_markers, waiting_positions, [])
	station_ui.set_process(false)
	var departing_profile: Dictionary = station_ui._departing_motion_profiles[0]
	var departing_end: float = float(departing_profile["start_time"]) + float(departing_profile["walk_duration"])
	station_ui._elapsed = departing_end + 0.15
	station_ui.call(&"_update_visuals")
	var departing_actor := station_ui.get_node("StationActorCanvas/ActorSlots/Actor0") as Node2D
	var first_departing_flow_position: Vector2 = departing_actor.position
	station_ui._elapsed = departing_end + 0.55
	station_ui.call(&"_update_visuals")
	assert(
		departing_actor.position.distance_to(first_departing_flow_position) > 10.0,
		"A departing passenger must continue through the platform crowd after leaving the train."
	)

	var skip_prompt := station_ui.get_node("CinematicBorderLayer/SkipHint/SkipPromptLabel") as Label
	var skip_button := station_ui.get_node("CinematicBorderLayer/SkipHint/SkipButton") as Button
	assert(skip_prompt != null and skip_prompt.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The non-interactive skip copy must not capture clicks.")
	assert(skip_button != null and skip_button.flat, "The station skip prompt must be a text-only clickable button.")
	assert(skip_button.text == "SKIP", "Only the colored SKIP word may act as the cutscene button.")
	assert(not skip_button.disabled, "The skip button must unlock after the opening screen fade.")
	var skip_requests: Array[int] = [0]
	station_ui.sequence_skip_requested.connect(func() -> void: skip_requests[0] += 1)
	skip_button.pressed.emit()
	assert(skip_requests[0] == 1, "Clicking the skip prompt must request the same cutscene skip as Space.")
	print("PASS: station crowd enters naturally, stays grounded, and remains bound to the station world.")
	quit()
