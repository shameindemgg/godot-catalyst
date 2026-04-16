@tool
class_name CatalystSceneHandler
extends RefCounted
## Handles scene management operations (create, open, save, close, tree, etc.)

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


# --- scene.create ---
func create(params: Dictionary) -> Dictionary:
	var root_type: String = params.get("root_type", "Node2D")
	var scene_name: String = params.get("scene_name", "NewScene")
	var save_path: String = params.get("save_path", "")

	if save_path.is_empty():
		save_path = "res://scenes/%s.tscn" % scene_name

	# Ensure directory exists
	var dir_path := save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	# Create root node
	var root: Node = ClassDB.instantiate(root_type)
	if root == null:
		return _error(-32003, "Invalid node type: '%s'" % root_type)
	root.name = scene_name

	# Pack and save
	var scene := PackedScene.new()
	var err := scene.pack(root)
	root.free()
	if err != OK:
		return _error(-32008, "Failed to pack scene: %s" % error_string(err))

	err = ResourceSaver.save(scene, save_path)
	if err != OK:
		return _error(-32008, "Failed to save scene to '%s': %s" % [save_path, error_string(err)])

	# Open it in the editor
	EditorInterface.open_scene_from_path(save_path)

	return {"success": true, "path": save_path, "message": "Created scene '%s' with root %s" % [scene_name, root_type]}


# --- scene.open ---
func open(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(-32600, "Missing 'path' parameter")

	if not FileAccess.file_exists(path):
		return _error(-32004, "Scene file not found: '%s'" % path)

	EditorInterface.open_scene_from_path(path)
	return {"success": true, "path": path, "message": "Opened scene '%s'" % path}


# --- scene.save ---
func save(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var err: Error

	if path.is_empty():
		err = EditorInterface.save_scene()
	else:
		EditorInterface.save_scene_as(path)
		err = OK

	if err != OK:
		return _error(-32008, "Failed to save scene: %s" % error_string(err))

	return {"success": true, "message": "Scene saved"}


# --- scene.save_as ---
func save_as(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(-32600, "Missing 'path' parameter")

	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	EditorInterface.save_scene_as(path)
	var err: Error = OK
	if err != OK:
		return _error(-32008, "Failed to save scene as '%s': %s" % [path, error_string(err)])

	return {"success": true, "path": path, "message": "Scene saved as '%s'" % path}


# --- scene.close ---
func close(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")

	# Find and close the scene tab matching this path
	var open_scenes := EditorInterface.get_open_scenes()
	if path.is_empty():
		# Close current
		# There's no direct close API; we can save and the user closes, or we use a workaround
		return _error(-32005, "Closing specific scenes requires 'path' parameter. Use the editor to close scenes manually.")

	if path not in open_scenes:
		return _error(-32002, "Scene '%s' is not currently open" % path)

	# Godot doesn't have a direct "close scene by path" API in EditorInterface.
	# Workaround: we note it's a limitation.
	return _error(-32005, "Direct scene closing is not supported by the Godot EditorInterface API. Please close the scene tab manually in the editor.")


# --- scene.get_tree ---
func get_tree(params: Dictionary) -> Dictionary:
	var depth: int = params.get("depth", -1)
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _error(-32002, "No scene is currently open")

	var tree := CatalystNodeSerializer.serialize_tree(root, depth)
	return {"success": true, "scene_path": root.scene_file_path, "tree": tree}


# --- scene.list_open ---
func list_open(_params: Dictionary) -> Dictionary:
	var scenes := EditorInterface.get_open_scenes()
	var current_root := EditorInterface.get_edited_scene_root()
	var current_path := current_root.scene_file_path if current_root else ""

	return {
		"success": true,
		"scenes": scenes,
		"current": current_path,
		"count": scenes.size(),
	}


# --- scene.duplicate ---
func duplicate(params: Dictionary) -> Dictionary:
	var source_path: String = params.get("source_path", "")
	var dest_path: String = params.get("dest_path", "")

	if source_path.is_empty() or dest_path.is_empty():
		return _error(-32600, "Missing 'source_path' or 'dest_path' parameter")

	if not FileAccess.file_exists(source_path):
		return _error(-32004, "Source scene not found: '%s'" % source_path)

	var dir_path := dest_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var err := DirAccess.copy_absolute(source_path, dest_path)
	if err != OK:
		return _error(-32008, "Failed to copy scene: %s" % error_string(err))

	return {"success": true, "source": source_path, "destination": dest_path, "message": "Scene duplicated"}


# --- scene.get_current ---
func get_current(_params: Dictionary) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _error(-32002, "No scene is currently open")

	return {
		"success": true,
		"path": root.scene_file_path,
		"root_name": root.name,
		"root_type": root.get_class(),
	}


# --- scene.set_current ---
func set_current(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(-32600, "Missing 'path' parameter")

	var open_scenes := EditorInterface.get_open_scenes()
	if path not in open_scenes:
		return _error(-32002, "Scene '%s' is not open. Open it first with scene.open" % path)

	# Open the scene (switches to it if already open)
	EditorInterface.open_scene_from_path(path)
	return {"success": true, "path": path, "message": "Switched to scene '%s'" % path}


# --- scene.reload ---
func reload(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		var root := EditorInterface.get_edited_scene_root()
		if root:
			path = root.scene_file_path

	if path.is_empty():
		return _error(-32002, "No scene to reload")

	EditorInterface.reload_scene_from_path(path)
	return {"success": true, "path": path, "message": "Reloaded scene '%s'" % path}


# --- scene.create_inherited ---
func create_inherited(params: Dictionary) -> Dictionary:
	var base_path: String = params.get("base_path", "")
	var save_path: String = params.get("save_path", "")

	if base_path.is_empty() or save_path.is_empty():
		return _error(-32600, "Missing 'base_path' or 'save_path' parameter")

	if not FileAccess.file_exists(base_path):
		return _error(-32004, "Base scene not found: '%s'" % base_path)

	# Load base scene and instance it
	var base_scene := load(base_path) as PackedScene
	if base_scene == null:
		return _error(-32008, "Failed to load base scene: '%s'" % base_path)

	var instance := base_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	if instance == null:
		return _error(-32008, "Failed to instantiate base scene")

	# Pack as inherited scene
	var inherited := PackedScene.new()
	var err := inherited.pack(instance)
	instance.free()
	if err != OK:
		return _error(-32008, "Failed to pack inherited scene: %s" % error_string(err))

	var dir_path := save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	err = ResourceSaver.save(inherited, save_path)
	if err != OK:
		return _error(-32008, "Failed to save inherited scene: %s" % error_string(err))

	EditorInterface.open_scene_from_path(save_path)
	return {"success": true, "base": base_path, "path": save_path, "message": "Created inherited scene from '%s'" % base_path}


func _error(code: int, message: String, data: Variant = null) -> Dictionary:
	var err := {"error": {"code": code, "message": message}}
	if data != null:
		err["error"]["data"] = data
	return err
