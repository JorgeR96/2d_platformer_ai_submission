class_name SearchGraphOverlay
extends Node2D

const _NODE_RADIUS := 8.0
const _EDGE_WIDTH := 3.0
const _PATH_EDGE_WIDTH := 6.0
const _LABEL_FONT_SIZE := 18
const _LABEL_PADDING := Vector2(5, 3)

const _BASE_EDGE_COLOR := Color(0.18, 0.18, 0.18, 0.48)
const _NODE_COLOR := Color(0.55, 0.55, 0.55, 0.88)
const _NODE_OUTLINE_COLOR := Color(0.05, 0.05, 0.05, 0.55)
const _DECISION_EDGE_COLOR := Color(0.38, 0.38, 0.38, 0.42)
const _CURRENT_NODE_OUTLINE := Color(1.0, 1.0, 1.0, 0.92)
const _LABEL_BG_COLOR := Color(1.0, 0.96, 0.78, 0.92)
const _LABEL_BORDER_COLOR := Color(0.02, 0.02, 0.02, 0.8)
const _LABEL_TEXT_COLOR := Color(0.02, 0.02, 0.02, 1.0)

const _MODE_PATH_COLORS := {
	AIPlanner.SearchMode.UNIFORM_COST: Color(0.16, 0.82, 0.95, 1.0),
	AIPlanner.SearchMode.GREEDY_BEST_FIRST: Color(1.0, 0.38, 0.74, 1.0),
	AIPlanner.SearchMode.ASTAR: Color(1.0, 0.82, 0.2, 1.0),
}

@export var ai_controller_path: NodePath = ^"../AIController"
@export var search_graph_path: NodePath = ^"../SearchGraph"

@onready var _ai_controller: AIController = get_node_or_null(ai_controller_path) as AIController
@onready var _search_graph: Node = get_node_or_null(search_graph_path)

var _preview_planner: AIPlanner

func _ready() -> void:
	_preview_planner = AIPlanner.new()
	_preview_planner.build(_search_graph)
	visible = true
	z_index = 20

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var planner := _get_visible_planner()
	if planner == null:
		return

	var nodes := planner.get_graph_nodes()
	_draw_base_edges(planner, nodes)
	_draw_active_decision_edges(planner, nodes)
	_draw_nodes(nodes, planner.last_path_ids)
	_draw_edge_labels(planner, nodes)
	_draw_node_labels(nodes, planner.get_graph_heuristics())

func _get_visible_planner() -> AIPlanner:
	if _ai_controller != null and _ai_controller.active and _ai_controller.get_planner() != null:
		return _ai_controller.get_planner()
	return _preview_planner

func _draw_active_decision_edges(planner: AIPlanner, nodes: Dictionary) -> void:
	if _ai_controller == null or not _ai_controller.active:
		return

	var path_ids := planner.last_path_ids
	var target_path_idx := _ai_controller.get_current_waypoint_index()
	if target_path_idx <= 0 or target_path_idx >= path_ids.size():
		return

	var source_id: int = path_ids[target_path_idx - 1]
	var selected_target_id: int = path_ids[target_path_idx]
	var path_color: Color = _MODE_PATH_COLORS.get(planner.current_search_mode, Color.WHITE)
	var chosen_key := _edge_key(source_id, selected_target_id)

	for edge in planner.get_graph_edges():
		if edge["from"] != source_id:
			continue
		var edge_from_id: int = edge["from"]
		var edge_to_id: int = edge["to"]
		var edge_from_pos: Vector2 = nodes[edge_from_id]
		var edge_to_pos: Vector2 = nodes[edge_to_id]
		draw_line(edge_from_pos, edge_to_pos, _DECISION_EDGE_COLOR, _EDGE_WIDTH)
		_draw_arrow_head(edge_from_pos, edge_to_pos, _DECISION_EDGE_COLOR)

		if _edge_key(edge_from_id, edge_to_id) == chosen_key:
			var reveal_progress := _edge_reveal_progress(edge_from_pos, edge_to_pos)
			var reveal_end := edge_from_pos.lerp(edge_to_pos, reveal_progress)
			draw_line(edge_from_pos, reveal_end, path_color, _PATH_EDGE_WIDTH)
			if reveal_progress > 0.12:
				_draw_arrow_head(edge_from_pos, reveal_end, path_color)

