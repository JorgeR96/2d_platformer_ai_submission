class_name AIPlanner
extends RefCounted

const EDGE_WALK := "walk"
const EDGE_JUMP := "jump"
const ROUTE_BASELINE := "Baseline Route"
const ROUTE_RISKY_SHORTCUT := "Risky Shortcut"
const ROUTE_SAFE_DETOUR := "Safe Detour"

enum SearchMode { UNIFORM_COST, GREEDY_BEST_FIRST, ASTAR }

const SEARCH_MODE_NAMES := {
	SearchMode.UNIFORM_COST: "Uniform Cost Search",
	SearchMode.GREEDY_BEST_FIRST: "Greedy Best-First Search",
	SearchMode.ASTAR: "A* Search",
}

var _points: Dictionary = {}
var _heuristics: Dictionary = {}
var _neighbors: Dictionary = {}
var _edge_kinds: Dictionary = {}
var _edge_costs: Dictionary = {}
var _edge_routes: Dictionary = {}
var _edge_count: int = 0
var current_search_mode: int = SearchMode.UNIFORM_COST

var last_planning_time_us: int = 0
var last_graph_node_count: int = 0
var last_graph_edge_count: int = 0
var last_path_node_count: int = 0
var last_nodes_expanded: int = 0
var last_path_cost: float = 0.0
var last_search_mode_name: String = "Uniform Cost Search"
var last_route_name: String = ROUTE_BASELINE
var last_path_ids: Array = []
var last_closed_ids: Array = []
var last_open_ids: Array = []

func build(graph_root: Node = null) -> void:
	_points.clear()
	_heuristics.clear()
	_neighbors.clear()
	_edge_kinds.clear()
	_edge_costs.clear()
	_edge_routes.clear()
	_edge_count = 0

	var scene_positions := _read_scene_node_positions(graph_root)
	# Hand-labeled heuristic values make the algorithm differences visible in the demo:
	# Greedy is tempted upward by lower h values, while A* weighs those labels against path cost.
	_add(0, scene_positions.get(0, Vector2(100, 480)), 30)    # start on LeftGround
	_add(1, scene_positions.get(1, Vector2(430, 480)), 29)    # LeftGround right takeoff
	_add(2, scene_positions.get(2, Vector2(610, 480)), 28)    # MidGround1 left landing
	_add(3, scene_positions.get(3, Vector2(980, 480)), 27)    # MidGround1 middle
	_add(4, scene_positions.get(4, Vector2(1360, 480)), 26)   # MidGround1 right branch
	_add(5, scene_positions.get(5, Vector2(1510, 379)), 19)   # upper route: MidGround3 left landing
	_add(6, scene_positions.get(6, Vector2(1730, 379)), 18)   # upper route: MidGround3 right takeoff
	_add(7, scene_positions.get(7, Vector2(1885, 377)), 17)   # upper route: FinalGround2 left landing
	_add(8, scene_positions.get(8, Vector2(2135, 377)), 16)   # upper route: FinalGround2 right takeoff
	_add(9, scene_positions.get(9, Vector2(2290, 377)), 15)   # upper route: MidGround5 left landing
	_add(10, scene_positions.get(10, Vector2(2525, 377)), 14) # upper route: MidGround5 right takeoff
	_add(11, scene_positions.get(11, Vector2(2685, 376)), 13) # upper route: MidGround6 left landing
	_add(12, scene_positions.get(12, Vector2(2920, 376)), 12) # upper route: MidGround6 right drop
	_add(13, scene_positions.get(13, Vector2(3270, 717)), 3)  # EndGround before final spike strip
	_add(14, scene_positions.get(14, Vector2(1550, 530)), 20) # lower route: MidGround2
	_add(15, scene_positions.get(15, Vector2(1985, 584)), 18) # lower route: MidGround4 right takeoff
	_add(16, scene_positions.get(16, Vector2(2140, 586)), 16) # lower route: FinalGround left landing
	_add(17, scene_positions.get(17, Vector2(2185, 586)), 14) # lower route: before spike strip 1
	_add(18, scene_positions.get(18, Vector2(2380, 586)), 12) # lower route: after spike strip 1
	_add(19, scene_positions.get(19, Vector2(2520, 586)), 10) # lower route: MidGround8 left landing
	_add(20, scene_positions.get(20, Vector2(2760, 586)), 8)  # lower route: MidGround8 right drop
	_add(21, scene_positions.get(21, Vector2(3020, 780)), 6)  # lower long platform takeoff
	_add(22, scene_positions.get(22, Vector2(3470, 717)), 2)  # EndGround after final spike strip
	_add(23, scene_positions.get(23, Vector2(3520, 717)), 1)  # EndGround after spike strip 2
	_add(24, scene_positions.get(24, Vector2(3711, 717)), 0)  # goal platform / flagpole
	_add(25, scene_positions.get(25, Vector2(2835, 780)), 9)  # lower long platform left landing
	_add(26, scene_positions.get(26, Vector2(2930, 780)), 8)  # lower long platform middle
	_add(27, scene_positions.get(27, Vector2(3105, 717)), 4)  # EndGround landing from lower platform

	# Edges are directed toward the goal. The fixed level and path follower do not need reverse traversal.
	_connect(0, 1, EDGE_WALK, 1)
	_connect(1, 2, EDGE_JUMP, 2)
	_connect(2, 3, EDGE_WALK, 1)
	_connect(3, 4, EDGE_WALK, 1)

	_connect(4, 5, EDGE_JUMP, 3, ROUTE_SAFE_DETOUR)
	_connect(5, 6, EDGE_WALK, 1, ROUTE_SAFE_DETOUR)
	_connect(6, 7, EDGE_JUMP, 2, ROUTE_SAFE_DETOUR)
	_connect(7, 8, EDGE_WALK, 1, ROUTE_SAFE_DETOUR)
	_connect(8, 9, EDGE_JUMP, 2, ROUTE_SAFE_DETOUR)
	_connect(9, 10, EDGE_WALK, 1, ROUTE_SAFE_DETOUR)
	_connect(10, 11, EDGE_JUMP, 2, ROUTE_SAFE_DETOUR)
	_connect(11, 12, EDGE_WALK, 1, ROUTE_SAFE_DETOUR)
	_connect(12, 21, EDGE_JUMP, 3, ROUTE_SAFE_DETOUR)

	_connect(4, 14, EDGE_WALK, 1, ROUTE_RISKY_SHORTCUT)
	_connect(14, 15, EDGE_WALK, 1, ROUTE_RISKY_SHORTCUT)
	_connect(15, 16, EDGE_JUMP, 2, ROUTE_RISKY_SHORTCUT)
	_connect(16, 17, EDGE_WALK, 1, ROUTE_RISKY_SHORTCUT)
	_connect(17, 18, EDGE_JUMP, 3, ROUTE_RISKY_SHORTCUT)
	_connect(18, 19, EDGE_JUMP, 2, ROUTE_RISKY_SHORTCUT)
	_connect(19, 20, EDGE_WALK, 1, ROUTE_RISKY_SHORTCUT)
	_connect(20, 21, EDGE_JUMP, 2, ROUTE_RISKY_SHORTCUT)

	_connect(15, 25, EDGE_JUMP, 4, ROUTE_SAFE_DETOUR)
	_connect(25, 26, EDGE_WALK, 1, ROUTE_SAFE_DETOUR)
	_connect(26, 21, EDGE_WALK, 1, ROUTE_SAFE_DETOUR)

	_connect(21, 27, EDGE_JUMP, 2)
	_connect(27, 13, EDGE_WALK, 1)
	_connect(13, 22, EDGE_JUMP, 3)
	_connect(22, 23, EDGE_WALK, 1)
	_connect(23, 24, EDGE_WALK, 1)
	last_graph_node_count = _points.size()
	last_graph_edge_count = _edge_count

