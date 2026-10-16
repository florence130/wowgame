extends Node
## 自动化冒烟测试：创建角色→进入世界→截图→战斗→任务

var step := 0
var t := 0.0
var shots := 0
var out_dir := "/tmp/shots"
var cls := "warrior"
var mode := "basic"
var tour_zone := "tidewind"
var tour_i := 0
var tour_views := PackedStringArray()
var tour_hour := -1.0   # hour=：巡游时固定游戏时刻（美术对比用），<0 不固定
var _loading_elapsed := 0.0
var _aerial: Camera3D
var _clean_tour := false
var _mmo_camera_samples: Array = []
var _section_restore: Array = []
## 巡游点：[名称, x, z, 镜头朝向(度，0=朝北，可省), 镜头距离(可省), 俯仰(可省)]
const TOURS := {
	# 晴岚港 v7（docs/city_v7/game.json，区域坐标）
	# v7.1：全城以东门 (300,430) 为基点 0.8 缩放；新增室内（in_*）与传送石（ws_*）检查点
	"city": [["gate", 330, 430, 90, 24, -0.15], ["boulevard", 180, 442, 90, 12, -0.08], ["plaza", -36, 490, 0, 30, -0.2], ["clock", -60, 462, 315, 30, -0.15],
		["market", 116, 376, 0, 22, -0.15], ["gatebridge", 208, 435, 90, 14, -0.08], ["artisan", 116, 498, 90, 12, -0.08], ["canal", 44, 256, 0, 22, -0.2],
		["royal_stair", -36, -146, 0, 30, -0.15], ["palace", 120, -250, 300, 40, -0.1], ["mage_lake", -532, -58, 0, 40, -0.25], ["c_core", 36, 290, 45, 9, 0.16], ["c_trade", 114, 292, 45, 9, 0.16], ["c_artisan", 248, 444, 225, 9, 0.16], ["c_oldtown", -283, -153, 45, 9, 0.16], ["c_mage", -638, -312, 135, 9, 0.16], ["c_station", -48, 634, 45, 9, 0.16], ["pt_a", -60, 440, 150, 22, -0.05], ["pt_b", -89, 450, 0, 14, 0.0], ["l_core", -76, 496, 180, 8, 0.15], ["l_hero", -236, 360, 0, 8, 0.15], ["l_artisan", 278, 496, 180, 8, 0.15], ["l_oldtown", -329, -72, 0, 8, 0.15], ["l_academy", -423, 504, 0, 8, 0.15], ["l_harbor", -212, 552, 0, 8, 0.15],["ml1", -532, -40, 0, 10, 0.1], ["ml2", -532, -40, 0, 22, -0.08], ["oldtown", -204, 6, 0, 12, -0.08],
		["military", 80, -34, 0, 30, -0.2], ["park", 244, -58, 0, 30, -0.2], ["academy", -356, 430, 90, 20, -0.12], ["nobles", -580, 470, 0, 30, -0.2],
		["cathedral", -588, 534, 180, 30, -0.15], ["harbor", -276, 598, 180, 30, -0.15], ["station", 4, 694, 180, 30, -0.15],
		["aerial", -204, 286, 0, 30, -0.4, 900], ["aerial_north", -180, -114, 0, 30, -0.4, 450],
		["in_guild", -90, 391, 54, 4, 0.05], ["in_guild_ceiling", -90, 391, 54, 3, 0.6],["in_cityhall", -36, 329, 0, 4, 0.05], ["in_cathedral", -588, 589, 180, 4, 0.05], ["in_station", 4, 750, 180, 4, 0.05],
		["in_shop", 23, 256, 0, 3, 0.05], ["ws_plaza", 3, 436, 90, 7, -0.1], ["ws_market", 113, 359, 90, 7, -0.1],
		# v7.2 过渡带：西海堤 / 离岸岛 / 飞艇天桥；北苑叠园
		["w_aerial", -820, 150, 0, 30, -0.2, [[-1230, 230, -140], [-800, 20, 150]]], ["w_shelf", -745, 60, 90, 18, -0.1], ["w_isle", -822, 42, 270, 16, -0.12],
		["w_viaduct", -820, 282, 90, 24, -0.1, [[-690, 70, 380], [-860, 30, 282]]], ["w_air", -939, 282, 270, 22, -0.15], ["w_pier", -815, 696, 90, 20, -0.1],
		["n_aerial", -36, -520, 0, 30, -0.4, [[-36, 150, -230], [-36, 55, -560]]], ["n_apron", -36, -389, 0, 14, -0.1], ["n_summit", -42, -650, 180, 18, -0.12],
		["n_wide", -36, -520, 0, 30, -0.4, [[-640, 250, -760], [-60, 45, -330]]]],
	"vale": [["g_aer", 435, 480, 0, 30, -0.55, 90], ["mine_a", 300.0, 585.0, 118, 14, -0.3], ["mine_b", 175.0, 625.0, 298, 14, -0.3], ["mine_top", 220.0, 610.0, 298, 150, -1.0], ["lake_big", 735.0, 320.0, 0, 190, -1.0], ["lake_shore", 646.0, 392.0, 20, 16, -0.15], ["g_aer2", 435, 440, 200, 30, -0.5, 55], ["g_inn", 462, 448, 45, 18, -0.06], ["g_smith", 395, 446, 300, 16, -0.06], ["g_in_inn", 476, 433, 45, 5, 0.05],
		["g_in_smith", 395.2, 442.2, 54.5, 3.5, 0.08], ["g_in_smith2", 391.6, 438.9, 144.5, 3.0, 0.1], ["g_home", 350, 410, 120, 18, -0.08], ["g_cot", 512, 417, 123, 12, -0.1], ["g_cot2", 540, 395, 350, 12, -0.1], ["g_wall", 470, 440, 20, 7, 0.0], ["g_fount", 435, 448, 0, 12, -0.12], ["t_inn", 435, 438, 0, 16, -0.05], ["t_inn_in", 438, 386, 0, 5, 0.05], ["t_smith", 409, 452, 40, 16, -0.05], ["t_store", 461, 452, 320, 16, -0.05], ["t_road", 500, 520, 300, 14, -0.15], ["f_farm", 190, 436, 330, 20, -0.1], ["f_barn", 232, 440, 60, 22, -0.1], ["f_thatch", 565, 480, 230, 18, -0.1], ["g_props", 405, 505, 40, 16, -0.15], ["g_street", 435, 540, 0, 22, -0.08], ["abbey", 485, 150, 0, 30, -0.3], ["abbey_court", 485, 104, 0, 24, -0.3], ["abbey_chapel", 500, 82, 315, 20, -0.2], ["abbey_west", 470, 112, 45, 26, -0.35], ["abbey_grave", 418, 158, 330, 18, -0.25], ["meadow", 430, 230, 200, 14, -0.22], ["town", 435, 500, 0, 26, -0.35], ["farm", 200, 480, 330, 24, -0.3], ["lake", 700, 330, 60, 26, -0.3], ["hills_n", 480, 300, 0, 30, -0.12], ["hills_e", 600, 520, 90, 30, -0.1], ["exit_sw", 120, 820, 225, 30, -0.15], ["aerial", 435, 500, 0, 30, -0.4, 420], ["aerial_low", 260, 600, 0, 30, -0.4, 120],
		["seam_pass", 90, 492, 90, 26, -0.16], ["seam_west", -90, 490, 90, 30, -0.16], ["seam_east", -60, 470, 270, 30, -0.14],
		["coast", 120, 900, 200, 30, -0.2], ["coast_b", 160, 935, 180, 14, -0.12], ["seam_aerial", 0, 520, 0, 30, -0.4, 600], ["world_aerial", -200, 640, 0, 30, -0.4, 1300]],
	# 修道院近景检查（mode=tour zone=abbey）
	"abbey": [["a_aerial", 490, 74, 0, 30, -0.9, 95], ["a_gate_out", 485, 140, 0, 16, -0.2], ["a_gate_in", 485, 108, 180, 12, -0.15],
		["a_chapel_front", 485, 88, 0, 14, -0.15], ["a_chapel_se", 500, 78, 330, 18, -0.2], ["a_chapel_e", 505, 56, 270, 14, -0.15], ["a_chapel_nw", 470, 36, 135, 16, -0.25],
		["a_tower", 474, 76, 330, 14, -0.15], ["a_inside", 485, 60, 0, 3, -0.05], ["a_house_e", 522, 86, 90, 14, -0.15], ["a_house_w", 461, 96, 270, 14, -0.15],
		["a_cottage_se", 520, 120, 135, 12, -0.15], ["a_cottage_nw", 452, 50, 0, 12, -0.15], ["a_court_w", 500, 96, 270, 20, -0.3], ["a_scale_qm", 508, 92, 90, 7, -0.08], ["a_scale_chapel", 485, 80, 0, 9, -0.05], ["a_cypress", 487.5, 101, 300, 4, -0.15], ["a_hall_door", 471, 88, 90, 6, -0.1], ["a_hall_in", 461, 88, 90, 4, -0.05], ["a_hall_ceiling", 459, 88, 90, 3, 0.6], ["a_qm_in", 514, 92, 270, 3.5, -0.05], ["a_gate_leaf", 485, 112, 0, 4, -0.05], ["a_court_grass", 486, 66, 200, 10, -0.6], ["a_altar", 485, 54, 0, 4, -0.2]],
	# 美术风格前后对比（mode=tour zone=style hour=11）：修道院庭院 / 礼拜堂 / 草地 / 金穗镇 / 农庄 / 湖 / 丘陵 / 室内
	"style": [["s_abbey_court", 485, 104, 0, 24, -0.3], ["s_chapel", 500, 82, 315, 20, -0.2], ["s_gate_out", 485, 140, 0, 16, -0.2], ["s_meadow", 430, 230, 200, 14, -0.22],
		["s_town", 435, 500, 0, 26, -0.35], ["s_town_low", 440, 515, 340, 10, -0.12], ["s_farm", 200, 480, 330, 24, -0.3], ["s_lake", 700, 330, 60, 26, -0.3],
		["s_hills", 600, 520, 90, 30, -0.1], ["s_hall_in", 461, 88, 90, 4, -0.05], ["s_aerial", 300, 600, 0, 30, -0.4, 120]],
	# 地形检查（mode=tour zone=terrain hour=11）：坐标为晨露谷区域坐标（潮风高地的点已换算：高地区域坐标 + (-960, 160)）
	"terrain": [["t_abbey_back", 485, 175, 0, 30, -0.18], ["t_mine_aerial", 220, 610, 0, 30, -0.4, 110], ["t_mine_ground", 300, 585, 270, 18, -0.12],
		["t_lake_aerial", 770, 290, 0, 30, -0.4, 190], ["t_lake_ground", 688, 338, 45, 16, -0.12], ["t_hyena", 240, 720, 200, 30, -0.15],
		["t_tower", 560, 720, 135, 30, -0.15], ["t_plateau_edge", -380, 580, 0, 32, -0.1], ["t_plateau_ramp", -515, 625, 340, 26, -0.15],
		["t_cliffs", -190, 650, 120, 32, -0.12], ["t_grass", 430, 230, 200, 6, -0.25], ["t_world", -200, 640, 0, 30, -0.4, 1300]],
	"tidewind": [["outpost", 700, 395], ["gate", 262, 450, 90], ["beach", 490, 860], ["farm", 560, 625], ["camp", 300, 190], ["rail", 390, 335], ["cliffs", 840, 560], ["sanctum", 790, 770]],
	"sanctum": [["entrance",104,239,0,10,-.15,[[104,24,241],[104,23,210]]],
		["court",104,184,0,12,-.2,[[116,25,198],[95,24,174]]],
		["cloister",48,192,0,8,-.2,[[67,22,195],[29,21,188]]],
		["rootgarden",38,134,0,14,-.2,[[49,26,150],[34,20,128]]],
		["cellar",105,126,90,16,-.2,[[119,13,137],[97,10,118]]],
		["supply",172,134,0,14,-.3,[[185,29,151],[166,22,125]]],
		["nave",104,118,0,12,-.1,[[108,29,135],[102,29,55]]],
		["altar",104,50,0,14,-.2,[[118,33,65],[103,28,40]]],
		["bell",36,32,0,18,-.3,[[51,42,49],[31,36,22]]],
		["emptyroom",85,220,270,4,-.05,[[88,23,223],[82,22,216]]],
		["chestroom",6,138,0,4,-.1,[[9,21,142],[6,19,134]]],
		["cryptchest",86,96,0,4,-.1,[[89,12,99],[85,9,93]]],
		["ledger",209,133,90,4,-.1,[[204,23,137],[213,22,130]]],
		["chapel",79,105,0,4,-.1,[[81,27,109],[78,26,101]]],
		["brewroom",105,152,0,4,-.1,[[108,12,155],[103,10,148]]],
		["mmo_cellar",105,126,90,16,-.28],
		["mmo_cellar_north",105,126,180,16,-.4],
		["mmo_cellar_south",105,126,0,16,-.4],
		["mmo_cellar_west",105,126,270,16,-.4],
		["mmo_cellar_high",105,126,90,16,-.6],
		["mmo_crypt",86,91,0,12,-.3],
		["mmo_brew",105,150,0,12,-.3],
		["mmo_nave",104,118,0,20,-.3],
		["mortuary_out",60,130,0,5,-.1,[[51,21,131],[73,20,130]]],
		["mortuary_in",72,125,0,4,-.1,[[73,13,117],[86,11,109]]],
		["loading_out",146,138,0,6,-.1,[[152,25,144],[130,16,130]]],
		["loading_in",129,129,0,4,-.1,[[125,12,128],[146,20,137]]],
		["foundation",209,133,0,6,-.1,[[222,24,147],[205,21,136]]],
		["underground_cutaway",105,126,0,30,-.4,[[144,82,179],[93,9,118]]],
		["overview",104,184,0,30,-.4,[[230,180,300],[100,21,128]]],
		["overview_cutaway",104,184,0,30,-.4,[[108,235,265],[108,21,130]]]],
}
## 区域坐标 → 世界坐标（无缝大世界：潮风高地整体平移 WorldLayout.offset），y 取该处地面高度
func _wp(zone_id: String, x: float, z: float) -> Vector3:
	var o := WorldLayout.offset(zone_id)
	var v := Vector3(x + o.x, 0.0, z + o.z)
	v.y = U.ground_height(get_tree(), v.x, v.z, 20.0)
	return v

