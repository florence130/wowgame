extends Node
## 性能探针：在若干城市 / 野外视点各停 4 秒，输出 FPS、CPU/GPU 帧时间、绘制调用、图元数。
## Godot --path . res://tests/perf_probe.tscn [-- toggle=grass|shadow|detail|far]
const SPOTS_ALL := [["plaza", "tidewind", -36, 490, 0], ["oldtown", "tidewind", -204, 6, 0], ["harbor", "tidewind", -276, 598, 180], ["vale_abbey", "vale", 485, 150, 0], ["vale_town", "vale", 435, 520, 0]]
var toggle := ""
var SPOTS: Array = []
var town_only := false
var output := ""

func _ready() -> void:
	if not has_meta("runner"):
		var n := Node.new()
		n.set_script(get_script())
		n.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(n)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a == "town_only": town_only = true
		if a.begins_with("out="): output = a.substr(4)
		if a.begins_with("toggle="):
			toggle = a.substr(7)
	SPOTS = SPOTS_ALL.slice(0, 1) if toggle == "census" else SPOTS_ALL
	if town_only: SPOTS = SPOTS_ALL.slice(4, 5)
	Game.new_character("性能", "warrior", DB.random_appearance(7, "f"))
	Game.slot_index = -1
	Game.pd["zone"] = "tidewind"
	Game.pd["level"] = 15
	Game.pd["flags"]["city_access"] = true
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")
	_run.call_deferred()

func _run() -> void:
	for i in 400:
		await get_tree().process_frame
		if Game.player and Game.world and not Game.world.loading:
			break
	await get_tree().create_timer(3.0).timeout
	Game.world.weather = "clear"
	Game.world.weather_amt = 0.0
	Game.world.weather_t = 9999.0
	Game.time_of_day = 12.0
	Game.settings["day_minutes"] = 1000000.0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var p: Player = Game.player
	for s in SPOTS:
		var w := Vector3(s[2], 80, s[3]) + WorldLayout.offset(s[1])
		await Game.world.streamer.prepare(w)
		p.global_position = Vector3(w.x, U.ground_height(get_tree(), w.x, w.z, 120.0) + 0.5, w.z)
		p.rotation.y = deg_to_rad(s[4])
		p.cam_yaw = p.rotation.y
		p.cam_dist_target = 14
		p.cam_pitch = -0.2
		_apply_toggle()
		await get_tree().create_timer(3.0 if s[1] == "tidewind" else 12.0).timeout
		var fr := 0
		var t0 := Time.get_ticks_usec()
		var gpu := 0.0
		var cpu := 0.0
		while Time.get_ticks_usec() - t0 < 4000000:
			await get_tree().process_frame
			fr += 1
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
		var fps := fr / ((Time.get_ticks_usec() - t0) / 1e6)
		print("PERF %-10s fps=%5.1f gpu_ms=%5.2f render_cpu_ms=%5.2f process_ms=%5.2f draws=%d prims=%dk objs=%d" % [s[0], fps, gpu / fr, cpu / fr,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
		if output != "":
			DirAccess.make_dir_recursive_absolute(output)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output + "/" + s[0] + ".png")
	if toggle == "census":
		_census()
	print("PERF DONE ", toggle)
	get_tree().quit()

func _apply_toggle() -> void:
	match toggle:
		"grass":
			for g in get_tree().root.find_children("*", "GrassField", true, false):
				g.visible = false
		"shadow":
			for l in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
				l.shadow_enabled = false
		"detail":
			for m in get_tree().root.find_children("detail*", "MeshInstance3D", true, false):
				m.visible = false

func _tri(mesh: Mesh) -> int:
	var t := 0
	for i in mesh.get_surface_count():
		var ar := mesh.surface_get_arrays(i)
		t += (ar[Mesh.ARRAY_INDEX].size() if ar[Mesh.ARRAY_INDEX] != null and ar[Mesh.ARRAY_INDEX].size() > 0 else ar[Mesh.ARRAY_VERTEX].size()) / 3
	return t

## 按"脚本类 / 父节点名"汇总可见几何体的三角形数（多重网格 × 实例数）
func _census() -> void:
	var tally := {}
	var cache := {}
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var tris := 0
		if g is MeshInstance3D and (g as MeshInstance3D).mesh:
			var m: Mesh = (g as MeshInstance3D).mesh
			if not cache.has(m): cache[m] = _tri(m)
			tris = cache[m]
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh and (g as MultiMeshInstance3D).multimesh.mesh:
			var mm: MultiMesh = (g as MultiMeshInstance3D).multimesh
			if not cache.has(mm.mesh): cache[mm.mesh] = _tri(mm.mesh)
			tris = cache[mm.mesh] * (mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count)
		else:
			continue
		var owner_n: Node = g
		var key := ""
		while owner_n != null and key == "":
			var sc = owner_n.get_script()
			if sc != null and sc.get_global_name() != "":
				key = sc.get_global_name()
			owner_n = owner_n.get_parent()
		key = key if key != "" else String(g.get_parent().name)
		tally[key] = tally.get(key, 0) + tris
	var keys := tally.keys()
	keys.sort_custom(func(a, b): return tally[a] > tally[b])
	for k in keys.slice(0, 14):
		print("CENSUS %-24s %8dk tris" % [k, tally[k] / 1000])
