@tool
extends EditorPlugin

var _mcp_server: Node
var _tool_executor: Node
var _status_panel: Control


func _enter_tree() -> void:
	# Create the MCP WebSocket server
	_mcp_server = preload("res://addons/godot_catalyst/mcp_server.gd").new()
	_mcp_server.name = "MCPServer"
	add_child(_mcp_server)

	# Create the tool executor (dispatches JSON-RPC to handlers)
	_tool_executor = preload("res://addons/godot_catalyst/tool_executor.gd").new()
	_tool_executor.name = "ToolExecutor"
	add_child(_tool_executor)
	_tool_executor.setup(self)

	# Create the status panel
	_status_panel = preload("res://addons/godot_catalyst/status_panel.tscn").instantiate()
	add_control_to_bottom_panel(_status_panel, "Godot Catalyst")

	# Wire up: server routes requests to executor
	_mcp_server.request_received.connect(_on_request_received)
	_mcp_server.client_connected.connect(_on_client_connected)
	_mcp_server.client_disconnected.connect(_on_client_disconnected)

	# Start listening
	var port := int(ProjectSettings.get_setting("godot_catalyst/port", 6505))
	_mcp_server.start_server(port)
	print("[Godot Catalyst] Plugin loaded, WebSocket server listening on port %d" % port)


func _exit_tree() -> void:
	if _mcp_server:
		_mcp_server.stop_server()
		remove_child(_mcp_server)
		_mcp_server.queue_free()

	if _tool_executor:
		remove_child(_tool_executor)
		_tool_executor.queue_free()

	if _status_panel:
		remove_control_from_bottom_panel(_status_panel)
		_status_panel.queue_free()

	print("[Godot Catalyst] Plugin unloaded")


func _on_request_received(peer_id: int, id: String, method: String, params: Dictionary) -> void:
	# Handle ping directly
	if method == "ping":
		_mcp_server.send_response(peer_id, id, {"pong": true, "timestamp": Time.get_unix_time_from_system()})
		return

	# Dispatch to tool executor
	var result: Dictionary = _tool_executor.execute(method, params)
	if result.has("error"):
		_mcp_server.send_error(peer_id, id, result["error"]["code"], result["error"]["message"], result["error"].get("data"))
	else:
		_mcp_server.send_response(peer_id, id, result)


func _on_client_connected(peer_id: int) -> void:
	print("[Godot Catalyst] Client connected: %d" % peer_id)
	if _status_panel and _status_panel.has_method("set_connected"):
		_status_panel.set_connected(true)


func _on_client_disconnected(peer_id: int) -> void:
	print("[Godot Catalyst] Client disconnected: %d" % peer_id)
	if _status_panel and _status_panel.has_method("set_connected"):
		_status_panel.set_connected(false)
