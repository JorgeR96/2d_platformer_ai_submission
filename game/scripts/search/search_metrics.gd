class_name RunMetrics
extends RefCounted

var success: bool = false
var run_time_ms: int = 0
var graph_node_count: int = 0
var graph_edge_count: int = 0
var path_node_count: int = 0
var waypoints_reached: int = 0
var nodes_expanded: int = 0
var path_cost: float = 0.0
var search_mode_name: String = ""
var jump_presses: int = 0
var direction_changes: int = 0

func format_summary() -> String:
	var result_text := "success" if success else "failure"
	return "\n".join([
		"AI Run Metrics",
		"result: %s" % result_text,
		"search mode: %s" % search_mode_name,
		"runtime: %d ms" % run_time_ms,
		"graph: %d nodes / %d edges" % [graph_node_count, graph_edge_count],
		"path: %d waypoints (%d reached)" % [path_node_count, waypoints_reached],
		"path cost: %.1f" % path_cost,
		"nodes expanded: %d" % nodes_expanded,
		"actions: %d jumps, %d direction changes" % [jump_presses, direction_changes],
	])

func format_log_line() -> String:
	return "[METRICS] success=%s search_mode=%s runtime_ms=%d graph_nodes=%d graph_edges=%d path_nodes=%d waypoints_reached=%d path_cost=%.1f nodes_expanded=%d jump_presses=%d direction_changes=%d" % [
		str(success).to_lower(),
		search_mode_name,
		run_time_ms,
		graph_node_count,
		graph_edge_count,
		path_node_count,
		waypoints_reached,
		path_cost,
		nodes_expanded,
		jump_presses,
		direction_changes,
	]
