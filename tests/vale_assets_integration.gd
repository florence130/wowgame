extends Node
## Render and physics evidence in the actual seamless world, without saving a character.
var out := "res://.shots/vale_runtime_v1"
var checks: Array = []
var captures: Array = []
var camera: Camera3D
var player: Player
var world: World
var started := Time.get_ticks_msec()

func _ready() -> void:
	if not has_meta("runner"):
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="): out = arg.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out.path_join(".gdignore"), FileAccess.WRITE)
	Game.new_character("建筑接入验收", "warrior", DB.random_appearance(7, "f"))
	Game.slot_index = -1
	Game.pd["zone"] = "vale"
	Game.pd["world_ver"] = WorldLayout.SAVE_VER
	Game.pd["pos"] = Vector3(485, 26, 80)
	Game.pd.erase("new")
	Game.pd["level"] = 15
	Game.pd["flags"]["city_access"] = true
	Game.time_of_day = 10.0
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")
	run.call_deferred()

func check(ok: bool, what: String, details = null) -> void:
	checks.append({"passed": ok, "check": what, "details": details})
	print(("PASS " if ok else "FAIL ") + what + " " + str(details))

func run() -> void:
	await get_tree().process_frame
	while Game.world == null or Game.world.loading or Game.player == null:
		await get_tree().create_timer(1.0).timeout
		if Time.get_ticks_msec() - started > 240000:
			check(false, "world load timeout")
			finish()
			return
	world = Game.world
	player = Game.player
	await get_tree().create_timer(3.0).timeout
	world.weather = "clear"
	world.weather_amt = 0.0
	world.weather_t = 99999.0
	Game.time_of_day = 10.0
	world._update_sky(0.0)
	check(world.zones.has("vale") and world.zones.has("tidewind"), "actual seamless world loaded", world.zones.keys())
	var buildings: Node = world.zones["vale"].get_node("Buildings")
	var targets := {"abbey_chapel_0": "chapel", "abbey_campanile_1": "belltower", "house_27": "farm", "house_28": "barn", "windmill_29": "windmill"}
	var assigned := 0
	for prop in buildings.get_children():
		if prop is ModelProp and prop.asset_scene != "": assigned += 1
	check(assigned == 5, "exactly five explicit valley assignments", assigned)
	for zone_id in world.zones:
		if zone_id == "vale": continue
		var other_count := 0
		for prop in world.zones[zone_id].get_node("Buildings").get_children():
			if prop is ModelProp and prop.asset_scene != "": other_count += 1
		check(other_count == 0, "no modular replacement in " + zone_id, other_count)
	for node_name in targets:
		var prop := buildings.get_node(node_name) as ModelProp
		check(prop.get_meta("modular_asset_scene", "") == prop.asset_scene and not prop.asset_scene.is_empty(), targets[node_name] + " loaded explicit asset", prop.asset_scene)
		var assembly := prop.get_node("_gen").get_child(0) as Node3D
		check(assembly.scale.is_equal_approx(Vector3.ONE), targets[node_name] + " keeps metric scale", assembly.scale)
		var meshes := assembly.find_children("*", "MeshInstance3D", true, false)
		var tris := 0
		var textured := 0
		var glass := 0
		for node in meshes:
			var mesh := node as MeshInstance3D
			for surface in mesh.mesh.get_surface_count():
				tris += mesh.mesh.surface_get_array_index_len(surface) / 3
				var mat := mesh.get_active_material(surface) as BaseMaterial3D
				if mat != null and mat.albedo_texture != null: textured += 1
				if mat != null and mat.resource_name.contains("glass") and mat.albedo_color.a < 0.9:
					glass += 1
		check(textured > 0, targets[node_name] + " authored textures survive", {"mesh_nodes": meshes.size(), "triangles": tris, "textured_surfaces": textured, "transparent_surfaces": glass})
		if targets[node_name] == "chapel": check(glass > 0, "chapel actual transparent glass")
	var chapel := buildings.get_node("abbey_chapel_0") as ModelProp
	var mill := buildings.get_node("windmill_29") as ModelProp
	var rotor := mill.get_node("_gen").get_child(0).get_node_or_null("Rotor") as Node3D
	check(rotor != null, "windmill has one independent rotor")
	if rotor != null:
		var before := rotor.rotation.z
		await get_tree().create_timer(0.5).timeout
		check(absf(rotor.rotation.z - before) > 0.05, "windmill rotor actually animates", rotor.rotation.z - before)
	# Use the real Player capsule/controller. autorun invokes its normal gravity/move_and_slide.
	await walk(chapel, Vector3(0, 0.1, -12.8), Vector3(0, 0, -6), "outside stairs and open portal")
	await walk(chapel, Vector3(0, 1.0, -6), Vector3(0, 0, 2.1), "central aisle")
	await walk(chapel, Vector3(0, 1.0, 2.1), Vector3(0, 0, 5.3), "altar wooden stairs")
	await walk(chapel, Vector3(0, 1.5, 5.3), Vector3(0, 0, -12.3), "return through door and down entry stairs")
	player.autorun = false
	player.set_physics_process(false)
	player.set_process(false)
	player.visible = false
	world.hud.visible = false
	camera = Camera3D.new()
	camera.fov = 60
	camera.near = 0.05
	camera.far = 3600
	world.add_child(camera)
	camera.make_current()
	await shot("chapel_exterior", chapel, Vector3(18, 12, -25), Vector3(0, 4.5, 0))
	await shot("chapel_interior", chapel, Vector3(0, 2.55, -7), Vector3(0, 3.0, 6))
	await shot("chapel_glass", chapel, Vector3(0, 2.6, -2.0), Vector3(4, 3.2, 0))
	await shot("chapel_entry", chapel, Vector3(4, 2.5, -12.5), Vector3(0, 1.3, -8.0))
	await shot("belltower", buildings.get_node("abbey_campanile_1"), Vector3(18, 13, -24), Vector3(0, 8, 0))
	await shot("farm", buildings.get_node("house_27"), Vector3(20, 11, -24), Vector3(0, 5, 0))
	await shot("barn", buildings.get_node("house_28"), Vector3(23, 13, -26), Vector3(0, 6, 0))
	await shot("windmill", mill, Vector3(23, 14, -26), Vector3(0, 9, 0))
	finish()

