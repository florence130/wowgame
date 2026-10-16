extends "res://tests/environment_pack.gd"
## Railway feedback regression; disposable character, no saved settings.
func run() -> void:
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):
		await get_tree().process_frame
	out = "res://.shots/lighting_20261011/" + ("before" if "before" in OS.get_cmdline_user_args() else "after")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	Game.settings["shadows"] = true
	set_weather("clear")
	await capture("01_rail_day", -570, 490, 25, 22, -0.24, 11.0)
	await capture("02_rail_dusk", -570, 490, 25, 22, -0.24, 19.5)
	await capture("03_rail_night", -570, 490, 25, 22, -0.24, 22.0)
	await capture("04_town_day", 462, 448, 45, 18, -0.12, 11.0)
	await capture("05_town_dusk", 462, 448, 45, 18, -0.12, 19.5)
	await capture("06_town_night", 462, 448, 45, 18, -0.12, 22.0)
	for at_hour in [11.0, 19.5, 22.0]:
		hour = at_hour
		Game.time_of_day = hour
		Game.world._update_sky(0.0)
		camera.global_position = Game.player.global_position + Vector3.UP * 60.0
		camera.look_at(camera.global_position + Vector3(0.6, 0.40, 0.7) * 100.0)
		await wait(1.0)
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png(out + "/sky_%s.png" % at_hour)
	FileAccess.open(out + "/metrics.json", FileAccess.WRITE).store_string(JSON.stringify({"views":results,"checks":checks},"\t"))
	print("LIGHTING STYLE DONE ", out)
	get_tree().quit(0)