## 巡游所在区域（巡游名 ≠ 区域名时登记）
const TOUR_ZONES := {"city": "tidewind", "abbey": "vale", "style": "vale", "terrain": "vale"}

func _ready() -> void:
	if not has_meta("runner"):
		var n := Node.new()
		n.set_script(get_script())
		n.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(n)
		return
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("class="):
			cls = a.substr(6)
		if a.begins_with("mode="):
			mode = a.substr(5)
		if a.begins_with("zone="):
			tour_zone = a.substr(5)
		if a.begins_with("out="):
			out_dir = a.substr(4)
		if a.begins_with("hour="):
			tour_hour = float(a.substr(5))
		if a.begins_with("views="):
			tour_views = a.substr(6).split(",")
		if a == "clean=true":
			_clean_tour = true
	# Windows 没有 /tmp：默认写到工程内 .shots（点开头目录不会被编辑器导入）
	if OS.get_name() == "Windows" and out_dir == "/tmp/shots":
		out_dir = ProjectSettings.globalize_path("res://.shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	if not FileAccess.file_exists(out_dir + "/.gdignore"):
		FileAccess.open(out_dir + "/.gdignore", FileAccess.WRITE)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if mode == "front":
		get_tree().change_scene_to_file.call_deferred("res://scenes/boot.tscn")
		return
	var app := DB.random_appearance(7, "f")
	app["hair"] = 7
	app["hair_color"] = DB.HAIR_COLORS[0]
	Game.new_character("测试者", cls, app)
	Game.slot_index = -1  # Automated tests must never overwrite a real character save.
	Game.pd["new"] = true
	if mode == "sanctum_grounding":
		for key in ["move_forward","move_back","strafe_left","strafe_right","turn_left","turn_right","jump"]: Game.keybinds[key] = KEY_NONE
		Game.pd["zone"] = "sanctum"
		Game.pd["new"] = false
		Game.pd["pos"] = Vector3(105,8.1,126)
		Game.pd["level"] = 15
		Game.pd["flags"]["sanctum_ember_root"] = true
	if mode == "dungeon":
		Game.pd["zone"] = "sanctum"
		Game.pd["level"] = 15
	if mode == "portal":
		Game.pd["zone"] = "tidewind"
		Game.pd["level"] = 15
	if mode == "ui":
		Game.pd["zone"] = "tidewind"
		Game.pd["level"] = 15
		Game.pd["flags"]["city_access"] = true
		Game.pd["money"] = 123456
		for it in ["potion_heal2", "food_cheese", "mat_wool", "gen|chest|mail|green|14|bear", "gen|sword|blue|15|str", "c_aether_pendant"]:
			Game.add_item(it, 3 if DB.get_item(it).get("stack", 1) > 1 else 1, true)
	if mode == "crafting":
		Game.pd["zone"] = "tidewind"
		Game.pd["level"] = 15
		Game.pd["flags"]["city_access"] = true
		Game.pd["money"] = 500000
	if mode == "services":
		Game.pd["zone"] = "tidewind"
		Game.pd["level"] = 15
		Game.pd["flags"]["city_access"] = true
		Game.pd["money"] = 500000
	if mode == "tour":
		Game.pd["zone"] = TOUR_ZONES.get(tour_zone, tour_zone)
		Game.pd["level"] = 15
		if tour_zone == "city":
			Game.pd["flags"]["city_access"] = true
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")

## 副本首领测试：带同伴按三枚火种顺序挑战四个首领（不开无敌、不复活），报告击杀用时或失败原因
const DUNGEON_BOSSES := ["boss_rootguard", "boss_lake", "boss_sanctum_lantern", "boss_victor"]
var boss_i := 0
var boss: Mob = null
var results: Array = []

func _dungeon_step(p: Player) -> void:
	if step == 0:
		if t < 4.0:
			return
		Commands.run("/gm learn")
		step = 1
		t = 0
	if boss_i >= DUNGEON_BOSSES.size() or p.dead:
		if p.dead:
			results.append("%s: 玩家阵亡（%.0fs）" % [DUNGEON_BOSSES[boss_i], t])
		print("DUNGEON RESULT ", " | ".join(results))
		get_tree().quit()
		return
	var id: String = DUNGEON_BOSSES[boss_i]
	if step == 1:
		boss = null
		for m in get_tree().get_nodes_in_group("mobs"):
			if m.mob_id == id and not m.dead:
				boss = m
		if boss == null:
			results.append("%s: 未找到" % id)
			boss_i += 1
			return
		# 模拟玩家已清完首领周围的小怪
		for m in get_tree().get_nodes_in_group("mobs"):
			if m != boss and not m.is_boss and m.global_position.distance_to(boss.global_position) < 35.0:
				m.queue_free()
		p.set_hp(p.max_hp)
		var off := Vector3(0, 1, 10)
		p.global_position = boss.global_position + off
		for a in get_tree().get_nodes_in_group("allies"):
			a.global_position = boss.global_position + off + Vector3(randf_range(-2, 2), 0, 2)
			a.set_hp(a.max_hp)
		p.face_towards(boss.global_position)
		p.cam_yaw = p.rotation.y
		p.cam_dist_target = 16
		p.cam_pitch = -0.4
		p.set_target(boss)
		p.interact_with(boss)
		step = 2
		t = 0
	elif step == 2:
		if is_instance_valid(boss) and not boss.dead:
			if p.target != boss:
				p.set_target(boss)
				p.interact_with(boss)
			p.face_towards(boss.global_position)
			for i in 6:
				p.use_bar_slot(i)
			if shots < 20 and fmod(t, 20.0) < get_process_delta_time():
				await shot("boss_%s_%d" % [id, int(t)])
		if not is_instance_valid(boss) or boss.dead:
			results.append("%s: 击杀 %.0fs，掉落=%s，玩家HP %d/%d" % [id, t, str(is_instance_valid(boss) and boss.has_loot()), p.hp, p.max_hp])
			await shot("boss_%s_dead" % id)
			boss_i += 1
			step = 1
		elif t > 180.0:
			results.append("%s: 超时，首领剩余HP %d/%d" % [id, boss.hp, boss.max_hp])
			boss_i += 1
			step = 1

## 传送门往返：潮风高地圣堂入口 → 副本 → 副本出口 → 潮风高地
const PORTAL_LEGS := [["tidewind", Vector3(790, 0, 796), "sanctum"], ["sanctum", Vector3(104, 20, 243), "tidewind"]]
var leg := 0

func _portal_step(p: Player) -> void:
	if leg >= PORTAL_LEGS.size():
		print("PORTAL OK 往返完成，当前区域=", Game.pd["zone"], " 位置=", p.global_position.round())
		get_tree().quit()
		return
	var l: Array = PORTAL_LEGS[leg]
	if step == 0 and t > 25.0:
		print("PORTAL FAIL 等待起点区域 %s 超时：当前区域=%s 位置=%s" % [l[0], Game.pd["zone"], p.global_position.round()])
		get_tree().quit()
		return
	if step == 0 and t > 3.0 and Game.pd["zone"] == l[0]:
		var pos: Vector3 = l[1]
		pos = _wp(l[0], pos.x, pos.z) + Vector3(0, 1.0, 0)
		step = -1
		await Game.world._teleport_to(pos)
		p.velocity = Vector3.ZERO
		step = 1
		t = 0
	elif step == 1:
		if Game.pd["zone"] == l[2]:
			print("PORTAL %s -> %s 用时 %.1fs，落点=%s" % [l[0], l[2], t, p.global_position.round()])
			await shot("portal_" + l[2])
			leg += 1
			step = 0
			t = 0
		elif t > 20.0:
			print("PORTAL FAIL %s -> %s 未触发" % [l[0], l[2]])
			get_tree().quit()

## 主城服务：银行 / 幻化 / 交易所 / 地下城查找器 / 列车，逐项操作并截图
var fails: Array = []

func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)

