extends SceneTree
# Package matte materials as native Godot scenes when the GLB importer ignores
# KHR_materials_specular. This does not touch the live game or existing imports.
var failures := 0
var records: Array = []
var raw_specular_values: Dictionary = {}
func _initialize() -> void:
	call_deferred("run_pack")
func prepare(n: Node, scene_root: Node) -> void:
	if n != scene_root: n.owner = scene_root
	if n is MeshInstance3D:
		for i in n.mesh.get_surface_count():
			var m = n.mesh.surface_get_material(i)
			if m is BaseMaterial3D:
				raw_specular_values[str(m.metallic_specular)] = true
				m.roughness = 1.0
				m.metallic_specular = 0.0
				m.metallic = 0.0
				m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	for child in n.get_children(): prepare(child, scene_root)
func inspect(n: Node) -> void:
	if n is MeshInstance3D:
		for i in n.mesh.get_surface_count():
			var m = n.mesh.surface_get_material(i)
			if not m is BaseMaterial3D:
				failures += 1
			elif m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or m.roughness < .99 or m.metallic_specular > .01 or m.specular_mode != BaseMaterial3D.SPECULAR_DISABLED:
				failures += 1
			elif m.resource_name.contains("barn") and m.albedo_texture != null and not m.normal_enabled:
				failures += 1
	for child in n.get_children(): inspect(child)
func run_pack() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	for sub in ["modules", "assemblies"]:
		DirAccess.make_dir_recursive_absolute(folder.path_join("godot").path_join(sub))
		for file in DirAccess.get_files_at(folder.path_join(sub)):
			if not file.ends_with(".glb"): continue
			var before := failures
			var doc := GLTFDocument.new()
			var state := GLTFState.new()
			var err := doc.append_from_file(folder.path_join(sub).path_join(file), state)
			if err != OK:
				failures += 1
				continue
			var n := doc.generate_scene(state)
			if n == null:
				failures += 1
				continue
			root.add_child(n)
			prepare(n,n)
			var packed := PackedScene.new()
			var destination := folder.path_join("godot").path_join(sub).path_join(file.get_basename()+".scn")
			if packed.pack(n) != OK or ResourceSaver.save(packed,destination) != OK:
				failures += 1
			n.free()
			# Reload saved bytes without the in-memory cache before asserting success.
			var saved = ResourceLoader.load(destination,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
			if saved == null:
				failures += 1
			else:
				var check = saved.instantiate()
				root.add_child(check)
				inspect(check)
				check.free()
			records.append({"file":"godot/"+sub+"/"+file.get_basename()+".scn","passed":before==failures})
	if records.is_empty(): failures += 1
	var result := {"passed":failures==0,"files":records.size(),"failures":failures,"checks":records,"raw_glb_import_specular_values":raw_specular_values.keys(),"scope":"Native .scn saved, reloaded without cache and instantiated; lit textures, roughness 1, specular disabled. Not live-map pixel/performance validation."}
	var f := FileAccess.open(folder.path_join("godot_native_validation.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result))
	quit(0 if failures==0 else 1)
