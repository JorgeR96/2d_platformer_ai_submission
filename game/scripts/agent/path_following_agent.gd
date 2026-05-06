class_name AIController
extends Node

const ARRIVE_THRESHOLD := 16.0
const JUMP_TRIGGER_THRESHOLD := 20.0

var player: CharacterBody2D
var active: bool = false
var planner: AIPlanner
var _path: Array = []
var _idx: int = 0
var _release_jump_next: bool = false

var _start_time_us: int = 0
var _end_time_us: int = 0
var _jump_presses: int = 0
var _direction_changes: int = 0
var _last_dir: int = 0

@export var search_graph_path: NodePath = ^"../SearchGraph"

@onready var _search_graph: Node = get_node_or_null(search_graph_path)

func get_current_waypoint_index() -> int:
	return _idx

func get_planner() -> AIPlanner:
	return planner

func _ready() -> void:
	process_physics_priority = -10

func start(p: CharacterBody2D, goal_world: Vector2, search_mode: int = AIPlanner.SearchMode.UNIFORM_COST) -> void:
	player = p
	planner = AIPlanner.new()
	planner.current_search_mode = search_mode
	planner.build(_search_graph)
	# Each run owns a fresh planner so restart and search comparisons do not leak state.
	_path = planner.plan(player.global_position, goal_world)
	_idx = 1 if _path.size() > 1 else 0
	_release_jump_next = false
	_jump_presses = 0
	_direction_changes = 0
	_last_dir = 0
	_start_time_us = Time.get_ticks_usec()
	_end_time_us = 0
	active = _path.size() > 0

func stop() -> void:
	if active and _end_time_us == 0:
		_end_time_us = Time.get_ticks_usec()
	active = false
	_release_all()

func get_metrics(success: bool) -> RunMetrics:
	var m := RunMetrics.new()
	m.success = success
	var end_us: int = _end_time_us if _end_time_us > 0 else Time.get_ticks_usec()
	m.run_time_ms = int((end_us - _start_time_us) / 1000) if _start_time_us > 0 else 0
	if planner != null:
		m.graph_node_count = planner.last_graph_node_count
		m.graph_edge_count = planner.last_graph_edge_count
		m.path_node_count = planner.last_path_node_count
		m.nodes_expanded = planner.last_nodes_expanded
		m.path_cost = planner.last_path_cost
		m.search_mode_name = planner.last_search_mode_name
	m.waypoints_reached = mini(_idx, _path.size())
	m.jump_presses = _jump_presses
	m.direction_changes = _direction_changes
	return m

func _physics_process(_delta: float) -> void:
	if not active or player == null:
		return
	if _release_jump_next:
		Input.action_release("jump")
		_release_jump_next = false
	if _idx >= _path.size():
		_release_all()
		return

	var target: Dictionary = _path[_idx]
	var dx: float = target.pos.x - player.global_position.x

	var new_dir: int = _last_dir
	if dx > ARRIVE_THRESHOLD:
		Input.action_press("move_right")
		Input.action_release("move_left")
		new_dir = 1
	elif dx < -ARRIVE_THRESHOLD:
		Input.action_press("move_left")
		Input.action_release("move_right")
		new_dir = -1
	if new_dir != _last_dir:
		_direction_changes += 1
		_last_dir = new_dir

	var target_threshold := JUMP_TRIGGER_THRESHOLD if target.edge_to_next == AIPlanner.EDGE_JUMP else ARRIVE_THRESHOLD
	if abs(dx) <= target_threshold and player.is_on_floor():
		if target.edge_to_next == AIPlanner.EDGE_JUMP:
			Input.action_press("jump")
			_jump_presses += 1
			_release_jump_next = true
		_idx += 1

func _release_all() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")
	if _last_dir != 0:
		_direction_changes += 1
		_last_dir = 0
