extends Node3D
## Isolated actual boss cast and interrupt, no combat balance claim.
func _ready() -> void:
	Game.new_character("丧钟预警检查","warrior",DB.random_appearance(7,"f"))
	Game.slot_index=-1
	Game.pd["flags"]={"sanctum_ember_root":true,"sanctum_ember_lake":true,"sanctum_ember_nave":true}
	U.bmat(2,Color.GRAY)
	var zone: Node3D=load("res://scenes/zones/windwhisper_sanctum.tscn").instantiate();add_child(zone)
	await get_tree().physics_frame
	var mob: Mob=zone.spawn_mob("boss_victor",Vector3(36,32.1,32),16)
	mob.set_physics_process(false)
	var environment := WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("94b2c3")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_energy=.8
	add_child(environment)
	var sun := DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-28,0);sun.light_energy=1.1;add_child(sun)
	var camera := Camera3D.new();add_child(camera);camera.global_position=Vector3(40,44,50);camera.look_at(Vector3(36,34,32));camera.make_current()
	var failures := []
	if not mob.begin_cast(DB.spell("mob_bell"),mob):failures.append("cast did not start")
	if not is_instance_valid(mob._bell_warning):failures.append("warning absent")
	await get_tree().create_timer(.9).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.shots/sanctum_bell_visual"))
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.shots/sanctum_bell_visual/warning.png"))
	mob.stop_cast(false)
	await get_tree().process_frame
	if is_instance_valid(mob._bell_warning):failures.append("interrupted warning retained")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.shots/sanctum_bell_visual/interrupted.png"))
	var victim := Unit.new();add_child(victim);victim.faction="player"
	victim.max_hp=1000;victim.hp=1000;victim.global_position=Vector3(40,32.1,32)
	var outside := Unit.new();add_child(outside);outside.faction="player"
	outside.max_hp=1000;outside.hp=1000;outside.global_position=Vector3(80,32.1,32)
	# Real hit rolls can resist once; repeat bounded casts, retaining native rolls.
	for attempt in 8:
		mob.gcd=0;mob.cooldowns.clear();mob.school_lock.clear()
		if not mob.begin_cast(DB.spell("mob_bell"),mob):failures.append("damage cast did not start")
		mob._tick_cast(3.1)
		if victim.hp<1000:break
	if victim.hp>=1000:failures.append("completed bell did not damage nearby target")
	if outside.hp!=1000:failures.append("completed bell damaged target outside radius")
	if is_instance_valid(mob._bell_warning):failures.append("completed warning retained")
	FileAccess.open("res://.shots/sanctum_bell_visual/report.json",FileAccess.WRITE).store_string(JSON.stringify({"isolated_cast":true,"nearby_damage":1000-victim.hp,"outside_damage":1000-outside.hp,"failures":failures}))
	print("BELL VISUAL failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
