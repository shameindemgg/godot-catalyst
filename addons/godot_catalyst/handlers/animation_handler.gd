@tool
class_name CatalystAnimationHandler
extends RefCounted
## Handles animations: AnimationPlayer CRUD, tracks, keyframes, playback, AnimationTree.

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


# --- animation.list ---
func list(params: Dictionary) -> Dictionary:
	var player_path: String = params.get("player_path", "")

	var node := _get_node(player_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % player_path)

	if not node is AnimationPlayer:
		return _error(-32003, "Node '%s' is not an AnimationPlayer (is %s)" % [player_path, node.get_class()])

	var player: AnimationPlayer = node
	var animations := []
	for anim_name in player.get_animation_list():
		var anim := player.get_animation(anim_name)
		animations.append({
			"name": anim_name,
			"length": anim.length,
			"loop_mode": anim.loop_mode,
			"track_count": anim.get_track_count(),
		})

	return {
		"success": true,
		"player_path": player_path,
		"animations": animations,
		"count": animations.size(),
	}


# --- animation.create ---
func create(params: Dictionary) -> Dictionary:
	var player_path: String = params.get("player_path", "")
	var anim_name: String = params.get("name", "")
	var length: float = float(params.get("length", 1.0))
	var loop: bool = bool(params.get("loop", false))

	if anim_name.is_empty():
		return _error(-32600, "Missing 'name' parameter")

	var node := _get_node(player_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % player_path)

	if not node is AnimationPlayer:
		return _error(-32003, "Node '%s' is not an AnimationPlayer (is %s)" % [player_path, node.get_class()])

	var player: AnimationPlayer = node
	var anim := Animation.new()
	anim.length = length
	if loop:
		anim.loop_mode = Animation.LOOP_LINEAR

	# Get or create the default AnimationLibrary
	var lib: AnimationLibrary
	if player.has_animation_library(""):
		lib = player.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		player.add_animation_library("", lib)

	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Create animation '%s'" % anim_name)
	ur.add_do_method(lib, "add_animation", anim_name, anim)
	ur.add_undo_method(lib, "remove_animation", anim_name)
	ur.commit_action()

	return {
		"success": true,
		"player_path": player_path,
		"animation_name": anim_name,
		"length": length,
		"loop": loop,
		"message": "Created animation '%s' (length: %s)" % [anim_name, length],
	}


# --- animation.delete ---
func delete(params: Dictionary) -> Dictionary:
	var player_path: String = params.get("player_path", "")
	var anim_name: String = params.get("name", "")

	if anim_name.is_empty():
		return _error(-32600, "Missing 'name' parameter")

	var node := _get_node(player_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % player_path)

	if not node is AnimationPlayer:
		return _error(-32003, "Node '%s' is not an AnimationPlayer (is %s)" % [player_path, node.get_class()])

	var player: AnimationPlayer = node
	if not player.has_animation(anim_name):
		return _error(-32001, "Animation not found: '%s'" % anim_name)

	var lib: AnimationLibrary = player.get_animation_library("")
	var anim := player.get_animation(anim_name)

	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Delete animation '%s'" % anim_name)
	ur.add_do_method(lib, "remove_animation", anim_name)
	ur.add_undo_method(lib, "add_animation", anim_name, anim)
	ur.commit_action()

	return {
		"success": true,
		"message": "Deleted animation '%s'" % anim_name,
	}


