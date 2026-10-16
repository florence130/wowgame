extends Node
## Read-only city snapshot. Never instances the zone or starts gameplay.
## Run this scene after generating the city; generated GLBs contain visuals only.

const PLAN := "res://docs/city_v5/layout.json"
const SCENE := "res://scenes/zones/tidewind_highlands.tscn"
const TERRAIN := "res://data/terrain/tidewind.res"
const GROUND_PLAN := "res://docs/city_v5/ground_plan.json"
const OUT := "res://tools/city_web/city-data.json"
const GLB_DIR := "res://tools/city_web/exported/"
const MIN_X := -1040.0
const MAX_X := 400.0
const MIN_Z := 160.0
const MAX_Z := 1200.0

var assets: Dictionary = {}
var asset_paths: Dictionary = {}
var material_cache: Dictionary = {}
var errors: Array[String] = []
var exported_meshes := 0
var skipped: Array = []
var ground_asset_keys: Dictionary = {}
var collision_assets: Dictionary = {}
var asset_source_hashes: Dictionary = {}

func collect_ground_collision(node: Node, parent_xf: Transform3D, vertices: Array) -> void:
	var xf := parent_xf
	if node is Node3D: xf = parent_xf * node.transform
	if node is CollisionShape3D and node.shape != null and not node.disabled:
		if node.shape is ConcavePolygonShape3D:
			for point in node.shape.get_faces(): vertices.append(xyz(xf * point))
		else:
			fail("Unsupported ground collision shape: " + node.name)
	for child in node.get_children(): collect_ground_collision(child, xf, vertices)

func _ready() -> void:
	Game.slot_index = -1
	if "validate_only" in OS.get_cmdline_user_args():
		print("CITY WEB EXPORT SCRIPT VALIDATED")
		get_tree().quit(0)
		return
	call_deferred("run")

func fail(message: String) -> void:
	errors.append(message)
	push_error(message)

func properties(state: SceneState, index: int) -> Dictionary:
	var result := {}
	for j in state.get_node_property_count(index):
		result[String(state.get_node_property_name(index, j))] = state.get_node_property_value(index, j)
	return result

func xyz(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func export_material(source: Material) -> Material:
	if source == null:
		return null
	var key := source.get_instance_id()
	if material_cache.has(key):
		return material_cache[key]
	if source is BaseMaterial3D:
		material_cache[key] = source
		return source
	var result := StandardMaterial3D.new()
	result.resource_name = source.resource_name
	result.roughness = 0.9
	if source is ShaderMaterial:
		# Procedural world-space shading has no GLTF equivalent. Preserve the
		# authored base color and geometry, documenting this simplification.
		for parameter in ["base_color", "albedo", "color"]:
			var value: Variant = source.get_shader_parameter(parameter)
			if value is Color:
				result.albedo_color = value
				break
	if result.albedo_color.a < 0.999:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_cache[key] = result
	return result

func collect_meshes(node: Node, parent_xf: Transform3D, output: Node3D) -> void:
	var name_lower := String(node.name).to_lower()
	if "colonly" in name_lower or "collision" in name_lower:
		return
	if node is Node3D and not node.visible:
		return
	var xf := parent_xf
	if node is Node3D:
		xf = parent_xf * node.transform
	if node is MeshInstance3D and node.mesh != null:
		var copy := MeshInstance3D.new()
		copy.name = "Mesh_%04d_%s" % [output.get_child_count(), node.name]
		copy.mesh = node.mesh
		copy.transform = xf
		for surface in node.mesh.get_surface_count():
			copy.set_surface_override_material(surface, export_material(node.get_active_material(surface)))
		output.add_child(copy)
		copy.owner = output
		exported_meshes += 1
	for child in node.get_children():
		collect_meshes(child, xf, output)

func export_glb(root: Node, key: String) -> bool:
	var visual := Node3D.new()
	visual.name = key.validate_node_name()
	collect_meshes(root, Transform3D.IDENTITY, visual)
	if visual.get_child_count() == 0:
		fail("No visual mesh in " + key)
		visual.free()
		return false
	var document := GLTFDocument.new()
	var gltf := GLTFState.new()
	var result := document.append_from_scene(visual, gltf)
	if result != OK:
		fail("GLTF append failed for %s: %s" % [key, result])
		visual.free()
		return false
	var path := GLB_DIR + key.validate_filename() + ".glb"
	result = document.write_to_filesystem(gltf, path)
	visual.free()
	if result != OK:
		fail("GLTF write failed for %s: %s" % [key, result])
		return false
	assets[key] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(path))
	return true

