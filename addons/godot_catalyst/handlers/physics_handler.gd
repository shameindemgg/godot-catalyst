@tool
class_name CatalystPhysicsHandler
extends RefCounted
## Handles physics body setup, collision shapes, layers, and raycasts.

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


# --- physics.setup_body ---
func setup_body(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var properties: Dictionary = params.get("properties", {})

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	if not (node is PhysicsBody2D or node is PhysicsBody3D):
		return _error(-32003, "Node '%s' is not a PhysicsBody2D/3D (is %s)" % [node_path, node.get_class()])

	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Setup physics body '%s'" % node.name)

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
		"message": "Set %d physics properties on '%s'" % [set_props.size(), node.name],
	}


# --- physics.setup_collision ---
func setup_collision(params: Dictionary) -> Dictionary:
	var body_path: String = params.get("body_path", "")
	var shape_type: String = params.get("shape_type", "")
	var shape_params: Dictionary = params.get("shape_params", {})
	var is_3d: bool = params.get("is_3d", false)

	var body := _get_node(body_path)
	if body == null:
		return _error(-32001, "Body node not found: '%s'" % body_path)

	var shape: Shape2D = null
	var shape_3d: Shape3D = null

	if is_3d:
		match shape_type.to_lower():
			"box":
				var s := BoxShape3D.new()
				if shape_params.has("size"):
					s.size = CatalystTypeConverter.json_to_variant(shape_params["size"])
				shape_3d = s
			"sphere":
				var s := SphereShape3D.new()
				if shape_params.has("radius"):
					s.radius = float(shape_params["radius"])
				shape_3d = s
			"capsule":
				var s := CapsuleShape3D.new()
				if shape_params.has("radius"):
					s.radius = float(shape_params["radius"])
				if shape_params.has("height"):
					s.height = float(shape_params["height"])
				shape_3d = s
			"cylinder":
				var s := CylinderShape3D.new()
				if shape_params.has("radius"):
					s.radius = float(shape_params["radius"])
				if shape_params.has("height"):
					s.height = float(shape_params["height"])
				shape_3d = s
			"convex":
				shape_3d = ConvexPolygonShape3D.new()
			"concave":
				shape_3d = ConcavePolygonShape3D.new()
			_:
				return _error(-32003, "Unknown 3D shape type: '%s'" % shape_type)
	else:
		match shape_type.to_lower():
			"rectangle":
				var s := RectangleShape2D.new()
				if shape_params.has("size"):
					s.size = CatalystTypeConverter.json_to_variant(shape_params["size"])
				shape = s
			"circle":
				var s := CircleShape2D.new()
				if shape_params.has("radius"):
					s.radius = float(shape_params["radius"])
				shape = s
			"capsule":
				var s := CapsuleShape2D.new()
				if shape_params.has("radius"):
					s.radius = float(shape_params["radius"])
				if shape_params.has("height"):
					s.height = float(shape_params["height"])
				shape = s
			"segment":
				var s := SegmentShape2D.new()
				if shape_params.has("a"):
					s.a = CatalystTypeConverter.json_to_variant(shape_params["a"])
				if shape_params.has("b"):
					s.b = CatalystTypeConverter.json_to_variant(shape_params["b"])
				shape = s
			"convex":
				shape = ConvexPolygonShape2D.new()
			"concave":
				shape = ConcavePolygonShape2D.new()
			_:
				return _error(-32003, "Unknown 2D shape type: '%s'" % shape_type)

	var collision_node: Node
	if is_3d:
		var col := CollisionShape3D.new()
		col.shape = shape_3d
		collision_node = col
	else:
		var col := CollisionShape2D.new()
		col.shape = shape
		collision_node = col

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Add CollisionShape to '%s'" % body.name)
	ur.add_do_method(body, "add_child", collision_node)
	ur.add_do_method(collision_node, "set_owner", scene_root)
	ur.add_do_reference(collision_node)
	ur.add_undo_method(body, "remove_child", collision_node)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(collision_node.get_path()),
		"name": collision_node.name,
		"shape_type": shape_type,
		"is_3d": is_3d,
		"message": "Added %s collision shape to '%s'" % [shape_type, body.name],
	}