func _goto_npc(p: Player, id: String) -> NPC:
	if Game.world.streamer:
		for z in Game.world.zones.values():
			for spot in z.actor_sources:
				if spot is NpcSpot and spot.npc_id == id:
					await Game.world._teleport_to(spot.global_position + Vector3(0, 0.5, 3))
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.npc_id == id:
			p.global_position = n.global_position + n.forward_dir() * 3.0 + Vector3(0, 0.5, 0)
			p.face_towards(n.global_position)
			p.cam_yaw = p.rotation.y
			p.cam_dist_target = 8
			return n
	return null

## 专业技能：通过训练师对话学习 → 在铁砧旁连续制造 → 技能提升 → 买配方 → 工作台限制 → 烹饪/精工
func _wait_crafting(win, timeout: float) -> void:
	var tt := 0.0
	while win.queue_left > 0 and tt < timeout:
		await _wait(0.25)
		tt += 0.25
	await _wait(0.3)

func _crafting(p: Player) -> void:
	var hud = Game.hud
	var pw = hud.win["prof"]
	# ---- 生成检查：NPC 不应站在屋顶上（码头栈桥上的除外）
	var on_roof := []
	for n in get_tree().get_nodes_in_group("npcs"):
		# 无缝大世界：按 NPC 所在位置取对应地形的高度
		var gh: float = U.ground_height(get_tree(), n.global_position.x, n.global_position.z, n.global_position.y)
		if gh > 9.0 and n.global_position.y - gh > 2.5:
			on_roof.append("%s@%s(+%.1f)" % [n.npc_id, n.global_position.round(), n.global_position.y - gh])
	_check(on_roof.is_empty(), "没有 NPC 站在屋顶上 %s" % str(on_roof))
	# ---- 锻造：对话学习
	var sm := await _goto_npc(p, "smith_master")
	await _wait(0.4)
	hud.open_npc(sm)
	await _wait(0.2)
	_find_btn(hud.win["npc"].content, "学习锻造").pressed.emit()
	await _wait(0.2)
	await shot("trainer_before")
	var lb := _find_btn(hud.win["npc"].content, "学习锻造")
	_check(lb != null, "训练师列出「学习锻造」")
	lb.pressed.emit()
	await _wait(0.2)
	_check(Prof.known("smith") and Prof.skill("smith") == 1, "学会锻造（技能 1）")
	_check(Game.pd["recipes"].has("sm_bar"), "自动获得「熔炼铜锭」")
	var up := _find_btn(hud.win["npc"].content, "熟练")
	_check(up != null and up.text.contains("需要技能"), "熟练等级显示未满足条件")
	await shot("trainer_after")
	hud.close_all()
	# ---- 在铁砧旁熔炼 10 个铜锭
	Game.add_item("mat_copper", 40, true)
	Game.add_item("mat_leather", 4, true)
	p.global_position = _wp("tidewind", 80, 430) + Vector3(0, 1.0, 0)
	await _wait(0.5)
	hud.toggle_window("prof")
	await _wait(0.3)
	pw.cur_rid = "sm_bar"
	pw.refresh()
	await shot("prof_window")
	pw.start("sm_bar", 10)
	await _wait_crafting(pw, 30.0)
	_check(Game.count_item("mat_copper_bar") == 10 and Game.count_item("mat_copper") == 20, "熔炼出 10 个铜锭（消耗 20 矿石）")
	_check(Prof.skill("smith") == 11, "橙色配方每次必升：技能 1 → %d" % Prof.skill("smith"))
	# ---- 买配方并打造匕首
	_check(Prof.learn_recipe("sm_dagger"), "技能 11 可购买「铜制匕首」配方")
	pw.cur_rid = "sm_dagger"
	pw.refresh()
	pw.start("sm_dagger", 1)
	await _wait_crafting(pw, 6.0)
	_check(Game.count_item(DB.recipes["sm_dagger"]["out"]) == 1, "打造出匕首")
	await shot("prof_crafted")
	# ---- 离开铁砧后不能锻造
	var far_pt := _wp("tidewind", 140, 430)
	p.global_position = Vector3(far_pt.x, p.global_position.y, far_pt.z)
	await _wait(0.3)
	_check(Prof.craft_block("sm_bar") == "", "远离铁砧也能锻造（随时随地制作）")
	hud.close_all()
	# ---- 烹饪（玛格丽特，火盆旁）
	var ck := await _goto_npc(p, "cook_master")
	await _wait(0.4)
	hud.open_npc(ck)
	await _wait(0.2)
	_find_btn(hud.win["npc"].content, "学习烹饪").pressed.emit()
	await _wait(0.2)
	_find_btn(hud.win["npc"].content, "学习烹饪").pressed.emit()
	_check(Prof.known("cook"), "学会烹饪")
	hud.close_all()
	Game.add_item("mat_raw_meat", 3, true)
	Game.add_item("mat_spice", 3, true)
	var meat0 := Game.count_item("food_meat")
	hud.toggle_window("prof")
	pw.cur_prof = "cook"
	pw.cur_rid = "ck_steak"
	pw.refresh()
	pw.start("ck_steak", 3)
	await _wait_crafting(pw, 12.0)
	_check(Game.count_item("food_meat") == meat0 + 3, "烤出 3 份香烤狼排")
	hud.close_all()
	# ---- 精工（无需工作台）
	var ar := await _goto_npc(p, "artisan_master")
	await _wait(0.4)
	hud.open_npc(ar)
	await _wait(0.2)
	_find_btn(hud.win["npc"].content, "学习精工").pressed.emit()
	await _wait(0.2)
	_find_btn(hud.win["npc"].content, "学习精工").pressed.emit()
	_check(Prof.known("artisan"), "学会精工")
	hud.close_all()
	Game.add_item("j_gear", 2, true)
	hud.toggle_window("prof")
	pw.cur_prof = "artisan"
	pw.cur_rid = "ar_gear"
	pw.refresh()
	pw.start("ar_gear", 2)
	await _wait_crafting(pw, 8.0)
	_check(Game.count_item("mat_gearwork") == 2, "组装出 2 个齿轮组件（任意地点）")
	await shot("prof_artisan")
	# ---- 野兽掉落生肉
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var meat := 0
	for i in 200:
		for e in DB.roll_loot(DB.mobs["highland_wolf"], 10, rng)["items"]:
			if e[0] == "mat_raw_meat":
				meat += 1
	_check(meat > 40, "高地狼 200 次掉落中出现生肉 %d 次" % meat)
	# ---- 对话功能
	hud.close_all()
	var n2 := await _goto_npc(p, "bath_attendant")
	await _wait(0.3)
	hud.open_npc(n2)
	_find_btn(hud.win["npc"].content, "热水澡").pressed.emit()
	_check(not p.get_aura("buff_bath").is_empty(), "浴池：获得「温泉暖意」")
	n2 = await _goto_npc(p, "doctor")
	await _wait(0.3)
	p.set_hp(p.max_hp * 0.4)
	hud.open_npc(n2)
	_find_btn(hud.win["npc"].content, "治疗").pressed.emit()
	_check(p.hp >= p.max_hp, "医院：生命回满")
	n2 = await _goto_npc(p, "welfare_officer")
	await _wait(0.3)
	hud.open_npc(n2)
	var f0 := Game.count_item("food_cheese")
	_find_btn(hud.win["npc"].content, "补助").pressed.emit()
	_check(Game.count_item("food_cheese") == f0 + 5, "社保局：领到补助")
	_check(_find_btn(hud.win["npc"].content, "已领取") != null, "社保局：同一天不能重复领取")
	n2 = await _goto_npc(p, "guild_reg")
	await _wait(0.3)
	hud.open_npc(n2)
	_find_btn(hud.win["npc"].content, "公会事务").pressed.emit()
	for c in hud.win["npc"].content.get_children():
		if c is LineEdit:
			c.text = "晴岚之风"
	_find_btn(hud.win["npc"].content, "登记创建").pressed.emit()
	_check(Game.pd.get("guild", "") == "晴岚之风", "公会登记：创建公会")
	await shot("guild_created")
	n2 = await _goto_npc(p, "opera_manager")
	await _wait(0.3)
	hud.open_npc(n2)
	_find_btn(hud.win["npc"].content, "戏票").pressed.emit()
	_check(not p.get_aura("buff_opera").is_empty(), "歌剧院：获得「灵感」")
	await shot("opera")
	n2 = await _goto_npc(p, "scholar_master")
	await _wait(0.3)
	Game.add_item("j_stone_chip", 10, true)
	var ae0 := Game.count_item("mat_aether")
	hud.open_npc(n2)
	_find_btn(hud.win["npc"].content, "雕像碎石").pressed.emit()
	_check(Game.count_item("mat_aether") == ae0 + 1, "学者行会：碎石换以太碎晶")
	n2 = await _goto_npc(p, "harbor_master")
	await _wait(0.3)
	hud.open_npc(n2)
	_find_btn(hud.win["npc"].content, "女神像").pressed.emit()
	var txt := ""
	for c in hud.win["npc"].content.get_children():
		if c is RichTextLabel:
			txt += c.text
	_check(txt.contains("蓝光"), "港务长：闲谈话题显示回答")
	await shot("topic")
	hud.close_all()
	var nt := 0
	for id in DB.npcs:
		if DB.npcs[id].has("topics") or DB.npcs[id].has("service"):
			nt += 1
	print("NPC 有话题或服务：%d" % nt)
	print("CRAFTING RESULT: %s" % ("ALL PASS" if fails.is_empty() else "FAILED: " + ", ".join(fails)))
	get_tree().quit()