func native_asset(path: String, key: String) -> bool:
	if assets.has(key):
		if asset_paths[key] != path:
			fail("Asset ID collision: " + key)
			return false
		return true
	asset_paths[key] = path
	asset_source_hashes[key] = FileAccess.get_sha256(path)
	if path.get_extension() == "glb":
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.is_empty():
			fail("Missing native GLB: " + path)
			return false
		assets[key] = Marshalls.raw_to_base64(bytes)
		return true
	var packed := load(path) as PackedScene
	if packed == null:
		fail("Missing civil scene: " + path)
		return false
	var root := packed.instantiate()
	if ground_asset_keys.has(key):
		var vertices: Array = []
		collect_ground_collision(root, Transform3D.IDENTITY, vertices)
		if vertices.is_empty(): fail("Ground mesh has no physical collision: " + key)
		var triangles: Array = []
		for i in range(0, vertices.size(), 3): triangles.append([i, i + 1, i + 2])
		collision_assets[key] = {"vertices": vertices, "triangles": triangles, "source": path, "sourceSha256": asset_source_hashes[key], "coordinateSpace": "asset-local", "shape": "ConcavePolygonShape3D"}
	var result := export_glb(root, key)
	root.free()
	return result

func legacy_asset(props: Dictionary, id: String) -> String:
	var prop := ModelProp.new()
	for field in ["kind", "variant", "size", "color_a", "color_b", "color_c", "label", "seed_v"]:
		if props.has(field):
			prop.set(field, props[field])
	prop.transform = props.get("transform", Transform3D.IDENTITY)
	prop.flag = ""
	prop.collide = false
	var signature := props.duplicate()
	for field in ["transform", "script", "seed_v"]:
		signature.erase(field)
	# Seed affects static geometry only through Tripo selection. Recording the
	# selected asset lets identical lamps and benches share one browser mesh.
	signature["selected_tripo"] = prop._tripo_id()
	signature["selected_kit"] = preload("res://src/world/goldshire_kit.gd").choice(prop)
	var key := "legacy_" + str(props.get("kind", "house")) + "_" + var_to_str(signature).sha256_text().left(12)
	if assets.has(key):
		prop.free()
		return key
	# Off-tree rebuild uses the game's real asset choice, scale and pivot.
	# Only static mesh descendants are copied; no logic enters the SceneTree.
	prop.rebuild()
	var result := export_glb(prop._gen, key)
	prop.free()
	if not result:
		fail("Cannot export legacy scenery " + id)
		return ""
	return key

