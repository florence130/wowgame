extends Node
## 晴岚港 v7 实走检查：真实 Player 物理，按住前进键走几条代表路线，看最终位置和高度。
## Godot --path . res://tests/city_v7_walk.tscn

const ROUTES := [
	# [名称, 起点 x, z, 朝向(度；Godot：0=北 -z、90=西 -x、180=南 +z、270=东 +x), 秒, 期望终点 y 范围(区域坐标，含水位 8)]
	# v7.1（0.8 缩放）坐标；路线与 tools/city_plan_v6 的步行碰撞模拟结果一致
	["王冠大道 东门内→广场（向西）", 284, 435, 90, 8.0, [23.5, 24.6]],
	["上路缘石（大道车行道→北侧人行道）", 220, 432, 0, 3.0, [24.05, 24.4]],
	["王冠阶梯 16→22m", -204, 431, 90, 12.0, [29.5, 30.6]],
	["南桥 16→9m", -36, 522, 180, 26.0, [16.5, 17.6]],
	["王宫天阶 16→30m", -36, -130, 0, 22.0, [37.5, 38.6]],
	["运河桥 中心台→旧城", -180, 258, 0, 6.0, [23.5, 24.6]],
	["星辉湖桥 进湖心岛（终点法师塔台基 +3m）", -532, -74, 0, 12.0, [30.5, 35.0]],
	# 走进功能建筑：冒险者公会门外 → 大厅地面（标高 17.38 + 8）
	["进入冒险者公会", -66, 408, 54, 5.0, [25.2, 25.6]],
	# v7.2：北苑叠园登台（宫后平台西侧阶梯后 T1 → T2：标高 42+8），海崖阶梯下到西海堤（9+8）
	["北苑叠园 一层台 → 二层台", -72, -452, 0, 5.0, [49.8, 50.6]],
	["海崖阶梯 崖上街道 → 西海堤", -690, -74, 90, 11.0, [16.9, 17.6]],
]
var results := []

func _ready() -> void:
	if not has_meta("runner"):
		var n := Node.new()
		n.set_script(get_script())
		n.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(n)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	var app := DB.random_appearance(7, "f")
	Game.new_character("城测", "warrior", app)
	Game.slot_index = -1
	Game.pd["zone"] = "tidewind"
	Game.pd["level"] = 15
	Game.pd["flags"]["city_access"] = true
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")
	_run.call_deferred()

func _run() -> void:
	for i in 300:
		await get_tree().process_frame
		if Game.player and is_instance_valid(Game.player) and Game.world and not Game.world.loading:
			break
	await get_tree().create_timer(3.0).timeout
	var p: Player = Game.player
	var off := WorldLayout.offset("tidewind")
	var fails := 0
	for r in ROUTES:
		var start := Vector3(r[1], 60, r[2]) + off
		Game.world.streamer.prepare(start)
		p.global_position = Vector3(start.x, U.ground_height(get_tree(), start.x, start.z, 80.0) + 0.5, start.z)
		p.velocity = Vector3.ZERO
		p.rotation.y = deg_to_rad(r[3])
		p.cam_yaw = p.rotation.y
		for k in 200:
			await get_tree().process_frame
			if Game.world.ground_ready(p.global_position):
				break
		await get_tree().create_timer(1.0).timeout
		p.global_position.y = U.ground_height(get_tree(), start.x, start.z, 80.0) + 0.5
		await get_tree().create_timer(0.5).timeout
		p.autorun = true
		await get_tree().create_timer(r[4]).timeout
		p.autorun = false
		await get_tree().create_timer(0.6).timeout
		var e := p.global_position - off
		var moved := Vector2(e.x - r[1], e.z - r[2]).length()
		var ok: bool = e.y >= r[5][0] and e.y <= r[5][1] and moved > 5.0
		if not ok:
			fails += 1
		print("CITY7_WALK ", "PASS " if ok else "FAIL ", r[0], "  终点=(%.1f, %.2f, %.1f) 走了 %.1fm" % [e.x, e.y, e.z, moved])
	print("CITY7_WALK RESULT: ", ROUTES.size() - fails, "/", ROUTES.size())
	get_tree().quit(1 if fails else 0)