## 找不到按钮时返回一个未接入场景的哑按钮并记一次失败，避免 null 报错让测试协程中断、游戏挂起
## UI 截图：windows=char,spells,... 逐个打开窗口截图（默认全部）；npc=<id> 时先打开该 NPC 对话
## 背包已并入角色页、天赋已并入技能书页签：窗口 id 仍可用 bag / talents（见 hud.gd WIN_ALIAS）
func _ui_shots(p: Player) -> void:
	var hud = Game.hud
	var wins: Array = ["hud", "char", "bag", "spells", "talents", "quests", "map", "menu", "dungeon", "prof", "bank", "transmog", "auction"]
	var npc_id := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("windows="):
			wins = a.substr(8).split(",")
		if a.begins_with("npc="):
			npc_id = a.substr(4)
	var bk := await _goto_npc(p, "banker")
	await _wait(0.6)
	for w in wins:
		hud.close_all()
		await _wait(0.25)
		if w == "hud":
			pass
		elif w in ["bank", "transmog", "auction"]:
			hud.open_service(w, await _goto_npc(p, {"bank": "banker", "transmog": "transmog", "auction": "auctioneer"}[w]))
		elif w == "npc":
			var n := await _goto_npc(p, npc_id if npc_id != "" else "mayor")
			await _wait(0.3)
			hud.open_npc(n)
		elif hud.win.has(hud._win_id(w)):
			hud.open_window(w)
		await _wait(0.6)
		await shot("ui_" + w)
	print("UI SHOTS DONE")
	get_tree().quit()

