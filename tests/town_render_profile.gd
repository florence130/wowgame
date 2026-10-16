extends "res://tests/art_style.gd"
## Fixed camera category isolation. Hides are diagnostic only and restored.
func run() -> void:
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):await get_tree().process_frame
	await capture("town_profile",435,500,0,9,-.25)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	var zone:Zone=Game.world.zones.vale
	var groups:Dictionary={"grass":get_tree().get_nodes_in_group("grass_fields"),"actors":get_tree().get_nodes_in_group("units"),"vegetation":[zone.get_node("Vegetation")],"buildings":[zone.get_node("Buildings")],"props":[zone.get_node("Props")]}
	var rows:Array=[]
	for category in ["baseline","grass","actors","vegetation","buildings","props"]:
		var restore:Array=[]
		for n in groups.get(category,[]):
			if n is Node3D and n.visible:restore.append(n);n.hide()
		await wait(.5)
		var gpu:=0.0;var cpu:=0.0;var draws:=0.0
		for i in 45:
			await get_tree().process_frame
			gpu+=RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
			cpu+=RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
			draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var row:Dictionary={"hidden":category,"gpu_ms":gpu/45,"render_cpu_ms":cpu/45,"draw_calls":draws/45}
		rows.append(row);print("TOWN RENDER ",JSON.stringify(row))
		for n in restore:n.show()
	FileAccess.open(out+"/render_profile.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	get_tree().quit()
