@tool
class_name CatalystNavigationHandler
extends RefCounted
## Handles navigation regions, agents, and navigation mesh baking.

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


# --- navigation.setup_region ---
func setup_region(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var dimension: String = params.get("dimension", "2d")

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	var node: Node
	match dimension:
		"2d":
			var region := NavigationRegion2D.new()
			region.navigation_polygon = NavigationPolygon.new()
			node = region
		"3d":
			var region := NavigationRegion3D.new()
			region.navigation_mesh = NavigationMesh.new()
			node = region
		_:
			return _error(-32003, "Invalid dimension: '%s'. Use '2d' or '3d'" % dimension)

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Create NavigationRegion%s" % dimension.to_upper())
	ur.add_do_method(parent, "add_child", node)
	ur.add_do_method(node, "set_owner", scene_root)
	ur.add_do_reference(node)
	ur.add_undo_method(parent, "remove_child", node)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(node.get_path()),
		"name": node.name,
		"dimension": dimension,
		"message": "Created NavigationRegion%s under '%s'" % [dimension.to_upper(), parent_path],
	}


# --- navigation.bake ---
func bake(params: Dictionary) -> Dictionary:
	var region_path: String = params.get("region_path", "")

	var node := _get_node(region_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % region_path)

	if node is NavigationRegion2D:
		node.bake_navigation_polygon()
		return {
			"success": true,
			"node_path": region_path,
			"message": "Baked navigation polygon on '%s'" % node.name,
		}
	elif node is NavigationRegion3D:
		node.bake_navigation_mesh()
		return {
			"success": true,
			"node_path": region_path,
			"message": "Baked navigation mesh on '%s'" % node.name,
		}
	else:
		return _error(-32003, "Node '%s' is not a NavigationRegion2D/3D (is %s)" % [region_path, node.get_class()])


# --- navigation.setup_agent ---
func setup_agent(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var properties: Dictionary = params.get("properties", {})

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	if not (node is NavigationAgent2D or node is NavigationAgent3D):
		return _error(-32003, "Node '%s' is not a NavigationAgent2D/3D (is %s)" % [node_path, node.get_class()])

	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Setup NavigationAgent '%s'" % node.name)

	var set_props := []
	for key in properties:
		var old_val: Variant = node.get(StringName(key))
		var new_val: Variant = CatalystTypeConverter.json_to_variant(properties[key])
		ur.add_do_property(node, key, new_val)
		ur.add_undo_property(node, key, old_val)
		set_props.append(key)

	ur.commit_action()

	return {
		"success": true,
		"node_path": node_path,
		"properties_set": set_props,
		"message": "Set %d properties on NavigationAgent '%s'" % [set_props.size(), node.name],
	}


# --- navigation.set_layers ---
func set_layers(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var layers: int = params.get("layers", 1)

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	var prop_name := ""
	if node is NavigationRegion2D or node is NavigationRegion3D:
		prop_name = "navigation_layers"
	elif node is NavigationAgent2D or node is NavigationAgent3D:
		prop_name = "navigation_layers"
	elif node is NavigationLink2D or node is NavigationLink3D:
		prop_name = "navigation_layers"
	else:
		return _error(-32003, "Node '%s' does not have navigation layers (is %s)" % [node_path, node.get_class()])

	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Set navigation layers on '%s'" % node.name)
	ur.add_do_property(node, prop_name, layers)
	ur.add_undo_property(node, prop_name, node.get(StringName(prop_name)))
	ur.commit_action()

	return {
		"success": true,
		"node_path": node_path,
		"navigation_layers": layers,
		"message": "Set navigation layers on '%s'" % node.name,
	}


# --- navigation.get_info ---
func get_info(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	var info := {
		"node_path": node_path,
		"type": node.get_class(),
	}

	if node is NavigationRegion2D:
		info["navigation_layers"] = node.navigation_layers
		info["enabled"] = node.enabled
		info["has_polygon"] = node.navigation_polygon != null
	elif node is NavigationRegion3D:
		info["navigation_layers"] = node.navigation_layers
		info["enabled"] = node.enabled
		info["has_mesh"] = node.navigation_mesh != null
	elif node is NavigationAgent2D:
		info["navigation_layers"] = node.navigation_layers
		info["radius"] = node.radius
		info["max_speed"] = node.max_speed
		info["path_desired_distance"] = node.path_desired_distance
		info["target_desired_distance"] = node.target_desired_distance
	elif node is NavigationAgent3D:
		info["navigation_layers"] = node.navigation_layers
		info["radius"] = node.radius
		info["max_speed"] = node.max_speed
		info["path_desired_distance"] = node.path_desired_distance
		info["target_desired_distance"] = node.target_desired_distance
	else:
		info["note"] = "Node is not a navigation-related type"

	# Check for navigation children
	var nav_children := []
	for child in node.get_children():
		if child is NavigationAgent2D or child is NavigationAgent3D:
			nav_children.append({"name": child.name, "type": child.get_class()})
		elif child is NavigationRegion2D or child is NavigationRegion3D:
			nav_children.append({"name": child.name, "type": child.get_class()})
	if nav_children.size() > 0:
		info["navigation_children"] = nav_children

	return {"success": true, "navigation_info": info}


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
