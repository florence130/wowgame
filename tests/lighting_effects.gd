extends "res://tests/environment_pack.gd"
## Actual receiver differences, moving spell light, budget and settings regression.
func run() -> void:
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):
		await get_tree().process_frame
	out = "res://.shots/lighting_20261011/final"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	Game.settings["shadows"] = true
	set_weather("clear")
	await capture("00_rail_day", -570, 490, 25, 22, -0.24, 11.0)
	await capture("01_rail_shadow_on", -570, 490, 25, 22, -0.24, 19.5)
	Game.settings["shadows"] = false
	await wait(0.5)
	await image_view("02_rail_shadow_off")
	check(not Game.world.sun.shadow_enabled and not Game.world.moon.shadow_enabled, "shadow setting disables both directional keys immediately")
	Game.settings["shadows"] = true
	await capture("03_night_shadow_on", -570, 490, 25, 22, -0.24, 22.0)
	check(Game.world.moon.shadow_enabled and Game.world.moon.light_energy > 0.1, "night uses a shadow casting moon key")
	Game.settings["shadows"] = false
	await wait(0.5)
	await image_view("04_night_shadow_off")
	Game.settings["shadows"] = true
	await capture("05_spell_view", -570, 490, 25, 12, -0.25, 22.0)
	var baseline_lights := get_tree().get_nodes_in_group("environment_local_lights").size()
	var target := Node3D.new()
	Game.world.add_child(target)
	target.global_position = Game.player.global_position + Vector3(5, 1.4, 0)
	var from: Vector3 = Game.player.global_position + Vector3(-5, 1.4, 0)
	var projectile := Projectile.spawn(Game.world, from, target, 2.0, Color("ff9b4f"), 0.28, "orb", func(): pass)
	await wait(0.3)
	var light: OmniLight3D = projectile.get_children().filter(func(n): return n is OmniLight3D)[0]
	check(light.visible and light.light_energy > 0.0, "actual spell projectile has active world illumination")
	await image_view("06_spell_start_on")
	projectile.set_physics_process(false)
	light.hide()
	# Avoid world budget update until paired screenshot is taken.
	Game.world._lamp_t = 10.0
	await wait(0.2)
	await image_view("07_spell_start_light_off")
	light.show()
	Game.world._lamp_t = 0.0
	projectile.set_physics_process(true)
	await wait(1.2)
	await image_view("08_spell_middle")
	check(light.global_position.distance_to(projectile.global_position) < 0.01, "light follows the real projectile position")
	await wait(1.2)
	await image_view("09_spell_end")
	await wait(3.5)
	check(not is_instance_valid(projectile), "projectile is removed after hit")
	check(get_tree().get_nodes_in_group("environment_local_lights").size() == baseline_lights, "spell and impact lights clean up with their effect")
	target.queue_free()
	var flame := Prop.new()
	flame.kind = "brazier"
	Game.world.add_child(flame)
	flame.global_position = Game.player.global_position + Vector3(2, 0, 0)
	await wait(0.6)
	await image_view("10_flame_local_light")
	var flame_light: OmniLight3D = flame.find_children("*", "OmniLight3D", true, false)[0]
	var previous := flame_light.light_energy
	await wait(0.2)
	check(absf(flame_light.light_energy - previous) > 0.001, "fire energy changes over time")
	flame.queue_free()
	await get_tree().process_frame
	var budget_root := Node3D.new()
	Game.world.add_child(budget_root)
	budget_root.global_position = Game.player.global_position
	for i in 12:
		preload("res://src/render/local_light.gd").attach(budget_root, Vector3(float(i) * 0.2, 1.0, 0), Color("ffac62"), 4.0, 1.0)
	Game.world._update_effect_lights()
	var local_lights := get_tree().get_nodes_in_group("environment_local_lights")
	check(local_lights.filter(func(l): return l.visible).size() <= 8, "nearby effect light budget stays at eight under load")
	check(local_lights.filter(func(l): return l.shadow_enabled).size() <= 1, "nearby effect shadow budget stays at one under load")
	Game.settings["shadows"] = false
	await wait(0.4)
	check(local_lights.all(func(l): return not l.shadow_enabled), "shadow setting disables local effect shadows")
	check(get_tree().get_nodes_in_group("lamp_lights").all(func(l): return not l.shadow_enabled), "shadow setting disables lamp shadows")
	Game.settings["shadows"] = true
	budget_root.queue_free()
	await get_tree().process_frame
	var probes: Array = []
	for at_hour in [18.0, 18.5, 19.0, 19.5, 20.0, 20.5, 21.0, 22.0]:
		hour = at_hour
		Game.time_of_day = at_hour
		Game.world._update_sky(0.0)
		probes.append({"hour":at_hour,"sun":Game.world.sun.light_energy,"moon":Game.world.moon.light_energy,"sun_shadow":Game.world.sun.shadow_enabled,"moon_shadow":Game.world.moon.shadow_enabled})
		check(maxf(Game.world.sun.light_energy, Game.world.moon.light_energy) > 0.1, "directional shape light retained at %s" % at_hour)
	for seam in [[5.999, 6.001], [19.999, 20.001], [23.999, 0.001]]:
		var directions: Array = []
		var energies: Array = []
		for at_hour in seam:
			hour = at_hour
			Game.time_of_day = at_hour
			Game.world._update_sky(0.0)
			directions.append(Game.world.sky_mat.get_shader_parameter("moon_dir"))
			energies.append(Vector2(Game.world.sun.light_energy, Game.world.moon.light_energy))
		check(directions[0].distance_to(directions[1]) < 0.005, "moon direction continuous across %s" % str(seam))
		check(energies[0].distance_to(energies[1]) < 0.005, "key energy continuous across %s" % str(seam))
	set_weather("clear")
	await capture("11_town_day", 462, 448, 45, 18, -0.12, 11.0)
	await capture("12_town_dusk", 462, 448, 45, 18, -0.12, 19.5)
	await capture("13_town_night", 462, 448, 45, 18, -0.12, 22.0)
	for sky_state in [[11.0, "clear"], [19.5, "clear"], [22.0, "clear"], [11.0, "storm"]]:
		hour = sky_state[0]
		set_weather(sky_state[1])
		camera.global_position = Game.player.global_position + Vector3.UP * 60
		camera.look_at(camera.global_position + Vector3(0.6, 0.4, 0.7) * 100)
		await wait(0.5)
		await image_view("sky_%s_%s" % sky_state)
	FileAccess.open(out + "/metrics.json", FileAccess.WRITE).store_string(JSON.stringify({"views":results,"checks":checks,"keys":probes},"\t"))
	print("LIGHTING EFFECTS DONE ", out)
	get_tree().quit(1 if checks.any(func(c): return not c["pass"]) else 0)

func image_view(label: String) -> void:
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + label + ".png")
