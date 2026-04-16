@tool
class_name Catalyst3DHandler
extends RefCounted
## Handles 3D manipulation: meshes, materials, lighting, cameras, environments, gridmaps, CSG, skeletons, multimesh, occlusion.

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


# --- manipulation_3d.add_mesh ---
func add_mesh(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var mesh_type: String = params.get("mesh_type", "box")
	var node_name: String = params.get("name", "MeshInstance3D")
	var transform_data: Variant = params.get("transform", null)

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	var mesh: PrimitiveMesh
	match mesh_type:
		"box":
			mesh = BoxMesh.new()
		"sphere":
			mesh = SphereMesh.new()
		"cylinder":
			mesh = CylinderMesh.new()
		"plane":
			mesh = PlaneMesh.new()
		"capsule":
			mesh = CapsuleMesh.new()
		_:
			return _error(-32003, "Unsupported mesh type: '%s'. Use 'box', 'sphere', 'cylinder', 'plane', or 'capsule'" % mesh_type)

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh

	if transform_data != null:
		instance.transform = CatalystTypeConverter.json_to_variant(transform_data)

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Create MeshInstance3D '%s'" % node_name)
	ur.add_do_method(parent, "add_child", instance)
	ur.add_do_method(instance, "set_owner", scene_root)
	ur.add_do_reference(instance)
	ur.add_undo_method(parent, "remove_child", instance)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(instance.get_path()),
		"name": instance.name,
		"mesh_type": mesh_type,
		"message": "Created MeshInstance3D '%s' (%s) under '%s'" % [node_name, mesh_type, parent_path],
	}