func _find_btn(root: Node, text_part: String) -> Button:
	for c in root.get_children():
		if c is Button and c.text.contains(text_part):
			return c
	_check(false, "找不到按钮「%s」" % text_part)
	return Button.new()

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _services(p: Player) -> void:
	var hud = Game.hud
	# ---- 银行
	var bk := await _goto_npc(p, "banker")
	_check(bk != null, "找到银行职员")
	await _wait(0.5)
	Game.add_item("mat_wool", 15, true)
	Game.add_item("potion_heal2", 3, true)
	hud.open_service("bank", bk)
	await _wait(0.4)
	var wool_idx: int = -1
	for i in Game.BAG_SIZE:
		var st = Game.pd["bag"][i]
		if st != null and st["id"] == "mat_wool":
			wool_idx = i
	hud.bag_right_click(wool_idx)
	_check(Game.count_item("mat_wool") == 0, "右键存入银行（背包毛料=0）")
	var in_bank := 0
	for st in Game.pd["bank"]:
		if st != null and st["id"] == "mat_wool":
			in_bank += st["n"]
	_check(in_bank == 15, "银行中有 15 毛料")
	await _wait(0.5)
	await shot("bank")
	var bidx: int = -1
	for i in Game.BANK_SIZE:
		if Game.pd["bank"][i] != null and Game.pd["bank"][i]["id"] == "mat_wool":
			bidx = i
	Game.bank_withdraw(bidx)
	_check(Game.count_item("mat_wool") == 15, "从银行取回毛料")
	hud.close_all()
	# ---- 幻化
	var a := "gen|chest|mail|green|14|bear"
	var b := "gen|chest|mail|blue|15|eagle"
	Game.add_item(a, 1, true)
	Game.add_item(b, 1, true)
	Game.equip_from_bag(Game.pd["bag"].find({"id": a, "n": 1}))
	_check(Game.pd["equip"].get("chest") == a, "装备胸甲 A")
	var tm := await _goto_npc(p, "transmog")
	await _wait(0.5)
	hud.open_service("transmog", tm)
	await _wait(0.3)
	hud.win["transmog"]._select("chest")
	var money0: int = Game.pd["money"]
	_check(TransmogWindow.eligible("chest", b), "胸甲 B 可作为幻化外观")
	hud.win["transmog"]._apply(b)
	_check(Game.pd["tmog"].get("chest") == b, "幻化写入 pd.tmog")
	_check(Game.pd["money"] == money0 - TransmogWindow.COST, "扣除幻化费用")
	_check(Game.gear_visuals().get("chest", {}) == DB.item_visual(b), "角色外观显示为 B")
	p.cam_yaw = p.rotation.y + PI
	await _wait(0.8)
	await shot("transmog")
	hud.win["transmog"]._select("head")
	hud.close_all()
	# ---- 交易所
	var ah := await _goto_npc(p, "auctioneer")
	await _wait(0.5)
	hud.open_service("auction", ah)
	await _wait(0.5)
	var m: Array = Auction.market()
	_check(m.size() >= 20, "交易所货架 %d 件" % m.size())
	await shot("auction_browse")
	var first: Dictionary = m[0]
	var cnt_before := Game.count_item(first["id"])
	var money1: int = Game.pd["money"]
	Auction.buy(0)
	_check(Game.count_item(first["id"]) > cnt_before and Game.pd["money"] == money1 - first["price"], "一口价购买")
	# 上架：低价必卖 + 天价必流拍（概率 0.95 / 0.05，各上架一件验证结算流程）
	var sell_id := "gen|legs|mail|green|13|bear"
	Game.add_item(sell_id, 1, true)
	hud.win["auction"].pick_for_sale(Game.pd["bag"].find({"id": sell_id, "n": 1}))
	await _wait(0.4)
	await shot("auction_sell")
	_check(Auction.post(Game.pd["bag"].find({"id": sell_id, "n": 1}), 1, 0), "上架（低价）")
	var exp_id := "gen|feet|mail|green|13|bear"
	Game.add_item(exp_id, 1, true)
	_check(Auction.post(Game.pd["bag"].find({"id": exp_id, "n": 1}), 99999999, 0), "上架（天价）")
	var mine: Array = Auction.data()["mine"]
	Game.pd["played"] += 700.0
	Auction.tick()
	print("AH states: ", mine.map(func(e): return e["state"]))
	_check(mine[-2]["state"] in ["sold", "expired"] and mine[-1]["state"] in ["sold", "expired"], "到期后结算")
	hud.win["auction"]._set_tab("mine")
	await _wait(0.4)
	await shot("auction_mine")
	for i in range(mine.size() - 1, -1, -1):
		if mine[i]["state"] == "expired":
			Auction.cancel(i)
	hud.close_all()
	# ---- 地下城查找器
	hud.toggle_window("dungeon")
	await _wait(0.5)
	await shot("dungeon_finder")
	hud.win["dungeon"]._enter()
	for k in 80:
		await _wait(0.25)
		if Game.pd["zone"] == "sanctum" and not Game.world.loading:
			break
	_check(Game.pd["zone"] == "sanctum", "地下城查找器进入副本")
	_check(get_tree().get_nodes_in_group("allies").size() >= 3, "同伴已加入")
	await _wait(1.0)
	hud.toggle_window("dungeon")
	await _wait(0.3)
	await shot("dungeon_inside")
	hud.win["dungeon"]._leave()
	for k in 200:
		await _wait(0.25)
		if Game.pd["zone"] == "tidewind" and not Game.world.loading:
			break
	_check(Game.pd["zone"] == "tidewind", "离开副本回到潮风高地")
	# ---- NPC 对话入口 + 传送门法师（通过真实对话按钮操作）
	for e in [["banker", "银行"], ["transmog", "幻化"], ["auctioneer", "交易所"], ["station_master", "魔导列车"], ["portal_mage", "传送门"]]:
		var n := await _goto_npc(p, e[0])
		await _wait(0.3)
		hud.open_npc(n)
		await _wait(0.2)
		_check(_find_btn(hud.win["npc"].content, e[1]) != null, "%s 的对话里有「%s」选项" % [e[0], e[1]])
	_find_btn(hud.win["npc"].content, "打开传送门").pressed.emit()
	await _wait(0.3)
	await shot("portal_menu")
	_find_btn(hud.win["npc"].content, "东门哨站").pressed.emit()
	for k in 40:
		await _wait(0.25)
		if U.flat_dist(p.global_position, _wp("tidewind", 706, 390)) < 15.0 and not Game.world.simulation_suspended():
			break
	_check(U.flat_dist(p.global_position, _wp("tidewind", 706, 390)) < 15.0, "传送门把玩家送到东门哨站")
	# ---- 魔导列车（需要完成 q_c12）
	Game.pd["qdone"]["q_c12"] = true
	await Game.world.ride_train("vale", "fp_goldenear", "金穗镇")
	for k in 200:
		await _wait(0.25)
		if Game.pd["zone"] == "vale" and not Game.world.loading:
			break
	_check(Game.pd["zone"] == "vale", "列车到达金穗镇")
	await _wait(1.0)
	await shot("train_goldenear")
	await Game.world.ride_train("tidewind", "st_solenne", "晴岚港 · 中央车站")
	for k in 200:
		await _wait(0.25)
		if Game.pd["zone"] == "tidewind" and not Game.world.loading:
			break
	_check(Game.pd["zone"] == "tidewind" and U.flat_dist(p.global_position, Game.world.zones.tidewind.get_spawn("st_solenne").global_position) < 10.0, "列车返回晴岚港中央车站")
	print("SERVICES RESULT: %s" % ("ALL PASS" if fails.is_empty() else "FAILED: " + ", ".join(fails)))
	get_tree().quit()

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [out_dir, shots, name])
	shots += 1
	print("SHOT ", name, " fps=", Engine.get_frames_per_second())