func plan(start_world: Vector2, goal_world: Vector2) -> Array:
	var t0: int = Time.get_ticks_usec()
	var start_id: int = _closest_point(start_world)
	var goal_id: int = _closest_point(goal_world)

	# Shared frontier search. The selected mode only changes how frontier priority is scored.
	var open_set: Array = [start_id]
	var closed_set: Dictionary = {}
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start_id: 0.0}
	var h_score: Dictionary = {start_id: _heuristic(start_id)}
	var priority_score: Dictionary = {start_id: _priority_for_mode(0.0, h_score[start_id])}
	var expanded: int = 0

	while open_set.size() > 0:
		# Find node in open set with lowest mode-specific priority.
		var current: int = open_set[0]
		for id in open_set:
			if priority_score.get(id, INF) < priority_score.get(current, INF):
				current = id

		if current == goal_id:
			break

		open_set.erase(current)
		closed_set[current] = true
		expanded += 1

		for neighbor_id in _neighbors.get(current, []):
			if neighbor_id in closed_set:
				continue
			var tentative_g: float = g_score[current] + _edge_cost(current, neighbor_id)
			if tentative_g < g_score.get(neighbor_id, INF):
				came_from[neighbor_id] = current
				g_score[neighbor_id] = tentative_g
				h_score[neighbor_id] = _heuristic(neighbor_id)
				priority_score[neighbor_id] = _priority_for_mode(tentative_g, h_score[neighbor_id])
				if not (neighbor_id in open_set):
					open_set.append(neighbor_id)

	# Reconstruct path
	var path_ids: Array = []
	if goal_id in came_from or goal_id == start_id:
		var current: int = goal_id
		while current in came_from:
			path_ids.push_front(current)
			current = came_from[current]
		path_ids.push_front(start_id)

	last_planning_time_us = Time.get_ticks_usec() - t0
	last_nodes_expanded = expanded
	last_path_node_count = path_ids.size()
	last_path_cost = _calculate_path_cost(path_ids)
	last_search_mode_name = SEARCH_MODE_NAMES[current_search_mode]
	last_route_name = _infer_route_name(path_ids)
	last_path_ids = path_ids.duplicate()
	last_closed_ids = closed_set.keys()
	last_open_ids = open_set.duplicate()

	# Build waypoints with edge kind annotations
	var waypoints: Array = []
	for i in path_ids.size():
		var kind: String = EDGE_WALK
		if i + 1 < path_ids.size():
			kind = _edge_kinds.get(_edge_key(path_ids[i], path_ids[i + 1]), EDGE_WALK)
		waypoints.append({
			"pos": _points[path_ids[i]],
			"edge_to_next": kind,
		})
	return waypoints

