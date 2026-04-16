@tool
class_name CatalystNodeHandler
extends RefCounted
## Handles node CRUD, properties, search, groups, instancing.

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


# --- node.create ---
func create(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var node_type: String = params.get("node_type", "Node")
	var node_name: String = params.get("node_name", "")
	var properties: Dictionary = params.get("properties", {})

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	if not ClassDB.class_exists(node_type):
		return _error(-32003, "Invalid node type: '%s'" % node_type)

	var node: Node = ClassDB.instantiate(node_type)
	if node == null:
		return _error(-32003, "Cannot instantiate type: '%s'" % node_type)

	if not node_name.is_empty():
		node.name = node_name

	# Apply properties
	_apply_properties(node, properties)

	# Add via undo/redo
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Create %s '%s'" % [node_type, node.name])
	ur.add_do_method(parent, "add_child", node)
	ur.add_do_method(node, "set_owner", _get_scene_root())
	ur.add_do_reference(node)
	ur.add_undo_method(parent, "remove_child", node)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(node.get_path()),
		"name": node.name,
		"type": node_type,
		"message": "Created %s '%s' under '%s'" % [node_type, node.name, parent_path],
	}


# --- node.delete ---
func delete(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	var scene_root := _get_scene_root()
	if node == scene_root:
		return _error(-32005, "Cannot delete the scene root node")

	var parent := node.get_parent()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Delete '%s'" % node.name)
	ur.add_do_method(parent, "remove_child", node)
	ur.add_undo_method(parent, "add_child", node)
	ur.add_undo_method(node, "set_owner", scene_root)
	ur.add_undo_reference(node)
	ur.commit_action()

	return {"success": true, "message": "Deleted node '%s'" % node_path}


# --- node.rename ---
func rename(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var new_name: String = params.get("new_name", "")
	if new_name.is_empty():
		return _error(-32600, "Missing 'new_name' parameter")

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	var old_name := node.name
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Rename '%s' to '%s'" % [old_name, new_name])
	ur.add_do_property(node, "name", new_name)
	ur.add_undo_property(node, "name", old_name)
	ur.commit_action()

	return {"success": true, "old_name": old_name, "new_name": node.name, "new_path": str(node.get_path())}


# --- node.move ---
func move(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var new_parent_path: String = params.get("new_parent_path", "")
	var index: int = params.get("index", -1)

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	var new_parent := _get_node(new_parent_path)
	if new_parent == null:
		return _error(-32001, "New parent not found: '%s'" % new_parent_path)

	var old_parent := node.get_parent()
	var old_index := node.get_index()
	var scene_root := _get_scene_root()

	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Move '%s' to '%s'" % [node.name, new_parent_path])
	ur.add_do_method(old_parent, "remove_child", node)
	ur.add_do_method(new_parent, "add_child", node)
	if index >= 0:
		ur.add_do_method(new_parent, "move_child", node, index)
	ur.add_do_method(node, "set_owner", scene_root)
	ur.add_undo_method(new_parent, "remove_child", node)
	ur.add_undo_method(old_parent, "add_child", node)
	ur.add_undo_method(old_parent, "move_child", node, old_index)
	ur.add_undo_method(node, "set_owner", scene_root)
	ur.commit_action()

	return {"success": true, "new_path": str(node.get_path()), "message": "Moved '%s' to '%s'" % [node.name, new_parent_path]}


# --- node.duplicate ---
func duplicate(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var new_name: String = params.get("new_name", "")

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	var dup := node.duplicate()
	if not new_name.is_empty():
		dup.name = new_name

	var parent := node.get_parent()
	var scene_root := _get_scene_root()

	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Duplicate '%s'" % node.name)
	ur.add_do_method(parent, "add_child", dup)
	ur.add_do_method(dup, "set_owner", scene_root)
	ur.add_do_reference(dup)
	ur.add_undo_method(parent, "remove_child", dup)
	ur.commit_action()

	# Set owner recursively for children
	_set_owner_recursive(dup, scene_root)

	return {"success": true, "new_path": str(dup.get_path()), "name": dup.name, "message": "Duplicated '%s'" % node_path}


# --- node.get_properties ---
func get_properties(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var prop_names: Array = params.get("properties", [])

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	var result := {}
	if prop_names.size() > 0:
		# Return only requested properties
		for prop_name in prop_names:
			var val: Variant = node.get(StringName(str(prop_name)))
			result[str(prop_name)] = CatalystTypeConverter.variant_to_json(val)
	else:
		# Return all exported/editable properties
		for prop in node.get_property_list():
			var usage: int = prop.get("usage", 0)
			if usage & PROPERTY_USAGE_EDITOR:
				var name_str: String = prop["name"]
				result[name_str] = CatalystTypeConverter.variant_to_json(node.get(StringName(name_str)))

	return {"success": true, "node_path": node_path, "type": node.get_class(), "properties": result}


# --- node.set_properties ---
func set_properties(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var properties: Dictionary = params.get("properties", {})

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Set properties on '%s'" % node.name)

	var set_props := []
	for key in properties:
		var old_val: Variant = node.get(StringName(key))
		var new_val: Variant = CatalystTypeConverter.json_to_variant(properties[key])
		ur.add_do_property(node, key, new_val)
		ur.add_undo_property(node, key, old_val)
		set_props.append(key)

	ur.commit_action()

	return {"success": true, "node_path": node_path, "properties_set": set_props, "message": "Set %d properties on '%s'" % [set_props.size(), node.name]}


# --- node.get_tree ---
func get_tree(params: Dictionary) -> Dictionary:
	var root_path: String = params.get("root_path", "")
	var depth: int = params.get("depth", -1)

	var root: Node
	if root_path.is_empty():
		root = _get_scene_root()
	else:
		root = _get_node(root_path)

	if root == null:
		return _error(-32001, "Root node not found: '%s'" % root_path)

	var tree := CatalystNodeSerializer.serialize_tree(root, depth)
	return {"success": true, "tree": tree}


# --- node.search ---
func search(params: Dictionary) -> Dictionary:
	var name_pattern: String = params.get("name_pattern", "")
	var type_filter: String = params.get("type_filter", "")
	var group: String = params.get("group", "")

	var scene_root := _get_scene_root()
	if scene_root == null:
		return _error(-32002, "No scene is currently open")

	var matches := []
	_search_recursive(scene_root, name_pattern, type_filter, group, matches)

	return {"success": true, "matches": matches, "count": matches.size()}


# --- node.get_children ---
func get_children(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	var children := []
	for child in node.get_children():
		children.append(CatalystNodeSerializer.serialize_node(child))

	return {"success": true, "node_path": node_path, "children": children, "count": children.size()}


# --- node.reparent ---
func reparent(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var new_parent: String = params.get("new_parent", "")
	var keep_global: bool = params.get("keep_global_transform", true)

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	var parent := _get_node(new_parent)
	if parent == null:
		return _error(-32001, "New parent not found: '%s'" % new_parent)

	var old_parent := node.get_parent()
	var scene_root := _get_scene_root()

	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Reparent '%s' to '%s'" % [node.name, new_parent])
	ur.add_do_method(node, "reparent", parent, keep_global)
	ur.add_do_method(node, "set_owner", scene_root)
	ur.add_undo_method(node, "reparent", old_parent, keep_global)
	ur.add_undo_method(node, "set_owner", scene_root)
	ur.commit_action()

	return {"success": true, "new_path": str(node.get_path()), "message": "Reparented '%s' to '%s'" % [node.name, new_parent]}


# --- node.add_to_group ---
func add_to_group(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var group_name: String = params.get("group", "")

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	node.add_to_group(group_name, true)
	return {"success": true, "message": "Added '%s' to group '%s'" % [node.name, group_name]}


# --- node.remove_from_group ---
func remove_from_group(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var group_name: String = params.get("group", "")

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	node.remove_from_group(group_name)
	return {"success": true, "message": "Removed '%s' from group '%s'" % [node.name, group_name]}


# --- node.instance_scene ---
func instance_scene(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var scene_path: String = params.get("scene_path", "")
	var node_name: String = params.get("node_name", "")

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	if not FileAccess.file_exists(scene_path):
		return _error(-32004, "Scene file not found: '%s'" % scene_path)

	var packed := load(scene_path) as PackedScene
	if packed == null:
		return _error(-32008, "Failed to load scene: '%s'" % scene_path)

	var instance := packed.instantiate()
	if not node_name.is_empty():
		instance.name = node_name

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Instance '%s'" % scene_path)
	ur.add_do_method(parent, "add_child", instance)
	ur.add_do_method(instance, "set_owner", scene_root)
	ur.add_do_reference(instance)
	ur.add_undo_method(parent, "remove_child", instance)
	ur.commit_action()

	_set_owner_recursive(instance, scene_root)

	return {
		"success": true,
		"node_path": str(instance.get_path()),
		"name": instance.name,
		"scene": scene_path,
		"message": "Instanced '%s' as child of '%s'" % [scene_path, parent_path],
	}


# ---------- Helpers ----------

func _get_scene_root() -> Node:
	return EditorInterface.get_edited_scene_root()


func _get_node(path: String) -> Node:
	if path.is_empty():
		return _get_scene_root()

	var scene_root := _get_scene_root()
	if scene_root == null:
		return null

	# Support both absolute paths and relative-to-root
	if path.begins_with("/root/"):
		# Strip the /root/ prefix and find from scene tree
		var rel := path.substr(6)  # skip "/root/"
		return scene_root.get_tree().root.get_node_or_null(rel)
	elif path == "/root":
		return scene_root
	else:
		return scene_root.get_node_or_null(path)


func _apply_properties(node: Node, properties: Dictionary) -> void:
	for key in properties:
		var val: Variant = CatalystTypeConverter.json_to_variant(properties[key])
		node.set(StringName(key), val)


func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.set_owner(owner)
		_set_owner_recursive(child, owner)


func _search_recursive(node: Node, name_pattern: String, type_filter: String, group: String, results: Array) -> void:
	var matches := true

	if not name_pattern.is_empty():
		if not node.name.matchn(name_pattern):
			matches = false

	if not type_filter.is_empty():
		if not node.is_class(type_filter):
			matches = false

	if not group.is_empty():
		if not node.is_in_group(group):
			matches = false

	if matches:
		results.append(CatalystNodeSerializer.serialize_node(node))

	for child in node.get_children():
		_search_recursive(child, name_pattern, type_filter, group, results)


func _error(code: int, message: String, data: Variant = null) -> Dictionary:
	var err := {"error": {"code": code, "message": message}}
	if data != null:
		err["error"]["data"] = data
	return err
