extends "res://tests/environment_pack.gd"
## Final targeted evidence. Uses the game consumers and the final fog shader.
func run() -> void:
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):
		await get_tree().process_frame
	out = "res://.shots/environment_20261011/final"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	set_weather("clear")
	await capture("01_lake_shore", 646, 392, 20, 22, -0.22)
	await capture("02_lake_overview", 735, 320, 0, 120, -0.70)
	await capture("03_morning_rays", 485, 180, 238, 12, -0.10, 7.0)
	Game.settings["volumetric_fog"] = false
	await capture("04_morning_without_volume", 485, 180, 238, 12, -0.10, 7.0)
	Game.settings["volumetric_fog"] = true
	await capture("05_meadow", 600, 520, 90, 24, -0.15, 11.0)
	await record_motion()
	# Use an existing game's fountain implementation in a clear inspection spot.
	var fountain := Prop.new()
	fountain.kind = "fountain"
	fountain.name = "AcceptanceFountain"
	var base: Vector3 = Game.player.global_position + Vector3(4, 0, 0)
	base.y = U.ground_height(get_tree(), base.x, base.z, 35)
	fountain.position = base
	Game.world.add_child(fountain)
	camera.global_position = base + Vector3(5, 4, 6)
	camera.look_at(base + Vector3.UP * 0.7)
	await wait(2.0)
	await save_view("06_prop_fountain")
	check(fountain.find_children("*", "MeshInstance3D", true, false).any(func(m): return m.material_override is ShaderMaterial and m.material_override.shader == BrushTerrain.WATER_SHADER), "actual prop fountain uses new water shader")
	fountain.queue_free()
	for spec in [["07_sky_day", 11.0, "clear"], ["08_sky_dusk", 18.5, "clear"], ["09_sky_night", 22.0, "clear"], ["10_sky_rain", 11.0, "rain"], ["11_sky_storm", 11.0, "storm"], ["12_sky_fog", 11.0, "fog"]]:
		await sky_view(spec[0], spec[1], spec[2])
	hour = 11.0
	set_weather("clear")
	await capture("13_town_boundary", 462, 448, 45, 18, -0.06)
	await capture("14_ocean", -1370, 1040, 150, 50, -0.30)
	await capture("15_transition_view", 600, 520, 90, 24, -0.15)
	# Long-running phase before weather conversion verifies accumulated motion.
	Game.world.atmosphere.motion_time = 7200.0
	await transition("fog", "rain")
	await transition("storm", "clear")
	await sky_pan()
	FileAccess.open(out + "/metrics.json", FileAccess.WRITE).store_string(JSON.stringify({"views": results, "checks": checks, "transitions": transition_samples}, "\t"))
	set_weather("storm")
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await wait(5.0)
	check(Game.world == null and Game.player == null, "front end context resets after storm")
	check(get_tree().current_scene.get_script().resource_path == "res://src/ui/front_end.gd", "actual front end is loaded")
	await save_view("16_front_end")
	FileAccess.open(out + "/final_checks.json", FileAccess.WRITE).store_string(JSON.stringify(checks, "\t"))
	print("ENVIRONMENT ACCEPTANCE DONE ", out)
	get_tree().quit(1 if checks.any(func(c): return not c["pass"]) else 0)

func save_view(label: String) -> void:
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + label + ".png")

func sky_view(label: String, at_hour: float, kind: String) -> void:
	hour = at_hour
	Game.time_of_day = hour
	set_weather(kind)
	camera.global_position = Game.player.global_position + Vector3.UP * 60.0
	var direction: Vector3 = Game.world.sky_mat.get_shader_parameter("moon_dir") if at_hour > 20 else Game.world.sky_mat.get_shader_parameter("sun_dir")
	direction.y = maxf(direction.y, 0.20)
	camera.look_at(camera.global_position + direction * 100.0)
	await wait(2.0)
	await save_view(label)

func record_motion() -> void:
	var start := camera.global_transform
	var elapsed := 0.0
	var next_frame := 0.0
	while elapsed < 6.0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		camera.global_position = start.origin + start.basis.x * (sin(elapsed * 0.7) * 2.5)
		if elapsed >= next_frame:
			RenderingServer.force_draw(false)
			get_viewport().get_texture().get_image().save_jpg(out + "/grass_motion_%03d.jpg" % int(next_frame * 10), 0.88)
			next_frame += 0.25
	camera.global_transform = start

func sky_pan() -> void:
	hour = 11.0
	set_weather("clear")
	camera.global_position = Game.player.global_position + Vector3.UP * 60.0
	for i in 24:
		var yaw := i * TAU / 24
		camera.look_at(camera.global_position + Vector3(sin(yaw), 0.38, cos(yaw)) * 100.0)
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_jpg(out + "/sky_pan_%03d.jpg" % i, 0.90)