func _heuristic(id: int) -> float:
	return float(_heuristics.get(id, 0.0))

func _priority_for_mode(g: float, h: float) -> float:
	match current_search_mode:
		SearchMode.UNIFORM_COST:
			return g
		SearchMode.GREEDY_BEST_FIRST:
			return h
		SearchMode.ASTAR:
			return g + h
	return g + h

func _edge_cost(from_id: int, to_id: int) -> float:
	return float(_edge_costs.get(_edge_key(from_id, to_id), 1.0))

func _calculate_path_cost(path_ids: Array) -> float:
	if path_ids.size() < 2:
		return 0.0
	var cost := 0.0
	for i in range(path_ids.size() - 1):
		cost += _edge_cost(path_ids[i], path_ids[i + 1])
	return cost

func _closest_point(pos: Vector2) -> int:
	var best_id: int = -1
	var best_dist: float = INF
	for id in _points:
		var d: float = pos.distance_to(_points[id])
		if d < best_dist:
			best_dist = d
			best_id = id
	return best_id

func _read_scene_node_positions(graph_root: Node) -> Dictionary:
	var positions := {}
	if graph_root == null:
		return positions
	_collect_scene_node_positions(graph_root, positions)
	return positions

func _collect_scene_node_positions(node: Node, positions: Dictionary) -> void:
	var graph_id_value = node.get("graph_id")
	if typeof(graph_id_value) == TYPE_INT and graph_id_value >= 0 and node is Node2D:
		positions[int(graph_id_value)] = (node as Node2D).global_position
	for child in node.get_children():
		_collect_scene_node_positions(child, positions)

func _add(id: int, pos: Vector2, heuristic: int) -> void:
	_points[id] = pos
	_heuristics[id] = heuristic
	if not (id in _neighbors):
		_neighbors[id] = []

func _connect(a: int, b: int, kind: String, cost: int, route_name: String = ROUTE_BASELINE) -> void:
	_neighbors[a].append(b)
	_edge_kinds[_edge_key(a, b)] = kind
	_edge_costs[_edge_key(a, b)] = cost
	_edge_routes[_edge_key(a, b)] = route_name
	_edge_count += 1

func _edge_key(a: int, b: int) -> String:
	return "%d-%d" % [a, b]

func _infer_route_name(path_ids: Array) -> String:
	if path_ids.size() < 2:
		return ROUTE_BASELINE

	var route_counts: Dictionary = {}
	for i in range(path_ids.size() - 1):
		var edge_route: String = _edge_routes.get(_edge_key(path_ids[i], path_ids[i + 1]), ROUTE_BASELINE)
		if edge_route == ROUTE_BASELINE:
			continue
		route_counts[edge_route] = route_counts.get(edge_route, 0) + 1

	if route_counts.is_empty():
		return ROUTE_BASELINE

	var best_route: String = ROUTE_BASELINE
	var best_count: int = -1
	for candidate_route in route_counts:
		if route_counts[candidate_route] > best_count:
			best_route = candidate_route
			best_count = route_counts[candidate_route]
	return best_route

func get_graph_nodes() -> Dictionary:
	return _points

func get_graph_heuristics() -> Dictionary:
	return _heuristics

func get_graph_edges() -> Array:
	var edges: Array = []
	for a in _neighbors:
		for b in _neighbors[a]:
			edges.append({
				"from": a,
				"to": b,
				"kind": _edge_kinds.get(_edge_key(a, b), EDGE_WALK),
				"cost": _edge_cost(a, b),
				"route": _edge_routes.get(_edge_key(a, b), ROUTE_BASELINE),
			})
	return edges