func _process(delta: float) -> void:
	t += delta
	if mode == "front":
		if t > 3.0 and step == 0:
			step = 1
			await shot("front")
			get_tree().quit()
		return
	if Game.player == null or Game.world == null or Game.world.loading:
		_loading_elapsed += delta
		if _loading_elapsed > 60.0:
			print("TIMEOUT loading")
			get_tree().quit()
		return
	_loading_elapsed = 0.0
	var p: Player = Game.player
	if mode == "sanctum_grounding":
		if step == 0 and t > 4.0:
			step = 1
			_sanctum_grounding(p)
		return
	if mode == "dungeon":
		_dungeon_step(p)
		return
	if mode == "portal":
		_portal_step(p)
		return
	if mode == "services":
		if step == 0 and t > 4.0:
			step = 1
			_services(p)
		return
	if mode == "map":
		# 世界地图截图（无缝大世界拼图）
		if step == 0 and t > 4.0:
			step = 1
			Game.pd["explored"]["poi_town"] = true
			Game.hud.toggle_window("map")
			await _wait(1.0)
			await shot("world_map")
			get_tree().quit()
		return
	if mode == "crafting":
		if step == 0 and t > 4.0:
			step = 1
			_crafting(p)
		return
	if mode == "ui":
		if step == 0 and t > 4.0:
			step = 1
			_ui_shots(p)
		return
	if mode == "tour":
		# 巡游只看场景：保持满血，避免被怪物打断
		if _clean_tour and tour_zone == "sanctum":
			p.set_process_unhandled_input(false)
			p.set_process_input(false)
			for actor in get_tree().get_nodes_in_group("units"):
				if actor != p:
					actor.set_physics_process(false)
		if p.dead:
			p.revive(true)
		p.set_hp(p.max_hp)
		# 巡游截图固定晴天，便于对比美术效果
		Game.world.weather = "clear"
		Game.world.weather_amt = 0.0
		Game.world.weather_t = 9999.0
		if tour_hour >= 0.0:
			Game.time_of_day = tour_hour
		if t > 4.0 and tour_i == 0 and step == 0:
			step = 1
		if step >= 1:
			var tl: Array = TOURS[tour_zone].filter(func(e):return tour_views.is_empty() or e[0] in tour_views)
			if tour_i >= tl.size():
				if tour_zone == "sanctum":
					FileAccess.open(out_dir+"/camera_report.json",FileAccess.WRITE).store_string(JSON.stringify({"version":SanctumFlow.layout().version,"samples":_mmo_camera_samples},"\t"))
				print("TOUR DONE")
				get_tree().quit()
				return
			var e: Array = tl[tour_i]
			if step == 1:
				if tour_zone == "sanctum":
					_sanctum_section(e[0] == "underground_cutaway")
					for roof in Game.world.find_children("roofs", "MeshInstance3D", true, false):
						roof.visible = e[0] not in ["overview_cutaway", "underground_cutaway"]
					# Inspection only; ordinary views retain the earth and underground ceilings.
					for group in ["terrain", "buried_roofs"]:
						for mesh in Game.world.find_children(group, "MeshInstance3D", true, false):
							mesh.visible = e[0] != "underground_cutaway"
				var wpt := _wp(TOUR_ZONES.get(tour_zone, tour_zone), e[1], e[2])
				if tour_zone == "city":
					if e[0] == "piers" or e[0] == "lighthouse": wpt.y = 13.3
					if e[0] == "river": wpt.y = 20.1
					if String(e[0]).begins_with("in_"):
						var hf := GenCityV7.hall_floor_at(e[1], e[2])
						if hf != INF: wpt.y = hf
				if tour_zone == "sanctum":
					var sy := SanctumFlow.floor_y(Vector2(e[1], e[2]))
					if e[0] in ["nave", "altar", "chapel", "mmo_nave"]:
						sy = 24.0
					if sy != INF:
						wpt.y = sy
				var y: float = wpt.y
				step = -1
				if _clean_tour: p.set_physics_process(true)
				await Game.world._teleport_to(wpt + Vector3(0, 1.5, 0))
				if _clean_tour:
					await get_tree().create_timer(.45).timeout
					p.set_physics_process(false)
					p._move_input = Vector2.ZERO
				p.velocity = Vector3.ZERO
				if e.size() > 3:
					p.rotation.y = deg_to_rad(e[3])
					p.cam_yaw = p.rotation.y
				else:
					p.cam_yaw = p.rotation.y + 0.8
				p.cam_dist_target = e[4] if e.size() > 4 else 22
				p.cam_pitch = e[5] if e.size() > 5 else -0.35
				p.spring.collision_mask = 1 if tour_zone in ["city", "sanctum"] else 0
				if _aerial and is_instance_valid(_aerial):
					_aerial.queue_free()
					_aerial = null
				if e.size() > 6:
					# Inspection cameras are either a height or explicit local eye/target coordinates.
					_aerial = Camera3D.new()
					_aerial.far = 4000.0
					Game.world.add_child(_aerial)
					var tgt := wpt
					if e[6] is Array:
						var eye: Array=e[6][0];var aim: Array=e[6][1]
						var offset:=WorldLayout.offset(TOUR_ZONES.get(tour_zone,tour_zone))
						_aerial.global_position=Vector3(eye[0],eye[1],eye[2])+offset
						tgt=Vector3(aim[0],aim[1],aim[2])+offset
					else:
						_aerial.global_position = tgt + Vector3(0, e[6], e[6] * 0.75)
					_aerial.look_at(tgt, Vector3.UP)
					_aerial.make_current()
				step = 2
				t = 0
			elif step == 2 and t > 3.0:
				Game.hud.close_all()
				if _clean_tour:
					Game.hud.visible = false
				if String(e[0]).begins_with("mmo_"):
					var record := {"view":e[0],"requested":p.cam_dist_target,"actual":p.spring.get_hit_length(),"pitch":p.cam_pitch,"player":str(p.global_position-WorldLayout.offset("sanctum")),"camera":str(p.camera.global_position-WorldLayout.offset("sanctum"))}
					_mmo_camera_samples.append(record)
					print("SANCTUM MMO CAMERA ",JSON.stringify(record))
				await shot("tour_" + e[0])
				if _clean_tour:
					Game.hud.visible = true
				tour_i += 1
				step = 1
		return
	match step:
		0:
			if t > 4.0:
				step = 1
				t = 0
				print("HUD size ", Game.hud.size, " vp ", Game.hud.get_viewport_rect().size, " bars ", Game.hud.bar_slots[0].global_position, " mm ", Game.hud.minimap.global_position)
				await shot("spawn")
		1:
			p.cam_yaw = p.rotation.y + PI
			p.cam_pitch = -0.25
			if t > 1.0:
				step = 2
				t = 0
				await shot("face")
		2:
			p.cam_yaw = p.rotation.y
			p.cam_dist_target = 30
			p.cam_pitch = -0.5
			if t > 1.5:
				step = 3
				t = 0
				await shot("overview")
		3:
			# 打开窗口
			Game.hud.open_window("bag")
			Game.hud.open_window("char")
			if t > 1.0:
				step = 4
				t = 0
				await shot("windows")
				Game.hud.close_all()
		4:
			# 与 NPC 对话
			var npc: NPC = null
			for n in get_tree().get_nodes_in_group("npcs"):
				if n.npc_id == "marcus":
					npc = n
			if npc:
				p.global_position = npc.global_position + npc.forward_dir() * 3.0
				npc.interact(p)
			if t > 1.0:
				step = 5
				t = 0
				await shot("npc")
				# 接受所有任务
				for q in DB.quests_by_giver.get("marcus", []):
					if Game.can_accept(q):
						Game.accept_quest(q)
				Game.hud.close_all()
		5:
			# 找狼战斗
			var wolf: Mob = null
			var bd := 1e9
			for m in get_tree().get_nodes_in_group("mobs"):
				if m.mob_id == "young_wolf" and not m.dead:
					var d: float = m.global_position.distance_to(p.global_position)
					if d < bd:
						bd = d
						wolf = m
			if wolf:
				p.global_position = wolf.global_position + Vector3(4, 1, 0)
				p.face_towards(wolf.global_position)
				p.cam_yaw = p.rotation.y
				p.cam_dist_target = 9
				p.cam_pitch = -0.3
				p.set_target(wolf)
				p.interact_with(wolf)
			step = 6
			t = 0
		6:
			if p.target and not p.target.dead:
				p.face_towards(p.target.global_position)
				for i in 6:
					p.use_bar_slot(i)
			if t > 2.0 and shots < 6:
				await shot("combat")
			if (p.target == null or p.target.dead) or t > 25.0:
				step = 7
				t = 0
		7:
			if t > 1.0:
				await shot("after_combat")
				print("HP ", p.hp, "/", p.max_hp, " XP ", Game.pd["xp"], " LV ", Game.pd["level"], " quests ", Game.pd["quests"].keys())
				print("AUTO LOOT money=", Game.pd.money, " pending=", Game.pd.get("pending_loot", []))
				step = 8
				t = 0
		8:
			if t > 1.0:
				Game.hud.open_window("bag")
				await shot("auto_loot_bag")
				Game.hud.close_all()
				Game.time_of_day = 21.5
				step = 9
				t = 0
		9:
			if U.flat_dist(p.global_position, Vector3(435, 20, 500)) > 10.0:
				step = -1
				await Game.world._teleport_to(_wp("vale", 435, 500))
				step = 9
			p.rotation.y = 0
			p.cam_yaw = 0
			p.cam_dist_target = 18
			p.cam_pitch = -0.35
			if t > 3.0:
				await shot("town_night")
				Game.time_of_day = 12.0
				step = 10
				t = 0
		10:
			if t > 3.0:
				await shot("town_day")
				Game.hud.open_window("map")
				step = 11
				t = 0
		11:
			if t > 1.0:
				await shot("map")
				print("AUTOTEST DONE")
				get_tree().quit()











