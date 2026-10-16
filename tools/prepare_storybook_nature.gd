extends SceneTree
## Rebuild our normalized CC0 derivatives; original vendor files remain untouched.
const SOURCE := "res://assets/third_party/quaternius/nature/"
const OUTPUT := "res://assets/models/nature_storybook/"
const MODELS := {
	# Source / mature height / crown spread. Keep the authored tree placement scale.
	"oak_0": ["CommonTree_1", 13.0, 1.12], "oak_1": ["CommonTree_2", 12.5, 1.22],
	"oak_2": ["CommonTree_5", 14.0, 1.20], "pine_0": ["Pine_1", 16.0, 0.84],
	"pine_1": ["Pine_2", 14.5, 0.84], "pine_2": ["Pine_3", 17.0, 0.90],
	"bush_0": ["Bush_Common", 1.2, 1.0],
}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT + "proxy/"))
	for key in MODELS:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var error := doc.append_from_file(SOURCE + MODELS[key][0] + ".gltf", state)
		assert(error == OK, "Failed source import: " + key)
		var source := doc.generate_scene(state)
		var meshes := source.find_children("*", "MeshInstance3D", true, false)
		assert(meshes.size() == 1, "Expected single authored mesh: " + key)
		var mesh: Mesh = meshes[0].mesh
		var bounds := mesh.get_aabb()
		var scale_factor: float = MODELS[key][1] / bounds.end.y
		var root := Node3D.new()
		root.name = key
		var proxy := Node3D.new()
		proxy.name = key
		var triangle_count := 0
		for surface in mesh.get_surface_count():
			var mat := mesh.surface_get_material(surface) as BaseMaterial3D
			assert(mat != null)
			var leaf := mat.resource_name.begins_with("Leaves")
			var arrays := mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var colors := PackedColorArray()
			var old_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var center := Vector3(0, bounds.end.y * 0.63, 0)
			var leaf_bottom := INF
			if leaf:
				for vertex in verts: leaf_bottom = minf(leaf_bottom, vertex.y * scale_factor)
			var trunk_radius := 0.2
			for i in verts.size():
				var h := clampf(verts[i].y / bounds.end.y, 0.0, 1.0)
				var ao := clampf(old_colors[i].r, 0.35, 1.0) if i < old_colors.size() else 1.0
				colors.append(Color(0.94, ao, h, 1.0))
				if leaf:
					# Canopy normals light whole crowns, not individual alpha cards.
					var crown := (verts[i] - center).normalized()
					normals[i] = (crown + Vector3.UP * 0.30).normalized()
				verts[i] *= scale_factor
				# Flare the upper limbs with the crown; keep the root and lower trunk grounded.
				var spread: float = lerpf(1.0, MODELS[key][2], smoothstep(0.12, 0.48, h))
				verts[i].x *= spread
				verts[i].z *= spread
				normals[i] = Vector3(normals[i].x / spread, normals[i].y, normals[i].z / spread).normalized()
				if leaf and not key.begins_with("bush"):
					# Mature crowns occupy most of the upper tree, not just a tuft at its tip.
					var height: float = MODELS[key][1]
					var start := height * (0.22 if key.begins_with("pine") else 0.34)
					var vertical_scale := (height-start) / (height-leaf_bottom)
					verts[i].y = start + (verts[i].y-leaf_bottom) * vertical_scale
					var width := 1.16 if key.begins_with("pine") else 1.30
					verts[i].x *= width
					verts[i].z *= width
					normals[i] = Vector3(normals[i].x/width, normals[i].y/vertical_scale, normals[i].z/width).normalized()
				if not leaf and verts[i].y > 0.5 and verts[i].y < 2.0:
					trunk_radius = maxf(trunk_radius, Vector2(verts[i].x, verts[i].z).length())
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_COLOR] = colors
			arrays[Mesh.ARRAY_TANGENT] = null
			# Low branches must not inflate a trunk-only blocker or its distant stem.
			trunk_radius = clampf(trunk_radius, 0.20, 0.78 if key.begins_with("oak") else 0.55)
			var builder := ImporterMesh.new()
			builder.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
			builder.generate_lods(60.0, 25.0, [])
			var result := builder.get_mesh()
			if not leaf and key.begins_with("pine"):
				# Keep a clean lower stem; the vendor's long bare dead limbs read as a dead tree.
				result = _pine_stem(MODELS[key][1], trunk_radius)
			if not leaf:
				result.set_meta("trunk_radius", trunk_radius)
			# Only the alpha texture is used for leaves; shader supplies the palette.
			var material := StandardMaterial3D.new()
			if leaf:
				var texture_name := "Leaf_Pine_C" if key.begins_with("pine") else "Leaves_TwistedTree_C" if key.begins_with("bush") else "Leaves_NormalTree_C"
				var painted := OUTPUT + "masks/" + texture_name + ".png"
				material.albedo_texture = load(painted if ResourceLoader.exists(painted) else SOURCE + texture_name + ".png")
			material.resource_name = "LeafMask" if leaf else "Bark"
			result.surface_set_material(0, material)
			var mi := MeshInstance3D.new()
			mi.name = "leaf" if leaf else "trunk"
			mi.mesh = result
			root.add_child(mi)
			mi.owner = root
			triangle_count += result.surface_get_array_index_len(0) / 3
			if leaf:
				var clusters := _clusters(verts, 9 if key.begins_with("oak") else 7)
				_add_mesh(proxy, "leaf", _pine_proxy(verts, MODELS[key][1], key) if key.begins_with("pine") else _cluster_mesh(clusters, MODELS[key][1], 0.93))
				if key.begins_with("oak"):
					# Opaque inner volumes close holes; alpha cards only soften the outer contour.
					_add_mesh(root, "leaf_core", _cluster_mesh(clusters, MODELS[key][1], 0.56))
					var fill := _leaf_shell(clusters, MODELS[key][1], hash(key), 42, 0.72)
					# Keep the extra foliage in the same batch/material as the existing cards.
					var joined := SurfaceTool.new()
					joined.append_from(result, 0, Transform3D.IDENTITY)
					joined.append_from(fill, 0, Transform3D.IDENTITY)
					var merged := ImporterMesh.new()
					merged.add_surface(Mesh.PRIMITIVE_TRIANGLES, joined.commit().surface_get_arrays(0))
					merged.generate_lods(60.0, 25.0, [])
					mi.mesh = merged.get_mesh()
					mi.mesh.surface_set_material(0, material)
				elif key.begins_with("pine"):
					_add_mesh(root, "leaf_core", _pine_proxy(verts, MODELS[key][1], key, 0.62))
			else:
				# Retain the authored forks and root flare in the coarsest native bark LOD.
				var low_arrays := arrays.duplicate()
				var lod_count := builder.get_surface_lod_count(0)
				for level in lod_count:
					var indices := builder.get_surface_lod_indices(0, level)
					if indices.size() < arrays[Mesh.ARRAY_INDEX].size() * 0.25: break
					low_arrays[Mesh.ARRAY_INDEX] = indices
				var stem_mesh := ArrayMesh.new()
				stem_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, low_arrays)
				if key.begins_with("pine"):
					stem_mesh = _pine_stem(MODELS[key][1], trunk_radius)
				stem_mesh.set_meta("trunk_radius", trunk_radius)
				_add_mesh(proxy, "trunk", stem_mesh)
		var packed := PackedScene.new()
		triangle_count = 0
		for instance in root.get_children():
			triangle_count += instance.mesh.surface_get_array_index_len(0) / 3
		assert(packed.pack(root) == OK)
		assert(ResourceSaver.save(packed, OUTPUT + key + ".scn") == OK)
		_save(proxy, OUTPUT + "proxy/" + key + ".scn")
		print("NATURE ", key, " triangles=", triangle_count, " height=", MODELS[key][1])
		root.free()
		source.free()
	for variant in 2:
		_birch(variant)
	quit()

