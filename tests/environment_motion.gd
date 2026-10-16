extends "res://tests/environment_acceptance.gd"
## Final repairs and per-rendered-frame motion evidence, without touching saves.
var clip_frames: Dictionary = {}

func run() -> void:
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):
		await get_tree().process_frame
	out = "res://.shots/environment_20261011/final_v3"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	set_weather("clear")
	await capture("01_lake_shore", 646, 392, 20, 22, -0.22)
	await capture("02_meadow", 600, 520, 90, 24, -0.15)
	await clip("grass_motion", 6.0, true)
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
	await save_view("03_prop_fountain")
	check(fountain.find_children("*", "MeshInstance3D", true, false).any(func(m): return m.material_override is ShaderMaterial and m.material_override.shader == BrushTerrain.WATER_SHADER and m.position.y > 0.9), "fountain water uses new shader above stone basin")
	await clip("fountain_motion", 4.0)
	fountain.queue_free()
	for spec in [["04_sky_day", 11.0, "clear"], ["05_sky_dusk", 18.5, "clear"], ["06_sky_night", 22.0, "clear"], ["07_sky_rain", 11.0, "rain"], ["08_sky_storm", 11.0, "storm"], ["09_sky_fog", 11.0, "fog"]]:
		await sky_view(spec[0], spec[1], spec[2])
	hour = 11.0
	set_weather("clear")
	await capture("10_ocean", -1370, 1040, 150, 50, -0.30)
	await capture("11_weather_motion_view", 600, 520, 90, 24, -0.15)
	for pair in [["fog", "rain"], ["storm", "clear"]]:
		set_weather(pair[0])
		Game.world.atmosphere.motion_time = 7200.0
		await wait(1.0)
		weather = pair[1]
		Game.world.weather = pair[1]
		await clip("%s_to_%s" % pair, 12.0)
	set_weather("clear")
	camera.global_position = Game.player.global_position + Vector3.UP * 60.0
	await clip("sky_pan", 10.0, false, true)
	set_weather("storm")
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await wait(5.0)
	check(Game.world == null and Game.player == null, "front end context resets after storm")
	check(get_tree().current_scene.get_script().resource_path == "res://src/ui/front_end.gd", "actual front end is loaded")
	await save_view("12_front_end")
	FileAccess.open(out + "/metrics.json", FileAccess.WRITE).store_string(JSON.stringify({"views": results, "checks": checks, "clips": clip_frames}, "\t"))
	print("ENVIRONMENT MOTION DONE ", out)
	get_tree().quit(1 if checks.any(func(c): return not c["pass"]) else 0)

func clip(label: String, seconds: float, move: bool = false, pan: bool = false) -> void:
	var start := camera.global_transform
	var began := Time.get_ticks_msec()
	var frames: Array = []
	var previous_motion: float = Game.world.atmosphere.motion_time
	var previous_cloud: float = Game.world.atmosphere.cloud
	var max_cloud_step := 0.0
	var monotonic := true
	while true:
		await get_tree().process_frame
		var elapsed := (Time.get_ticks_msec() - began) / 1000.0
		if move:
			camera.global_position = start.origin + start.basis.x * sin(elapsed * 0.7) * 3.0
		if pan:
			var yaw := elapsed * TAU / seconds
			camera.look_at(camera.global_position + Vector3(sin(yaw), 0.38, cos(yaw)) * 100.0)
		RenderingServer.force_draw(false)
		await RenderingServer.frame_post_draw
		var state: EnvironmentWeather = Game.world.atmosphere
		max_cloud_step = maxf(max_cloud_step, absf(state.cloud - previous_cloud))
		monotonic = monotonic and state.motion_time >= previous_motion
		previous_motion = state.motion_time
		previous_cloud = state.cloud
		var filename := "%s_%05d.jpg" % [label, frames.size()]
		get_viewport().get_texture().get_image().save_jpg(out + "/" + filename, 0.90)
		frames.append({"file": filename, "seconds": (Time.get_ticks_msec() - began) / 1000.0, "motion": state.motion_time, "cloud": state.cloud, "rain": state.rain, "mist": state.mist, "wind": state.wind})
		if elapsed >= seconds:
			break
	clip_frames[label] = frames
	FileAccess.open(out + "/clip_frames.json", FileAccess.WRITE).store_string(JSON.stringify(clip_frames, "\t"))
	check(monotonic, label + " motion clock stays monotonic")
	check(max_cloud_step < 0.08, label + " weather state changes continuously")
	camera.global_transform = start
