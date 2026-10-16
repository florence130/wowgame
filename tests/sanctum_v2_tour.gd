extends Node
## 海神旧圣堂 v2 实机检查：加载副本，沿路线逐点传送、截图，并报告每个点的地面 / 天花 / 护栏射线检测。
##   godot --path . res://tests/sanctum_v2_tour.tscn -- out=E:/wowgame/.shots/sanctum_v2_game [views=a,b]
const DATA := "res://assets/models/sanctum_v2/sanctum_data.json"
var out_dir := "E:/wowgame/.shots/sanctum_v2_game"
var only: PackedStringArray = PackedStringArray()
var views: Array = []
var _t := 0.0
var _step := 0
var _i := 0
var _loading := 0.0
var report: Array = []

func _ready() -> void:
	# change_scene_to_file 会释放当前场景（也就是本节点）；把真正的执行体挂到 root 上，与 autotest 相同
	if not has_meta("runner"):
		var n := Node.new()
		n.set_script(get_script())
		n.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(n)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out_dir = a.substr(4)
		if a.begins_with("views="):
			only = a.substr(6).split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	if not FileAccess.file_exists(out_dir + "/.gdignore"):
		FileAccess.open(out_dir + "/.gdignore", FileAccess.WRITE)
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.new_character("测试者", "warrior", DB.random_appearance(7, "f"))
	Game.slot_index = -1
	Game.pd["new"] = true
	Game.pd["zone"] = "sanctum"
	Game.pd["level"] = 15
	for f in ["sanctum_ember_root", "sanctum_ember_lake", "sanctum_ember_nave"]:
		Game.pd["flags"][f] = true
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	# 视点：每个段中点（从后看向前进方向）、每个首领场地、每道门、几个侧室
	for seg in d.segments:
		pass
	var s: Dictionary = d.start
	views.append(["entrance", Vector3(s.x, s.y, s.z), float(s.yaw), 12.0, -0.2])
	for r in d.rooms:
		views.append(["room_" + String(r.id), Vector3(r.c[0], r.y, r.c[1]), 0.0, 24.0 if r.has("r") else 20.0, -0.35])
	var nv = d.rooms.filter(func(r): return r.id == "nave")[0]
	views.append(["look_up_nave", Vector3(nv.c[0], nv.y, nv.c[1]), 0.0, 5.0, 0.85])
	var cl = d.rooms.filter(func(r): return r.id == "cistern")[0]
	views.append(["look_up_cistern", Vector3(cl.c[0], cl.y, cl.c[1]), 0.0, 5.0, 0.85])
	views.append(["nave_low", Vector3(nv.c[0] - 30.0, nv.y, nv.c[1]), 0.0, 3.0, -0.05])
	for g in d.gates:
		views.append(["gate_" + String(g.flag).replace("sanctum_", ""), Vector3(g.x, g.y, g.z), float(g.yaw), 10.0, -0.15])
	for sd in d.side:
		views.append(["side_" + String(sd.id), Vector3(sd.x, sd.y, sd.z), 0.0, 8.0, -0.25])
	for p in d.pulls:
		views.append(["pull_" + String(p.id).substr(5), Vector3(p.x, p.y, p.z), float(p.yaw), 14.0, -0.28])
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")

func _process(delta: float) -> void:
	if Game.world == null or Game.world.loading or Game.player == null:
		_loading += delta
		if _loading > 90.0:
			print("TIMEOUT loading")
			get_tree().quit()
		return
	_t += delta
	var p: Player = Game.player
	p.set_hp(p.max_hp)
	if p.dead:
		p.revive(true)
	Game.world.weather = "clear"
	Game.world.weather_amt = 0.0
	Game.world.weather_t = 9999.0
	for actor in get_tree().get_nodes_in_group("units"):
		if actor != p and actor.has_method("set_physics_process"):
			actor.set_physics_process(false)
	if _step == 0 and _t > 3.0:
		_step = 1
	if _step < 1:
		return
	var list: Array = views.filter(func(v): return only.is_empty() or String(v[0]) in only)
	if _i >= list.size():
		FileAccess.open(out_dir + "/report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
		print("TOUR DONE ", list.size(), " views")
		get_tree().quit()
		return
	var v: Array = list[_i]
	if _step == 1:
		_step = -1
		p.set_physics_process(true)
		await Game.world._teleport_to(v[1] + Vector3(0, 1.5, 0))
		await get_tree().create_timer(0.6).timeout
		p.set_physics_process(false)
		p.velocity = Vector3.ZERO
		p.rotation.y = -float(v[2]) + PI * 0.5
		p.cam_yaw = p.rotation.y + PI
		p.cam_dist_target = v[3]
		p.cam_pitch = v[4]
		p.spring.collision_mask = 1
		_step = 2
		_t = 0.0
	elif _step == 2 and _t > 2.0:
		_step = -2   # 下面有 await，防止 _process 重入
		var space := p.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(p.global_position + Vector3(0, 0.5, 0), p.global_position - Vector3(0, 3, 0), 1)
		var down := space.intersect_ray(q)
		var q2 := PhysicsRayQueryParameters3D.create(p.global_position + Vector3(0, 1.0, 0), p.global_position + Vector3(0, 40, 0), 1)
		var up := space.intersect_ray(q2)
		report.append({"view": v[0], "player_y": snappedf(p.global_position.y, 0.01),
			"floor_y": snappedf(down.position.y, 0.01) if not down.is_empty() else null,
			"ceiling_dy": snappedf(up.position.y - p.global_position.y, 0.1) if not up.is_empty() else null,
			"cam": snappedf(p.spring.get_hit_length(), 0.1)})
		Game.hud.close_all()
		Game.hud.visible = false
		await get_tree().process_frame
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [out_dir, v[0]])
		Game.hud.visible = true
		_i += 1
		_step = 1