func _save(root: Node3D, path: String) -> void:
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	root.free()

func _add_mesh(root: Node3D, label: String, mesh: ArrayMesh, mask: Texture2D = null) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_texture = mask
	mesh.surface_set_material(0, material)
	var mi := MeshInstance3D.new()
	mi.name = label
	mi.mesh = mesh
	root.add_child(mi)
	mi.owner = root

func _clusters(vertices: PackedVector3Array, count: int) -> Array:
	# Deterministic spatial clusters fitted to the actual crown, not unrelated old trees.
	var centres: Array[Vector3] = [vertices[0]]
	for k in range(1, count):
		var best := Vector3.ZERO
		var distance := -1.0
		for v in vertices:
			var nearest := INF
			for c in centres: nearest = minf(nearest, v.distance_squared_to(c))
			if nearest > distance:
				distance = nearest
				best = v
		centres.append(best)
	var groups := []
	for iteration in 7:
		groups.clear()
		for k in count: groups.append([])
		for v in vertices:
			var nearest := INF
			var selected := 0
			for k in count:
				var d := v.distance_squared_to(centres[k])
				if d < nearest:
					nearest = d
					selected = k
			groups[selected].append(v)
		for k in count:
			if groups[k].is_empty(): continue
			var sum := Vector3.ZERO
			for v in groups[k]: sum += v
			centres[k] = sum / groups[k].size()
	var result := []
	for group in groups:
		if group.is_empty(): continue
		var box := AABB(group[0], Vector3.ZERO)
		for v in group: box = box.expand(v)
		result.append([box.get_center(), box.size * 0.5])
	return result

