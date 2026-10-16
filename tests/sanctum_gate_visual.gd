extends Node3D
## Isolated visual states of the live zone's gates. Flags here are a fixture,
## separate from the continuous combat run which earns its seeds naturally.
var out_dir := "res://.shots/sanctum_gate_visual"
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):out_dir=arg.substr(4)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	Game.new_character("门锁画面检查","warrior",DB.random_appearance(7,"f"))
	Game.slot_index=-1;Game.pd["flags"]={}
	U.bmat(2,Color.GRAY)
	var zone: Node3D=load("res://scenes/zones/windwhisper_sanctum.tscn").instantiate()
	add_child(zone)
	await get_tree().physics_frame
	zone.process_mode=Node.PROCESS_MODE_DISABLED
	var environment := WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("8babbf")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("c8d2d8")
	environment.environment.ambient_light_energy=.75
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	add_child(environment)
	var sun := DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-28,0)
	sun.light_energy=1.15;sun.shadow_enabled=true;add_child(sun)
	var camera := Camera3D.new();camera.fov=58;add_child(camera);camera.make_current()
	var gates: Array=get_tree().get_nodes_in_group("gates")
	var final_gate: Node3D=gates.filter(func(g):return g.flag=="sanctum_final_open")[0]
	for stage in 4:
		if stage>0:Game.pd.flags[["sanctum_ember_root","sanctum_ember_lake","sanctum_ember_nave"][stage-1]]=true
		for gate in gates:gate.refresh_gate()
		camera.global_position=final_gate.to_global(Vector3(1,9,17))
		camera.look_at(final_gate.to_global(Vector3(0,2.8,0)))
		await capture("final_%d_seeds" % stage)
	for gate in gates:
		if gate==final_gate:continue
		for lit in [false,true]:
			Game.pd.flags[gate.flag]=lit;gate.refresh_gate()
			var door_x := 4.5 if gate.flag=="sanctum_ember_root" else 0.0
			camera.global_position=gate.to_global(Vector3(door_x+1,9,17))
			camera.look_at(gate.to_global(Vector3(door_x,2.8,0)))
			await capture(gate.flag+("_open" if lit else "_locked"))
	camera.global_position=Vector3(36,26,164)
	camera.look_at(Vector3(36,20,149))
	await capture("garden_eave_combat_view")
	print("GATE VISUAL 8 gate frames plus garden camera; isolated stage flags, no real save writes")
	get_tree().quit()

func capture(label: String) -> void:
	for frame in 5:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out_dir)+"/"+label+".png")
