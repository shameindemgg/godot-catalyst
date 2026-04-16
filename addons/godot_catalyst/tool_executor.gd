@tool
extends Node
## Central dispatcher: routes JSON-RPC method names to handler instances.

var _plugin: EditorPlugin
var _handlers: Dictionary = {}  # namespace -> handler instance


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin

	# Phase 2: Scene and Node handlers
	_register_handler("scene", preload("res://addons/godot_catalyst/handlers/scene_handler.gd").new())
	_register_handler("node", preload("res://addons/godot_catalyst/handlers/node_handler.gd").new())

	# Phase 3: Script, Resource, Editor, Project handlers
	_register_handler("script", preload("res://addons/godot_catalyst/handlers/script_handler.gd").new())
	_register_handler("resource", preload("res://addons/godot_catalyst/handlers/resource_handler.gd").new())
	_register_handler("editor", preload("res://addons/godot_catalyst/handlers/editor_handler.gd").new())
	_register_handler("project", preload("res://addons/godot_catalyst/handlers/project_handler.gd").new())

	# Phase 4: Signal and Build handlers
	_register_handler("signal", preload("res://addons/godot_catalyst/handlers/signal_handler.gd").new())
	_register_handler("build", preload("res://addons/godot_catalyst/handlers/build_handler.gd").new())

	# Phase 4b: 2D, 3D, Animation handlers
	_register_handler("manipulation_2d", preload("res://addons/godot_catalyst/handlers/manipulation_2d_handler.gd").new())
	_register_handler("manipulation_3d", preload("res://addons/godot_catalyst/handlers/manipulation_3d_handler.gd").new())
	_register_handler("animation", preload("res://addons/godot_catalyst/handlers/animation_handler.gd").new())

	# Phase 5: Domain-specific handlers
	_register_handler("audio", preload("res://addons/godot_catalyst/handlers/audio_handler.gd").new())
	_register_handler("physics", preload("res://addons/godot_catalyst/handlers/physics_handler.gd").new())
	_register_handler("navigation", preload("res://addons/godot_catalyst/handlers/navigation_handler.gd").new())
	_register_handler("shader", preload("res://addons/godot_catalyst/handlers/shader_handler.gd").new())
	_register_handler("theme", preload("res://addons/godot_catalyst/handlers/theme_handler.gd").new())
	_register_handler("particle", preload("res://addons/godot_catalyst/handlers/particle_handler.gd").new())
	_register_handler("tilemap", preload("res://addons/godot_catalyst/handlers/tilemap_handler.gd").new())

	# Phase 10: Input simulation, profiling, and runtime inspection
	_register_handler("input", preload("res://addons/godot_catalyst/handlers/input_handler.gd").new())
	_register_handler("profiling", preload("res://addons/godot_catalyst/handlers/profiling_handler.gd").new())
	_register_handler("runtime", preload("res://addons/godot_catalyst/handlers/runtime_handler.gd").new())

	# Phase 12: Spatial intelligence
	_register_handler("spatial", preload("res://addons/godot_catalyst/handlers/spatial_handler.gd").new())

	# Phase 13: Networking
	_register_handler("networking", preload("res://addons/godot_catalyst/handlers/networking_handler.gd").new())

	print("[Godot Catalyst] ToolExecutor ready, %d handler namespaces registered" % _handlers.size())


func execute(method: String, params: Dictionary) -> Dictionary:
	# Split method on '.' to get namespace and action
	var parts := method.split(".", false, 2)
	if parts.size() < 2:
		return _make_error(-32601, "Method not found: '%s' (expected 'namespace.action' format)" % method)

	var ns: String = parts[0]
	var action: String = parts[1]

	if not _handlers.has(ns):
		return _make_error(-32601, "Unknown namespace: '%s'. Available: %s" % [ns, ", ".join(_handlers.keys())])

	var handler: RefCounted = _handlers[ns]

	if not handler.has_method(action):
		return _make_error(-32601, "Unknown action: '%s.%s'" % [ns, action])

	# Call the handler method
	var result: Variant = handler.call(action, params)

	if result is Dictionary:
		return result
	else:
		return {"success": true, "result": result}


func _register_handler(ns: String, handler: RefCounted) -> void:
	handler.setup(_plugin)
	_handlers[ns] = handler


func _make_error(code: int, message: String, data: Variant = null) -> Dictionary:
	var err := {"error": {"code": code, "message": message}}
	if data != null:
		err["error"]["data"] = data
	return err
