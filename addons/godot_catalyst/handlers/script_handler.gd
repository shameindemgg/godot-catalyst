@tool
class_name CatalystScriptHandler
extends RefCounted

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


func create(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var content: String = params.get("content", "")
	var template: String = params.get("template", "")
	var cls_name: String = params.get("class_name", "")

	if path.is_empty():
		return _error(-32600, "Missing 'path' parameter")

	if content.is_empty() and template.is_empty():
		content = "extends Node\n\n\nfunc _ready() -> void:\n\tpass\n"

	if not template.is_empty():
		content = _get_template(template, cls_name)

	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _error(-32008, "Cannot write to '%s': %s" % [path, error_string(FileAccess.get_open_error())])
	file.store_string(content)
	file.close()

	EditorInterface.get_resource_filesystem().scan()
	return {"success": true, "path": path, "message": "Created script '%s'" % path}


func read(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(-32600, "Missing 'path' parameter")

	if not FileAccess.file_exists(path):
		return _error(-32004, "Script not found: '%s'" % path)

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error(-32004, "Cannot read '%s'" % path)
	var content := file.get_as_text()
	file.close()

	return {"success": true, "path": path, "content": content, "length": content.length()}


func update(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var content: String = params.get("content", "")

	if path.is_empty():
		return _error(-32600, "Missing 'path' parameter")

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _error(-32008, "Cannot write to '%s'" % path)
	file.store_string(content)
	file.close()

	EditorInterface.get_resource_filesystem().scan()
	return {"success": true, "path": path, "message": "Updated script '%s'" % path}


func delete(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(-32600, "Missing 'path' parameter")

	if not FileAccess.file_exists(path):
		return _error(-32004, "Script not found: '%s'" % path)

	var err := DirAccess.remove_absolute(path)
	if err != OK:
		return _error(-32008, "Failed to delete '%s': %s" % [path, error_string(err)])

	EditorInterface.get_resource_filesystem().scan()
	return {"success": true, "path": path, "message": "Deleted script '%s'" % path}


func attach(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var script_path: String = params.get("script_path", "")

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	if not FileAccess.file_exists(script_path):
		return _error(-32004, "Script not found: '%s'" % script_path)

	var script := load(script_path) as Script
	if script == null:
		return _error(-32008, "Failed to load script: '%s'" % script_path)

	var ur := EditorInterface.get_editor_undo_redo()
	var old_script := node.get_script()
	ur.create_action("Attach script to '%s'" % node.name)
	ur.add_do_method(node, "set_script", script)
	ur.add_undo_method(node, "set_script", old_script)
	ur.commit_action()

	return {"success": true, "node": node_path, "script": script_path, "message": "Attached '%s' to '%s'" % [script_path, node.name]}


func detach(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	var old_script := node.get_script()
	if old_script == null:
		return _error(-32005, "Node '%s' has no script attached" % node_path)

	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Detach script from '%s'" % node.name)
	ur.add_do_method(node, "set_script", null)
	ur.add_undo_method(node, "set_script", old_script)
	ur.commit_action()

	return {"success": true, "node": node_path, "message": "Detached script from '%s'" % node.name}


func get_errors(_params: Dictionary) -> Dictionary:
	# EditorInterface doesn't expose script errors directly;
	# we read from the Script Editor's error list if available
	var script_editor := EditorInterface.get_script_editor()
	if script_editor == null:
		return {"success": true, "errors": [], "message": "Script editor not available"}

	# Currently no direct API to get errors; return empty
	return {"success": true, "errors": [], "message": "Use the Godot LSP for diagnostics"}


func open_in_editor(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var line: int = params.get("line", 0)
	var column: int = params.get("column", 0)

	if path.is_empty():
		return _error(-32600, "Missing 'path' parameter")

	var script := load(path) as Script
	if script == null:
		return _error(-32004, "Cannot load script: '%s'" % path)

	EditorInterface.edit_script(script, line, column)
	EditorInterface.set_main_screen_editor("Script")

	return {"success": true, "path": path, "line": line, "message": "Opened '%s' in script editor" % path}


func execute_snippet(params: Dictionary) -> Dictionary:
	var code: String = params.get("code", "")
	if code.is_empty():
		return _error(-32600, "Missing 'code' parameter")

	# Create a temporary EditorScript, write it, execute, and clean up
	var tmp_path := "res://.tmp_catalyst_snippet.gd"
	var full_code := "@tool\nextends EditorScript\n\nfunc _run() -> void:\n"
	for line in code.split("\n"):
		full_code += "\t" + line + "\n"

	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return _error(-32008, "Cannot create temp script")
	file.store_string(full_code)
	file.close()

	# We can't easily capture output from EditorScript._run()
	# Instead, return success and note the limitation
	return {"success": true, "message": "Snippet written to temp file. Use File > Run (Ctrl+Shift+X) in the Script Editor to execute, or use the LSP for evaluation."}


func search_in_scripts(params: Dictionary) -> Dictionary:
	var pattern: String = params.get("pattern", "")
	var search_path: String = params.get("path", "res://")

	if pattern.is_empty():
		return _error(-32600, "Missing 'pattern' parameter")

	var results := []
	_search_scripts_recursive(search_path, pattern, results)

	return {"success": true, "pattern": pattern, "matches": results, "count": results.size()}


# --- Helpers ---

func _get_node(path: String) -> Node:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return null
	if path.is_empty():
		return root
	if path.begins_with("/root/"):
		return root.get_tree().root.get_node_or_null(path.substr(6))
	return root.get_node_or_null(path)


func _get_template(template_name: String, cls_name: String) -> String:
	var base := "extends %s\n" % template_name
	if not cls_name.is_empty():
		base = "class_name %s\n%s" % [cls_name, base]
	base += "\n\nfunc _ready() -> void:\n\tpass\n"
	return base


func _search_scripts_recursive(dir_path: String, pattern: String, results: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := dir_path.path_join(file_name)
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_search_scripts_recursive(full_path, pattern, results)
		elif file_name.ends_with(".gd"):
			var file := FileAccess.open(full_path, FileAccess.READ)
			if file:
				var content := file.get_as_text()
				file.close()
				var line_num := 0
				for line in content.split("\n"):
					line_num += 1
					if line.containsn(pattern):
						results.append({"file": full_path, "line": line_num, "text": line.strip_edges()})
		file_name = dir.get_next()
	dir.list_dir_end()


func _error(code: int, message: String, data: Variant = null) -> Dictionary:
	var err := {"error": {"code": code, "message": message}}
	if data != null:
		err["error"]["data"] = data
	return err
