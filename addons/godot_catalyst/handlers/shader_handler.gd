@tool
class_name CatalystShaderHandler
extends RefCounted
## Handles shader creation, editing, material assignment, and shader parameters.

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


# --- shader.create ---
func create(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var shader_type: String = params.get("shader_type", "spatial")
	var code: String = params.get("code", "")

	if path.is_empty():
		return _error(-32600, "Missing 'path' parameter")

	if not path.ends_with(".gdshader"):
		path += ".gdshader"

	# Generate default code if none provided
	if code.is_empty():
		match shader_type.to_lower():
			"spatial":
				code = "shader_type spatial;\n\nvoid vertex() {\n\t// Vertex shader\n}\n\nvoid fragment() {\n\t// Fragment shader\n}\n"
			"canvas_item":
				code = "shader_type canvas_item;\n\nvoid vertex() {\n\t// Vertex shader\n}\n\nvoid fragment() {\n\t// Fragment shader\n}\n"
			"particles":
				code = "shader_type particles;\n\nvoid start() {\n\t// Start function\n}\n\nvoid process() {\n\t// Process function\n}\n"
			"sky":
				code = "shader_type sky;\n\nvoid sky() {\n\t// Sky shader\n}\n"
			_:
				return _error(-32003, "Invalid shader type: '%s'. Use 'spatial', 'canvas_item', 'particles', or 'sky'" % shader_type)

	var shader := Shader.new()
	shader.code = code

	var err := ResourceSaver.save(shader, path)
	if err != OK:
		return _error(-32008, "Failed to save shader to '%s': error %d" % [path, err])

	return {
		"success": true,
		"path": path,
		"shader_type": shader_type,
		"message": "Created %s shader at '%s'" % [shader_type, path],
	}


# --- shader.read ---
func read(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")

	if path.is_empty():
		return _error(-32600, "Missing 'path' parameter")

	if not FileAccess.file_exists(path):
		return _error(-32004, "Shader file not found: '%s'" % path)

	var shader := load(path) as Shader
	if shader == null:
		return _error(-32008, "Failed to load shader: '%s'" % path)

	return {
		"success": true,
		"path": path,
		"code": shader.code,
	}


# --- shader.edit ---
func edit(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var code: String = params.get("code", "")

	if path.is_empty():
		return _error(-32600, "Missing 'path' parameter")
	if code.is_empty():
		return _error(-32600, "Missing 'code' parameter")

	if not FileAccess.file_exists(path):
		return _error(-32004, "Shader file not found: '%s'" % path)

	var shader := load(path) as Shader
	if shader == null:
		return _error(-32008, "Failed to load shader: '%s'" % path)

	shader.code = code

	var err := ResourceSaver.save(shader, path)
	if err != OK:
		return _error(-32008, "Failed to save shader to '%s': error %d" % [path, err])

	return {
		"success": true,
		"path": path,
		"message": "Updated shader at '%s'" % path,
	}


# --- shader.assign_material ---
func assign_material(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var shader_path: String = params.get("shader_path", "")

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	if not FileAccess.file_exists(shader_path):
		return _error(-32004, "Shader file not found: '%s'" % shader_path)

	var shader := load(shader_path) as Shader
	if shader == null:
		return _error(-32008, "Failed to load shader: '%s'" % shader_path)

	var mat := ShaderMaterial.new()
	mat.shader = shader

	if not ("material" in node):
		return _error(-32003, "Node '%s' does not have a material property (is %s)" % [node_path, node.get_class()])

	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Assign ShaderMaterial to '%s'" % node.name)
	ur.add_do_property(node, "material", mat)
	ur.add_undo_property(node, "material", node.material)
	ur.commit_action()

	return {
		"success": true,
		"node_path": node_path,
		"shader_path": shader_path,
		"message": "Assigned ShaderMaterial with '%s' to '%s'" % [shader_path, node.name],
	}


# --- shader.set_param ---
func set_param(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var param_name: String = params.get("param_name", "")
	var value = params.get("value", null)

	if param_name.is_empty():
		return _error(-32600, "Missing 'param_name' parameter")

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	if not ("material" in node) or node.material == null:
		return _error(-32003, "Node '%s' has no material assigned" % node_path)

	if not (node.material is ShaderMaterial):
		return _error(-32003, "Node '%s' material is not a ShaderMaterial (is %s)" % [node_path, node.material.get_class()])

	var mat: ShaderMaterial = node.material
	var converted_value: Variant = CatalystTypeConverter.json_to_variant(value)

	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Set shader param '%s' on '%s'" % [param_name, node.name])
	ur.add_do_method(mat, "set_shader_parameter", param_name, converted_value)
	ur.add_undo_method(mat, "set_shader_parameter", param_name, mat.get_shader_parameter(param_name))
	ur.commit_action()

	return {
		"success": true,
		"node_path": node_path,
		"param_name": param_name,
		"message": "Set shader parameter '%s' on '%s'" % [param_name, node.name],
	}


# --- shader.get_params ---
func get_params(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	if not ("material" in node) or node.material == null:
		return _error(-32003, "Node '%s' has no material assigned" % node_path)

	if not (node.material is ShaderMaterial):
		return _error(-32003, "Node '%s' material is not a ShaderMaterial (is %s)" % [node_path, node.material.get_class()])

	var mat: ShaderMaterial = node.material
	var shader: Shader = mat.shader
	if shader == null:
		return _error(-32003, "ShaderMaterial on '%s' has no shader" % node_path)

	var shader_params := {}
	for param in shader.get_shader_uniform_list():
		var name_str: String = param["name"]
		var val: Variant = mat.get_shader_parameter(name_str)
		shader_params[name_str] = {
			"type": param.get("type", 0),
			"value": CatalystTypeConverter.variant_to_json(val),
		}

	return {
		"success": true,
		"node_path": node_path,
		"shader_path": shader.resource_path,
		"parameters": shader_params,
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
