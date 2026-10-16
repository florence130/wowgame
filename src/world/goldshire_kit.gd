extends RefCounted
## Native-size hollow village kit. Never pass through ModelProp recolour or box collision.
const DIR := "res://assets/models/goldshire_kit_v1/build_004/"
const LABELS := {"铁匠铺": "smithy", "杂货店": "general_store", "裁缝铺": "tailor", "金穗旅店": "tavern", "治安所": "guard_tower"}
const HOMES := ["home_cottage", "home_long", "home_loft", "home_porch", "home_wing", "home_broad"]
const HOME_POINTS := [Vector2(375,430), Vector2(495,432), Vector2(371,510), Vector2(497,514), Vector2(415,408), Vector2(469,406), Vector2(395,532)]
static var cache: Dictionary = {}
const BAKED := "res://assets/streaming/goldshire/"
static var _baked_valid := {}

static func bake_signature(id: String) -> String:
	return FileAccess.get_sha256(DIR + "assemblies/" + id + ".glb") + ":" + FileAccess.get_sha256("res://src/world/goldshire_kit.gd")

static func baked_path(id: String) -> String:
	if not _baked_valid.has(id):
		var stamp := BAKED + id + ".sha256"
		_baked_valid[id] = FileAccess.file_exists(stamp) and FileAccess.get_file_as_string(stamp).strip_edges() == bake_signature(id)
	return BAKED + id + ".scn" if _baked_valid[id] and ResourceLoader.exists(BAKED + id + ".scn") else ""

static func choice(prop: Node3D) -> String:
	# Only Goldenear's local map coordinates. Other towns and abbey assets keep their paths.
	if prop.position.x < 355 or prop.position.x > 515 or prop.position.z < 395 or prop.position.z > 545:
		return ""
	if LABELS.has(prop.label):
		return LABELS[prop.label]
	if prop.kind == "house" and prop.label == "":
		# Stable across saved scenes; existing variant cycles only 3 and cannot cover six homes.
		var closest := 0
		var best := INF
		for i in HOME_POINTS.size():
			var distance := Vector2(prop.position.x, prop.position.z).distance_squared_to(HOME_POINTS[i])
			if distance < best:
				best = distance
				closest = i
		return HOMES[closest % HOMES.size()]
	return ""

static func try_build(prop: Node3D, target: Node3D) -> bool:
	var id := choice(prop)
	if id == "" or not FileAccess.file_exists(DIR + "assemblies/" + id + ".glb"):
		return false
	var instance := create(id, prop.collide and not Engine.is_editor_hint())
	if instance == null:
		return false
	target.add_child(instance)
	prop.set_meta("goldshire_asset", id)
	# Existing terrain is slightly sloped: floor sits at the building centre's terrain height.
	# Native-scale doors stay 2m wide rather than being compressed to legacy placeholder bounds.
	if not Engine.is_editor_hint():
		var terrain = U.terrain_at(prop.get_tree(), prop.global_position.x, prop.global_position.z)
		if terrain != null:
			var centre_y: float = terrain.get_height_global(prop.global_position.x, prop.global_position.z)
			instance.position.y = maxf(0.0, centre_y - prop.global_position.y)
	return true

static func create(id: String, collision := true, allow_baked := true) -> Node3D:
	var path := baked_path(id) if allow_baked else ""
	if path != "":
		var baked := (load(path) as PackedScene).instantiate() as Node3D
		if not collision:
			for body in baked.find_children("*", "CollisionObject3D", true, false):
				body.free()
		return baked
	if not cache.has(id):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var error := doc.append_from_file(ProjectSettings.globalize_path(DIR + "assemblies/" + id + ".glb"), state)
		if error != OK:
			push_error("Goldshire load failed: " + id)
			return null
		var source := doc.generate_scene(state)
		var surfaces: Dictionary = {}
		var faces := PackedVector3Array()
		for node in source.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			var xf := relative_transform(mi, source)
			var solid := not (mi.name.begins_with("Stair tread") or mi.name.begins_with("Stair stringer") or mi.name.begins_with("Baluster") or mi.name.begins_with("Stair handrail"))
			for i in mi.mesh.get_surface_count():
				var mat: Material = mi.get_active_material(i)
				var key: String = mat.resource_name if mat else "none"
				if not surfaces.has(key):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					st.set_material(mat)
					surfaces[key] = st
				(surfaces[key] as SurfaceTool).append_from(mi.mesh, i, xf)
			if solid:
				for vertex in mi.mesh.get_faces():
					faces.append(xf * vertex)
		# Smooth ramps are separate from visual treads; GLB extras keep their metric dimensions.
		for node in source.find_children("COLLISION_RAMP*", "Node3D", true, false):
			var xf := relative_transform(node, source)
			var w := 1.5
			var d := 5.4
			var h := 3.4
			var p := [Vector3(-w/2,0,-d/2), Vector3(w/2,0,-d/2), Vector3(w/2,h,d/2), Vector3(-w/2,h,d/2)]
			for idx in [0,2,1,0,3,2]:
				faces.append(xf * p[idx])
		var meshes: Array[ArrayMesh] = []
		for st in surfaces.values():
			meshes.append(st.commit())
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = true
		cache[id] = {"meshes": meshes, "shape": shape, "source_meshes": source.find_children("*", "MeshInstance3D", true, false).size()}
		source.free()
	var root := Node3D.new()
	root.name = "Goldshire_" + id
	root.set_meta("asset_id", id)
	for mesh in cache[id].meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		root.add_child(mi)
		var mat: Material = mesh.surface_get_material(0)
		if mat and mat.resource_name.contains("glass"):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if collision:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = cache[id].shape
		body.add_child(cs)
		root.add_child(body)
	return root

static func relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != ancestor and current != null:
		if current is Node3D:
			result = current.transform * result
		current = current.get_parent()
	return result