# --- animation.add_track ---
func add_track(params: Dictionary) -> Dictionary:
	var player_path: String = params.get("player_path", "")
	var anim_name: String = params.get("anim_name", "")
	var track_type: String = params.get("track_type", "value")
	var node_path: String = params.get("node_path", "")
	var property: String = params.get("property", "")

	var node := _get_node(player_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % player_path)

	if not node is AnimationPlayer:
		return _error(-32003, "Node '%s' is not an AnimationPlayer (is %s)" % [player_path, node.get_class()])

	var player: AnimationPlayer = node
	if not player.has_animation(anim_name):
		return _error(-32001, "Animation not found: '%s'" % anim_name)

	var anim := player.get_animation(anim_name)

	var type_enum: Animation.TrackType
	match track_type:
		"value":
			type_enum = Animation.TYPE_VALUE
		"method":
			type_enum = Animation.TYPE_METHOD
		"bezier":
			type_enum = Animation.TYPE_BEZIER
		"position_3d":
			type_enum = Animation.TYPE_POSITION_3D
		"rotation_3d":
			type_enum = Animation.TYPE_ROTATION_3D
		"scale_3d":
			type_enum = Animation.TYPE_SCALE_3D
		_:
			return _error(-32003, "Unsupported track type: '%s'. Use 'value', 'method', 'bezier', 'position_3d', 'rotation_3d', or 'scale_3d'" % track_type)

	var track_idx := anim.add_track(type_enum)

	# Build the track path: node_path:property
	var track_path: String = node_path
	if not property.is_empty():
		track_path = "%s:%s" % [node_path, property]
	anim.track_set_path(track_idx, NodePath(track_path))

	return {
		"success": true,
		"player_path": player_path,
		"animation_name": anim_name,
		"track_index": track_idx,
		"track_type": track_type,
		"track_path": track_path,
		"message": "Added %s track %d to '%s' targeting '%s'" % [track_type, track_idx, anim_name, track_path],
	}


# --- animation.set_keyframe ---
func set_keyframe(params: Dictionary) -> Dictionary:
	var player_path: String = params.get("player_path", "")
	var anim_name: String = params.get("anim_name", "")
	var track_idx: int = int(params.get("track_idx", 0))
	var time: float = float(params.get("time", 0.0))
	var value: Variant = params.get("value", null)

	var node := _get_node(player_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % player_path)

	if not node is AnimationPlayer:
		return _error(-32003, "Node '%s' is not an AnimationPlayer (is %s)" % [player_path, node.get_class()])

	var player: AnimationPlayer = node
	if not player.has_animation(anim_name):
		return _error(-32001, "Animation not found: '%s'" % anim_name)

	var anim := player.get_animation(anim_name)
	if track_idx < 0 or track_idx >= anim.get_track_count():
		return _error(-32003, "Track index %d out of range (0-%d)" % [track_idx, anim.get_track_count() - 1])

	var converted_value: Variant = CatalystTypeConverter.json_to_variant(value)

	var track_type := anim.track_get_type(track_idx)
	var key_idx: int
	match track_type:
		Animation.TYPE_VALUE:
			key_idx = anim.track_insert_key(track_idx, time, converted_value)
		Animation.TYPE_BEZIER:
			key_idx = anim.bezier_track_insert_key(track_idx, time, float(converted_value))
		Animation.TYPE_METHOD:
			# For method tracks, value should be a dict with method and args
			if converted_value is Dictionary:
				var method_name: String = converted_value.get("method", "")
				var args: Array = converted_value.get("args", [])
				key_idx = anim.track_insert_key(track_idx, time, {"method": method_name, "args": args})
			else:
				return _error(-32003, "Method track value must be {method: String, args: Array}")
		Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D:
			key_idx = anim.track_insert_key(track_idx, time, converted_value)
		_:
			key_idx = anim.track_insert_key(track_idx, time, converted_value)

	return {
		"success": true,
		"key_index": key_idx,
		"track_index": track_idx,
		"time": time,
		"message": "Inserted keyframe at time %s on track %d" % [time, track_idx],
	}


# --- animation.get_info ---
func get_info(params: Dictionary) -> Dictionary:
	var player_path: String = params.get("player_path", "")
	var anim_name: String = params.get("anim_name", "")

	var node := _get_node(player_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % player_path)

	if not node is AnimationPlayer:
		return _error(-32003, "Node '%s' is not an AnimationPlayer (is %s)" % [player_path, node.get_class()])

	var player: AnimationPlayer = node
	if not player.has_animation(anim_name):
		return _error(-32001, "Animation not found: '%s'" % anim_name)

	var anim := player.get_animation(anim_name)
	var tracks := []
	for i in range(anim.get_track_count()):
		var track_info := {
			"index": i,
			"type": anim.track_get_type(i),
			"path": str(anim.track_get_path(i)),
			"key_count": anim.track_get_key_count(i),
		}
		var keys := []
		for k in range(anim.track_get_key_count(i)):
			keys.append({
				"time": anim.track_get_key_time(i, k),
				"value": CatalystTypeConverter.variant_to_json(anim.track_get_key_value(i, k)),
			})
		track_info["keys"] = keys
		tracks.append(track_info)

	return {
		"success": true,
		"animation_name": anim_name,
		"length": anim.length,
		"loop_mode": anim.loop_mode,
		"step": anim.step,
		"track_count": anim.get_track_count(),
		"tracks": tracks,
	}