func _sanctum_grounding(p: Player) -> void:
	await _wait(1.0)
	var errors: Array = []
	if absf(p.global_position.y - 8.0) > .4:
		errors.append("saved cellar feet " + str(p.global_position))
	var basement: Array = Game.zone.units_root.get_children().filter(func(n):return n is Mob and n.encounter_room in ["P5","P6"])
	if basement.is_empty():
		errors.append("no live basement monsters")
	for m in basement:
		if absf(m.global_position.y - 8.0) > .4:
			errors.append("basement monster " + str(m.global_position))
	var basement_count: int = basement.size()
	Game.pd["sanctum_layout_ver"] = 0
	await Game.world._load_zone("sanctum", "", Vector3(105,16.1,126))
	await _wait(1.0)
	if absf(p.global_position.y - 8.0) > .4:
		errors.append("old cellar save migration feet " + str(p.global_position))
	await Game.world._load_zone("sanctum", "", Vector3(105,24.1,126))
	await _wait(.8)
	if absf(p.global_position.y - 24.0) > .4:
		errors.append("saved upper nave feet " + str(p.global_position))
	await Game.world._load_zone("sanctum", "", Vector3(86,8.1,96))
	await _wait(.8)
	if absf(p.global_position.y - 8.0) > .4:
		errors.append("saved underground side room feet " + str(p.global_position))
	var gf: Node3D = Game.zone.get_node_or_null("GrassField")
	if gf == null or not gf.is_visible_in_tree():
		errors.append("grass is hidden with editor terrain")
	FileAccess.open(out_dir+"/grounding_report.json",FileAccess.WRITE).store_string(JSON.stringify({"version":SanctumFlow.layout().version,"basement_mobs":basement_count,"failures":errors},"\t"))
	print("SANCTUM GROUNDING RESULT failed ", errors.size(), " ", errors)
	get_tree().quit(0 if errors.is_empty() else 1)

