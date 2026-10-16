extends SceneTree
var failures := 0
var records: Array = []
func _initialize() -> void:
	call_deferred("run_check")
func inspect_node(n: Node) -> void:
	if n is MeshInstance3D:
		for i in n.mesh.get_surface_count():
			var m = n.mesh.surface_get_material(i)
			if not m is BaseMaterial3D or m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
				failures += 1
			elif m.roughness < 0.99 or m.metallic_specular > 0.01:
				failures += 1
	for c in n.get_children(): inspect_node(c)
func run_check() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	for sub in ["modules", "assemblies"]:
		for file in DirAccess.get_files_at(folder.path_join(sub)):
			if not file.ends_with(".glb"): continue
			var doc := GLTFDocument.new()
			var state := GLTFState.new()
			var err := doc.append_from_file(folder.path_join(sub).path_join(file), state)
			var before := failures
			if err != OK:
				failures += 1
			else:
				var n := doc.generate_scene(state)
				if n == null: failures += 1
				else:
					root.add_child(n)
					inspect_node(n)
					n.free()
			records.append({"file":sub+"/"+file,"passed":before==failures,"load_error":err})
	if records.is_empty(): failures += 1
	var result := {"passed":failures==0,"files":records.size(),"failures":failures,"checks":records,"scope":"Actual GLTFDocument loading, instantiation, lit materials, roughness >= .99 and specular <= .01; isolated project, not live map integration"}
	var f := FileAccess.open(folder.path_join("godot_validation.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result))
	quit(0 if failures==0 else 1)
