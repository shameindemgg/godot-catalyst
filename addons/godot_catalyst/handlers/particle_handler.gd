@tool
class_name CatalystParticleHandler
extends RefCounted
## Handles particle system creation, material configuration, gradients, and presets.

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


# --- particle.create ---
func create(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var dimension: String = params.get("dimension", "2d")
	var particle_name: String = params.get("name", "")

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	var node: Node
	match dimension:
		"2d":
			var p := GPUParticles2D.new()
			p.process_material = ParticleProcessMaterial.new()
			p.emitting = false
			node = p
		"3d":
			var p := GPUParticles3D.new()
			p.process_material = ParticleProcessMaterial.new()
			p.emitting = false
			node = p
		_:
			return _error(-32003, "Invalid dimension: '%s'. Use '2d' or '3d'" % dimension)

	if not particle_name.is_empty():
		node.name = particle_name

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Create GPUParticles%s" % dimension.to_upper())
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
		"message": "Created GPUParticles%s '%s' under '%s'" % [dimension.to_upper(), node.name, parent_path],
	}


# --- particle.set_material ---
func set_material(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var properties: Dictionary = params.get("properties", {})

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	if not (node is GPUParticles2D or node is GPUParticles3D):
		return _error(-32003, "Node '%s' is not GPUParticles2D/3D (is %s)" % [node_path, node.get_class()])

	var mat: ParticleProcessMaterial = node.process_material
	if mat == null:
		mat = ParticleProcessMaterial.new()
		node.process_material = mat

	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Set particle material on '%s'" % node.name)

	var set_props := []
	for key in properties:
		var old_val: Variant = mat.get(StringName(key))
		var new_val: Variant = CatalystTypeConverter.json_to_variant(properties[key])
		ur.add_do_property(mat, key, new_val)
		ur.add_undo_property(mat, key, old_val)
		set_props.append(key)

	ur.commit_action()

	return {
		"success": true,
		"node_path": node_path,
		"properties_set": set_props,
		"message": "Set %d particle material properties on '%s'" % [set_props.size(), node.name],
	}


# --- particle.set_gradient ---
func set_gradient(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var colors: Array = params.get("colors", [])
	var offsets: Array = params.get("offsets", [])

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	if not (node is GPUParticles2D or node is GPUParticles3D):
		return _error(-32003, "Node '%s' is not GPUParticles2D/3D (is %s)" % [node_path, node.get_class()])

	if colors.size() == 0:
		return _error(-32600, "Missing or empty 'colors' array")

	var mat: ParticleProcessMaterial = node.process_material
	if mat == null:
		mat = ParticleProcessMaterial.new()
		node.process_material = mat

	var gradient := Gradient.new()
	gradient.remove_point(0)  # Remove default points
	if gradient.get_point_count() > 0:
		gradient.remove_point(0)

	for i in range(colors.size()):
		var c: Color = CatalystTypeConverter.json_to_variant(colors[i])
		var offset: float = offsets[i] if i < offsets.size() else float(i) / max(colors.size() - 1, 1)
		gradient.add_point(offset, c)

	var tex := GradientTexture1D.new()
	tex.gradient = gradient

	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Set particle color ramp on '%s'" % node.name)
	ur.add_do_property(mat, "color_ramp", tex)
	ur.add_undo_property(mat, "color_ramp", mat.color_ramp)
	ur.commit_action()

	return {
		"success": true,
		"node_path": node_path,
		"color_count": colors.size(),
		"message": "Set color ramp with %d colors on '%s'" % [colors.size(), node.name],
	}


# --- particle.apply_preset ---
func apply_preset(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var preset: String = params.get("preset", "")

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	if not (node is GPUParticles2D or node is GPUParticles3D):
		return _error(-32003, "Node '%s' is not GPUParticles2D/3D (is %s)" % [node_path, node.get_class()])

	var mat := ParticleProcessMaterial.new()
	var is_3d := node is GPUParticles3D

	match preset.to_lower():
		"fire":
			mat.direction = Vector3(0, -1, 0)
			mat.spread = 15.0
			mat.initial_velocity_min = 20.0
			mat.initial_velocity_max = 40.0
			mat.gravity = Vector3(0, -20, 0)
			mat.scale_min = 0.5
			mat.scale_max = 1.5
			node.lifetime = 1.5
			node.amount = 64
		"snow":
			mat.direction = Vector3(0, 1, 0)
			mat.spread = 30.0
			mat.initial_velocity_min = 5.0
			mat.initial_velocity_max = 15.0
			mat.gravity = Vector3(0, 30, 0)
			mat.scale_min = 0.2
			mat.scale_max = 0.6
			node.lifetime = 4.0
			node.amount = 128
		"explosion":
			mat.direction = Vector3(0, 0, 0)
			mat.spread = 180.0
			mat.initial_velocity_min = 50.0
			mat.initial_velocity_max = 150.0
			mat.gravity = Vector3(0, 98, 0)
			mat.damping_min = 5.0
			mat.damping_max = 10.0
			mat.scale_min = 0.5
			mat.scale_max = 2.0
			node.lifetime = 1.0
			node.amount = 48
			node.one_shot = true
			node.explosiveness = 1.0
		"sparks":
			mat.direction = Vector3(0, -1, 0)
			mat.spread = 45.0
			mat.initial_velocity_min = 30.0
			mat.initial_velocity_max = 80.0
			mat.gravity = Vector3(0, 98, 0)
			mat.damping_min = 2.0
			mat.damping_max = 5.0
			mat.scale_min = 0.1
			mat.scale_max = 0.3
			node.lifetime = 0.8
			node.amount = 32
		_:
			return _error(-32003, "Unknown preset: '%s'. Use 'fire', 'snow', 'explosion', or 'sparks'" % preset)

	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Apply '%s' preset to '%s'" % [preset, node.name])
	ur.add_do_property(node, "process_material", mat)
	ur.add_undo_property(node, "process_material", node.process_material)
	ur.commit_action()

	return {
		"success": true,
		"node_path": node_path,
		"preset": preset,
		"message": "Applied '%s' particle preset to '%s'" % [preset, node.name],
	}


# --- particle.get_info ---
func get_info(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	if not (node is GPUParticles2D or node is GPUParticles3D):
		return _error(-32003, "Node '%s' is not GPUParticles2D/3D (is %s)" % [node_path, node.get_class()])

	var info := {
		"node_path": node_path,
		"type": node.get_class(),
		"emitting": node.emitting,
		"amount": node.amount,
		"lifetime": node.lifetime,
		"one_shot": node.one_shot,
		"explosiveness": node.explosiveness,
		"randomness": node.randomness,
	}

	var mat: ParticleProcessMaterial = node.process_material
	if mat != null:
		info["material"] = {
			"direction": CatalystTypeConverter.variant_to_json(mat.direction),
			"spread": mat.spread,
			"initial_velocity_min": mat.initial_velocity_min,
			"initial_velocity_max": mat.initial_velocity_max,
			"gravity": CatalystTypeConverter.variant_to_json(mat.gravity),
			"scale_min": mat.scale_min,
			"scale_max": mat.scale_max,
			"damping_min": mat.damping_min,
			"damping_max": mat.damping_max,
			"has_color_ramp": mat.color_ramp != null,
		}
	else:
		info["material"] = null

	return {"success": true, "particle_info": info}


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