# --- animation.play ---
func play(params: Dictionary) -> Dictionary:
	var player_path: String = params.get("player_path", "")
	var anim_name: String = params.get("anim_name", "")

	var node := _get_node(player_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % player_path)

	if not node is AnimationPlayer:
		return _error(-32003, "Node '%s' is not an AnimationPlayer (is %s)" % [player_path, node.get_class()])

	var player: AnimationPlayer = node
	if not anim_name.is_empty() and not player.has_animation(anim_name):
		return _error(-32001, "Animation not found: '%s'" % anim_name)

	if anim_name.is_empty():
		player.play()
	else:
		player.play(anim_name)

	return {
		"success": true,
		"player_path": player_path,
		"animation_name": anim_name,
		"message": "Playing animation '%s'" % anim_name,
	}


# --- animation.stop ---
func stop(params: Dictionary) -> Dictionary:
	var player_path: String = params.get("player_path", "")

	var node := _get_node(player_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % player_path)

	if not node is AnimationPlayer:
		return _error(-32003, "Node '%s' is not an AnimationPlayer (is %s)" % [player_path, node.get_class()])

	var player: AnimationPlayer = node
	player.stop()

	return {
		"success": true,
		"player_path": player_path,
		"message": "Stopped playback on '%s'" % player_path,
	}


# --- animation.setup_tree ---
func setup_tree(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var tree_config: Dictionary = params.get("tree_config", {})

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	# If the node is an AnimationPlayer, create an AnimationTree as sibling
	# If it's a parent, create AnimationTree under it
	var parent: Node
	var anim_player_path: String = ""
	if node is AnimationPlayer:
		parent = node.get_parent()
		anim_player_path = str(node.get_path())
	else:
		parent = node
		# Try to find an AnimationPlayer child
		for child in node.get_children():
			if child is AnimationPlayer:
				anim_player_path = str(child.get_path())
				break

	var tree := AnimationTree.new()
	tree.name = tree_config.get("name", "AnimationTree")

	if not anim_player_path.is_empty():
		tree.anim_player = NodePath(anim_player_path)

	if tree_config.has("active"):
		tree.active = bool(tree_config["active"])

	# Setup root node type
	var root_type: String = tree_config.get("root_type", "state_machine")
	match root_type:
		"state_machine":
			tree.tree_root = AnimationNodeStateMachine.new()
		"blend_tree":
			tree.tree_root = AnimationNodeBlendTree.new()
		"blend_space_1d":
			tree.tree_root = AnimationNodeBlendSpace1D.new()
		"blend_space_2d":
			tree.tree_root = AnimationNodeBlendSpace2D.new()

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Create AnimationTree '%s'" % tree.name)
	ur.add_do_method(parent, "add_child", tree)
	ur.add_do_method(tree, "set_owner", scene_root)
	ur.add_do_reference(tree)
	ur.add_undo_method(parent, "remove_child", tree)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(tree.get_path()),
		"name": tree.name,
		"root_type": root_type,
		"message": "Created AnimationTree '%s' with %s root" % [tree.name, root_type],
	}


# --- animation.set_blend ---
func set_blend(params: Dictionary) -> Dictionary:
	var tree_path: String = params.get("tree_path", "")
	var parameter: String = params.get("parameter", "")
	var value: Variant = params.get("value", null)

	if parameter.is_empty():
		return _error(-32600, "Missing 'parameter' parameter")

	var node := _get_node(tree_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % tree_path)

	if not node is AnimationTree:
		return _error(-32003, "Node '%s' is not an AnimationTree (is %s)" % [tree_path, node.get_class()])

	var tree: AnimationTree = node
	var param_path := "parameters/" + parameter
	var converted_value: Variant = CatalystTypeConverter.json_to_variant(value)

	var old_value: Variant = tree.get(param_path)
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Set blend parameter '%s'" % parameter)
	ur.add_do_property(tree, param_path, converted_value)
	ur.add_undo_property(tree, param_path, old_value)
	ur.commit_action()

	return {
		"success": true,
		"tree_path": tree_path,
		"parameter": parameter,
		"message": "Set blend parameter '%s' on '%s'" % [parameter, tree_path],
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
