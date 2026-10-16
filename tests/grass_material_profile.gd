extends "res://tests/art_style.gd"
## Same camera and resident geometry, alternating only the grass shader.
func run()->void:
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):await get_tree().process_frame
	await capture("grass_optimized",435,500,0,9,-.25)
	var previous:=Shader.new()
	previous.code=FileAccess.get_file_as_string("res://.local/gameplay_world_20261016/grass_before_optimization.gdshader")
	var current:=Shader.new()
	current.code=FileAccess.get_file_as_string("res://.local/gameplay_world_20261016/grass_optimization_candidate.gdshader")
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	var rows:Array=[]
	for pass_id in 4:
		var original:=pass_id%2==0
		for field in get_tree().get_nodes_in_group("grass_fields"):field.mat.shader=previous if original else current
		await wait(1.0)
		var gpu:=0.0;var cpu:=0.0;var wall:=0.0
		for i in 90:
			await get_tree().process_frame
			gpu+=RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
			cpu+=RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
			wall+=get_process_delta_time()*1000.0
		var row:Dictionary={"shader":"original" if original else "optimized","gpu_ms":gpu/90,"render_cpu_ms":cpu/90,"frame_ms":wall/90}
		rows.append(row);print("GRASS MATERIAL ",JSON.stringify(row))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out+"/grass_"+str(pass_id)+".png")
	FileAccess.open(out+"/material_profile.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	get_tree().quit()
