@tool
class_name CatalystAudioHandler
extends RefCounted
## Handles audio players, buses, and effects.

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


# --- audio.add_player ---
func add_player(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var stream_path: String = params.get("stream_path", "")
	var bus: String = params.get("bus", "Master")
	var player_type: String = params.get("type", "2d")
	var player_name: String = params.get("name", "")

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	var node: Node
	match player_type:
		"2d":
			node = AudioStreamPlayer2D.new()
		"3d":
			node = AudioStreamPlayer3D.new()
		"non_positional":
			node = AudioStreamPlayer.new()
		_:
			return _error(-32003, "Invalid audio player type: '%s'. Use '2d', '3d', or 'non_positional'" % player_type)

	if not player_name.is_empty():
		node.name = player_name

	node.bus = bus

	if not stream_path.is_empty():
		if not FileAccess.file_exists(stream_path):
			return _error(-32004, "Audio stream file not found: '%s'" % stream_path)
		var stream := load(stream_path) as AudioStream
		if stream == null:
			return _error(-32008, "Failed to load audio stream: '%s'" % stream_path)
		node.stream = stream

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Add AudioStreamPlayer '%s'" % node.name)
	ur.add_do_method(parent, "add_child", node)
	ur.add_do_method(node, "set_owner", scene_root)
	ur.add_do_reference(node)
	ur.add_undo_method(parent, "remove_child", node)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(node.get_path()),
		"name": node.name,
		"type": player_type,
		"bus": bus,
		"message": "Created AudioStreamPlayer (%s) '%s' under '%s'" % [player_type, node.name, parent_path],
	}


# --- audio.get_bus_layout ---
func get_bus_layout(params: Dictionary) -> Dictionary:
	var buses := []
	for i in range(AudioServer.bus_count):
		var bus_info := {
			"index": i,
			"name": AudioServer.get_bus_name(i),
			"volume_db": AudioServer.get_bus_volume_db(i),
			"send": AudioServer.get_bus_send(i),
			"solo": AudioServer.is_bus_solo(i),
			"mute": AudioServer.is_bus_mute(i),
			"effect_count": AudioServer.get_bus_effect_count(i),
		}
		var effects := []
		for j in range(AudioServer.get_bus_effect_count(i)):
			effects.append({
				"index": j,
				"name": AudioServer.get_bus_effect(i, j).get_class(),
				"enabled": AudioServer.is_bus_effect_enabled(i, j),
			})
		bus_info["effects"] = effects
		buses.append(bus_info)

	return {"success": true, "bus_count": AudioServer.bus_count, "buses": buses}


# --- audio.add_bus ---
func add_bus(params: Dictionary) -> Dictionary:
	var bus_name: String = params.get("name", "")
	var send: String = params.get("send", "Master")

	if bus_name.is_empty():
		return _error(-32600, "Missing 'name' parameter")

	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send)

	return {
		"success": true,
		"index": idx,
		"name": bus_name,
		"send": send,
		"message": "Added audio bus '%s' at index %d" % [bus_name, idx],
	}


# --- audio.set_bus ---
func set_bus(params: Dictionary) -> Dictionary:
	var bus_name: String = params.get("bus_name", "")
	if bus_name.is_empty():
		return _error(-32600, "Missing 'bus_name' parameter")

	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return _error(-32001, "Audio bus not found: '%s'" % bus_name)

	var changed := []

	if params.has("volume_db"):
		AudioServer.set_bus_volume_db(bus_idx, float(params["volume_db"]))
		changed.append("volume_db")

	if params.has("solo"):
		AudioServer.set_bus_solo(bus_idx, bool(params["solo"]))
		changed.append("solo")

	if params.has("mute"):
		AudioServer.set_bus_mute(bus_idx, bool(params["mute"]))
		changed.append("mute")

	return {
		"success": true,
		"bus_name": bus_name,
		"properties_set": changed,
		"message": "Set %d properties on bus '%s'" % [changed.size(), bus_name],
	}


# --- audio.add_effect ---
func add_effect(params: Dictionary) -> Dictionary:
	var bus_name: String = params.get("bus_name", "")
	var effect_type: String = params.get("effect_type", "")
	var properties: Dictionary = params.get("properties", {})

	if bus_name.is_empty():
		return _error(-32600, "Missing 'bus_name' parameter")

	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return _error(-32001, "Audio bus not found: '%s'" % bus_name)

	var effect: AudioEffect
	match effect_type.to_lower():
		"reverb":
			effect = AudioEffectReverb.new()
		"delay":
			effect = AudioEffectDelay.new()
		"chorus":
			effect = AudioEffectChorus.new()
		"amplify":
			effect = AudioEffectAmplify.new()
		"compressor":
			effect = AudioEffectCompressor.new()
		"distortion":
			effect = AudioEffectDistortion.new()
		"eq":
			effect = AudioEffectEQ.new()
		"filter":
			effect = AudioEffectFilter.new()
		"limiter":
			effect = AudioEffectLimiter.new()
		"panner":
			effect = AudioEffectPanner.new()
		"phaser":
			effect = AudioEffectPhaser.new()
		"pitch_shift":
			effect = AudioEffectPitchShift.new()
		"stereo_enhance":
			effect = AudioEffectStereoEnhance.new()
		_:
			return _error(-32003, "Unknown audio effect type: '%s'" % effect_type)

	# Apply properties
	for key in properties:
		var val: Variant = CatalystTypeConverter.json_to_variant(properties[key])
		effect.set(StringName(key), val)

	var effect_idx := AudioServer.get_bus_effect_count(bus_idx)
	AudioServer.add_bus_effect(bus_idx, effect, effect_idx)

	return {
		"success": true,
		"bus_name": bus_name,
		"effect_type": effect_type,
		"effect_index": effect_idx,
		"message": "Added %s effect to bus '%s'" % [effect_type, bus_name],
	}


# --- audio.get_info ---
func get_info(params: Dictionary) -> Dictionary:
	var info := {
		"mix_rate": AudioServer.get_mix_rate(),
		"bus_count": AudioServer.bus_count,
		"output_device": AudioServer.output_device,
		"input_device": AudioServer.input_device,
	}

	var buses := []
	for i in range(AudioServer.bus_count):
		var bus_info := {
			"index": i,
			"name": AudioServer.get_bus_name(i),
			"volume_db": AudioServer.get_bus_volume_db(i),
			"send": AudioServer.get_bus_send(i),
			"solo": AudioServer.is_bus_solo(i),
			"mute": AudioServer.is_bus_mute(i),
			"effect_count": AudioServer.get_bus_effect_count(i),
		}
		buses.append(bus_info)
	info["buses"] = buses

	return {"success": true, "audio_info": info}


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
