extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var win_area: Area2D = $Flagpole/WinArea
@onready var kill_zone: Area2D = $KillZone
@onready var spike_strip_2: Area2D = $SpikeStrip2
@onready var overlay: CanvasLayer = $Overlay
@onready var result_label: Label = $Overlay/Center/Result
@onready var ai_controller: AIController = $AIController
@onready var metrics_label: Label = $HUD/MetricsLabel
@onready var music_player: AudioStreamPlayer = get_node_or_null("AudioStreamPlayer") as AudioStreamPlayer
@onready var search_graph_overlay: SearchGraphOverlay = $SearchGraphOverlay

var _game_over: bool = false
var _ai_mode: bool = false
var _active_search_mode: int = AIPlanner.SearchMode.UNIFORM_COST
var _last_web_run_request_id: int = 0

const _SEARCH_MODE_NAMES := [
	"Uniform Cost Search",
	"Greedy Best-First Search",
	"A* Search",
]

func _ready() -> void:
	overlay.visible = false
	metrics_label.text = ""
	_last_web_run_request_id = _read_web_run_request_id()
	_start_background_music()
	_sync_web_search_mode_selection()
	win_area.body_entered.connect(_on_win_area_body_entered)
	kill_zone.body_entered.connect(_on_kill_zone_body_entered)
	spike_strip_2.body_entered.connect(_on_kill_zone_body_entered)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("graph_overlay_toggle"):
		_toggle_graph_overlay()
	if _game_over:
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
		return
	if not _ai_mode:
		_sync_web_search_mode_selection()
		if Input.is_action_just_pressed("search_mode_cycle"):
			_cycle_search_mode()
		if Input.is_action_just_pressed("ai_toggle") or _consume_web_run_request():
			_start_ai_mode()

func _cycle_search_mode() -> void:
	_active_search_mode = (_active_search_mode + 1) % _SEARCH_MODE_NAMES.size()

func _toggle_graph_overlay() -> void:
	if search_graph_overlay == null:
		return
	search_graph_overlay.visible = not search_graph_overlay.visible

func _start_ai_mode() -> void:
	_apply_web_search_mode_override()
	_ai_mode = true
	ai_controller.start(player, win_area.global_position, _active_search_mode)
	_send_search_mode_to_web(_SEARCH_MODE_NAMES[_active_search_mode])

func _start_background_music() -> void:
	if music_player == null or music_player.stream == null:
		return
	if music_player.stream is AudioStreamMP3:
		var mp3_stream := music_player.stream as AudioStreamMP3
		mp3_stream.loop = true
	if not music_player.playing:
		music_player.play()

func _stop_background_music() -> void:
	if music_player != null and music_player.playing:
		music_player.stop()

func _apply_web_search_mode_override() -> void:
	var selected := _read_web_selected_search_mode()
	if selected == "":
		return
	_set_active_search_mode_by_name(selected)

func _sync_web_search_mode_selection() -> void:
	var selected := _read_web_selected_search_mode()
	if selected == "":
		return
	_set_active_search_mode_by_name(selected)

func _set_active_search_mode_by_name(search_mode_name: String) -> bool:
	var normalized_name := _normalize_search_mode_name(search_mode_name)
	for i in range(_SEARCH_MODE_NAMES.size()):
		if normalized_name == _SEARCH_MODE_NAMES[i]:
			_active_search_mode = i
			return true
	return false

func _normalize_search_mode_name(search_mode_name: String) -> String:
	var name := search_mode_name.strip_edges()
	match name:
		"Uniform Cost Search", "UCS":
			return "Uniform Cost Search"
		"Greedy Best-First Search", "Greedy Best First Search", "Greedy":
			return "Greedy Best-First Search"
		"A* Search", "A Star Search", "Astar", "A*":
			return "A* Search"
	return name

func _read_web_selected_search_mode() -> String:
	if not OS.has_feature("web"):
		return ""
	return str(JavaScriptBridge.eval("window.platformerAI && window.platformerAI.selectedSearchMode ? String(window.platformerAI.selectedSearchMode) : '';")).strip_edges()

func _read_web_run_request_id() -> int:
	if not OS.has_feature("web"):
		return 0
	return int(JavaScriptBridge.eval("window.platformerAI && window.platformerAI.runRequestId ? (Number(window.platformerAI.runRequestId) || 0) : 0;"))

func _consume_web_run_request() -> bool:
	var request_id := _read_web_run_request_id()
	if request_id <= _last_web_run_request_id:
		return false
	_last_web_run_request_id = request_id
	return true

func _send_search_mode_to_web(search_mode_name: String) -> void:
	if not OS.has_feature("web"):
		return
	var encoded_name := JSON.stringify(search_mode_name)
	var script := "window.platformerAI = window.platformerAI || {}; window.platformerAI.lastSearchMode = %s;" % encoded_name
	JavaScriptBridge.eval(script)

func _send_metrics_to_web(metrics: RunMetrics) -> void:
	if not OS.has_feature("web"):
		return
	# Browser table consumes this plain object through window.platformerAI.recordResult.
	var payload := {
		"searchMode": metrics.search_mode_name,
		"success": metrics.success,
		"runtimeMs": metrics.run_time_ms,
		"nodesExpanded": metrics.nodes_expanded,
		"pathLength": metrics.path_node_count,
		"pathCost": metrics.path_cost,
		"jumps": metrics.jump_presses,
	}
	var script := "window.platformerAI = window.platformerAI || {}; if (window.platformerAI.recordResult) { window.platformerAI.recordResult(%s); }" % JSON.stringify(payload)
	JavaScriptBridge.eval(script)

func _on_win_area_body_entered(body: Node2D) -> void:
	if _game_over or body != player:
		return
	var message := "AI Won!" if _ai_mode else "You Win!"
	_end_game(message, Color(0.25, 0.85, 0.35), true)

func _on_kill_zone_body_entered(body: Node2D) -> void:
	if _game_over or body != player:
		return
	var message := "AI Failed" if _ai_mode else "You Lost"
	_end_game(message, Color(0.95, 0.35, 0.35), false)

func _end_game(message: String, color: Color, success: bool) -> void:
	_game_over = true
	_stop_background_music()
	result_label.text = message
	result_label.add_theme_color_override("font_color", color)
	overlay.visible = true
	player.set_physics_process(false)
	if _ai_mode:
		ai_controller.stop()
		var metrics := ai_controller.get_metrics(success)
		metrics_label.text = metrics.format_summary()
		_send_metrics_to_web(metrics)
		print(metrics.format_log_line())
	else:
		ai_controller.stop()
