extends SceneTree
## Independent Godot 4 validation of actual exported GLB scenes.
## Run with --headless --path ISOLATED_PROJECT --script THIS_FILE -- BUILD_DIR.
## This verifies imported material/shadow settings, not rendered shadow pixels.

var records: Array = []
var issues: Array = []
var failures: int = 0
var mesh_count: int = 0
var surface_count: int = 0
var pbr_surface_count: int = 0
var textured_surface_count: int = 0
var casting_mesh_count: int = 0
var unique_materials: Dictionary = {}
var active_file: String = ""
var stage: Node3D


func _initialize() -> void:
	call_deferred("run_check")


func fail_check(check_name: String, node_name: String, details: Dictionary = {}) -> void:
	failures += 1
	issues.append({"file": active_file, "check": check_name, "node": node_name, "details": details})


func inspect_node(node: Node) -> void:
	if node is MeshInstance3D:
		mesh_count += 1
		var instance := node as MeshInstance3D
		var node_path: String = str(instance.get_path())
		if instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			fail_check("shadow_casting_enabled", node_path, {"cast_shadow": instance.cast_shadow})
		else:
			casting_mesh_count += 1
		if instance.mesh == null:
			fail_check("mesh_resource_available", node_path)
		else:
			for surface_index in range(instance.mesh.get_surface_count()):
				surface_count += 1
				var material: Material = instance.get_active_material(surface_index)
				if not material is BaseMaterial3D:
					fail_check("standard_pbr_material", node_path, {"surface": surface_index, "material_class": material.get_class() if material != null else "null"})
					continue
				var pbr := material as BaseMaterial3D
				# A plain imported StandardMaterial3D must actually receive lighting.
				# Reject the v1 UNSHADED mode explicitly instead of inheriting its test.
				if pbr.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
					fail_check("material_is_not_unshaded", node_path, {"surface": surface_index, "material": pbr.resource_name})
				elif pbr.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL:
					fail_check("material_uses_per_pixel_pbr", node_path, {"surface": surface_index, "shading_mode": pbr.shading_mode})
				else:
					pbr_surface_count += 1
				if not is_finite(pbr.roughness) or not is_finite(pbr.metallic) or pbr.roughness < 0.0 or pbr.roughness > 1.0 or pbr.metallic < 0.0 or pbr.metallic > 1.0:
					fail_check("finite_pbr_parameters", node_path, {"surface": surface_index, "roughness": pbr.roughness, "metallic": pbr.metallic})
				var texture: Texture2D = pbr.albedo_texture
				var textured: bool = texture != null
				if textured:
					if texture.get_width() > 0 and texture.get_height() > 0:
						textured_surface_count += 1
					else:
						fail_check("albedo_texture_has_pixels", node_path, {"surface": surface_index, "material": pbr.resource_name})
				var material_key: String = active_file + "::" + pbr.resource_name
				unique_materials[material_key] = {"file": active_file, "name": pbr.resource_name,
					"class": pbr.get_class(), "shading_mode": pbr.shading_mode,
					"roughness": pbr.roughness, "metallic": pbr.metallic,
					"has_albedo_texture": textured,
					"texture_width": texture.get_width() if textured else 0,
					"texture_height": texture.get_height() if textured else 0}
	for child in node.get_children():
		inspect_node(child)


func create_lighting_context() -> void:
	stage = Node3D.new()
	stage.name = "IsolatedPBRValidation"
	root.add_child(stage)
	var world := WorldEnvironment.new()
	world.name = "ValidationEnvironment"
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.12, 0.15, 0.2)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.5, 0.62, 0.8)
	world.environment.ambient_light_energy = 0.35
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "ValidationSunWithShadows"
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-38.0, -30.0, 0.0)
	stage.add_child(sun)


func run_check() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass absolute build directory after --")
		quit(2)
		return
	var folder: String = args[0]
	create_lighting_context()
	for sub: String in ["glb", "assemblies"]:
		var paths: PackedStringArray = DirAccess.get_files_at(folder.path_join(sub))
		paths.sort()
		for file: String in paths:
			if not file.to_lower().ends_with(".glb"):
				continue
			active_file = sub + "/" + file
			var previous_failures: int = failures
			var previous_meshes: int = mesh_count
			var previous_surfaces: int = surface_count
			var previous_pbr: int = pbr_surface_count
			var previous_textures: int = textured_surface_count
			var previous_casting: int = casting_mesh_count
			var document := GLTFDocument.new()
			var state := GLTFState.new()
			var load_error: Error = document.append_from_file(folder.path_join(sub).path_join(file), state)
			var imported: Node = null
			if load_error == OK:
				imported = document.generate_scene(state)
			if imported == null:
				fail_check("gltf_load_and_scene_generation", "", {"load_error": load_error})
			else:
				stage.add_child(imported)
				inspect_node(imported)
				if mesh_count == previous_meshes:
					fail_check("scene_has_actual_mesh_instances", imported.name)
				if textured_surface_count == previous_textures:
					fail_check("scene_uses_actual_albedo_texture", imported.name)
				imported.free()
			records.append({"file": active_file, "load_error": load_error,
				"passed": failures == previous_failures,
				"mesh_instances": mesh_count - previous_meshes,
				"material_surfaces": surface_count - previous_surfaces,
				"per_pixel_pbr_surfaces": pbr_surface_count - previous_pbr,
				"textured_surfaces": textured_surface_count - previous_textures,
				"shadow_casting_meshes": casting_mesh_count - previous_casting})
	if records.is_empty():
		active_file = ""
		fail_check("export_files_found", folder)
	var report: Dictionary = {"passed": failures == 0, "engine": Engine.get_version_info(),
		"files": records.size(), "mesh_instances": mesh_count,
		"material_surfaces": surface_count, "per_pixel_pbr_surfaces": pbr_surface_count,
		"textured_surfaces": textured_surface_count, "shadow_casting_meshes": casting_mesh_count,
		"failures": failures, "checks": records, "issues": issues,
		"materials": unique_materials.values(), "lighting_context": "WorldEnvironment plus DirectionalLight3D with shadows enabled",
		"scope": "Actual Godot GLTFDocument load and scene instantiation; StandardMaterial3D PBR per-pixel lighting mode, albedo textures, finite roughness/metallic, mesh shadow casting flags. Isolated project. No raster shadow pixel, gameplay, collision or performance claim."}
	var output_path: String = folder.path_join("godot_validation.json")
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		push_error("Could not write validation report: " + output_path)
		quit(2)
		return
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print("ABBEY_V2_GODOT_CHECK ", JSON.stringify({"passed": failures == 0,
		"files": records.size(), "mesh_instances": mesh_count, "material_surfaces": surface_count,
		"per_pixel_pbr_surfaces": pbr_surface_count, "textured_surfaces": textured_surface_count,
		"shadow_casting_meshes": casting_mesh_count, "failures": failures,
		"issues": issues, "report": output_path}))
	stage.free()
	quit(0 if failures == 0 else 1)