# --- manipulation_3d.set_material ---
func set_material(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var material_properties: Dictionary = params.get("material_properties", {})

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	if not node is MeshInstance3D and not node is CSGShape3D:
		return _error(-32003, "Node '%s' is not a MeshInstance3D or CSGShape3D (is %s)" % [node_path, node.get_class()])

	var mat := StandardMaterial3D.new()

	if material_properties.has("albedo_color"):
		mat.albedo_color = CatalystTypeConverter.json_to_variant(material_properties["albedo_color"])
	if material_properties.has("metallic"):
		mat.metallic = float(material_properties["metallic"])
	if material_properties.has("roughness"):
		mat.roughness = float(material_properties["roughness"])
	if material_properties.has("emission_enabled"):
		mat.emission_enabled = bool(material_properties["emission_enabled"])
	if material_properties.has("emission"):
		mat.emission = CatalystTypeConverter.json_to_variant(material_properties["emission"])
	if material_properties.has("transparency"):
		mat.transparency = int(material_properties["transparency"])
	if material_properties.has("albedo_texture"):
		var tex_path: String = material_properties["albedo_texture"]
		if FileAccess.file_exists(tex_path):
			mat.albedo_texture = load(tex_path)

	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Set material on '%s'" % node.name)

	if node is MeshInstance3D:
		var mesh_inst: MeshInstance3D = node
		var old_mat := mesh_inst.get_surface_override_material(0)
		ur.add_do_method(mesh_inst, "set_surface_override_material", 0, mat)
		ur.add_undo_method(mesh_inst, "set_surface_override_material", 0, old_mat)
	elif node is CSGShape3D:
		var csg: CSGShape3D = node
		var old_mat: Variant = csg.material
		ur.add_do_property(csg, "material", mat)
		ur.add_undo_property(csg, "material", old_mat)

	ur.commit_action()

	return {
		"success": true,
		"node_path": node_path,
		"message": "Set StandardMaterial3D on '%s'" % node_path,
	}


# --- manipulation_3d.setup_lighting ---
func setup_lighting(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var light_type: String = params.get("light_type", "directional")
	var properties: Dictionary = params.get("properties", {})

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	var light: Light3D
	match light_type:
		"directional":
			light = DirectionalLight3D.new()
		"omni":
			light = OmniLight3D.new()
		"spot":
			light = SpotLight3D.new()
		_:
			return _error(-32003, "Unsupported light type: '%s'. Use 'directional', 'omni', or 'spot'" % light_type)

	light.name = params.get("name", light.get_class())

	if properties.has("color"):
		light.light_color = CatalystTypeConverter.json_to_variant(properties["color"])
	if properties.has("energy"):
		light.light_energy = float(properties["energy"])
	if properties.has("shadow_enabled"):
		light.shadow_enabled = bool(properties["shadow_enabled"])
	if properties.has("transform"):
		light.transform = CatalystTypeConverter.json_to_variant(properties["transform"])

	if light is OmniLight3D and properties.has("range"):
		(light as OmniLight3D).omni_range = float(properties["range"])
	if light is SpotLight3D:
		if properties.has("range"):
			(light as SpotLight3D).spot_range = float(properties["range"])
		if properties.has("angle"):
			(light as SpotLight3D).spot_angle = float(properties["angle"])

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Create %s '%s'" % [light.get_class(), light.name])
	ur.add_do_method(parent, "add_child", light)
	ur.add_do_method(light, "set_owner", scene_root)
	ur.add_do_reference(light)
	ur.add_undo_method(parent, "remove_child", light)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(light.get_path()),
		"name": light.name,
		"light_type": light_type,
		"message": "Created %s '%s' under '%s'" % [light.get_class(), light.name, parent_path],
	}


# --- manipulation_3d.setup_camera ---
func setup_camera(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var projection: Variant = params.get("projection", null)
	var fov: Variant = params.get("fov", null)
	var transform_data: Variant = params.get("transform", null)

	var node := _get_node(node_path)
	if node == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	if not node is Camera3D:
		return _error(-32003, "Node '%s' is not a Camera3D (is %s)" % [node_path, node.get_class()])

	var camera: Camera3D = node
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Configure Camera3D '%s'" % camera.name)

	if projection != null:
		var old_proj := camera.projection
		ur.add_do_property(camera, "projection", int(projection))
		ur.add_undo_property(camera, "projection", old_proj)

	if fov != null:
		var old_fov := camera.fov
		ur.add_do_property(camera, "fov", float(fov))
		ur.add_undo_property(camera, "fov", old_fov)

	if transform_data != null:
		var old_transform := camera.transform
		var new_transform: Transform3D = CatalystTypeConverter.json_to_variant(transform_data)
		ur.add_do_property(camera, "transform", new_transform)
		ur.add_undo_property(camera, "transform", old_transform)

	ur.commit_action()

	return {
		"success": true,
		"node_path": node_path,
		"message": "Configured Camera3D '%s'" % node_path,
	}


# --- manipulation_3d.setup_environment ---
func setup_environment(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var env_properties: Dictionary = params.get("environment_properties", {})

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	var env := Environment.new()

	if env_properties.has("background_mode"):
		env.background_mode = int(env_properties["background_mode"])
	if env_properties.has("background_color"):
		env.background_color = CatalystTypeConverter.json_to_variant(env_properties["background_color"])
	if env_properties.has("ambient_light_color"):
		env.ambient_light_color = CatalystTypeConverter.json_to_variant(env_properties["ambient_light_color"])
	if env_properties.has("ambient_light_energy"):
		env.ambient_light_energy = float(env_properties["ambient_light_energy"])
	if env_properties.has("glow_enabled"):
		env.glow_enabled = bool(env_properties["glow_enabled"])
	if env_properties.has("tonemap_mode"):
		env.tonemap_mode = int(env_properties["tonemap_mode"])
	if env_properties.has("fog_enabled"):
		env.fog_enabled = bool(env_properties["fog_enabled"])
	if env_properties.has("ssao_enabled"):
		env.ssao_enabled = bool(env_properties["ssao_enabled"])

	var world_env := WorldEnvironment.new()
	world_env.name = params.get("name", "WorldEnvironment")
	world_env.environment = env

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Create WorldEnvironment '%s'" % world_env.name)
	ur.add_do_method(parent, "add_child", world_env)
	ur.add_do_method(world_env, "set_owner", scene_root)
	ur.add_do_reference(world_env)
	ur.add_undo_method(parent, "remove_child", world_env)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(world_env.get_path()),
		"name": world_env.name,
		"message": "Created WorldEnvironment '%s' under '%s'" % [world_env.name, parent_path],
	}


# --- manipulation_3d.add_gridmap ---
func add_gridmap(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var mesh_library_path: String = params.get("mesh_library_path", "")

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	var gridmap := GridMap.new()
	gridmap.name = params.get("name", "GridMap")

	if not mesh_library_path.is_empty():
		if not FileAccess.file_exists(mesh_library_path):
			return _error(-32004, "MeshLibrary file not found: '%s'" % mesh_library_path)
		var lib := load(mesh_library_path) as MeshLibrary
		if lib == null:
			return _error(-32008, "Failed to load MeshLibrary: '%s'" % mesh_library_path)
		gridmap.mesh_library = lib

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Create GridMap '%s'" % gridmap.name)
	ur.add_do_method(parent, "add_child", gridmap)
	ur.add_do_method(gridmap, "set_owner", scene_root)
	ur.add_do_reference(gridmap)
	ur.add_undo_method(parent, "remove_child", gridmap)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(gridmap.get_path()),
		"name": gridmap.name,
		"message": "Created GridMap '%s' under '%s'" % [gridmap.name, parent_path],
	}


# --- manipulation_3d.create_csg ---
func create_csg(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var csg_type: String = params.get("csg_type", "box")
	var properties: Dictionary = params.get("properties", {})

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	var csg: CSGShape3D
	match csg_type:
		"box":
			var box := CSGBox3D.new()
			if properties.has("size"):
				box.size = CatalystTypeConverter.json_to_variant(properties["size"])
			csg = box
		"sphere":
			var sphere := CSGSphere3D.new()
			if properties.has("radius"):
				sphere.radius = float(properties["radius"])
			if properties.has("radial_segments"):
				sphere.radial_segments = int(properties["radial_segments"])
			csg = sphere
		"cylinder":
			var cylinder := CSGCylinder3D.new()
			if properties.has("radius"):
				cylinder.radius = float(properties["radius"])
			if properties.has("height"):
				cylinder.height = float(properties["height"])
			csg = cylinder
		"polygon":
			var polygon := CSGPolygon3D.new()
			if properties.has("polygon"):
				var packed := PackedVector2Array()
				for pt in properties["polygon"]:
					packed.append(CatalystTypeConverter.json_to_variant(pt))
				polygon.polygon = packed
			csg = polygon
		"torus":
			var torus := CSGTorus3D.new()
			if properties.has("inner_radius"):
				torus.inner_radius = float(properties["inner_radius"])
			if properties.has("outer_radius"):
				torus.outer_radius = float(properties["outer_radius"])
			csg = torus
		_:
			return _error(-32003, "Unsupported CSG type: '%s'. Use 'box', 'sphere', 'cylinder', 'polygon', or 'torus'" % csg_type)

	csg.name = params.get("name", csg.get_class())

	if properties.has("operation"):
		csg.operation = int(properties["operation"])
	if properties.has("use_collision"):
		csg.use_collision = bool(properties["use_collision"])
	if properties.has("transform"):
		csg.transform = CatalystTypeConverter.json_to_variant(properties["transform"])

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Create %s '%s'" % [csg.get_class(), csg.name])
	ur.add_do_method(parent, "add_child", csg)
	ur.add_do_method(csg, "set_owner", scene_root)
	ur.add_do_reference(csg)
	ur.add_undo_method(parent, "remove_child", csg)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(csg.get_path()),
		"name": csg.name,
		"csg_type": csg_type,
		"message": "Created %s '%s' under '%s'" % [csg.get_class(), csg.name, parent_path],
	}


# --- manipulation_3d.setup_skeleton ---
func setup_skeleton(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var bones: Array = params.get("bones", [])

	var parent := _get_node(node_path)
	if parent == null:
		return _error(-32001, "Node not found: '%s'" % node_path)

	var skeleton: Skeleton3D
	if parent is Skeleton3D:
		skeleton = parent
	else:
		# Create a new Skeleton3D under the given node
		skeleton = Skeleton3D.new()
		skeleton.name = params.get("name", "Skeleton3D")
		var scene_root := _get_scene_root()
		var ur := EditorInterface.get_editor_undo_redo()
		ur.create_action("Create Skeleton3D '%s'" % skeleton.name)
		ur.add_do_method(parent, "add_child", skeleton)
		ur.add_do_method(skeleton, "set_owner", scene_root)
		ur.add_do_reference(skeleton)
		ur.add_undo_method(parent, "remove_child", skeleton)
		ur.commit_action()

	var added_bones := []
	for bone_data in bones:
		var bone_name: String = bone_data.get("name", "Bone")
		var parent_bone_idx: int = bone_data.get("parent", -1)
		var bone_idx := skeleton.get_bone_count()
		skeleton.add_bone(bone_name)
		if parent_bone_idx >= 0:
			skeleton.set_bone_parent(bone_idx, parent_bone_idx)
		if bone_data.has("rest"):
			skeleton.set_bone_rest(bone_idx, CatalystTypeConverter.json_to_variant(bone_data["rest"]))
		added_bones.append({"name": bone_name, "index": bone_idx})

	return {
		"success": true,
		"node_path": str(skeleton.get_path()),
		"bones": added_bones,
		"bone_count": skeleton.get_bone_count(),
		"message": "Configured Skeleton3D with %d bones" % skeleton.get_bone_count(),
	}


# --- manipulation_3d.create_multimesh ---
func create_multimesh(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var mesh_data: Variant = params.get("mesh", null)
	var instance_count: int = int(params.get("instance_count", 1))
	var transforms: Array = params.get("transforms", [])

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.instance_count = instance_count

	# Create a default mesh if mesh type is provided
	if mesh_data is String:
		match mesh_data:
			"box":
				multi.mesh = BoxMesh.new()
			"sphere":
				multi.mesh = SphereMesh.new()
			"cylinder":
				multi.mesh = CylinderMesh.new()
			"plane":
				multi.mesh = PlaneMesh.new()
			"capsule":
				multi.mesh = CapsuleMesh.new()
			_:
				return _error(-32003, "Unsupported mesh type: '%s'" % str(mesh_data))

	# Apply instance transforms
	for i in range(mini(transforms.size(), instance_count)):
		multi.set_instance_transform(i, CatalystTypeConverter.json_to_variant(transforms[i]))

	var mm_instance := MultiMeshInstance3D.new()
	mm_instance.name = params.get("name", "MultiMeshInstance3D")
	mm_instance.multimesh = multi

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Create MultiMeshInstance3D '%s'" % mm_instance.name)
	ur.add_do_method(parent, "add_child", mm_instance)
	ur.add_do_method(mm_instance, "set_owner", scene_root)
	ur.add_do_reference(mm_instance)
	ur.add_undo_method(parent, "remove_child", mm_instance)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(mm_instance.get_path()),
		"name": mm_instance.name,
		"instance_count": instance_count,
		"message": "Created MultiMeshInstance3D '%s' with %d instances under '%s'" % [mm_instance.name, instance_count, parent_path],
	}


# --- manipulation_3d.setup_occlusion ---
func setup_occlusion(params: Dictionary) -> Dictionary:
	var parent_path: String = params.get("parent_path", "")
	var occluder_type: String = params.get("occluder_type", "quad")

	var parent := _get_node(parent_path)
	if parent == null:
		return _error(-32001, "Parent node not found: '%s'" % parent_path)

	var occluder_instance := OccluderInstance3D.new()
	occluder_instance.name = params.get("name", "OccluderInstance3D")

	var occluder: Occluder3D
	match occluder_type:
		"quad":
			occluder = QuadOccluder3D.new()
		"box":
			occluder = BoxOccluder3D.new()
		"sphere":
			occluder = SphereOccluder3D.new()
		"polygon":
			occluder = PolygonOccluder3D.new()
		_:
			return _error(-32003, "Unsupported occluder type: '%s'. Use 'quad', 'box', 'sphere', or 'polygon'" % occluder_type)

	occluder_instance.occluder = occluder

	if params.has("transform"):
		occluder_instance.transform = CatalystTypeConverter.json_to_variant(params["transform"])

	var scene_root := _get_scene_root()
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Create OccluderInstance3D '%s'" % occluder_instance.name)
	ur.add_do_method(parent, "add_child", occluder_instance)
	ur.add_do_method(occluder_instance, "set_owner", scene_root)
	ur.add_do_reference(occluder_instance)
	ur.add_undo_method(parent, "remove_child", occluder_instance)
	ur.commit_action()

	return {
		"success": true,
		"node_path": str(occluder_instance.get_path()),
		"name": occluder_instance.name,
		"occluder_type": occluder_type,
		"message": "Created OccluderInstance3D '%s' (%s) under '%s'" % [occluder_instance.name, occluder_type, parent_path],
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