# --- physics.set_layers ---
func set_layers(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var layer = params.get("layer", null)
	var mask = params.get("mask", null)

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	if not ("collision_layer" in node) or not ("collision_mask" in node):
		return _error(-32003, "Node '%s' does not have collision layers (is %s)" % [node_path, node.get_class()])

	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Set collision layers on '%s'" % node.name)

	var changed := []
	if layer != null:
		ur.add_do_property(node, "collision_layer", int(layer))
		ur.add_undo_property(node, "collision_layer", node.collision_layer)
		changed.append("collision_layer")

	if mask != null:
		ur.add_do_property(node, "collision_mask", int(mask))
		ur.add_undo_property(node, "collision_mask", node.collision_mask)
		changed.append("collision_mask")

	ur.commit_action()

	return {
		"success": true,
		"node_path": node_path,
		"properties_set": changed,
		"message": "Set collision layers on '%s'" % node.name,
	}


# --- physics.get_layers ---
func get_layers(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	if not ("collision_layer" in node) or not ("collision_mask" in node):
		return _error(-32003, "Node '%s' does not have collision layers (is %s)" % [node_path, node.get_class()])

	return {
		"success": true,
		"node_path": node_path,
		"collision_layer": node.collision_layer,
		"collision_mask": node.collision_mask,
	}


# --- physics.add_raycast ---
func add_raycast(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var target_position = params.get("target_position", null)
	var raycast_name: String = params.get("name", "")
	var is_3d: bool = params.get("is_3d", false)

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	var node: Node
	if is_3d:
		var rc := RayCast3D.new()
		if target_position != null:
			rc.target_position = CatalystTypeConverter.json_to_variant(target_position)
		node = rc
	else:
		var rc := RayCast2D.new()
		if target_position != null:
			rc.target_position = CatalystTypeConverter.json_to_variant(target_position)
		node = rc

	if not raycast_name.is_empty():
		node.name = raycast_name

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Add RayCast to '%s'" % parent.name)
	ur.add_do_method(parent, "add_child", node)
	ur.add_do_method(node, "set_owner", scene_root)
	ur.add_do_reference(node)
	ur.add_undo_method(parent, "remove_child", node)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(node.get_path()),
		"name": node.name,
		"is_3d": is_3d,
		"message": "Added RayCast to '%s'" % parent.name,
	}


# --- physics.get_collision_info ---
func get_collision_info(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	var info := {
		"node_path": node_path,
		"type": node.get_class(),
	}

	if "collision_layer" in node:
		info["collision_layer"] = node.collision_layer
	if "collision_mask" in node:
		info["collision_mask"] = node.collision_mask

	# Gather collision shapes
	var shapes := []
	for child in node.get_children():
		if child is CollisionShape2D:
			var shape_info := {"name": child.name, "type": "CollisionShape2D", "disabled": child.disabled}
			if child.shape != null:
				shape_info["shape_type"] = child.shape.get_class()
			shapes.append(shape_info)
		elif child is CollisionShape3D:
			var shape_info := {"name": child.name, "type": "CollisionShape3D", "disabled": child.disabled}
			if child.shape != null:
				shape_info["shape_type"] = child.shape.get_class()
			shapes.append(shape_info)
		elif child is CollisionPolygon2D:
			shapes.append({"name": child.name, "type": "CollisionPolygon2D"})
		elif child is CollisionPolygon3D:
			shapes.append({"name": child.name, "type": "CollisionPolygon3D"})
	info["collision_shapes"] = shapes

	# Physics body specific properties
	if node is RigidBody2D or node is RigidBody3D:
		info["mass"] = node.mass
		info["gravity_scale"] = node.gravity_scale
	if node is CharacterBody2D or node is CharacterBody3D:
		info["velocity"] = CatalystTypeConverter.variant_to_json(node.velocity)

	return {"success": true, "collision_info": info}


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
