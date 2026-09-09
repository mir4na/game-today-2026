class_name NightStationPathLayout
extends Control
## One editable station-path layout for a single Night Service level.

@export_range(1, 5, 1) var service_level: int = 1
@export var validation_order: PackedStringArray = PackedStringArray()


func get_station_targets() -> Array[NightStationTarget]:
	var result: Array[NightStationTarget] = []
	for child: Node in get_children():
		if child is NightStationTarget:
			result.append(child as NightStationTarget)
	return result


func get_path_markers() -> Array[NightPathMarker]:
	var result: Array[NightPathMarker] = []
	for child: Node in get_children():
		if child is NightPathMarker:
			result.append(child as NightPathMarker)
	return result


func get_path_segments() -> Array[NightPathSegment]:
	var result: Array[NightPathSegment] = []
	for child: Node in get_children():
		if child is NightPathSegment:
			result.append(child as NightPathSegment)
	return result


func get_small_mark_distance(first_station: String, second_station: String) -> int:
	if first_station == second_station:
		return 0
	var adjacency: Dictionary = _build_adjacency()
	if not adjacency.has(first_station) or not adjacency.has(second_station):
		return -1
	var small_ids: Dictionary = {}
	for marker: NightPathMarker in get_path_markers():
		small_ids[str(marker.path_node_id)] = true
	var best_cost: Dictionary = {first_station: 0}
	var frontier: Array[String] = [first_station]
	while not frontier.is_empty():
		var current_index: int = _lowest_cost_index(frontier, best_cost)
		var current: String = frontier.pop_at(current_index)
		if current == second_station:
			return int(best_cost[current])
		for neighbor_value: Variant in adjacency.get(current, []):
			var neighbor: String = str(neighbor_value)
			var next_cost: int = int(best_cost[current]) + (1 if small_ids.has(neighbor) else 0)
			if next_cost >= int(best_cost.get(neighbor, 1_000_000)):
				continue
			best_cost[neighbor] = next_cost
			if not frontier.has(neighbor):
				frontier.append(neighbor)
	return -1


func stations_share_direct_route(first_station: String, second_station: String) -> bool:
	if first_station == second_station:
		return false
	var adjacency: Dictionary = _build_adjacency()
	var station_ids: Dictionary = {}
	for target: NightStationTarget in get_station_targets():
		station_ids[target.station_name] = true
	var visited: Dictionary = {first_station: true}
	var frontier: Array[String] = [first_station]
	while not frontier.is_empty():
		var current: String = frontier.pop_front()
		for neighbor_value: Variant in adjacency.get(current, []):
			var neighbor: String = str(neighbor_value)
			if neighbor == second_station:
				return true
			if station_ids.has(neighbor) or visited.has(neighbor):
				continue
			visited[neighbor] = true
			frontier.append(neighbor)
	return false


func _build_adjacency() -> Dictionary:
	var result: Dictionary = {}
	for segment: NightPathSegment in get_path_segments():
		var endpoints: PackedStringArray = segment.get_endpoint_ids()
		if endpoints.size() != 2 or endpoints[0].is_empty() or endpoints[1].is_empty():
			continue
		if not result.has(endpoints[0]):
			result[endpoints[0]] = []
		if not result.has(endpoints[1]):
			result[endpoints[1]] = []
		(result[endpoints[0]] as Array).append(endpoints[1])
		(result[endpoints[1]] as Array).append(endpoints[0])
	return result


func _lowest_cost_index(frontier: Array[String], costs: Dictionary) -> int:
	var best_index: int = 0
	var lowest_cost: int = int(costs.get(frontier[0], 1_000_000))
	for index: int in range(1, frontier.size()):
		var candidate_cost: int = int(costs.get(frontier[index], 1_000_000))
		if candidate_cost < lowest_cost:
			lowest_cost = candidate_cost
			best_index = index
	return best_index


func get_validation_targets() -> Array[NightStationTarget]:
	var targets_by_name: Dictionary = {}
	for target: NightStationTarget in get_station_targets():
		targets_by_name[target.station_name] = target
	var result: Array[NightStationTarget] = []
	for station_name: String in validation_order:
		var target := targets_by_name.get(station_name) as NightStationTarget
		if target != null:
			result.append(target)
	return result
