extends Node
## Fixed-camera visual regression. Disposable character; no saved settings/characters.
var out := "res://.local/art_style_20261007/before"
var hour := 11.0
var weather := "clear"
var camera: Camera3D
var results: Array = []
var checks: Array = []
var profile := false

func _ready() -> void:
	if not has_meta("runner"):
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	for arg in OS.get_cmdline_user_args():
		if arg == "profile":
			profile = true
		if arg.begins_with("out="):
			out = arg.substr(4)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	Game.slot_index = -1
	Game.new_character("美术巡览", "mage", DB.random_appearance(7, "f"))
	Game.pd["new"] = false
	Game.pd.flags.city_access = true
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")
	call_deferred("run")

func _process(_delta: float) -> void:
	if is_instance_valid(Game.world):
		Game.time_of_day = hour
		Game.world.weather = weather
		Game.world.weather_amt = 0.0 if weather == "clear" else 1.0
		Game.world.weather_t = 99999
		Game.world._flash = 0
	if is_instance_valid(Game.player):
		Game.player.set_hp(Game.player.max_hp)
	# Freeze newly streamed units too, before they can enter combat during a view.
	for unit in get_tree().get_nodes_in_group("units"):
		if unit != Game.player:
			unit.set_physics_process(false)

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func check(ok: bool, label: String) -> void:
	checks.append({"pass": ok, "label": label})
	print(("ART PASS " if ok else "ART FAIL ") + label)

func capture(label: String, x: float, z: float, yaw: float, distance: float, pitch: float, at_hour: float = 11.0, at_weather: String = "clear") -> void:
	hour = at_hour
	weather = at_weather
	var point := Vector3(x, U.ground_height(get_tree(), x, z, 35), z)
	if label.contains("lake") or label.contains("harbor"):
		# A lakebed sample is not a valid camera/player surface for a water review.
		point.y = maxf(point.y, Game.world.zone.terrain.water_level_global() + 0.5)
	Game.player.set_physics_process(true)
	await Game.world._teleport_to(point + Vector3.UP * 0.4)
	await wait(.4)
	Game.player.set_physics_process(false)
	Game.player.velocity = Vector3.ZERO
	Game.hud.hide()
	Game.hud.process_mode = Node.PROCESS_MODE_DISABLED
	if not is_instance_valid(camera):
		camera = Camera3D.new()
		camera.fov = 60
		camera.far = 4000
		Game.world.add_child(camera)
	var target := point + Vector3.UP * 1.6
	camera.global_position = target + Vector3(0, sin(-pitch) * distance, cos(pitch) * distance).rotated(Vector3.UP, deg_to_rad(yaw))
	camera.look_at(target)
	camera.make_current()
	await wait(3.5)
	var frames: Array[float] = []
	for i in 60:
		await get_tree().process_frame
		frames.append(get_process_delta_time() * 1000.0)
	frames.sort()
	# Explicit draw also works when another game window leaves this test occluded.
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(out + "/" + label + ".png")
	var n_grass := 0
	var tris := 0
	for field in get_tree().get_nodes_in_group("grass_fields"):
		if not field.is_visible_in_tree():
			continue
		for chunk in field.chunks.values():
			if is_instance_valid(chunk[0]):
				for mi in chunk[0].get_children():
					if mi is MultiMeshInstance3D:
						n_grass += mi.multimesh.instance_count
						var mesh: ArrayMesh = mi.multimesh.mesh
						tris += mi.multimesh.instance_count * mesh.surface_get_array_index_len(0) / 3
	var stats := {"view": label, "camera": str(camera.global_transform), "hour": hour, "weather": weather, "median_ms": frames[30], "p95_ms": frames[57], "grass_instances": n_grass, "grass_triangles": tris, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	results.append(stats)
	print("ART VIEW ", JSON.stringify(stats))
	check(Game.world.env.ambient_light_energy > 0 and Game.world.env.tonemap_exposure > 0, label + " environment valid")
	if Game.world.streamer:
		check(Game.world.ground_ready(Game.player.global_position), label + " terrain collision ready")

func run() -> void:
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):
		await get_tree().process_frame
	for u in get_tree().get_nodes_in_group("units"):
		if u != Game.player:
			u.set_physics_process(false)
	if profile:
		await capture("hills_profile", 600, 520, 90, 30, -0.12)
		await profile_hills()
		get_tree().quit()
		return
	await capture("01_meadow", 430, 230, 200, 14, -0.22)
	await capture("02_grass_close", 430, 230, 200, 6, -0.25)
	await capture("03_abbey", 485, 104, 0, 24, -0.3)
	await capture("04_town", 435, 500, 0, 26, -0.35)
	await capture("05_lake", 688, 338, 45, 18, -0.12)
	await capture("06_hills", 600, 520, 90, 30, -0.12)
	await capture("07_dusk", 435, 500, 0, 26, -0.35, 18.5)
	await capture("08_night", 435, 500, 0, 26, -0.35, 22)
	await capture("09_rain", 430, 230, 200, 14, -0.22, 11, "rain")
	await Game.world.travel("sanctum", "start")
	camera = null
	await capture("10_dungeon", 200, 305, 0, 30, -0.45, 11)
	FileAccess.open(out + "/metrics.json", FileAccess.WRITE).store_string(JSON.stringify({"views": results, "checks": checks}, "\t"))
	print("ART TOUR DONE ", out)
	get_tree().quit(1 if checks.any(func(c): return not c["pass"]) else 0)

func sample_frames(label: String) -> Dictionary:
	await wait(1.0)
	var frames: Array[float] = []
	for i in 120:
		await get_tree().process_frame
		frames.append(get_process_delta_time() * 1000.0)
	frames.sort()
	var item := {"label": label, "median_ms": frames[60], "p95_ms": frames[114], "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	print("ART PROFILE ", JSON.stringify(item))
	return item

func profile_hills() -> void:
	var samples := [await sample_frames("baseline")]
	var leaves := []
	for mi in Game.world.find_children("*", "MultiMeshInstance3D", true, false):
		if mi.material_override is ShaderMaterial and mi.material_override.shader == Forest.CANOPY:
			leaves.append(mi)
			mi.hide()
	samples.append(await sample_frames("alpha_canopies_hidden"))
	for mi in leaves:
		mi.show()
	var old_shadows: bool = Game.world.sun.shadow_enabled
	Game.world.sun.shadow_enabled = false
	samples.append(await sample_frames("sun_shadows_disabled"))
	Game.world.sun.shadow_enabled = old_shadows
	for g in get_tree().get_nodes_in_group("grass_fields"):
		g.hide()
	samples.append(await sample_frames("grass_hidden"))
	for g in get_tree().get_nodes_in_group("grass_fields"):
		g.show()
	var old_ssao: bool = Game.world.env.ssao_enabled
	Game.world.env.ssao_enabled = false
	samples.append(await sample_frames("ssao_disabled"))
	Game.world.env.ssao_enabled = old_ssao
	samples.append(await sample_frames("baseline_restored"))
	FileAccess.open(out + "/profile.json", FileAccess.WRITE).store_string(JSON.stringify(samples, "\t"))
