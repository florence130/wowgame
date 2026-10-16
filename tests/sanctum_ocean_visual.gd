extends Node3D
## Actual saved scene previews. Isolated flags; no writes to a real character.
var out_dir := "res://.shots/sanctum_ocean_phase1"


var camera: Camera3D
var samples: Array=[]

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):out_dir=arg.substr(4)
		if arg=="baseline=true" or arg.begins_with("scene="):
			push_error("旧版地图预览入口已移除")
			get_tree().quit(2)
			return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	Game.new_character("海洋圣堂环境检查","warrior",DB.random_appearance(7,"f"))
	Game.slot_index=-1;Game.pd["flags"]={}
	var scene_path := "res://scenes/zones/windwhisper_sanctum.tscn"

	var zone: Node3D=load(scene_path).instantiate();add_child(zone)
	await get_tree().physics_frame
	# Freeze scripts only: disabling the whole tree removes collision bodies.
	zone.set_process(false);zone.set_physics_process(false)
	for node in zone.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
	# Native character models at original scale provide a readable MMO size cue.
	# They are stationary visual markers, not a gameplay or combat fixture.
	for i in 3:
		var avatar := Avatar.new();add_child(avatar)
		avatar.setup(DB.random_appearance(7+i,"f" if i==0 else "m"),DB.outfit_gear("knight",7+i))
		avatar.position=Vector3(102.8+float(i)*1.2,24.05,115.0+float(i%2)*1.1)
		avatar.rotation_degrees.y=0
	var env := WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("9db8c6")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("c8d2d8")
	env.environment.ambient_light_energy=.40
	env.environment.ssao_enabled=true;env.environment.ssao_radius=1.05;env.environment.ssao_intensity=1.25
	env.environment.ssao_power=1.15;env.environment.ssao_light_affect=.18
	env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-28,0)
	sun.light_energy=1.0;sun.shadow_enabled=true;add_child(sun)
	camera=Camera3D.new();camera.fov=60;camera.far=900;add_child(camera);camera.make_current()
	for view in [
		["reference_nave",Vector3(104,32,132),Vector3(104,28.6,40)],
		["reference_mid_nave",Vector3(104,32,111),Vector3(104,34,35)],
		["nave_altar",Vector3(104,33,76),Vector3(104,29,34)],
		["nave_axis",Vector3(104,34,135),Vector3(104,28,70)],
		["garden_court",Vector3(43,30,156),Vector3(37,20,132)],
		["prayer_cloister",Vector3(70,29,188),Vector3(44,20,174)],
		["rat_stores",Vector3(107,16,131),Vector3(109,11,112)],
		["rat_nests",Vector3(107,15,120),Vector3(107,10,140)],
		["rat_delivery",Vector3(173,31,151),Vector3(174,23,121)],
		["departure_bell",Vector3(36,42,53),Vector3(36,36,21)],
	]:
		camera.global_position=view[1];camera.look_at(view[2]);select_local_lights(camera.global_position)
		env.environment.ambient_light_energy=.40*preload("res://src/render/sanctum_window_rig.gd").ambient_factor(camera.global_position)
		await capture(view[0])
	# Same 16m sphere SpringArm and pitch as the continuous gameplay runner.
	var pivot := Node3D.new();add_child(pivot)
	var arm := SpringArm3D.new();arm.spring_length=16;arm.margin=.3;arm.collision_mask=1
	var sphere := SphereShape3D.new();sphere.radius=.25;arm.shape=sphere;pivot.add_child(arm)
	var actual := Camera3D.new();actual.fov=60;arm.add_child(actual);actual.make_current()
	for view in [["garden_spring_16m",Vector3(38,19.55,138),0.0],["apse_spring_16m",Vector3(104,25.55,60),0.0],["stores_spring_16m",Vector3(108,9.55,124),0.0],["delivery_spring_16m",Vector3(172,21.55,134),0.0]]:
		pivot.global_position=view[1];pivot.rotation=Vector3(-.4,view[2],0)
		for frame in 8:await get_tree().physics_frame
		select_local_lights(actual.global_position)
		env.environment.ambient_light_energy=.40*preload("res://src/render/sanctum_window_rig.gd").ambient_factor(pivot.global_position)
		samples.append({"name":view[0],"target_length":16,"actual_length":arm.get_hit_length(),"camera":actual.global_position,"pivot":pivot.global_position})
		await capture(view[0])
	var report := {"baseline":false,"scene":scene_path,"real_save_writes":false,"boundary":"Actual saved architecture with ten fixed cameras and four player-equivalent 16m SpringArm probes. Three stationary native character models provide unscaled size reference. Same daylight/ambient and finite saved light budgets for before/after. No combat or enemy theme validation.","camera_samples":samples,"mesh_instances":zone.find_children("*","MeshInstance3D",true,false).size()}
	var file := FileAccess.open(out_dir+"/report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("OCEAN VISUAL ",JSON.stringify(report))
	get_tree().quit()

func capture(label: String) -> void:
	for frame in 5:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out_dir)+"/"+label+".png")
	if err!=OK:push_error("preview save failed "+label)

func select_local_lights(p: Vector3) -> void:
	# Match a finite world light budget; previously all authored lamps were hidden
	# in this isolated fixture, making saved-room comparisons uniformly flat.
	var lights := get_tree().get_nodes_in_group("environment_local_lights")
	lights.sort_custom(func(a,b):return a.global_position.distance_squared_to(p)<b.global_position.distance_squared_to(p))
	for i in lights.size():
		lights[i].visible=i<8
		if lights[i].get("authored_energy")!=null:lights[i].light_energy=lights[i].authored_energy
		lights[i].shadow_enabled=i<1 and lights[i].global_position.distance_to(p)<24.0
	for rig in get_tree().get_nodes_in_group("sanctum_window_rig"):rig.select_lights(p)