func walk(prop: Node3D, start: Vector3, end: Vector3, name_: String) -> void:
	player.autorun = false
	player.global_position = prop.to_global(start)
	player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.25).timeout
	var destination := prop.to_global(end)
	player.face_towards(destination)
	player.walking = true
	player.autorun = true
	var elapsed := 0.0
	var closest := INF
	var minimum_y := player.global_position.y
	while elapsed < 16.0:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		var distance := Vector2(player.global_position.x-destination.x, player.global_position.z-destination.z).length()
		closest = minf(closest, distance)
		minimum_y = minf(minimum_y, player.global_position.y)
		if distance < 0.25: break
	player.autorun = false
	check(closest < 0.3 and minimum_y > prop.global_position.y - 0.2, "real Player walk: " + name_, {"closest_m": closest, "local_end": prop.to_local(player.global_position), "min_world_y": minimum_y, "seconds": elapsed})

func shot(name_: String, prop: Node3D, from: Vector3, to: Vector3) -> void:
	player.global_position = prop.to_global(to)
	camera.position = prop.to_global(from)
	camera.look_at(prop.to_global(to), Vector3.UP)
	await get_tree().create_timer(1.5).timeout
	var timings: Array = []
	for frame in 30:
		await get_tree().process_frame
		timings.append(get_process_delta_time() * 1000.0)
	await RenderingServer.frame_post_draw
	var path := out.path_join(name_ + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	timings.sort()
	captures.append({"file": path, "median_frame_ms": timings[15], "p95_frame_ms": timings[28], "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "rendered_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	print("CAPTURE ", captures[-1])

func finish() -> void:
	var failed := checks.filter(func(row): return not row.passed).size()
	var result := {"passed": failed == 0, "failures": failed, "checks": checks, "captures": captures, "no_character_save": Game.slot_index == -1, "scope": "Actual loaded seamless game world, real Player controller and Godot rendered screenshots; performance is whole-scene observation, not an isolated benchmark."}
	FileAccess.open(out.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "  "))
	print("VALE INTEGRATION RESULT ", JSON.stringify(result))
	get_tree().quit(0 if failed == 0 else 1)