func terrain_snapshot(data: TerrainData, origin: Vector2) -> Dictionary:
	# Sample on the native grid for a faithful surface, cropped to city bounds.
	var step := data.cell_size
	var cols := int(round((MAX_X - MIN_X) / step)) + 1
	var rows := int(round((MAX_Z - MIN_Z) / step)) + 1
	var heights := []
	var surface_colors := PackedByteArray()
	surface_colors.resize(cols * rows * 3)
	heights.resize(rows * cols)
	for row in rows:
		for col in cols:
			var lx: float = MIN_X + col * step - origin.x
			var lz: float = MIN_Z + row * step - origin.y
			var index := row * cols + col
			heights[index] = snappedf(data.sample(lx, lz), 0.001)
			var weights := data.get_layer(clampi(int(lx / step), 0, data.resolution - 1), clampi(int(lz / step), 0, data.resolution - 1))
			var total := 0.0
			var color := Color(0, 0, 0, 1)
			for layer in 8:
				total += weights[layer]
				color += data.layer_colors[layer + 1] * weights[layer]
			color += data.layer_colors[0] * maxf(0, 1 - total)
			surface_colors[index * 3] = roundi(clampf(color.r, 0, 1) * 255)
			surface_colors[index * 3 + 1] = roundi(clampf(color.g, 0, 1) * 255)
			surface_colors[index * 3 + 2] = roundi(clampf(color.b, 0, 1) * 255)
	return {"origin": [MIN_X, MIN_Z], "size": [MAX_X - MIN_X, MAX_Z - MIN_Z], "cols": cols, "rows": rows, "heights": heights, "waterLevel": data.water_level, "nativeCellSize": data.cell_size, "surfaceColors": Marshalls.raw_to_base64(surface_colors), "surfaceColorEncoding": "rgb8-srgb-from-actual-layer-weights", "surfaceColorScope": "Actual TerrainData layer weights and palette; lighting and texture microdetail remain simplified."}

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GLB_DIR))
	var baseline_hash := FileAccess.get_sha256(PLAN)
	var scene_hash := FileAccess.get_sha256(SCENE)
	var terrain_hash := FileAccess.get_sha256(TERRAIN)
	var ground_hash := FileAccess.get_sha256(GROUND_PLAN) if FileAccess.file_exists(GROUND_PLAN) else ""
	var ground_plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GROUND_PLAN)) if ground_hash != "" else {}
	var ground_by_scene_id: Dictionary = {}
	for collection in ["faces", "edges", "links"]:
		for item in ground_plan.get(collection, []):
			ground_by_scene_id[item.get("sceneId", "ground_" + str(item.id))] = item
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PLAN))
	var building_by_id := {}
	for b in layout.buildings:
		building_by_id[b.id] = b
	var packed := load(SCENE) as PackedScene
	var state := packed.get_state()
	var origin := Vector2.ZERO
	var scene_objects := []
	var found_buildings := {}
	var object_ids := {}
	var native_count := 0
	var legacy_count := 0
	for i in state.get_node_count():
		var id := String(state.get_node_name(i))
		var props := properties(state, i)
		var xf: Transform3D = props.get("transform", Transform3D.IDENTITY)
		if id == "Terrain":
			origin = Vector2(xf.origin.x, xf.origin.z)
		var group := String(state.get_node_path(i, true)).trim_prefix("./")
		if group not in ["Buildings", "Props"]:
			continue
		if not props.has("script") or props.script.resource_path != "res://src/world/model_prop.gd":
			continue
		if xf.origin.x < MIN_X or xf.origin.x > MAX_X or xf.origin.z < MIN_Z or xf.origin.z > MAX_Z:
			skipped.append({"id": id, "reason": "outside_city_bounds"})
			continue
		var authored: Dictionary = building_by_id.get(id, {})
		if object_ids.has(id):
			fail("Duplicate object ID across city groups: " + id)
			continue
		object_ids[id] = true
		var path: String = props.get("asset_scene", "")
		var asset := ""
		if path != "":
			asset = authored.get("asset", path.get_file().get_basename())
			if id.begins_with("ground_"): ground_asset_keys[asset] = true
			if not native_asset(path, asset):
				continue
			native_count += 1
		else:
			asset = legacy_asset(props, id)
			if asset == "":
				continue
			legacy_count += 1
		var row := {"id": id, "asset": asset, "position": xyz(xf.origin), "yaw": rad_to_deg(xf.basis.get_euler().y), "scale": xyz(xf.basis.get_scale()), "family": authored.get("family", "civil" if path != "" and group == "Buildings" else "scenery"), "kind": props.get("kind", "house"), "label": props.get("label", ""), "sourceGroup": group}
		if id.begins_with("ground_"):
			var ground_item: Dictionary = ground_by_scene_id.get(id, {})
			if ground_item.is_empty(): fail("Ground scene object missing from ground_plan: " + id)
			row["groundId"] = ground_item.get("id", id)
			row["groundKind"] = ground_item.get("kind", "paving")
			row["groundMaterial"] = ground_item.get("material", row.groundKind)
			row["groundPlanSha256"] = ground_hash
		if id.begins_with("road_"):
			row["layoutRoadId"] = id.trim_prefix("road_")
		if authored.size() > 0:
			found_buildings[id] = true
			row["size"] = authored.size
			if Vector2(xf.origin.x, xf.origin.z).distance_to(Vector2(authored.c[0], authored.c[1])) > 0.02 or absf(wrapf(float(row.yaw) - float(authored.yaw), -180, 180)) > 0.01:
				fail("Scene/layout pose mismatch; regenerate city first: " + id)
			# Both v5 architectural manifests and _buildings() specify this lift.
			# This validates consistency; the exported Y still comes from the scene.
			if authored.has("y") and absf(xf.origin.y - float(authored.y) - 0.6) > 0.02:
				fail("Scene/layout street elevation mismatch; regenerate city first: " + id)
		scene_objects.append(row)
	for id in building_by_id:
		if not found_buildings.has(id):
			fail("Missing authored building in export: " + id)
	var data := load(TERRAIN) as TerrainData
	var terrain := terrain_snapshot(data, origin)
	var stable := baseline_hash == FileAccess.get_sha256(PLAN) and scene_hash == FileAccess.get_sha256(SCENE) and terrain_hash == FileAccess.get_sha256(TERRAIN)
	stable = stable and (ground_hash == "" or ground_hash == FileAccess.get_sha256(GROUND_PLAN))
	if not ground_plan.is_empty() and ground_asset_keys.is_empty(): fail("Ground plan exists but the saved city has no ground_* geometry; regenerate the city before export")
	for scene_id in ground_by_scene_id:
		var item: Dictionary = ground_by_scene_id[scene_id]
		if item.get("vertices", item.get("mesh", {}).get("vertices", [])).size() > 0 and not object_ids.has(scene_id): fail("Ground plan mesh missing from saved scene: " + scene_id)
	if not stable:
		fail("City changed during export; regenerate snapshot after generation finishes")
	var output := {"schemaVersion": 2, "baselineHash": baseline_hash, "sceneHash": scene_hash, "terrainHash": terrain_hash, "groundPlanHash": ground_hash, "groundPlan": ground_plan, "collisionAssets": collision_assets, "assetSourceHashes": asset_source_hashes, "layout": layout, "sceneObjects": scene_objects, "assets": assets, "terrain": terrain, "exportNotes": ["City-local coordinates and actual saved-scene transforms.", "Native GLBs preserve authored geometry; collision-only meshes are not drawn.", "Ground visuals and actual collision triangles are exported from the same saved civil assets, linked to ground_plan.", "Ground paving uses metre-scaled browser stone joints; terrain colors come from actual paint weights. Other procedural Godot materials retain authored base colors.", "No NPCs, gameplay logic, animations or UI included."], "exportedAt": Time.get_datetime_string_from_system(true)}
	var summary := {"success": errors.is_empty(), "stable": stable, "buildings": found_buildings.size(), "objects": scene_objects.size(), "nativeObjects": native_count, "legacyObjects": legacy_count, "assets": assets.size(), "exportedMeshes": exported_meshes, "terrainCols": terrain.cols, "terrainRows": terrain.rows, "baselineHash": baseline_hash, "sceneHash": scene_hash, "terrainHash": terrain_hash, "skipped": skipped, "errors": errors}
	summary["groundPlanHash"] = ground_hash
	summary["groundObjects"] = ground_asset_keys.size()
	summary["collisionAssets"] = collision_assets.size()
	if errors.is_empty():
		var file := FileAccess.open(OUT, FileAccess.WRITE)
		file.store_string(JSON.stringify(output))
		file.close()
	var report := FileAccess.open("res://tools/city_web/export-summary.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(summary, "  "))
	report.close()
	print("CITY WEB EXPORT: " + JSON.stringify(summary))
	get_tree().quit(0 if errors.is_empty() else 1)
