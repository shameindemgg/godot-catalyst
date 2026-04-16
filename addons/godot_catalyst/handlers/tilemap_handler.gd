@tool
class_name CatalystTileMapHandler
extends RefCounted
## Handles TileMap cell operations, fill, clear, and info queries.

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


# --- tilemap.set_cell ---
func set_cell(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var coords: Array = params.get("coords", [])
	var source_id: int = params.get("source_id", 0)
	var atlas_coords: Array = params.get("atlas_coords", [0, 0])
	var layer: int = params.get("layer", 0)

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	if not (node is TileMapLayer):
		# Support TileMap (deprecated) or TileMapLayer
		if node is TileMap:
			return _set_cell_tilemap(node, coords, source_id, atlas_coords, layer)
		return _error(-32003, "Node '%s' is not a TileMapLayer or TileMap (is %s)" % [node_path, node.get_class()])

	if coords.size() < 2:
		return _error(-32600, "Invalid 'coords': expected [x, y] array")

	var cell_pos := Vector2i(int(coords[0]), int(coords[1]))
	var atlas := Vector2i(int(atlas_coords[0]), int(atlas_coords[1]))

	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Set tile at (%d, %d)" % [cell_pos.x, cell_pos.y])
	ur.add_do_method(node, "set_cell", cell_pos, source_id, atlas)
	ur.add_undo_method(node, "set_cell", cell_pos, node.get_cell_source_id(cell_pos), node.get_cell_atlas_coords(cell_pos))
	ur.commit_action()

	return {
		"success": true,
		"node_path": node_path,
		"coords": [cell_pos.x, cell_pos.y],
		"source_id": source_id,
		"atlas_coords": [atlas.x, atlas.y],
		"message": "Set tile at (%d, %d) on '%s'" % [cell_pos.x, cell_pos.y, node.name],
	}


# --- tilemap.fill_rect ---
func fill_rect(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var rect: Array = params.get("rect", [])
	var source_id: int = params.get("source_id", 0)
	var atlas_coords: Array = params.get("atlas_coords", [0, 0])
	var layer: int = params.get("layer", 0)

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	if rect.size() < 4:
		return _error(-32600, "Invalid 'rect': expected [x, y, w, h] array")

	var rx: int = int(rect[0])
	var ry: int = int(rect[1])
	var rw: int = int(rect[2])
	var rh: int = int(rect[3])
	var atlas := Vector2i(int(atlas_coords[0]), int(atlas_coords[1]))

	if node is TileMapLayer:
		var ur := EditorInterface.get_editor_undo_redo()
		ur.create_action("Fill tiles rect (%d,%d,%d,%d)" % [rx, ry, rw, rh])

		for x in range(rx, rx + rw):
			for y in range(ry, ry + rh):
				var pos := Vector2i(x, y)
				ur.add_do_method(node, "set_cell", pos, source_id, atlas)
				ur.add_undo_method(node, "set_cell", pos, node.get_cell_source_id(pos), node.get_cell_atlas_coords(pos))

		ur.commit_action()
	elif node is TileMap:
		var ur := EditorInterface.get_editor_undo_redo()
		ur.create_action("Fill tiles rect (%d,%d,%d,%d)" % [rx, ry, rw, rh])

		for x in range(rx, rx + rw):
			for y in range(ry, ry + rh):
				var pos := Vector2i(x, y)
				ur.add_do_method(node, "set_cell", layer, pos, source_id, atlas)
				ur.add_undo_method(node, "set_cell", layer, pos, node.get_cell_source_id(layer, pos), node.get_cell_atlas_coords(layer, pos))

		ur.commit_action()
	else:
		return _error(-32003, "Node '%s' is not a TileMapLayer or TileMap (is %s)" % [node_path, node.get_class()])

	var count := rw * rh
	return {
		"success": true,
		"node_path": node_path,
		"rect": [rx, ry, rw, rh],
		"tiles_set": count,
		"message": "Filled %d tiles in rect (%d,%d,%d,%d) on '%s'" % [count, rx, ry, rw, rh, node.name],
	}


# --- tilemap.get_cell ---
func get_cell(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var coords: Array = params.get("coords", [])
	var layer: int = params.get("layer", 0)

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	if coords.size() < 2:
		return _error(-32600, "Invalid 'coords': expected [x, y] array")

	var cell_pos := Vector2i(int(coords[0]), int(coords[1]))

	if node is TileMapLayer:
		var src: int = node.get_cell_source_id(cell_pos)
		var atlas: Vector2i = node.get_cell_atlas_coords(cell_pos)
		var alt: int = node.get_cell_alternative_tile(cell_pos)
		return {
			"success": true,
			"node_path": node_path,
			"coords": [cell_pos.x, cell_pos.y],
			"source_id": src,
			"atlas_coords": [atlas.x, atlas.y],
			"alternative_tile": alt,
			"is_empty": src == -1,
		}
	elif node is TileMap:
		var src: int = node.get_cell_source_id(layer, cell_pos)
		var atlas: Vector2i = node.get_cell_atlas_coords(layer, cell_pos)
		var alt: int = node.get_cell_alternative_tile(layer, cell_pos)
		return {
			"success": true,
			"node_path": node_path,
			"coords": [cell_pos.x, cell_pos.y],
			"layer": layer,
			"source_id": src,
			"atlas_coords": [atlas.x, atlas.y],
			"alternative_tile": alt,
			"is_empty": src == -1,
		}
	else:
		return _error(-32003, "Node '%s' is not a TileMapLayer or TileMap (is %s)" % [node_path, node.get_class()])


# --- tilemap.clear ---
func clear(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var layer: int = params.get("layer", 0)

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	if node is TileMapLayer:
		var ur := EditorInterface.get_editor_undo_redo()
		ur.create_action("Clear TileMapLayer '%s'" % node.name)
		# Store current cells for undo
		var used: Array = node.get_used_cells()
		for pos in used:
			ur.add_undo_method(node, "set_cell", pos, node.get_cell_source_id(pos), node.get_cell_atlas_coords(pos))
		ur.add_do_method(node, "clear")
		ur.commit_action()

		return {
			"success": true,
			"node_path": node_path,
			"cleared_count": used.size(),
			"message": "Cleared %d tiles from '%s'" % [used.size(), node.name],
		}
	elif node is TileMap:
		var ur := EditorInterface.get_editor_undo_redo()
		ur.create_action("Clear TileMap layer %d on '%s'" % [layer, node.name])
		var used: Array = node.get_used_cells(layer)
		for pos in used:
			ur.add_undo_method(node, "set_cell", layer, pos, node.get_cell_source_id(layer, pos), node.get_cell_atlas_coords(layer, pos))
		ur.add_do_method(node, "clear_layer", layer)
		ur.commit_action()

		return {
			"success": true,
			"node_path": node_path,
			"layer": layer,
			"cleared_count": used.size(),
			"message": "Cleared %d tiles from layer %d on '%s'" % [used.size(), layer, node.name],
		}
	else:
		return _error(-32003, "Node '%s' is not a TileMapLayer or TileMap (is %s)" % [node_path, node.get_class()])


# --- tilemap.get_info ---
func get_info(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	if node is TileMapLayer:
		var used: Array = node.get_used_cells()
		var info := {
			"node_path": node_path,
			"type": "TileMapLayer",
			"name": node.name,
			"used_cells_count": used.size(),
			"tile_set": node.tile_set != null,
			"enabled": node.enabled,
		}
		if node.tile_set != null:
			info["tile_set_sources"] = node.tile_set.get_source_count()
		return {"success": true, "tilemap_info": info}

	elif node is TileMap:
		var layer_count: int = node.get_layers_count()
		var layers := []
		for i in range(layer_count):
			var used: Array = node.get_used_cells(i)
			layers.append({
				"index": i,
				"name": node.get_layer_name(i),
				"used_cells_count": used.size(),
				"enabled": node.is_layer_enabled(i),
			})
		var info := {
			"node_path": node_path,
			"type": "TileMap",
			"name": node.name,
			"layer_count": layer_count,
			"layers": layers,
			"tile_set": node.tile_set != null,
		}
		if node.tile_set != null:
			info["tile_set_sources"] = node.tile_set.get_source_count()
		return {"success": true, "tilemap_info": info}

	else:
		return _error(-32003, "Node '%s' is not a TileMapLayer or TileMap (is %s)" % [node_path, node.get_class()])


# --- tilemap.get_used_cells ---
func get_used_cells(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var layer: int = params.get("layer", 0)

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	var cells := []

	if node is TileMapLayer:
		var used: Array = node.get_used_cells()
		for pos in used:
			cells.append({
				"coords": [pos.x, pos.y],
				"source_id": node.get_cell_source_id(pos),
				"atlas_coords": [node.get_cell_atlas_coords(pos).x, node.get_cell_atlas_coords(pos).y],
			})
	elif node is TileMap:
		var used: Array = node.get_used_cells(layer)
		for pos in used:
			cells.append({
				"coords": [pos.x, pos.y],
				"source_id": node.get_cell_source_id(layer, pos),
				"atlas_coords": [node.get_cell_atlas_coords(layer, pos).x, node.get_cell_atlas_coords(layer, pos).y],
			})
	else:
		return _error(-32003, "Node '%s' is not a TileMapLayer or TileMap (is %s)" % [node_path, node.get_class()])

	return {
		"success": true,
		"node_path": node_path,
		"cells": cells,
		"count": cells.size(),
	}


# ---------- Helpers ----------

func _set_cell_tilemap(tilemap: TileMap, coords: Array, source_id: int, atlas_coords: Array, layer: int) -> Dictionary:
	if coords.size() < 2:
		return _error(-32600, "Invalid 'coords': expected [x, y] array")

	var cell_pos := Vector2i(int(coords[0]), int(coords[1]))
	var atlas := Vector2i(int(atlas_coords[0]), int(atlas_coords[1]))

	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Set tile at (%d, %d) layer %d" % [cell_pos.x, cell_pos.y, layer])
	ur.add_do_method(tilemap, "set_cell", layer, cell_pos, source_id, atlas)
	ur.add_undo_method(tilemap, "set_cell", layer, cell_pos, tilemap.get_cell_source_id(layer, cell_pos), tilemap.get_cell_atlas_coords(layer, cell_pos))
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(tilemap.get_path()),
		"coords": [cell_pos.x, cell_pos.y],
		"layer": layer,
		"source_id": source_id,
		"atlas_coords": [atlas.x, atlas.y],
		"message": "Set tile at (%d, %d) layer %d on '%s'" % [cell_pos.x, cell_pos.y, layer, tilemap.name],
	}


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