func _sanctum_section(enabled: bool) -> void:
	for item in _section_restore:
		if is_instance_valid(item[0]):
			item[0].set_surface_override_material(item[1],item[2])
	_section_restore.clear()
	if not enabled:return
	# Test camera only: expose the real lower meshes by clipping the upper storey.
	var section_shader := Shader.new()
	section_shader.code = "shader_type spatial; render_mode cull_disabled, specular_disabled; uniform vec4 tint : source_color = vec4(1.0); uniform sampler2D stone : source_color, hint_default_white; varying float world_y; void vertex(){world_y=(MODEL_MATRIX*vec4(VERTEX,1.0)).y;} void fragment(){if(world_y>22.0)discard; ALBEDO=tint.rgb*texture(stone,UV).rgb; ROUGHNESS=0.95;}"
	var model: Node3D = Game.zone.get_node("Buildings/UnitySpatialSanctum")
	for mesh in model.get_children():
		if mesh is not MeshInstance3D or mesh.name not in ["floor","walls","detail","props"]:continue
		for i in mesh.mesh.get_surface_count():
			var original: Material = mesh.get_surface_override_material(i)
			var active: Material = mesh.get_active_material(i)
			_section_restore.append([mesh,i,original])
			var mat := ShaderMaterial.new()
			mat.shader = section_shader
			if active is StandardMaterial3D:
				mat.set_shader_parameter("tint",active.albedo_color)
				if active.albedo_texture:mat.set_shader_parameter("stone",active.albedo_texture)
			mesh.set_surface_override_material(i,mat)
