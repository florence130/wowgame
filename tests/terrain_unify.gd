extends Node3D

var failed := 0
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failed += 1

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.shots/terrain_unify_20261011"))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -30, 0)
	add_child(light)
	var camera := Camera3D.new()
	camera.current = true
	add_child(camera)
	var road_weights := []
	for id in ["vale", "tidewind"]:
		var data := load("res://data/terrain/%s.res" % id) as TerrainData
		check(data.layer_colors == PackedColorArray(ArtStyle.TERRAIN_COLORS), id + " shared palette")
		var zone := Node3D.new()
		zone.position = WorldLayout.offset(id)
		add_child(zone)
		var terrain := BrushTerrain.new()
		terrain.data = data
		terrain.position = Vector3.ZERO if id == "vale" else Vector3(GenTidewind.ORIGIN.x, 0, GenTidewind.ORIGIN.y)
		terrain.chunk_cells = data.resolution
		terrain.streamed = true
		terrain.collision_enabled = false
		zone.add_child(terrain)
		var grass := GrassField.new()
		zone.add_child(grass)
		grass.setup(terrain)
		grass.set_process(false)
		var local_road := Vector2(1.25 if id == "vale" else -1.25, WorldLayout.ROAD_Z) - Vector2(terrain.global_position.x, terrain.global_position.z)
		road_weights.append(data.get_layer(int(local_road.x / data.cell_size), int(local_road.y / data.cell_size))[1])
		check(grass._density(1.25 if id == "vale" else -1.25, WorldLayout.ROAD_Z) < 0.02, id + " road excludes grass")
		var found := false
		for z in range(320, 720, 24):
			for x in range(24 if id == "vale" else -240, 240 if id == "vale" else -24, 24):
				if grass._density(x, z) < 0.5 or terrain.get_normal_global(x, z).y < 0.85 or terrain.get_height_global(x, z) < terrain.water_level_global() + 2:
					continue
				var k := Vector2i(floori(x / 24.0), floori(z / 24.0))
				var chunk := grass._build(k)
				if chunk == null:
					continue
				check(chunk.global_transform.is_equal_approx(Transform3D.IDENTITY), id + " grass world transform has no duplicate zone offset")
				var mi := chunk.get_child(0) as MultiMeshInstance3D
				var p := mi.global_transform * mi.multimesh.get_instance_transform(0).origin
				print("GROUND SAMPLE ", id, " ", p, " sampled=", terrain.get_height_global(p.x, p.z), " transform=", mi.global_transform)
				check(absf(p.y - terrain.get_height_global(p.x, p.z) + 0.04) < 0.01, id + " grass sits on actual ground")
				check(mi.material_override.shader == GrassField.SHADER, id + " actual shared grass shader")
				camera.position = p + Vector3(12, 8, 15)
				camera.look_at(p + Vector3(7, 0, 7))
				await get_tree().process_frame
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://.shots/terrain_unify_20261011/%s_grass.png" % id)
				found = true
				break
			if found:
				break
		check(found, id + " generated grass instances")
	camera.position = Vector3(12, 37, 515)
	camera.look_at(Vector3(0, 19, 490))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.shots/terrain_unify_20261011/road_crossing.png")
	check(absf(road_weights[0] - road_weights[1]) < 0.01 and road_weights[0] > 0.99, "crossing road control weights continuous")
	check(not FileAccess.get_file_as_string("res://src/ui/camp_sky.gdshader").contains("float red="), "selection red moon removed")
	print("TERRAIN RESULT failures=", failed)
	get_tree().quit(failed)
