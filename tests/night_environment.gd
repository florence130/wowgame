extends "res://tests/environment_pack.gd"
## Same-camera night, water and streamed tent regression; disposable character.
var tents: Array = []

func run() -> void:
	get_tree().auto_accept_quit = false
	get_tree().root.gui_disable_input = true
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):
		await get_tree().process_frame
	out = "res://.shots/lighting_20261011/resume_v3"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	get_window().size = Vector2i(1280, 720)
	Game.settings["shadows"] = true
	Game.settings["depth_of_field"] = true
	set_weather("clear")
	if "water_tents_only" in OS.get_cmdline_user_args():
		await capture("10_lake_night", 646, 392, 20, 22, -0.22, 22.0)
		await shore_detail()
		await capture("11_lake_overview", 735, 320, 0, 120, -0.70, 11.0)
		await capture("12_camp_day", 856, 300, 150, 17, -0.20, 11.0)
		await audit_tents("lake_camp")
		await capture("13_forest_camp", 236, 714, 200, 15, -0.20, 11.0)
		await audit_tents("forest_camp")
		await capture("14_highland_camp", -570, 490, 25, 22, -0.24, 11.0)
		await audit_tents("highlands")
		check(not tents.is_empty(), "runtime generated tents were inspected")
		_finish()
		return
	hour = 22.0
	Game.time_of_day = hour
	Game.world._update_sky(0.0)
	check(Game.player.camera.attributes is CameraAttributesPractical and Game.player.camera.attributes.dof_blur_far_enabled, "actual player camera uses night depth of field")
	await capture("01_rail_day", -570, 490, 25, 22, -0.24, 11.0)
	check(not camera.attributes.dof_blur_far_enabled, "day disables night blur")
	await capture("02_rail_dusk", -570, 490, 25, 22, -0.24, 19.5)
	await capture("03_rail_night", -570, 490, 25, 22, -0.24, 22.0)
	check(Game.world.sun.light_energy < 0.01 and Game.world.moon.shadow_enabled, "night key is a shadow casting moon")
	check(Game.world.env.glow_enabled and Game.world.env.glow_bloom > 0.05 and Game.world.env.glow_hdr_threshold < 1.2, "night bloom is active for lamps and windows")
	var character_fill := Game.player.get_node_or_null("NightCharacterFill") as OmniLight3D
	check(character_fill != null and character_fill.visible and character_fill.light_energy > 0.1, "night character fill keeps the avatar readable")
	Game.world.moon.hide()
	Game.world.set_process(false)
	await wait(0.5)
	await image_view("04_night_moon_off")
	Game.world.set_process(true)
	Game.world._update_sky(0.0)
	await wait(0.5)
	Game.settings["volumetric_fog"] = false
	Game.world.env.fog_enabled = false
	Game.settings["depth_of_field"] = false
	Game.world._update_sky(0.0)
	await wait(0.7)
	await image_view("05_night_fog_off")
	Game.settings["volumetric_fog"] = true
	Game.world.env.fog_enabled = true
	Game.settings["depth_of_field"] = true
	await capture("06_town_night", 435, 500, 0, 20, -0.18, 22.0)
	await capture("07_town_close_night", 462, 448, 45, 18, -0.12, 22.0)
	Game.settings["depth_of_field"] = false
	await wait(0.5)
	check(not camera.attributes.dof_blur_far_enabled, "depth of field setting disables blur immediately")
	await image_view("08_town_blur_off")
	Game.settings["depth_of_field"] = true
	await capture("09_lake_day", 646, 392, 20, 22, -0.22, 11.0)
	await capture("10_lake_night", 646, 392, 20, 22, -0.22, 22.0)
	await capture("10b_lake_shore_close", 646, 392, 20, 8, -0.16, 11.0)
	await shore_detail()
	await capture("11_lake_overview", 735, 320, 0, 120, -0.70, 11.0)
	hour = 22.0
	Game.time_of_day = hour
	Game.world._update_sky(0.0)
	var moon_dir: Vector3 = Game.world.sky_mat.get_shader_parameter("moon_dir")
	camera.global_position = Game.player.global_position + Vector3.UP * 30.0
	camera.look_at(camera.global_position + moon_dir * 120.0)
	await wait(1.0)
	await image_view("10c_moon_sky")
	await capture("12_camp_day", 856, 300, 150, 17, -0.20, 11.0)
	await audit_tents("lake_camp")
	await capture("13_forest_camp", 236, 714, 200, 15, -0.20, 11.0)
	await audit_tents("forest_camp")
	await capture("14_highland_camp", -570, 490, 25, 22, -0.24, 11.0)
	await audit_tents("highlands")
	check(not tents.is_empty(), "runtime generated tents were inspected")
	_finish()

