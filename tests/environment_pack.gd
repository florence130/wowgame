extends "res://tests/art_style.gd"
## Actual Forward+ validation of purchased ports and weather transitions; disposable save.
var baseline_fields: Array = []
var transition_samples: Array = []

func set_weather(kind: String) -> void:
	weather = kind
	Game.world.weather = kind
	Game.world.atmosphere.advance(kind, 120.0)
	Game.world._update_sky(0.0)

func weather_view(label: String, at_hour: float, kind: String) -> void:
	hour = at_hour
	set_weather(kind)
	await capture(label, 430, 230, 200, 14, -0.22, at_hour, kind)

func run() -> void:
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):
		await get_tree().process_frame
	out = "res://.shots/environment_20261011"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for unit in get_tree().get_nodes_in_group("units"):
		if unit != Game.player:
			unit.set_physics_process(false)
	if "focused" in OS.get_cmdline_user_args():
		await focused_views()
		return
	set_weather("clear")
	await capture("01_meadow", 430, 230, 200, 14, -0.22)
	await capture("02_grass_close", 430, 230, 200, 6, -0.25)
	var new_fields := get_tree().get_nodes_in_group("grass_fields")
	var old_source := FileAccess.get_file_as_string("res://.local/environment_20261011/before/src/terrain/grass_field.gd")
	old_source = old_source.replace("class_name GrassField", "").replace('const SHADER := preload("res://src/terrain/grass.gdshader")', 'var old_shader: Shader').replace('mat.shader = SHADER', 'mat.shader = old_shader')
	var old_script := GDScript.new()
	old_script.source_code = old_source
	check(old_script.reload() == OK, "baseline grass source compiles")
	var old_shader := Shader.new()
	old_shader.code = FileAccess.get_file_as_string("res://.local/environment_20261011/before/src/terrain/grass.gdshader")
	for field in new_fields:
		field.hide()
		field.set_process(false)
		var baseline := Node3D.new()
		baseline.set_script(old_script)
		baseline.old_shader = old_shader
		field.get_parent().add_child(baseline)
		baseline.setup(field.terrain)
		baseline_fields.append(baseline)
	await wait(6.0)
	await capture("03_grass_before_same_camera", 430, 230, 200, 6, -0.25)
	for field in baseline_fields:
		field.queue_free()
	await get_tree().process_frame
	for field in new_fields:
		field.show()
		field.set_process(true)
	await capture("04_grass_after_same_camera", 430, 230, 200, 6, -0.25)
	await capture("05_town_paths", 435, 500, 0, 26, -0.35)
	await capture("06_lake", 688, 338, 45, 18, -0.12)
	await capture("07_abbey", 485, 104, 0, 24, -0.3)
	await weather_view("08_dusk", 18.0, "clear")
	await weather_view("09_night", 22.0, "clear")
	await weather_view("10_rain", 11.0, "rain")
	await weather_view("11_storm", 11.0, "storm")
	await weather_view("12_fog", 11.0, "fog")
	await transition("fog", "rain")
	await transition("storm", "clear")
	set_weather("clear")
	hour = 8.0
	await capture("13_morning_rays", 485, 180, 238, 12, -0.10, 7.0)
	Game.world.env.volumetric_fog_enabled = false
	Game.settings["volumetric_fog"] = false
	await capture("14_morning_without_volume", 485, 180, 238, 12, -0.10, 7.0)
	Game.settings["volumetric_fog"] = true
	# Cross into the city/harbor; terrain origins and depths must remain world-space.
	await capture("15_harbor", -1236, 758, 180, 30, -0.30)
	var views := results.duplicate(true)
	FileAccess.open(out + "/metrics.json", FileAccess.WRITE).store_string(JSON.stringify({"views": views, "checks": checks, "transitions": transition_samples}, "\t"))
	print("ENVIRONMENT TOUR DONE ", out)
	get_tree().quit(1 if checks.any(func(c): return not c["pass"]) else 0)

func transition(from: String, to: String) -> void:
	set_weather(from)
	weather = to
	Game.world.weather = to
	var previous: float = Game.world.atmosphere.cloud
	var max_step := 0.0
	var elapsed := 0.0
	var next_capture := 0.0
	var frame := 0
	while elapsed < 12.0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var state: EnvironmentWeather = Game.world.atmosphere
		max_step = maxf(max_step, absf(state.cloud - previous))
		previous = state.cloud
		if elapsed >= next_capture:
			transition_samples.append({"from": from, "to": to, "seconds": elapsed, "cloud": state.cloud, "rain": state.rain, "mist": state.mist, "wind": state.wind, "sky": str(Game.world.env.fog_light_color)})
			RenderingServer.force_draw(false)
			var image := get_viewport().get_texture().get_image()
			image.save_png(out + "/transition_%s_%s_%03d.png" % [from, to, int(next_capture * 10)])
			next_capture += 0.5
		frame += 1
	check(max_step < 0.08, "%s to %s has no abrupt cloud step (%f)" % [from, to, max_step])

func focused_views() -> void:
	set_weather("clear")
	await capture("16_lake_shore", 646, 392, 20, 22, -0.22)
	await capture("17_lake_overview", 735, 320, 0, 120, -0.70)
	await capture("18_fountain", 435, 448, 0, 12, -0.18)
	await capture("19_morning_rays", 485, 180, 238, 12, -0.10, 7.0)
	Game.settings["volumetric_fog"] = false
	await capture("20_morning_without_volume", 485, 180, 238, 12, -0.10, 7.0)
	Game.settings["volumetric_fog"] = true
	await capture("21_harbor", -1236, 758, 180, 30, -0.30, 11.0)
	await capture("22_ocean_seam", -1370, 1040, 150, 50, -0.30, 11.0)
	hour = 11.0
	await capture("23_transition_view", 430, 230, 200, 14, -0.22)
	await transition("fog", "rain")
	await transition("storm", "clear")
	FileAccess.open(out + "/focused_metrics.json", FileAccess.WRITE).store_string(JSON.stringify({"views": results, "checks": checks, "transitions": transition_samples}, "\t"))
	# Real return to front end after a storm validates cleanup of shader globals.
	set_weather("storm")
	var front := "res://scenes/boot.tscn"
	get_tree().change_scene_to_file(front)
	await wait(4.0)
	check(Game.world == null and Game.player == null, "front end context resets after storm")
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(out + "/24_front_end.png")
	print("ENVIRONMENT FOCUSED DONE")
	get_tree().quit(1 if checks.any(func(c): return not c["pass"]) else 0)
