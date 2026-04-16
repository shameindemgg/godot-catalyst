@tool
class_name CatalystNetworkingHandler
extends RefCounted
## Handles networking setup: HTTPRequest, WebSocket, multiplayer, RPC, and sync nodes.

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


# --- networking.create_http_request ---
func create_http_request(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var node_name: String = params.get("name", "HTTPRequest")
	var timeout: int = params.get("timeout", 0)

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	var node := HTTPRequest.new()
	node.name = node_name
	if timeout > 0:
		node.timeout = timeout

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Add HTTPRequest '%s'" % node_name)
	ur.add_do_method(parent, "add_child", node)
	ur.add_do_method(node, "set_owner", scene_root)
	ur.add_do_reference(node)
	ur.add_undo_method(parent, "remove_child", node)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(node.get_path()),
		"name": node.name,
		"message": "HTTPRequest node created. Connect to 'request_completed' signal for response handling.",
	}


# --- networking.setup_websocket ---
func setup_websocket(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var mode: String = params.get("mode", "client")
	var node_name: String = params.get("name", "WebSocket")

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	# WebSocket in Godot 4.x is handled via WebSocketPeer — no dedicated node
	# We'll create a Node with a script that manages the WebSocketPeer
	var node := Node.new()
	node.name = node_name

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Add WebSocket '%s'" % node_name)
	ur.add_do_method(parent, "add_child", node)
	ur.add_do_method(node, "set_owner", scene_root)
	ur.add_do_reference(node)
	ur.add_undo_method(parent, "remove_child", node)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(node.get_path()),
		"name": node.name,
		"mode": mode,
		"message": "Node created for WebSocket. Attach a script using WebSocketPeer for %s functionality." % mode,
	}


# --- networking.setup_multiplayer ---
func setup_multiplayer(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var transport: String = params.get("transport", "enet")
	var mode: String = params.get("mode", "server")
	var address: String = params.get("address", "127.0.0.1")
	var port: int = params.get("port", 7000)
	var max_clients: int = params.get("max_clients", 32)

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	# Create a Node to manage multiplayer
	var node := Node.new()
	node.name = "MultiplayerManager"

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Add MultiplayerManager")
	ur.add_do_method(parent, "add_child", node)
	ur.add_do_method(node, "set_owner", scene_root)
	ur.add_do_reference(node)
	ur.add_undo_method(parent, "remove_child", node)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(node.get_path()),
		"transport": transport,
		"mode": mode,
		"address": address if mode == "client" else "0.0.0.0",
		"port": port,
		"max_clients": max_clients if mode == "server" else 0,
		"message": "MultiplayerManager created. Attach a script to set up %s%s peer on port %d." % [transport.to_upper(), " " + mode, port],
	}


# --- networking.setup_rpc ---
func setup_rpc(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var method_name: String = params.get("method_name", "")
	var rpc_mode: String = params.get("rpc_mode", "authority")
	var transfer_mode: String = params.get("transfer_mode", "reliable")
	var call_local: bool = params.get("call_local", false)
	var channel: int = params.get("channel", 0)

	if method_name.is_empty():
		return _error(-32600, "Missing 'method_name' parameter")

	return {
		"success": true,
		"node_path": node_path,
		"method_name": method_name,
		"rpc_config": {
			"rpc_mode": rpc_mode,
			"transfer_mode": transfer_mode,
			"call_local": call_local,
			"channel": channel,
		},
		"annotation": '@rpc("%s", "%s", "call_%s", %d)' % [rpc_mode, transfer_mode, "local" if call_local else "remote", channel],
		"message": "Add this annotation above your method: @rpc(\"%s\", \"%s\", \"call_%s\", %d)" % [rpc_mode, transfer_mode, "local" if call_local else "remote", channel],
	}


# --- networking.setup_sync ---
func setup_sync(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var type: String = params.get("type", "synchronizer")
	var root_path: String = params.get("root_path", "")
	var properties: Array = params.get("properties", [])
	var spawn_path: String = params.get("spawn_path", "")

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()

	if type == "synchronizer":
		var node := MultiplayerSynchronizer.new()
		node.name = "MultiplayerSynchronizer"
		if not root_path.is_empty():
			node.root_path = NodePath(root_path)

		ur.create_action("Add MultiplayerSynchronizer")
		ur.add_do_method(parent, "add_child", node)
		ur.add_do_method(node, "set_owner", scene_root)
		ur.add_do_reference(node)
		ur.add_undo_method(parent, "remove_child", node)
		ur.commit_action()

		return {
			"success": true,
			"node_path": str(node.get_path()),
			"type": "synchronizer",
			"properties": properties,
			"message": "MultiplayerSynchronizer created. Add properties to sync via the inspector's Replication panel.",
		}
	else:
		var node := MultiplayerSpawner.new()
		node.name = "MultiplayerSpawner"
		if not spawn_path.is_empty():
			node.spawn_path = NodePath(spawn_path)

		ur.create_action("Add MultiplayerSpawner")
		ur.add_do_method(parent, "add_child", node)
		ur.add_do_method(node, "set_owner", scene_root)
		ur.add_do_reference(node)
		ur.add_undo_method(parent, "remove_child", node)
		ur.commit_action()

		return {
			"success": true,
			"node_path": str(node.get_path()),
			"type": "spawner",
			"spawn_path": spawn_path,
			"message": "MultiplayerSpawner created. Add spawnable scenes in the inspector.",
		}


# --- networking.get_info ---
func get_info(params: Dictionary) -> Dictionary:
	var tree := _get_scene_root()
	if tree == null:
		return _error(-32002, "No scene root available")

	var mp := tree.get_tree().get_multiplayer()
	var info := {
		"has_multiplayer_peer": mp.multiplayer_peer != null,
		"unique_id": mp.get_unique_id() if mp.multiplayer_peer != null else 0,
		"is_server": mp.is_server() if mp.multiplayer_peer != null else false,
	}

	if mp.multiplayer_peer != null:
		info["peers"] = mp.get_peers()
		info["connection_status"] = mp.multiplayer_peer.get_connection_status()

	return {"success": true, "network_info": info}


# ---------- Helpers ----------

func _get_scene_root() -> Node:
	return EditorInterface.get_edited_scene_root()


func _get_node(path: String) -> Node:
	if path.is_empty():
		return _get_scene_root()
	var scene_root := _get_scene_root()
	if scene_root == null:
		return null
	if path.begins_with("/root/"):
		var rel := path.substr(6)
		return scene_root.get_tree().root.get_node_or_null(rel)
	elif path == "/root":
		return scene_root
	else:
		return scene_root.get_node_or_null(path)


func _error(code: int, message: String, data: Variant = null) -> Dictionary:
	var err := {"error": {"code": code, "message": message}}
	if data != null:
		err["error"]["data"] = data
	return err
