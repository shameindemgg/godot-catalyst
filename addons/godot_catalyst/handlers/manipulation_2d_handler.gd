@tool
class_name Catalyst2DHandler
extends RefCounted
## Handles 2D manipulation: sprites, collisions, tilemaps, cameras, areas, parallax, lines, polygons.

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


# --- manipulation_2d.create_sprite ---
func create_sprite(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var texture_path: String = params.get("texture_path", "")
	var node_name: String = params.get("name", "Sprite2D")
	var position: Variant = params.get("position", null)

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	if not texture_path.is_empty() and not FileAccess.file_exists(texture_path):
		return _error(-32004, "Texture file not found: '%s'" % texture_path)

	var sprite := Sprite2D.new()
	sprite.name = node_name

	if not texture_path.is_empty():
		var tex := load(texture_path) as Texture2D
		if tex == null:
			return _error(-32008, "Failed to load texture: '%s'" % texture_path)
		sprite.texture = tex

	if position != null:
		sprite.position = CatalystTypeConverter.json_to_variant(position)

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Create Sprite2D '%s'" % node_name)
	ur.add_do_method(parent, "add_child", sprite)
	ur.add_do_method(sprite, "set_owner", scene_root)
	ur.add_do_reference(sprite)
	ur.add_undo_method(parent, "remove_child", sprite)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(sprite.get_path()),
		"name": sprite.name,
		"message": "Created Sprite2D '%s' under '%s'" % [node_name, parent_path],
	}


# --- manipulation_2d.setup_collision ---
func setup_collision(params: Dictionary) -> Dictionary:
	var body_path: String = params.get("body_path", "")
	var shape_type: String = params.get("shape_type", "rectangle")
	var shape_params: Dictionary = params.get("shape_params", {})

	var body := _get_node(body_path)
	if body == null:
		return _error(-32001, "Body node not found: '%s'" % body_path)

	var shape: Shape2D
	match shape_type:
		"rectangle":
			var rect := RectangleShape2D.new()
			if shape_params.has("size"):
				rect.size = CatalystTypeConverter.json_to_variant(shape_params["size"])
			shape = rect
		"circle":
			var circle := CircleShape2D.new()
			if shape_params.has("radius"):
				circle.radius = float(shape_params["radius"])
			shape = circle
		"capsule":
			var capsule := CapsuleShape2D.new()
			if shape_params.has("radius"):
				capsule.radius = float(shape_params["radius"])
			if shape_params.has("height"):
				capsule.height = float(shape_params["height"])
			shape = capsule
		_:
			return _error(-32003, "Unsupported shape type: '%s'. Use 'rectangle', 'circle', or 'capsule'" % shape_type)

	var collision := CollisionShape2D.new()
	collision.shape = shape

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Add CollisionShape2D to '%s'" % body.name)
	ur.add_do_method(body, "add_child", collision)
	ur.add_do_method(collision, "set_owner", scene_root)
	ur.add_do_reference(collision)
	ur.add_undo_method(body, "remove_child", collision)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(collision.get_path()),
		"shape_type": shape_type,
		"message": "Added CollisionShape2D (%s) to '%s'" % [shape_type, body_path],
	}


# --- manipulation_2d.create_tilemap ---
func create_tilemap(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var node_name: String = params.get("name", "TileMapLayer")
	var tile_set_path: String = params.get("tile_set_path", "")

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	var tilemap := TileMapLayer.new()
	tilemap.name = node_name

	if not tile_set_path.is_empty():
		if not FileAccess.file_exists(tile_set_path):
			return _error(-32004, "TileSet file not found: '%s'" % tile_set_path)
		var ts := load(tile_set_path) as TileSet
		if ts == null:
			return _error(-32008, "Failed to load TileSet: '%s'" % tile_set_path)
		tilemap.tile_set = ts

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Create TileMapLayer '%s'" % node_name)
	ur.add_do_method(parent, "add_child", tilemap)
	ur.add_do_method(tilemap, "set_owner", scene_root)
	ur.add_do_reference(tilemap)
	ur.add_undo_method(parent, "remove_child", tilemap)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(tilemap.get_path()),
		"name": tilemap.name,
		"message": "Created TileMapLayer '%s' under '%s'" % [node_name, parent_path],
	}