func _cluster_mesh(clusters: Array, height: float, scale_v: float = 1.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 10
	sphere.rings = 5
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for item in clusters:
		var centre: Vector3 = item[0]
		var radius: Vector3 = item[1] * scale_v
		for index in indices:
			var normal := vertices[index].normalized()
			var ripple := 1.0 + sin(normal.x*8.0+normal.z*6.0+centre.y)*0.045 + sin(normal.y*11.0+normal.x*5.0)*0.025
			var p: Vector3 = centre + normal * radius * ripple
			var hy := clampf(p.y / height, 0.0, 1.0)
			st.set_color(Color(0.94, 0.85, hy, 1.0))
			st.set_normal(((p-Vector3(0,height*0.63,0)).normalized()+Vector3.UP*0.3).normalized())
			st.add_vertex(p)
	st.index()
	return st.commit()

func _pine_stem(height: float, radius: float) -> ArrayMesh:
	var stem := SurfaceTool.new()
	stem.begin(Mesh.PRIMITIVE_TRIANGLES)
	_limb(stem, Vector3(0,-0.15,0), Vector3(0,height*0.76,0), radius,0.06)
	return stem.commit()

func _pine_proxy(vertices: PackedVector3Array, height: float, key: String, width: float = 1.0) -> ArrayMesh:
	# Keep the established serrated skirts; fit them to each new crown's width and start height.
	var source: Node3D = load("res://assets/models/veg/pine_%d.glb" % (1 if key == "pine_1" else 0)).instantiate()
	var leaf: MeshInstance3D
	for node in source.find_children("*", "MeshInstance3D", true, false):
		if String(node.name).contains("leaf"): leaf = node
	assert(leaf != null)
	var arrays := leaf.mesh.surface_get_arrays(0)
	var old_box := leaf.mesh.get_aabb()
	var box := AABB(vertices[0], Vector3.ZERO)
	for v in vertices: box = box.expand(v)
	var scale_v := box.size / old_box.size
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors := PackedColorArray()
	for i in verts.size():
		verts[i] = (verts[i]-old_box.position)*scale_v + box.position
		verts[i].x *= width
		verts[i].z *= width
		if width < 1.0:
			# The solid support must stay inside the cutout needle silhouette.
			verts[i].y = box.position.y + 1.0 + (verts[i].y-box.position.y) * (box.size.y-1.6)/box.size.y
		normals[i] = (normals[i]/scale_v).normalized()
		colors.append(Color(0.94,0.85,clampf(verts[i].y/height,0,1),1))
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TANGENT] = null
	var builder := ImporterMesh.new()
	builder.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	builder.generate_lods(60.0,25.0,[])
	source.free()
	return builder.get_mesh()

func _limb(st: SurfaceTool, p0: Vector3, p1: Vector3, r0: float, r1: float) -> void:
	var axis := (p1 - p0).normalized()
	var side := axis.cross(Vector3.FORWARD).normalized()
	var other := axis.cross(side).normalized()
	for i in 8:
		var a := float(i) * TAU / 8.0
		var b := float(i + 1) * TAU / 8.0
		var na := side * cos(a) + other * sin(a)
		var nb := side * cos(b) + other * sin(b)
		for v in [[p0+na*r0,na], [p1+na*r1,na], [p0+nb*r0,nb], [p0+nb*r0,nb], [p1+na*r1,na], [p1+nb*r1,nb]]:
			st.set_color(Color.WHITE)
			st.set_normal(v[1])
			st.add_vertex(v[0])