func _draw_base_edges(planner: AIPlanner, nodes: Dictionary) -> void:
	for edge in planner.get_graph_edges():
		var edge_from_id: int = edge["from"]
		var edge_to_id: int = edge["to"]
		if not nodes.has(edge_from_id) or not nodes.has(edge_to_id):
			continue
		var edge_from_pos: Vector2 = nodes[edge_from_id]
		var edge_to_pos: Vector2 = nodes[edge_to_id]
		draw_line(edge_from_pos, edge_to_pos, _BASE_EDGE_COLOR, _EDGE_WIDTH)
		_draw_arrow_head(edge_from_pos, edge_to_pos, _BASE_EDGE_COLOR)

func _draw_nodes(nodes: Dictionary, path_ids: Array) -> void:
	var current_source_id := -1
	var current_target_id := -1
	if _ai_controller != null and _ai_controller.active:
		var target_path_idx := _ai_controller.get_current_waypoint_index()
		if target_path_idx > 0 and target_path_idx < path_ids.size():
			current_source_id = int(path_ids[target_path_idx - 1])
			current_target_id = int(path_ids[target_path_idx])

	for id in nodes:
		var pos: Vector2 = nodes[id]
		draw_circle(pos, _NODE_RADIUS + 3.0, _NODE_OUTLINE_COLOR)
		draw_circle(pos, _NODE_RADIUS, _NODE_COLOR)

		if id == current_source_id or id == current_target_id:
			draw_arc(pos, _NODE_RADIUS + 6.0, 0.0, TAU, 32, _CURRENT_NODE_OUTLINE, 3.0)

func _draw_edge_labels(planner: AIPlanner, nodes: Dictionary) -> void:
	for edge in planner.get_graph_edges():
		var edge_from_id: int = edge["from"]
		var edge_to_id: int = edge["to"]
		if not nodes.has(edge_from_id) or not nodes.has(edge_to_id):
			continue
		var edge_from_pos: Vector2 = nodes[edge_from_id]
		var edge_to_pos: Vector2 = nodes[edge_to_id]
		var label_pos := edge_from_pos.lerp(edge_to_pos, 0.5) + _edge_label_offset(edge_from_pos, edge_to_pos)
		_draw_label("c=%s" % _format_number(float(edge["cost"])), label_pos)

func _draw_node_labels(nodes: Dictionary, heuristics: Dictionary) -> void:
	for id in nodes:
		var pos: Vector2 = nodes[id] + Vector2(_NODE_RADIUS + 8.0, -_NODE_RADIUS - 18.0)
		_draw_label("h=%s" % _format_number(float(heuristics.get(id, 0.0))), pos)

func _edge_label_offset(from_pos: Vector2, to_pos: Vector2) -> Vector2:
	var edge_vector := to_pos - from_pos
	if edge_vector.length() == 0.0:
		return Vector2(10.0, -28.0)
	var offset := edge_vector.normalized().orthogonal() * 20.0
	if offset.y > 0.0:
		offset = -offset
	return offset

func _draw_label(text: String, top_left: Vector2) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _LABEL_FONT_SIZE)
	var rect := Rect2(top_left, text_size + _LABEL_PADDING * 2.0)
	draw_rect(rect.grow(1.0), _LABEL_BORDER_COLOR, true)
	draw_rect(rect, _LABEL_BG_COLOR, true)
	draw_string(font, top_left + Vector2(_LABEL_PADDING.x, _LABEL_PADDING.y + _LABEL_FONT_SIZE), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _LABEL_FONT_SIZE, _LABEL_TEXT_COLOR)

func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value

func _edge_reveal_progress(from_pos: Vector2, to_pos: Vector2) -> float:
	if _ai_controller == null or _ai_controller.player == null:
		return 0.0

	var edge_vector := to_pos - from_pos
	var edge_length_squared := edge_vector.length_squared()
	if edge_length_squared == 0.0:
		return 1.0

	var player_offset := _ai_controller.player.global_position - from_pos
	var projected_progress := player_offset.dot(edge_vector) / edge_length_squared
	return clampf(projected_progress, 0.0, 1.0)

func _draw_arrow_head(from_pos: Vector2, to_pos: Vector2, color: Color) -> void:
	var direction := to_pos - from_pos
	if direction.length() == 0.0:
		return

	var unit := direction.normalized()
	var side := unit.orthogonal()
	var tip := from_pos.lerp(to_pos, 0.72)
	var arrow_points := PackedVector2Array([
		tip,
		tip - unit * 14.0 + side * 6.0,
		tip - unit * 14.0 - side * 6.0,
	])
	draw_colored_polygon(arrow_points, color)

func _edge_key(from_id: int, to_id: int) -> String:
	return "%d-%d" % [from_id, to_id]