# --- manipulation_2d.setup_camera ---
func setup_camera(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var zoom: Variant = params.get("zoom", null)
	var limits: Dictionary = params.get("limits", {})
	var smoothing: Variant = params.get("smoothing", null)

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	if not node is Camera2D:
		return _error(-32003, "Node '%s' is not a Camera2D (is %s)" % [node_path, node.get_class()])

	var camera: Camera2D = node
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Configure Camera2D '%s'" % camera.name)

	if zoom != null:
		var old_zoom := camera.zoom
		var new_zoom: Vector2 = CatalystTypeConverter.json_to_variant(zoom)
		ur.add_do_property(camera, "zoom", new_zoom)
		ur.add_undo_property(camera, "zoom", old_zoom)

	if limits.has("left"):
		ur.add_do_property(camera, "limit_left", int(limits["left"]))
		ur.add_undo_property(camera, "limit_left", camera.limit_left)
	if limits.has("right"):
		ur.add_do_property(camera, "limit_right", int(limits["right"]))
		ur.add_undo_property(camera, "limit_right", camera.limit_right)
	if limits.has("top"):
		ur.add_do_property(camera, "limit_top", int(limits["top"]))
		ur.add_undo_property(camera, "limit_top", camera.limit_top)
	if limits.has("bottom"):
		ur.add_do_property(camera, "limit_bottom", int(limits["bottom"]))
		ur.add_undo_property(camera, "limit_bottom", camera.limit_bottom)

	if smoothing != null:
		var enabled: bool = bool(smoothing)
		ur.add_do_property(camera, "position_smoothing_enabled", enabled)
		ur.add_undo_property(camera, "position_smoothing_enabled", camera.position_smoothing_enabled)

	ur.commit_action()

	return {
		"success": true,
		"node_path": node_path,
		"message": "Configured Camera2D '%s'" % node_path,
	}


# --- manipulation_2d.create_area ---
func create_area(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var shape_type: String = params.get("shape_type", "rectangle")
	var shape_params: Dictionary = params.get("shape_params", {})
	var node_name: String = params.get("name", "Area2D")

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	var shape: Shape2D
	match shape_type:
		"rectangle":
			var rect := RectangleShape2D.new()
			if shape_params.has("size"):
				rect.size = CatalystTypeConverter.json_to_variant(shape_params["size"])
			shape = rect
		"circle":
			var circle := CircleShape2D.new()
			if shape_params.has("radius"):
				circle.radius = float(shape_params["radius"])
			shape = circle
		"capsule":
			var capsule := CapsuleShape2D.new()
			if shape_params.has("radius"):
				capsule.radius = float(shape_params["radius"])
			if shape_params.has("height"):
				capsule.height = float(shape_params["height"])
			shape = capsule
		_:
			return _error(-32003, "Unsupported shape type: '%s'. Use 'rectangle', 'circle', or 'capsule'" % shape_type)

	var area := Area2D.new()
	area.name = node_name

	var collision := CollisionShape2D.new()
	collision.shape = shape

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Create Area2D '%s'" % node_name)
	ur.add_do_method(parent, "add_child", area)
	ur.add_do_method(area, "set_owner", scene_root)
	ur.add_do_method(area, "add_child", collision)
	ur.add_do_method(collision, "set_owner", scene_root)
	ur.add_do_reference(area)
	ur.add_undo_method(parent, "remove_child", area)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(area.get_path()),
		"name": area.name,
		"shape_type": shape_type,
		"message": "Created Area2D '%s' with CollisionShape2D under '%s'" % [node_name, parent_path],
	}


# --- manipulation_2d.setup_parallax ---
func setup_parallax(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var layers: Array = params.get("layers", [])

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	var bg := ParallaxBackground.new()
	bg.name = "ParallaxBackground"

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Create ParallaxBackground with %d layers" % layers.size())
	ur.add_do_method(parent, "add_child", bg)
	ur.add_do_method(bg, "set_owner", scene_root)
	ur.add_do_reference(bg)

	for i in range(layers.size()):
		var layer_data: Dictionary = layers[i]
		var layer := ParallaxLayer.new()
		layer.name = "ParallaxLayer%d" % i

		if layer_data.has("motion_scale"):
			layer.motion_scale = CatalystTypeConverter.json_to_variant(layer_data["motion_scale"])
		if layer_data.has("mirroring"):
			layer.motion_mirroring = CatalystTypeConverter.json_to_variant(layer_data["mirroring"])

		ur.add_do_method(bg, "add_child", layer)
		ur.add_do_method(layer, "set_owner", scene_root)

		if layer_data.has("texture"):
			var tex_path: String = layer_data["texture"]
			if FileAccess.file_exists(tex_path):
				var tex := load(tex_path) as Texture2D
				if tex != null:
					var sprite := Sprite2D.new()
					sprite.texture = tex
					sprite.name = "Sprite2D"
					ur.add_do_method(layer, "add_child", sprite)
					ur.add_do_method(sprite, "set_owner", scene_root)

	ur.add_undo_method(parent, "remove_child", bg)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(bg.get_path()),
		"layer_count": layers.size(),
		"message": "Created ParallaxBackground with %d layers under '%s'" % [layers.size(), parent_path],
	}


# --- manipulation_2d.create_line ---
func create_line(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var points: Array = params.get("points", [])
	var width: float = float(params.get("width", 2.0))
	var color: Variant = params.get("color", null)

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	var line := Line2D.new()
	line.name = params.get("name", "Line2D")
	line.width = width

	for pt in points:
		line.add_point(CatalystTypeConverter.json_to_variant(pt))

	if color != null:
		line.default_color = CatalystTypeConverter.json_to_variant(color)

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Create Line2D '%s'" % line.name)
	ur.add_do_method(parent, "add_child", line)
	ur.add_do_method(line, "set_owner", scene_root)
	ur.add_do_reference(line)
	ur.add_undo_method(parent, "remove_child", line)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(line.get_path()),
		"name": line.name,
		"point_count": line.get_point_count(),
		"message": "Created Line2D '%s' with %d points" % [line.name, line.get_point_count()],
	}


# --- manipulation_2d.create_polygon ---
func create_polygon(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var polygon_points: Array = params.get("polygon", [])
	var color: Variant = params.get("color", null)

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	var polygon := Polygon2D.new()
	polygon.name = params.get("name", "Polygon2D")

	var packed_points := PackedVector2Array()
	for pt in polygon_points:
		packed_points.append(CatalystTypeConverter.json_to_variant(pt))
	polygon.polygon = packed_points

	if color != null:
		polygon.color = CatalystTypeConverter.json_to_variant(color)

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Create Polygon2D '%s'" % polygon.name)
	ur.add_do_method(parent, "add_child", polygon)
	ur.add_do_method(polygon, "set_owner", scene_root)
	ur.add_do_reference(polygon)
	ur.add_undo_method(parent, "remove_child", polygon)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(polygon.get_path()),
		"name": polygon.name,
		"vertex_count": packed_points.size(),
		"message": "Created Polygon2D '%s' with %d vertices" % [polygon.name, packed_points.size()],
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