func _finish() -> void:
	FileAccess.open(out + "/metrics.json", FileAccess.WRITE).store_string(JSON.stringify({"views": results, "checks": checks, "tents": tents}, "\t"))
	print("NIGHT ENVIRONMENT DONE ", out)
	get_tree().quit(1 if checks.any(func(c): return not c["pass"]) else 0)

func audit_tents(site: String) -> void:
	var worst_tent: ModelProp
	var worst_contact := -INF
	for node in Game.world.find_children("*", "Node3D", true, false):
		if not node is ModelProp or node.kind != "tent" or not is_instance_valid(node._gen):
			continue
		var terrain = U.terrain_at(get_tree(), node.global_position.x, node.global_position.z)
		if terrain == null:
			continue
		var max_gap := -INF
		var max_burial := 0.0
		for sx in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			for sz in [-1.0, -0.5, 0.0, 0.5, 1.0]:
				var q: Vector3 = node.global_transform * Vector3(node.size.x * 0.5 * sx, 0, node.size.z * 0.5 * sz)
				var gap: float = q.y - terrain.get_height_global(q.x, q.z)
				max_gap = maxf(max_gap, gap)
				max_burial = maxf(max_burial, -gap)
		var report := {"site": site, "name": node.name, "position": str(node.global_position), "gap": max_gap, "burial": max_burial}
		tents.append(report)
		check(max_gap <= 0.12, "tent footprint grounded: %s (%.3fm)" % [node.name, max_gap])
		check(max_burial <= 0.12, "tent footprint not buried: %s (%.3fm)" % [node.name, max_burial])
		if maxf(max_gap, max_burial) > worst_contact:
			worst_contact = maxf(max_gap, max_burial)
			worst_tent = node as ModelProp
	if not is_instance_valid(worst_tent):
		return
	var centre := worst_tent.global_position
	var distance := maxf(worst_tent.size.x, worst_tent.size.z) + 3.0
	for angle in [35.0, 145.0]:
		var offset := Vector3(0, 0, distance).rotated(Vector3.UP, worst_tent.global_rotation.y + deg_to_rad(angle))
		var view_pos := centre + offset
		await Game.world._teleport_to(Vector3(view_pos.x, U.ground_height(get_tree(), view_pos.x, view_pos.z, 80.0) + 0.5, view_pos.z))
		Game.player.set_physics_process(false)
		camera.global_position = Vector3(view_pos.x, maxf(centre.y + 2.8, U.ground_height(get_tree(), view_pos.x, view_pos.z, 80.0) + 1.8), view_pos.z)
		camera.look_at(centre + Vector3.UP * 0.8)
		await wait(0.7)
		await image_view("tent_%s_%d" % [site, int(angle)])

func shore_detail() -> void:
	# Locate a real wet/dry crossing, rather than taking a distant lake view
	# from behind the fisherman's house.
	var terrain := Game.world.zone.terrain as BrushTerrain
	var water_y: float = terrain.water_level_global()
	var shoreline := Vector3.ZERO
	for x in range(855, 775, -1):
		var ground_y: float = terrain.get_height_global(float(x), 300.0)
		if ground_y < water_y:
			shoreline = Vector3(float(x), water_y, 300.0)
			break
	check(shoreline != Vector3.ZERO, "close shoreline camera found a wet/dry crossing")
	if shoreline == Vector3.ZERO:
		return
	await capture("10d_lake_waterline_detail", shoreline.x - 2.0, shoreline.z, 90, 9, -0.32, 11.0)

func image_view(label: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(out + "/" + label + ".png")
