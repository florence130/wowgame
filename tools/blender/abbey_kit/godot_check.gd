extends SceneTree
## Isolated validation through GLTFDocument; no live map or ModelProp mutations.
var records: Array = []
var failures := 0
var mesh_count := 0
var surface_count := 0

func _initialize() -> void:
	call_deferred("run_check")

func inspect_node(node: Node) -> void:
	if node is MeshInstance3D:
		mesh_count += 1
		var mi := node as MeshInstance3D
		for i in range(mi.mesh.get_surface_count()):
			surface_count += 1
			var mat := mi.mesh.surface_get_material(i)
			if not mat is BaseMaterial3D or mat.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
				failures += 1
	for c in node.get_children(): inspect_node(c)

func run_check() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass absolute build directory after --")
		quit(2)
		return
	var folder: String = args[0]
	for sub: String in ["glb", "assemblies"]:
		for file: String in DirAccess.get_files_at(folder.path_join(sub)):
			if not file.ends_with(".glb"): continue
			var doc := GLTFDocument.new()
			var state := GLTFState.new()
			var err := doc.append_from_file(folder.path_join(sub).path_join(file), state)
			var root_node: Node = null
			if err == OK: root_node = doc.generate_scene(state)
			var previous := failures
			if root_node == null:
				failures += 1
			else:
				root.add_child(root_node)
				inspect_node(root_node)
				root_node.free()
			records.append({"file": sub + "/" + file, "load_error": err, "passed": previous == failures})
	var report := {"passed": failures == 0, "files": records.size(), "mesh_instances": mesh_count, "material_surfaces": surface_count, "failures": failures, "checks": records, "scope": "Actual Godot GLTFDocument load, scene instantiation, unshaded material flags; no map gameplay/collision/performance test"}
	var output := FileAccess.open(folder.path_join("godot_validation.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print("ABBEY_GODOT_CHECK ", JSON.stringify(report))
	quit(0 if failures == 0 else 1)
