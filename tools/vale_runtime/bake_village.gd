extends SceneTree
## Bake static village assemblies once, retaining materials, vertices and collision.
const DIR := "res://assets/models/village_kit/"
const OUT := "res://assets/streaming/village/"
func _initialize() -> void:
	call_deferred("run")
func relative(n: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	while n != root:
		xf = n.transform * xf
		n = n.get_parent() as Node3D
	return xf
func own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		own(c, root)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var reports: Array = []
	for file in DirAccess.get_files_at(DIR):
		if not file.ends_with(".glb") or file == "door_leaf_hinged.glb": continue
		var root := (load(DIR + file) as PackedScene).instantiate() as Node3D
		var groups := {}
		var originals: Array = []
		var triangles := 0
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			# Animated branches and transparent surfaces retain their own sorting.
			if mi.skeleton != NodePath("") and mi.get_node_or_null(mi.skeleton) is Skeleton3D: continue
			if mi.mesh == null or mi.mesh.get_blend_shape_count() > 0: continue
			var eligible := true
			for i in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(i)
				if mat is BaseMaterial3D and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: eligible = false
			if not eligible: continue
			var xf := relative(mi, root)
			for i in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(i)
				var part_mesh: Mesh = mi.mesh
				var part_surface := i
				var material_key := str(mat.get_instance_id() if mat else 0)
				if mat != null and mat.resource_name.begins_with("K|"):
					var fields := mat.resource_name.split("|")
					if fields.size() == 5 and fields[1].is_valid_int():
						material_key = "V|%s|%s|%s" % [fields[1],fields[3],fields[4]]
						var arrays := mi.mesh.surface_get_arrays(i)
						var colours := PackedColorArray()
						colours.resize(arrays[Mesh.ARRAY_VERTEX].size())
						colours.fill(Color(fields[2]).srgb_to_linear())
						arrays[Mesh.ARRAY_COLOR] = colours
						var tinted := ArrayMesh.new()
						tinted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
						part_mesh = tinted
						part_surface = 0
						mat = StandardMaterial3D.new()
						mat.resource_name = material_key
				# Retain each source mesh transform so world-space shading/hrel is identical.
				var key := str(mi.get_instance_id()) + ":" + material_key
				if not groups.has(key):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					st.set_material(mat)
					groups[key] = {"tool":st,"shadow":mi.cast_shadow,"visible":mi.visible,"xf":xf}
				groups[key].tool.append_from(part_mesh, part_surface, Transform3D.IDENTITY)
				var ar := mi.mesh.surface_get_arrays(i)
				triangles += (ar[Mesh.ARRAY_INDEX].size() if ar[Mesh.ARRAY_INDEX] != null and ar[Mesh.ARRAY_INDEX].size() > 0 else ar[Mesh.ARRAY_VERTEX].size()) / 3
			originals.append(mi)
		for mi: MeshInstance3D in originals:
			# Preserve children, including imported collision shapes and anchors.
			mi.mesh = null
		var assemblies := {}
		for key in groups:
			var source_key: String = key.get_slice(":", 0)
			if not assemblies.has(source_key):
				assemblies[source_key] = {"mesh": ArrayMesh.new(), "settings": groups[key]}
			groups[key].tool.commit(assemblies[source_key].mesh)
		for source_key in assemblies:
			var settings: Dictionary = assemblies[source_key].settings
			var mi := MeshInstance3D.new()
			mi.name = "BatchedVillage_" + str(root.get_child_count())
			mi.mesh = assemblies[source_key].mesh
			mi.cast_shadow = settings.shadow
			mi.visible = settings.visible
			mi.transform = settings.xf
			root.add_child(mi)
		own(root, root)
		var packed := PackedScene.new()
		assert(packed.pack(root) == OK)
		assert(ResourceSaver.save(packed, OUT + file.get_basename() + ".scn") == OK)
		var stamp := FileAccess.open(OUT + file.get_basename() + ".sha256", FileAccess.WRITE)
		stamp.store_string(FileAccess.get_sha256(DIR + file) + ":" + FileAccess.get_sha256(get_script().resource_path))
		var row := {"asset":file,"before_meshes":originals.size(),"after_batches":groups.size(),"triangles_preserved":triangles}
		reports.append(row)
		print("VILLAGE_BATCH ", JSON.stringify(row))
		root.free()
	var report := FileAccess.open(OUT + "manifest.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(reports,"\t"))
	quit()
