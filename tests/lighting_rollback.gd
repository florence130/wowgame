extends "res://tests/environment_pack.gd"
## Restored purchased clouds plus targeted current lighting/volume evidence.
func run() -> void:
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):
		await get_tree().process_frame
	out = "res://.shots/lighting_20261011/lighting-v4-restored"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	Game.settings["shadows"] = true
	Game.settings["volumetric_fog"] = true
	set_weather("clear")
	if "volume-final" in OS.get_cmdline_user_args():
		out = "res://.shots/lighting_20261011/lighting-v4-volume-final"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
		await capture("01_morning_volume_on", 485, 180, 238, 12, -0.10, 7.0)
		Game.settings["volumetric_fog"] = false
		await wait(0.5)
		await image_view("02_morning_volume_off")
		check(not Game.world.env.volumetric_fog_enabled, "final thin-fog setting switches off")
		Game.settings["volumetric_fog"] = true
		await wait(0.5)
		await image_view("03_morning_restored")
		for state in [[22.0,"clear"],[11.0,"fog"],[11.0,"storm"]]:
			set_weather(state[1])
			await capture("volume_%s_%s" % state, 485, 180, 238, 12, -0.10, state[0], state[1])
		FileAccess.open(out + "/metrics.json", FileAccess.WRITE).store_string(JSON.stringify({"views":results,"checks":checks},"\t"))
		print("VOLUME FINAL DONE")
		get_tree().quit(1 if checks.any(func(c): return not c["pass"]) else 0)
		return
	if "volume-only" in OS.get_cmdline_user_args():
		out = "res://.shots/lighting_20261011/lighting-v4-volume-material"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
		await capture("01_volume_fresh", 485, 180, 238, 12, -0.10, 7.0)
		print("VOLUME DIAGNOSTIC ", JSON.stringify({"fog":str(Game.world.env.fog_light_color),"albedo":str(Game.world.volume_atmosphere.material.get_shader_parameter("fog_color")),"sun":str(Game.world.sun.light_color),"sun_energy":Game.world.sun.light_energy,"sun_scatter":Game.world.sun.light_volumetric_fog_energy}))
		# Isolate a temporal-history artifact without changing the production settings.
		Game.world.set_process(false)
		Game.world.env.volumetric_fog_temporal_reprojection_enabled = false
		await wait(1.0)
		await image_view("02_volume_no_history")
		var lights: Array = []
		for light in get_tree().root.find_children("*", "Light3D", true, false):
			if light.visible:
				lights.append({"path":str(light.get_path()),"color":str(light.light_color),"energy":light.light_energy,"fog_energy":light.light_volumetric_fog_energy,"position":str(light.global_position)})
			if light != Game.world.sun:
				light.light_volumetric_fog_energy = 0
		Game.world.env.volumetric_fog_ambient_inject = 0
		print("VOLUME LIGHTS ", JSON.stringify(lights))
		await wait(1.0)
		await image_view("03_volume_sun_only")
		var original_fog_color: Color = Game.world.env.fog_light_color
		var original_sun_color: Color = Game.world.sun.light_color
		Game.world.volume_atmosphere.material.set_shader_parameter("fog_color", Color.WHITE)
		await wait(1.0)
		await image_view("04_volume_white_albedo")
		Game.world.volume_atmosphere.material.set_shader_parameter("fog_color", original_fog_color)
		Game.world.sun.light_color = Color.WHITE
		await wait(1.0)
		await image_view("05_volume_white_sun")
		Game.world.sun.light_color = original_sun_color
		var native_fog := FogMaterial.new()
		native_fog.density = 0.0011
		native_fog.albedo = original_fog_color
		Game.world.volume_atmosphere.volume.material = native_fog
		await wait(1.0)
		await image_view("06_volume_native")
		Game.world.volume_atmosphere.volume.material = Game.world.volume_atmosphere.material
		Game.settings["volumetric_fog"] = false
		Game.world.env.volumetric_fog_enabled = false
		await wait(0.5)
		await image_view("07_volume_off")
		Game.settings["volumetric_fog"] = true
		FileAccess.open(out + "/metrics.json", FileAccess.WRITE).store_string(JSON.stringify({"views":results,"checks":checks},"\t"))
		print("VOLUME FRESH DONE")
		get_tree().quit()
		return
	await capture("01_rail_dusk", -570, 490, 25, 22, -0.24, 19.5)
	var original: Shader = Game.world.sky_mat.shader
	var cheap := Shader.new()
	cheap.code = "shader_type sky; void sky() { COLOR = vec3(0.35, 0.55, 0.9); }"
	var sky_samples: Array = []
	for sample in ["restored", "cheap", "restored_repeat"]:
		Game.world.sky_mat.shader = cheap if sample == "cheap" else original
		await wait(0.5)
		var times: Array[float] = []
		for i in 90:
			await get_tree().process_frame
			times.append(get_process_delta_time() * 1000.0)
		times.sort()
		sky_samples.append({"sky":sample,"median_ms":times[45],"p95_ms":times[85]})
	Game.world.sky_mat.shader = original
	check(Game.world.sky_mat.shader == preload("res://src/render/sky.gdshader"), "restored sky remains active after isolated timing control")
	await capture("02_rail_night", -570, 490, 25, 22, -0.24, 22.0)
	await capture("03_town_day", 462, 448, 45, 18, -0.12, 11.0)
	for state in [[11.0,"clear"],[19.5,"clear"],[22.0,"clear"],[11.0,"storm"]]:
		hour = state[0]
		set_weather(state[1])
		camera.global_position = Game.player.global_position + Vector3.UP * 60
		camera.look_at(camera.global_position + Vector3(0.6, 0.4, 0.7) * 100)
		await wait(0.5)
		await image_view("sky_%s_%s" % state)
	set_weather("clear")
	await capture("04_morning_volume_on", 485, 180, 238, 12, -0.10, 7.0)
	check(Game.world.env.volumetric_fog_enabled and Game.world.sun.light_volumetric_fog_energy > 0, "current morning uses actual sun volume scattering")
	Game.settings["volumetric_fog"] = false
	await wait(0.5)
	await image_view("05_morning_volume_off")
	check(not Game.world.env.volumetric_fog_enabled, "current volume control disables volume only")
	Game.settings["volumetric_fog"] = true
	await capture("06_lake_current_light", 646, 392, 20, 22, -0.22, 11.0)
	FileAccess.open(out + "/metrics.json", FileAccess.WRITE).store_string(JSON.stringify({"views":results,"checks":checks,"sky_control":sky_samples},"\t"))
	print("LIGHTING ROLLBACK DONE ", JSON.stringify(sky_samples))
	get_tree().quit(1 if checks.any(func(c): return not c["pass"]) else 0)

func image_view(label: String) -> void:
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + label + ".png")