func _birch(variant: int) -> void:
	var root := Node3D.new()
	root.name = "birch_%d" % variant
	var proxy := Node3D.new()
	proxy.name = root.name
	var rng := RandomNumberGenerator.new()
	rng.seed = 901 + variant * 71
	var clusters := []
	var template := [Vector3(-2.1, 6.3, -0.1), Vector3(1.9, 6.8, 0.35), Vector3(-1.25, 8.7, 0.4), Vector3(1.5, 9.4, -0.15), Vector3(-0.2, 10.9, 0), Vector3(0, 7.3, -1.65), Vector3(0.6, 8.4, 1.55), Vector3(-0.4, 6.4, 1.2), Vector3(-0.1, 8.8, -1.4), Vector3(1.15, 10.25, 0.55), Vector3(-1.6, 9.8, -0.35)]
	var trunk := SurfaceTool.new()
	trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	var previous := Vector3(0, -0.18, 0)
	for i in range(1, 6):
		var next := Vector3(sin(i * 0.8 + variant) * 0.28, i * 2.2, sin(i * 0.7) * 0.12)
		_limb(trunk, previous, next, lerpf(0.34, 0.05, float(i-1)/5), lerpf(0.34, 0.05, float(i)/5))
		previous = next
	for point in template:
		point.x *= -1.0 if variant == 1 else 1.0
		point += Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.25, 0.25), rng.randf_range(-0.3, 0.3))
		var radius := Vector3(rng.randf_range(1.65, 2.05), rng.randf_range(1.5, 1.8), rng.randf_range(1.5, 1.85))
		clusters.append([point, radius])
		var base := Vector3(0.1, point.y - 2.3, 0)
		var elbow := base.lerp(point, 0.55) + Vector3.UP * 0.15
		_limb(trunk, base, elbow, 0.13, 0.07)
		_limb(trunk, elbow, point, 0.07, 0.025)
	var bark := trunk.commit()
	bark.set_meta("trunk_radius", 0.36)
	_add_mesh(root, "trunk", bark)
	_add_mesh(proxy, "trunk", bark)
	_add_mesh(root, "leaf_core", _cluster_mesh(clusters, 13.0, 0.68))
	_add_mesh(proxy, "leaf", _cluster_mesh(clusters, 13.0, 1.10))
	_add_mesh(root, "leaf_cards", _leaf_shell(clusters, 13.0, 171+variant, 60, 0.94), load(OUTPUT + "masks/Leaves_NormalTree_C.png"))
	_save(root, OUTPUT + "birch_%d.scn" % variant)
	_save(proxy, OUTPUT + "proxy/birch_%d.scn" % variant)
	print("NATURE birch_", variant, " overlapping crown, 1320 leaf-card triangles")

func _leaf_shell(clusters: Array, height: float, seed_value: int, count: int, shell_radius: float) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cards := SurfaceTool.new()
	cards.begin(Mesh.PRIMITIVE_TRIANGLES)
	for item in clusters:
		for i in count:
			var normal := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.8, 1), rng.randf_range(-1, 1)).normalized()
			var p: Vector3 = item[0] + normal * item[1] * rng.randf_range(shell_radius*0.85, shell_radius)
			var side := normal.cross(Vector3.UP).normalized()
			var up := side.cross(normal).normalized()
			var size := rng.randf_range(0.65, 0.95)
			for uv in [Vector2(0,0), Vector2(1,0), Vector2(0,1), Vector2(1,0), Vector2(1,1), Vector2(0,1)]:
				var v: Vector3 = p + (side*(uv.x-0.5) + up*(uv.y-0.5)) * size * 2.0
				cards.set_uv(uv)
				cards.set_normal((normal + Vector3.UP * 0.3).normalized())
				cards.set_color(Color(0.94, 0.85, clampf(v.y/height,0,1),1))
				cards.add_vertex(v)
	cards.index()
	var builder := ImporterMesh.new()
	builder.add_surface(Mesh.PRIMITIVE_TRIANGLES, cards.commit().surface_get_arrays(0))
	builder.generate_lods(60.0, 25.0, [])
	return builder.get_mesh()
