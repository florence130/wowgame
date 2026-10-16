class_name GenVale
extends RefCounted
## 晨露谷（1-10级新手地图）生成器
## 地形优先：先塑造山谷、湖泊、河流、高地，再沿地形布置道路、村镇与野外区域。

const W := 960.0
const WATER := 8.0

static func build() -> void:
	var b := ZoneBuilder.new("vale", 384, 2.5, 20261004)
	b.obj_scale = ZoneBuilder.OBJ_SCALE      # 门高 3.0m（玩家 1.7m）；所有世界物件统一使用 3.0/2.3
	b.data.water_level = WATER
	b.data.layer_colors = PackedColorArray(ArtStyle.TERRAIN_COLORS)
	_terrain(b)
	_roads(b)
	_paint(b)
	_abbey(b)
	_town(b)
	_farms(b)
	_mine(b)
	_lake(b)
	_lumber(b)
	_tower(b)
	_hyena(b)
	_exit(b)
	_wild(b)
	_vegetation(b)
	_dress(b)
	b.smooth_banks(WATER, 3.0, 2)   # 道路 / 平台 / 房基压平之后再把水岸抹一遍
	WorldLayout.stitch(b, "vale")
	b.save("res://data/terrain/vale.res", "res://scenes/zones/dawnmist_vale.tscn")
	b.root.free()

# ================================================================ 地形
static func _terrain(b: ZoneBuilder) -> void:
	# v4（2026-10-05）：去掉圆锥 + 削顶的平顶山、圆盘据点和山谷外的环形山；
	# 地貌 = 低频分区（草原 / 丘陵）+ 脊状噪声山体 + 北、东两侧山脉带，据点用不规则平台
	b.set_heights(func(x, z):
		var macro := b.n2(x * 0.5 + 900.0, z * 0.5 - 300.0) * 0.5 + 0.5          # 哪里是丘陵、哪里是草原
		var hills := pow(b.ridge(x * 0.9, z * 0.9), 2.2) * 15.0 * smoothstep(0.4, 0.8, macro)
		var base := 13.0 + b.n2(x, z) * 6.0 + b.n2(x * 2.7 + 300.0, z * 2.7) * 2.0 + hills
		# 边缘山脉带：北、东两侧（西边是与潮风高地的接缝，南边是海岸）；脊状噪声做出山脊、山谷与冲沟
		var de := minf(z, W - x)
		var e := 1.0 - smoothstep(0.0, 210.0, de)
		var mr := b.ridge(x * 0.55 + 500.0, z * 0.55 - 200.0)
		var m := pow(e, 1.4) * (5.0 + 42.0 * pow(mr, 1.4))
		# 岩石露头（只在山脉带）
		var rk := pow(1.0 - absf(b.n2(x * 2.2 + 40.0, z * 2.2)), 4.0)
		m += rk * 7.0 * smoothstep(0.35, 0.8, e)
		# 西南河口（河流向南入海）保持开阔
		var exit_gap := Vector2(x - 40.0, z - 940.0).length()
		m *= smoothstep(40.0, 140.0, exit_gap)
		# 南缘：缓坡沙滩入海（与高地南岸、远景海面连成一条海岸线）
		return lerpf(base + m, WATER - 3.0, smoothstep(905.0, 962.0, z + b.n2(x * 0.9 + 40.0, 31.0) * 55.0 + b.n2(x * 3.0, 77.0) * 14.0)))   # 海岸线：大尺度海湾 / 岬角（±55m）+ 小尺度起伏，不再是一条直线
	# 无缝大世界：西边与潮风高地相接，向世界基础高度过渡（不再有边缘山墙）
	WorldLayout.apply_seam(b, "vale")
	# 晨钟修道院所在的北部山谷：谷底平缓，南侧敞开。两侧是伸进来的山嘴（脊状噪声决定形状），不再是一圈环形山
	var vc := Vector2(485, 150)
	b.modify(vc.x, vc.y, 330.0, func(hv, x, z, _d):
		var ev := Vector2((x - vc.x) / 165.0, (z - vc.y) / 140.0)
		var r := ev.length() * (1.0 + 0.12 * b.n2(x * 2.4, z * 2.4))
		var ang := atan2(ev.y, ev.x)
		var south := clampf(1.0 - absf(ang - PI * 0.5) / 0.9, 0.0, 1.0)
		var floor_h := 22.0 + b.n2(x * 2.0, z * 2.0) * 2.0
		var spur := smoothstep(0.95, 1.35, r) * (1.0 - smoothstep(1.7, 2.3, r)) * pow(b.ridge(x * 1.25 + 90.0, z * 1.25), 2.0) * 26.0 * (1.0 - south)
		var inside := 1.0 - smoothstep(0.8, 1.2, r)
		return lerpf(hv, floor_h, inside) + spur)
	# 山体先隆起（必须在河流 / 湖 / 矿坑之前，否则会把河床填高）
	b.ridge_line([Vector2(600, 40), Vector2(650, 85), Vector2(700, 110)], 70.0, 20.0, 1.5)   # 鼠人营地背后的山梁
	b.ridge_line([Vector2(700, 150), Vector2(790, 130), Vector2(880, 170), Vector2(930, 260)], 85.0, 24.0, 1.4)   # 镜湖北岸山
	b.ridge_line([Vector2(915, 330), Vector2(930, 430)], 55.0, 14.0, 1.4)   # 镜湖东岸山
	b.ridge_line([Vector2(130, 670), Vector2(215, 625), Vector2(290, 590), Vector2(350, 553), Vector2(420, 505)], 150.0, 52.0, 1.2)   # 深石矿坑山梁（西北—东南；扩大 2.2 倍）
	b.ridge_line([Vector2(575, 815), Vector2(620, 780), Vector2(668, 752)], 62.0, 17.0, 1.5)   # 蔚蓝之塔山岗
	b.ridge_line([Vector2(110, 870), Vector2(165, 830), Vector2(215, 790), Vector2(270, 765)], 85.0, 30.0, 1.25)   # 狂牙岭
	# 修道院台地：与谷底同高、边缘宽缓过渡（旧版高出 3m 并削出直角岩壁）
	b.flatten_rect(492, 72, 120, 96, 22.5, 38)
	b.platform(600, 125, 28, 22.0, 22, 0.35)   # 鼠人营地：山脚下的小台地
	b.platform(575, 245, 46, 21.0, 26, 0.3)   # 葡萄园（缓坡上的台地）
	# 镜湖：多瓣山间湖——北湾、西湾、东南湾围出一个半岛（蛙人营地），东北有溪流入湖、西南出湖成河
	b.carve_path([Vector2(905, 175), Vector2(860, 200), Vector2(815, 215)], 4.0, WATER + 1.0, 8.0)   # 入湖溪
	b.lake([Vector3(735, 300, 80), Vector3(772, 205, 62), Vector3(662, 280, 58), Vector3(640, 336, 38), Vector3(735, 355, 40), Vector3(790, 330, 46)], 1.5, WATER + 0.9, 34.0)   # 2026-10-10 扩大：约 3 倍水面（原先只有 ~150m 的一汪池塘）
	b.platform(640, 398, 12, WATER + 2.0, 12, 0.25, 0.2)   # 渔夫小屋的岸边平地（湖扩大后挪到西南岸）
	# 河流（从镜湖向西南）
	var river := [Vector2(735, 365), Vector2(720, 450), Vector2(660, 580), Vector2(560, 640), Vector2(440, 655), Vector2(320, 665), Vector2(220, 690), Vector2(130, 720), Vector2(70, 735)]
	b.carve_path(river, 9.0, WATER - 2.5, 10.0)
	b.platform(70, 740, 26, WATER - 2.5, 14, 0.3, 0.2)
	# 河流出湖后向南经西南河谷入海（南边是海岸）
	b.carve_path([Vector2(70, 745), Vector2(60, 800), Vector2(48, 860), Vector2(38, 915), Vector2(30, 975)], 10.0, WATER - 2.5, 12.0)
	# 金穗镇：紧凑核心平台，半径约 62m；外缘留给农庄、河谷和矿坑。
	b.platform(435, 470, 62.0, 17.0, 30, 0.18, 0.35)
	# 麦浪农庄（西）与灰巾帮废弃农舍
	b.platform(200, 440, 90, 16.0, 34, 0.25, 0.5)
	b.platform(110, 380, 36, 18.0, 22, 0.35)
	# 深石矿坑：迁到西南山梁，和金穗镇、麦浪农庄、银溪保持地形缓冲。
	b.quarry(220, 610, 100, 58, -28.0, 10.0, 9)
	# 林风伐木场
	b.platform(805, 475, 38, 18.0, 22, 0.3)
	# 蔚蓝之塔：东南一道短山岗，塔立在岗顶的小台地上；魔导工坊在山脚
	b.platform(620, 780, 13, b.h(620, 780), 12, 0.3, 0.3)
	b.platform(770, 820, 42, 16.0, 24, 0.3)
	# 狂牙岭：西南一道石岭（不是平顶圆山）——鬣狗营地在岭腰的鞍部，首领的王座在西南端的岩丘
	b.platform(205, 800, 38, b.h(205, 800) - 4.0, 26, 0.4, 0.8)
	b.platform(150, 852, 14, b.h(150, 852), 12, 0.35, 0.4)
	# 蛛巢（东部山脚）
	b.platform(870, 640, 32, 20.0, 22, 0.35)
	# 西南出口山道
	b.carve_path([Vector2(120, 780), Vector2(70, 880), Vector2(25, 935)], 10.0, 18.0, 12.0)
	# 2026-10-10 地形抛光：热侵蚀去掉针刺 / 台阶，水岸平滑（岸线圆润）。设计好的陡崖 / 采场壁坡度 < 1.0 以内不受影响
	b.soften_shore(WATER, 3.5, 0.42)   # 水线两侧缓坡：沙滩 / 河滩变宽
	b.polish(WATER, 1.0, 5)

static func _roads(b: ZoneBuilder) -> void:
	b.road([Vector2(485, 128), Vector2(486, 200), Vector2(484, 300), Vector2(470, 370), Vector2(440, 420)], 6.5)
	b.road([Vector2(400, 470), Vector2(320, 455), Vector2(240, 445), Vector2(170, 420), Vector2(115, 385)], 6.0)
	# 西去潮风高地的大路（接缝处 z=490 接上高地东门大路）
	b.road([Vector2(240, 445), Vector2(170, 455), Vector2(110, 472), Vector2(50, 486), Vector2(-2, 490)], 6.5)
	b.road([Vector2(500, 470), Vector2(560, 470), Vector2(650, 455), Vector2(730, 470), Vector2(800, 475)], 6.0)
	b.road([Vector2(650, 455), Vector2(665, 430), Vector2(655, 408), Vector2(645, 400)], 4.5)   # 通到西南岸的渔夫小屋
	b.road([Vector2(450, 520), Vector2(455, 580), Vector2(500, 660), Vector2(560, 720), Vector2(605, 765)], 6.0)
	b.road([Vector2(410, 520), Vector2(360, 555), Vector2(300, 585), Vector2(250, 600)], 5.0)   # 金穗镇西南出口 → 新矿坑东侧坡道
	b.road([Vector2(200, 470), Vector2(190, 560), Vector2(160, 660), Vector2(130, 730), Vector2(100, 800), Vector2(78, 870)], 6.0)
	b.road([Vector2(605, 765), Vector2(690, 800), Vector2(760, 815)], 4.5)

static func _paint(b: ZoneBuilder) -> void:
	# 沙滩：近水位
	b.paint_where(4, func(_x, _z, hv): return 1.0 - smoothstep(WATER + 0.4, WATER + 2.2, hv) if hv > WATER - 3.0 else 0.0)
	# 修道院山谷花草地
	b.paint_where(7, func(x, z, _hv):
		var e := Vector2((x - 485.0) / 150.0, (z - 165.0) / 125.0).length()
		return (1.0 - smoothstep(0.6, 0.9, e)) * (0.6 + 0.4 * b.n2(x * 6.0, z * 6.0)))
	# 东部森林深草
	b.paint_where(1, func(x, z, _hv):
		var f := 0.0
		f = maxf(f, 1.0 - smoothstep(120.0, 200.0, Vector2(x - 760.0, z - 560.0).length()))
		f = maxf(f, 1.0 - smoothstep(60.0, 110.0, Vector2(x - 880.0, z - 380.0).length()))
		return f * (0.7 + 0.3 * b.n2(x * 4.0, z * 4.0)))
	# 蛛巢苔藓
	b.paint_circle(870, 640, 45, 8, 0.9, 0.6)
	# 狂牙岭干土
	b.paint_where(2, func(x, z, _hv): return (1.0 - smoothstep(60.0, 110.0, Vector2(x - 200.0, z - 800.0).length())) * 0.55)
	# 广场与修道院庭院石板
	b.paint_circle(435, 470, 21.0 * ZoneBuilder.OBJ_SCALE, 5, 1.0, 0.2)
	# 修道院：院内以草坪为底，只铺主路、礼拜堂前小广场与通往各屋的支路
	b.paint_rect(488, 74, 80, 84, 0)
	b.paint_rect(485, 78, 22, 12, 5)            # 礼拜堂前广场
	b.paint_rect(485, 100, 5, 32, 5)            # 南门 → 广场
	b.paint_rect(485, 122, 6, 12, 5)            # 门外
	b.paint_rect(500, 92, 30, 4, 5)             # 支路 → 军需处
	b.paint_rect(473, 88, 20, 4, 5)             # 支路 → 训练场
	b.paint_rect(462, 106, 16, 12, 2)           # 训练场沙地
	# 农田由 _field() 统一压平 / 避水；这里只保留葡萄园平台的农田层。
	b.paint_rect(575, 245, 48, 36, 6)
	# 矿坑底部
	b.paint_circle(220, 610, 42, 2, 0.8, 0.5)

# ================================================================ 晨钟修道院
## 晨钟修道院（重制：tools/blender/build_abbey.py 的石砌礼拜堂、钟楼、石木住宅、院墙门拱、柏树与庭院小品）
## 院墙 x 436-548、z 28-116，南门在 (485,116)；礼拜堂正门朝南
static func _abbey(b: ZoneBuilder) -> void:
	var stone := Color("e2d6bc")
	var slate := Color("4c5a78")
	var wood := Color("6e4a2e")
	var plaster := Color("eee4cc")
	# GPT abbey_kit_v3 的礼拜堂 / 钟楼 / 回廊庭院是同一套组合（Blender 中 Chapel@(4,0)、BellTower@(-9,-4)、Courtyard@原点），
	# 必须按原相对位置一起摆放，否则回廊缺失、钟楼孤立。组合原点 (490.4,58)，转 180° 使正门朝南，整组放大 1.35 倍。
	_abbey_group(b, 490.4, 58.0, 180.0, stone, slate, wood, 1.35)
	# 构件库建筑（tools/blender/modkit，拆分方式参照 SUNTAIL）：正门朝模型 +Z，yaw 让门对着院内道路
	_kit(b.building("abbey_house", 516, 92, 270, Vector3(12, 12.8, 9.6), plaster, slate, wood, 0, "军需处"), "abbey_quartermaster")
	_kit(b.building("abbey_house", 459, 88, 90, Vector3(16.8, 9.5, 9.6), plaster, slate, wood, 1, "训练场"), "abbey_training_hall")
	_kit(b.building("abbey_cottage", 528, 130, 270, Vector3(7.2, 8.2, 7.2), stone, slate, wood), "abbey_cottage")
	_kit(b.building("abbey_cottage", 516, 42, 0, Vector3(7.2, 8.2, 7.2), stone, slate, wood), "abbey_cottage")
	_kit(b.building("abbey_cottage", 458, 42, 0, Vector3(7.2, 8.2, 7.2), stone, slate, wood), "abbey_cottage")
	# 院墙与南门（院子收紧到 x 448-528、z 32-116）
	# 构件库院墙：4.8m 一段（勒脚 + 石墙 + 压顶 + 墙墩），首尾相接绕院一圈；南门是门楼（门洞 4.2m，总宽 7.8m）
	for run in [[448, 32, 528, 32], [528, 32, 528, 116], [528, 116, 488.9, 116], [481.1, 116, 448, 116], [448, 116, 448, 32]]:
		_kit_wall(b, Vector2(run[0], run[1]), Vector2(run[2], run[3]), stone, slate, wood)
	_kit(b.prop("abbey_gate", 485, 116, 0, Vector3(7.8, 9.0, 2.4), stone, slate, wood, 0, "", 0.0, "Buildings"), "abbey_gatehouse")
	for x in [479.0, 491.0]:
		b.prop("abbey_lamp", x, 120, 0, Vector3.ONE, Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
		b.prop("banner", x - 1.5 if x < 485 else x + 1.5, 113, 0, Vector3(1, 6, 1), Color.WHITE, slate, Color("c0a060"), 0, "", 0.0, "Props")
	# 主路：柏树夹道 + 灯柱，礼拜堂前小广场（喷泉移到西侧草坪，不再挡住正门视线）
	for z in [86.0, 98.0, 110.0]:
		for sx in [-1, 1]:
			b.prop("cypress", 485 + sx * 4.5, z, 0, Vector3(2, b.rng.randf_range(6.0, 7.5), 2), Color.WHITE, Color("2f5a34"), Color.WHITE, 0, "", 0.0, "Props")
	for z in [80.0, 92.0, 104.0]:
		for sx in [-1, 1]:
			b.prop("abbey_lamp", 485 + sx * 3.4, z, 90 if sx < 0 else 270, Vector3.ONE, Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	for p in [[480.5, 72], [489.5, 72], [475, 73], [495, 73]]:
		b.prop("flower_pot", p[0], p[1], 0, Vector3(1, 1, 1), Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	for p in [[476, 80, 90], [494, 80, 270]]:
		b.prop("bench", p[0], p[1], p[2], Vector3(2.4, 1, 1), Color.WHITE, Color.WHITE, wood, 0, "", 0.0, "Props")
	for p in [[478, 84, 0], [492, 84, 0]]:
		b.prop("flowerbed", p[0], p[1], p[2], Vector3(4, 1, 2.5), Color.WHITE, Color.WHITE, Color.WHITE, b.rng.randi() % 3, "", 0.0, "Props")
	# 西侧草坪：喷泉、长椅、鸟浴盆、药草园
	b.prop("fountain", 468, 78, 0, Vector3(5, 3.5, 5), Color("e8dfcc"), Color.WHITE, Color("c0a060"), 0, "", 0.0, "Props")
	for p in [[468, 72.5, 0], [473.5, 78, 270]]:
		b.prop("bench", p[0], p[1], p[2], Vector3(2.4, 1, 1), Color.WHITE, Color.WHITE, wood, 0, "", 0.0, "Props")
	b.prop("birdbath", 474, 86, 0, Vector3.ONE, stone, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	for i in 6:
		b.prop("flowerbed", 456 + (i % 2) * 6.0, 52 + (i / 2) * 5.0, 90, Vector3(4, 1, 2.5), Color.WHITE, Color.WHITE, Color.WHITE, b.rng.randi() % 3, "", 0.0, "Props")
	b.prop("fence", 459, 49, 0, Vector3(12, 1, 1), Color.WHITE, Color.WHITE, Color("8a6a40"), 0, "", 0.0, "Props")
	# 院角柏树
	for p in [[452, 36], [524, 36], [452, 112], [524, 112], [472, 112], [498, 112], [512, 64], [512, 76]]:
		b.prop("cypress", p[0], p[1], 0, Vector3(2, b.rng.randf_range(6.0, 8.0), 2), Color.WHITE, Color("2f5a34"), Color.WHITE, 0, "", 0.0, "Props")
	# 东北角小果园（回廊后）
	b.forest("oak", [Vector2(514, 56), Vector2(522, 62), Vector2(514, 70), Vector2(522, 76)], Color("5a9a3e"), 0.7, 0.9)
	# 训练场：假人、武器架（西南沙地）
	for p in [[460, 104], [466, 106], [462, 110]]:
		b.prop("training_dummy", p[0], p[1], b.rng.randf_range(60, 120), Vector3.ONE, Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	b.prop("weapon_rack", 455, 110, 0, Vector3.ONE, Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	# 军需处：货摊、铁砧、火盆、货箱（东侧）
	b.prop("stall", 506, 100, 90, Vector3(4, 3, 3), Color.WHITE, slate, wood, 0, "", 0.0, "Props")
	b.prop("anvil", 505, 107, 0, Vector3.ONE, Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	b.prop("brazier", 501, 108, 0, Vector3.ONE, Color.WHITE, Color("ff9030"), Color.WHITE, 0, "", 0.0, "Props")
	for p in [[523, 100], [524.5, 98], [523, 82]]:
		b.prop("crate", p[0], p[1], b.rng.randf() * 90, Vector3(1.1, 1.1, 1.1), Color.WHITE, Color.WHITE, Color("8a6a40"), 0, "", 0.0, "Props")
	b.prop("barrel", 522, 104, 0, Vector3(1, 1.3, 1), Color.WHITE, Color.WHITE, Color("8a6a40"), 0, "", 0.0, "Props")
	b.prop("sign", 492, 142, 180, Vector3.ONE, Color.WHITE, Color.WHITE, wood, 0, "金穗镇 ↓", 0.0, "Props")
	b.block(488, 74, 56)
	# 修道院墓地（门外西侧）：十字墓碑、柏树、矮墙
	for i in 9:
		b.prop("grave_cross", 412 + (i % 3) * 4.5, 132 + (i / 3) * 5.0, 180, Vector3.ONE, Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	for p in [[406, 128], [430, 128], [406, 150], [430, 150]]:
		b.prop("cypress", p[0], p[1], 0, Vector3(2, 6.5, 2), Color.WHITE, Color("2f5a34"), Color.WHITE, 0, "", 0.0, "Props")
	b.prop("abbey_wall", 418, 126, 0, Vector3(24, 1.6, 0.9), stone, slate, wood, 0, "", 0.0, "Props")
	# 门前大道：灯柱与花灌木
	for i in 5:
		var z := 130.0 + i * 16.0
		for sx in [-1, 1]:
			b.prop("abbey_lamp", 485 + sx * 5.5, z, 90 if sx < 0 else 270, Vector3.ONE, Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	b.forest("bush", b.scatter(485, 150, 30, 26, 4.0, 0.3), Color("4f8a3c"), 0.7, 1.1, false)
	b.forest("flower", b.scatter(485, 145, 40, 320, 1.2, 0.35, true, 0.5), Color("f4f0e6"), 0.8, 1.3, false)
	b.forest("flower", b.scatter(485, 145, 40, 220, 1.2, 0.35, true, 0.5), Color("e888b0"), 0.8, 1.3, false)
	# 院外菜园与果园（东侧）
	b.prop("field", 568, 60, 0, Vector3(18, 1, 14), Color.WHITE, Color("80c050"), Color.WHITE, 2, "", 0.0, "Props")
	b.prop("fence", 568, 52, 0, Vector3(20, 1, 1), Color.WHITE, Color.WHITE, Color("8a6a40"), 0, "", 0.0, "Props")
	b.forest("oak", [Vector2(565, 85), Vector2(575, 92), Vector2(562, 98), Vector2(578, 104), Vector2(568, 110)], Color("5a9a3e"), 0.8, 1.0)
	b.spawn_point("start", 485, 127, 180)
	b.spawn_point("gy_abbey", 425, 145, 180)
	b.npc("marcus", 485, 121, 180)
	b.npc("lina", 495, 135, 200)
	b.npc("samuel", 470, 88, 120)
	b.npc("tom", 511, 98, 270)
	b.npc("gwen", 503, 104, 270)
	b.npc("lucy", 511, 87, 270)
	b.npc("t_warrior_1", 467, 101, 90)
	b.npc("t_mage_1", 474, 78, 180)
	b.npc("t_priest_1", 496, 78, 180)
	b.npc("t_rogue_1", 455, 122, 45)
	b.npc("t_gunner_1", 470, 108, 90)
	b.npc("abbey_fp", 515, 128, 200)
	b.npc("guard_abbey", 480, 118.5, 180)
	b.npc("guard_abbey", 490, 118.5, 180)
	b.npc("guard_abbey", 486, 200, 180).patrol = PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, 80), Vector3(-10, 0, 120), Vector3(0, 0, 80)])
	b.npc("milo", 548, 220, 240)
	b.poi("poi_abbey", "晨钟修道院", 485, 90, 60, 10, true)
	_kit_dress(b, Rect2(400, 25, 160, 185))
	b.poi("poi_valley", "晨钟山谷", 485, 170, 150, 0)

# ================================================================ 金穗镇
static func _town(b: ZoneBuilder) -> void:
	# 金穗镇 v2：紧凑中心 + 单一主环路 + 少量短支路。
	# 建筑资产全部来自 Blender village_kit；Tripo 只作为独立道具的可选来源。
	var cx := 435.0
	var cz := 470.0
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/village_kit/buildings.json"))
	var S := ZoneBuilder.OBJ_SCALE
	if not _tp(b, "fountain", cx, cz, 0):
		b.prop("fountain", cx, cz, 0, Vector3(7, 4, 7), Color("e0dcd0"), Color.WHITE, Color("c0a060"), 0, "", 0.0, "Props")
	b.block(cx, cz, 34.0 * S)
	var plan := [
		["tavern", 0, -24, "金穗旅店", 0], ["smithy", -20, -14, "", 0], ["store", 20, -14, "杂货店", 0],
		["tailor", 27, 6, "裁缝铺", 0], ["guard", -27, 5, "治安所", 0],
		["trainer", -18, 26, "训练师之家", 0], ["stable", 19, 27, "马厩", 0],
		["home_l", -38, -24, "", 0], ["home_cot", 38, -24, "", 0], ["home_long", -40, 22, "", 0],
		["home_loft", 40, 25, "", 0], ["home_thatch", -42, 0, "", 0], ["home_thatch", -18, 48, "", 0],
		["home_wing", 16, 52, "", 0], ["home_broad", 42, 8, "", 0], ["home_mini", 18, -40, "", 0],
	]
	# 六边形主环路；环路外只接一条短门前支路，禁止相邻房屋全量连线。
	var ring := []
	for q in [[-28.0, -22.0], [28.0, -22.0], [34.0, 0.0], [28.0, 22.0], [-28.0, 22.0], [-34.0, 0.0], [-28.0, -22.0]]:
		ring.append(Vector2(cx + q[0] * S, cz + q[1] * S))
	b.road(ring, 3.2 * S, 5)
	var houses := {}
	for idx in plan.size():
		var e: Array = plan[idx]
		var rm: Dictionary = meta[e[0]]
		var rx: float = cx + float(e[1]) * S
		var rz: float = cz + float(e[2]) * S
		var ryaw := rad_to_deg(atan2(-float(e[1]), -float(e[2]))) + float(e[4])
		var rb := Basis(Vector3.UP, deg_to_rad(ryaw))
		var rf := rb * Vector3(0, 0, 1)
		var rd := Vector3(rx, 0, rz) + rb * Vector3(float(rm.door[0]), 0, float(rm.door[1]))
		var door_p := Vector2(rd.x, rd.z) + Vector2(rf.x, rf.z) * 0.8
		var edge := Vector2(cx, cz) + (door_p - Vector2(cx, cz)).normalized() * 27.0 * S
		if door_p.distance_to(edge) > 5.0 * S:
			b.road([door_p, door_p.lerp(edge, 0.5), edge], 2.5 * S if e[0].begins_with("home") else 3.0 * S, 2)
		b.paint_circle(door_p.x, door_p.y, 3.5 * S, 2, 0.8, 0.45)
		var m: Dictionary = meta[e[0]]
		var x: float = rx
		var z: float = rz
		var sz := Vector3(float(m.w), float(m.h), float(m.d))
		var ground := b.h(x, z)
		var fwd := Basis(Vector3.UP, deg_to_rad(ryaw)) * Vector3(0, 0, 3.0 * S)
		var fx: float = x + fwd.x
		var fz: float = z + fwd.z
		var fw: float = sz.x + 5.0
		if m.has("ext"):
			var ex0: float = float(m.ext[0])
			var ex1: float = float(m.ext[1])
			var co := Basis(Vector3.UP, deg_to_rad(ryaw)) * Vector3((ex0 + ex1) * 0.5, 0, 0)
			fx += co.x
			fz += co.z
			fw = (ex1 - ex0) + 5.0
		b.flatten_rect(fx, fz, fw, sz.z + 10.0, ground, 10.0, -deg_to_rad(ryaw))
		var node: Node3D = b.building("house", x, z, ryaw, sz, Color.WHITE, Color.WHITE, Color.WHITE, 0, e[3], 1.0)
		node.set("asset_scene", "res://assets/models/village_kit/%s.glb" % e[0])
		var key: String = e[0]
		if houses.has(key):
			key = e[0] + "_" + str(idx)
		houses[key] = {"node": node, "m": m, "yaw": ryaw}
		_house_fx(b, node, m, ryaw)
	# 室内 NPC（站位按主室范围 inner 的比例；yaw 与房屋相同 = 面向门）
	_in_npc(b, houses, "tavern", "faria", 0.5, 0.88)
	_meta_npc(b, houses, "smithy", "argo")      # 武器商人：武器柜台后
	_meta_npc(b, houses, "smithy", "dorn")      # 护甲商人：护甲柜台后
	_in_npc(b, houses, "store", "britta", 0.62, 0.74)
	_in_npc(b, houses, "tailor", "kate", 0.72, 0.62)
	_in_npc(b, houses, "guard", "duke", 0.26, 0.5)
	for i in 5:
		_in_npc(b, houses, "trainer", ["t_warrior_2", "t_mage_2", "t_priest_2", "t_rogue_2", "t_gunner_2"][i], 0.14 + i * 0.18, 0.5)
	_in_npc(b, houses, "stable", "ron", 0.35, 0.42)
	# 独立坐骑商人站在马厩门外，使用同一 stable 货单与骑术服务；不放在室内，避免 NPC 与墙/柜台重叠。
	var stable_h: Dictionary = houses["stable"]
	var mount_pos := _lx(stable_h.node, stable_h.yaw, Vector3(-5.0, 0, 11.5))
	b.npc("mount_merchant_vale", mount_pos.x, mount_pos.z, stable_h.yaw + 180.0, 0.0)
	b.poi("poi_inn", "金穗旅店", cx, cz - 24.0 * S, 12.0 * S, 20, true, false)
	# 门前小广场、屋外陈设
	b.prop("brazier", cx - 22 * S, cz - 8 * S, 0, Vector3.ONE, Color.WHITE, Color("ff9030"), Color.WHITE, 0, "", 0.0, "Props")
	b.prop("fence", cx + 27 * S, cz + 12 * S, 0, Vector3(8, 1, 1), Color.WHITE, Color.WHITE, Color("8a6a40"), 0, "", 0.0, "Props")
	b.prop("haystack", cx + 24 * S, cz + 9 * S, 0, Vector3(2, 1.5, 2), Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	# 2026-10-10：金穗镇不再有飞艇坪 / 飞艇 / 驿站管理员（飞艇只在主城晴岚港使用）；改为一块传送石，直达主城东门 / 海角飞艇坪（来回都能传）
	var ws := Waystone.new()
	ws.name = "ws_goldenear"
	ws.ws_id = "ws_goldenear"
	ws.title = "金穗镇"
	ws.zone_id = "vale"
	ws.links = ["ws_gate_e", "ws_airship"]
	ws.position = Vector3(cx + 5 * S, b.h(cx + 5 * S, cz + 32 * S), cz + 32 * S)
	ws.scale = Vector3.ONE * S
	ws.land_rel = Vector3(0, 0.3, 3.8)
	ws.land_yaw = 180.0
	b.groups.Buildings.add_child(ws)
	b.spawn_point("fp_goldenear", cx + 5 * S, cz + 37 * S, 0)
	# 洛奇M 武器摊（Dunbarton_WeaponStore 原模型，tools/blender/village_kit/build_mabi_props.py 导出）：铁匠铺门前广场外缘的露天摊位
	var wsx := cx - 18.0 * S
	var wsz := cz - 18.0 * S
	var wsy := rad_to_deg(atan2(-(wsx - cx), -(wsz - cz)))
	b.flatten_rect(wsx, wsz, 10.0 * S, 8.0 * S, b.h(wsx, wsz), 7.0, -deg_to_rad(wsy))
	var wst: Node3D = b.building("house", wsx, wsz, wsy, Vector3(7.4, 3.58, 5.27), Color.WHITE, Color.WHITE, Color.WHITE, 0, "")
	wst.set("asset_scene", "res://assets/models/mabi/weapon_stall.glb")	# 街灯、长椅、摊位、水井
	for i in 6:
		var a := i * TAU / 6.0 + 0.2
		if not _tp(b, "lamp", cx + cos(a) * 18 * S, cz + sin(a) * 18 * S, -rad_to_deg(a)):
			b.prop("lamp", cx + cos(a) * 17 * S, cz + sin(a) * 17 * S, -rad_to_deg(a), Vector3(1, 4, 1), Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	for p in [[cx + 12 * S, cz - 7 * S], [cx - 10 * S, cz + 9 * S]]:
		var byaw: float = rad_to_deg(atan2(p[0] - cx, p[1] - cz)) + 180.0
		if not _tp(b, "bench", p[0], p[1], byaw):
			b.prop("bench", p[0], p[1], byaw, Vector3(2.4, 1, 1), Color.WHITE, Color.WHITE, Color("8a6a40"), 0, "", 0.0, "Props")
	# 保留移除陈设原先消耗的随机数，重建时不改变后续农田、植被和 NPC 布局。
	for _removed_slot in 2:
		b.rng.randi()
	if not _tp(b, "haycart", cx + 20 * S, cz + 8 * S, 70):
		b.prop("cart", cx + 18 * S, cz + 7 * S, 70, Vector3.ONE, Color.WHITE, Color.WHITE, Color("8a6a40"), 1, "", 0.0, "Props")
	for _removed_slot in 6:
		b.rng.randi()
	_tp(b, "noticeboard", cx + 22 * S, cz - 10 * S, 270)
	_tp(b, "signpost", cx + 5 * S, cz + 18 * S, 0)
	_tp(b, "brazier", cx - 22 * S, cz - 5 * S, 0)
	_tp(b, "woodshed", cx - 30 * S, cz - 18 * S, 90)
	_tp(b, "trough", cx + 28 * S, cz + 30 * S, 0)
	_tp(b, "haystack", cx + 31 * S, cz + 32 * S, 0)
	b.prop("sign", cx + 4 * S, cz + 20 * S, 0, Vector3.ONE, Color.WHITE, Color.WHITE, Color("6a4a30"), 0, "← 麦浪农庄  深石矿坑 ↓", 0.0, "Props")
	b.prop("sign", cx + 40 * S, cz - 5 * S, 90, Vector3.ONE, Color.WHITE, Color.WHITE, Color("6a4a30"), 0, "林风伐木场 →", 0.0, "Props")
	for i in 5:
		b.npc("guard_town", cx + [10, -10, 44, -44, 0][i] * S, cz + [-8, 8, -8, 18, 34][i] * S, b.rng.randf() * 360)
	for i in 6:
		b.npc("villager", cx + b.rng.randf_range(-30, 30) * S, cz + b.rng.randf_range(-30, 30) * S, b.rng.randf() * 360, 18.0, INF, i)
	b.spawn_point("gy_town", cx + 25 * S, cz + 32 * S, 0)
	b.poi("poi_town", "金穗镇", cx, cz, 58.0, 5, false)
	_town_dress(b, cx, cz, houses)
	_town_green(b, cx, cz, houses)
	# 绿化 / 菜畦可能改动房屋边缘地形；最后按 GLB 原点和 bbox 再压一次室内地板，避免地形穿出。
	for id in houses:
		var hh: Dictionary = houses[id]
		var nn: Node3D = hh.node
		var mm: Dictionary = hh.m
		b.flatten_rect(nn.position.x, nn.position.z, float(mm.w), float(mm.d), nn.position.y, 2.0, -deg_to_rad(float(hh.yaw)))

## Tripo 通用道具（tools/tripo/import_props.py：几何来自 Tripo，材质重绘成本项目 K| 手绘 PBR 材质；尺寸已是世界比例，不再乘 obj_scale）。
## 资产存在则放置并返回 true，否则返回 false 让调用方退回旧的程序化 / Blender 道具。
static var _tp_meta: Dictionary = {}
static func _tp(b: ZoneBuilder, name: String, x: float, z: float, yaw: float, sc0: float = 1.0, group: String = "Props") -> bool:
	# Tripo 建筑 / 道具材质未通过本轮语义审计；金穗镇使用项目自有构件，保留 GLB 供后续独立复核。
	return false

## 设定图里的绿化与细节（2026-10-10）：广场环形花坛 + 外圈小树、每栋房屋四周的灌木 / 花丛 / 矮篱笆、麦田围栏、更密的野花和灌木、更多村民
static func _town_green(b: ZoneBuilder, cx: float, cz: float, houses: Dictionary) -> void:
	var S := ZoneBuilder.OBJ_SCALE
	# 广场：少量环形花坛放在房屋外缘与主环路之间，避免侵入门前通道。
	for i in 8:
		var a := (i + 0.5) * TAU / 8.0
		b.prop("flowerbed", cx + cos(a) * 26.0 * S, cz + sin(a) * 26.0 * S, -rad_to_deg(a) + 90.0, Vector3(3.0, 1, 1.8), Color.WHITE, Color.WHITE, Color.WHITE, i % 3, "", 0.0, "Props")
	var ptrees := []
	for i in 14:
		var a2 := (i + 0.5) * TAU / 14.0 + 0.1
		ptrees.append(Vector2(cx + cos(a2) * 34.0 * S, cz + sin(a2) * 34.0 * S))
	b.forest("oak", ptrees, Color("6aa03a"), 0.6, 0.8)
	for id in houses:
		var h: Dictionary = houses[id]
		var n: Node3D = h.node
		var m: Dictionary = h.m
		var yaw: float = h.yaw
		var hw: float = float(m.w) * 0.5
		var hd: float = float(m.d) * 0.5
		var dx: float = float(m.door[0])
		var bushes := []
		var flowers := []
		for k in 14:
			var side := -1.0 if k % 2 == 0 else 1.0
			var lx := dx + side * b.rng.randf_range(4.2, hw + 3.5)       # 绕开门前 ±4m 的通道
			var lz := hd + b.rng.randf_range(0.8, 3.4)
			if k >= 10:                                                  # 侧墙与后墙外
				lx = side * (hw + b.rng.randf_range(0.8, 2.5))
				lz = b.rng.randf_range(-hd, hd)
			var p := _lx(n, yaw, Vector3(lx, 0, lz))
			if k % 3 != 0:
				bushes.append(Vector2(p.x, p.z))
			else:
				flowers.append(Vector2(p.x, p.z))
		b.forest("bush", bushes, Color("4a8a3a"), 0.8, 1.5, false)
		b.forest("flower", flowers, Color("ff90b0"), 1.0, 1.6, false)
		if id.begins_with("home"):                                       # 民居前院矮篱笆（两段，留出门前通道）
			for s in [-1.0, 1.0]:
				var fp := _lx(n, yaw, Vector3(dx + s * (4.2 + 3.0), 0, hd + 3.8))
				b.prop("fence", fp.x, fp.z, yaw, Vector3(6.0, 1, 1), Color.WHITE, Color.WHITE, Color("8a6a40"), 0, "", 0.0, "Props")
	# 外圈更密的灌木 / 野花 / 小树（设定图里路边处处是绿）
	b.forest("bush", b.scatter(cx, cz, 82.0, 90, 4.0, 0.5), Color("4a8a3a"), 0.8, 1.5, false)
	b.forest("flower", b.scatter(cx, cz, 72.0, 130, 1.8, 0.5, true, 0.5), Color("fff0a0"), 1.0, 1.6, false)
	b.forest("flower", b.scatter(cx, cz, 72.0, 100, 1.8, 0.5, true, 0.5), Color("e0e0ff"), 1.0, 1.6, false)
	b.forest("oak", b.scatter(cx, cz, 96.0, 24, 12.0, 0.4), Color("6aa03a"), 0.8, 1.1)
	for i in 8:
		b.npc("villager", cx + b.rng.randf_range(-60, 60) * S, cz + b.rng.randf_range(-60, 60) * S, b.rng.randf() * 360, 22.0, INF, 10 + i)


## 二次贝塞尔曲线采样（含两端点），n 段
static func _curve(a: Vector2, c: Vector2, b2: Vector2, n: int) -> Array:
	var out := []
	for i in n + 1:
		var t := float(i) / n
		out.append(a * (1.0 - t) * (1.0 - t) + c * 2.0 * (1.0 - t) * t + b2 * t * t)
	return out

## 构件库房屋（village_kit GLB）摆到任意位置：压平房基 + 前院、朝向 face 点、挂灯光 / 炊烟。返回节点。
static func _kit_house(b: ZoneBuilder, id: String, x: float, z: float, face: Vector2, label: String = "") -> Node3D:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/village_kit/buildings.json"))
	var m: Dictionary = meta[id]
	var yaw := rad_to_deg(atan2(face.x - x, face.y - z))
	var sz := Vector3(float(m.w), float(m.h), float(m.d))
	var fwd := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 4.0 * ZoneBuilder.OBJ_SCALE)
	b.flatten_rect(x + fwd.x, z + fwd.z, sz.x + 6.0, sz.z + 16.0, b.h(x, z), 13.0, -deg_to_rad(yaw))
	var node: Node3D = b.building("house", x, z, yaw, sz, Color.WHITE, Color.WHITE, Color.WHITE, 0, label, 1.0)
	node.set("asset_scene", "res://assets/models/village_kit/%s.glb" % id)
	_house_fx(b, node, m, yaw)
	return node

## 本地坐标（相对房屋原点、glTF 轴：x 右、z 朝门外）→ 区域坐标
static func _lx(node: Node3D, yaw: float, v: Vector3) -> Vector3:
	return node.position + Basis(Vector3.UP, deg_to_rad(yaw)) * v

## 房屋灯光（室内暖光，随距离淡出）与炊烟
static func _house_fx(b: ZoneBuilder, node: Node3D, m: Dictionary, yaw: float) -> void:
	var i := 0
	for l in m.lights:
		var o := OmniLight3D.new()
		o.name = "%s_light_%d" % [node.name, i]
		o.position = _lx(node, yaw, Vector3(float(l[0]), float(l[1]), float(l[2])))
		o.light_color = Color("ffc47a")
		o.omni_range = float(l[3]) * 1.15
		o.light_energy = float(l[4])
		# 室内主光源（吊灯 / 炉火，能量 ≥ 1.0）投影：桌椅、梁柱、柜台在地板和墙上有真实的影子；只在近处（28m 内）开影，远处只留光
		o.shadow_enabled = float(l[4]) >= 1.5
		o.shadow_bias = 0.04
		o.shadow_blur = 1.4
		o.distance_fade_enabled = true
		o.distance_fade_begin = 45.0
		o.distance_fade_length = 25.0
		o.distance_fade_shadow = 28.0
		b.groups.Props.add_child(o)
		i += 1
	i = 0
	for s in m.smoke:
		var sm := ChimneySmoke.new()
		sm.name = "%s_smoke_%d" % [node.name, i]
		sm.position = _lx(node, yaw, Vector3(float(s[0]), float(s[1]), float(s[2])))
		b.groups.Props.add_child(sm)
		i += 1

## 站位由建筑元数据给出（buildings.json 的 npcs：glTF 局部 x / z），面朝门
static func _meta_npc(b: ZoneBuilder, houses: Dictionary, id: String, npc_id: String) -> void:
	var h: Dictionary = houses[id]
	var q: Array = h.m.npcs[npc_id]
	var p := _lx(h.node, h.yaw, Vector3(float(q[0]), 0, float(q[1])))
	b.npc(npc_id, p.x, p.z, h.yaw, 0.0, h.node.position.y + 0.2)

static func _in_npc(b: ZoneBuilder, houses: Dictionary, id: String, npc_id: String, fx: float, fz: float) -> void:
	var h: Dictionary = houses[id]
	var inner: Array = h.m.inner
	var lx := lerpf(float(inner[0]), float(inner[1]), fx)
	var lz := lerpf(float(inner[2]), float(inner[3]), fz)
	var p := _lx(h.node, h.yaw, Vector3(lx, 0, lz))
	b.npc(npc_id, p.x, p.z, h.yaw, 0.0, h.node.position.y + 0.2)

## 屋外静态细节：每栋房屋门前 / 墙边的花坛、木桶、木箱、柴堆、长椅、灯柱、栅栏小院；镇外的果树、灌木、野花、岩石与小动物。
static func _town_dress(b: ZoneBuilder, cx: float, cz: float, houses: Dictionary) -> void:
	var S := ZoneBuilder.OBJ_SCALE
	var wood := Color("8a6a40")
	for id in houses:
		var h: Dictionary = houses[id]
		var n: Node3D = h.node
		var m: Dictionary = h.m
		var yaw: float = h.yaw
		var hw: float = float(m.w) * 0.5
		var hd: float = float(m.d) * 0.5
		var dx: float = float(m.door[0])
		var is_home: bool = id.begins_with("home")
		# 门边灯柱（花坛 / 花盆 / 栅栏已经是构件库 T08c / T09 的一部分，在房屋模型里）
		var lp := _lx(n, yaw, Vector3(dx + 3.3 * S, 0, hd + 2.4 * S))
		b.prop("lantern_post", lp.x, lp.z, 0, Vector3(1, 4, 1), Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
		# 侧墙：柴堆 / 木桶 / 木箱 / 水桶
		var sx := 1.0 if b.rng.randf() < 0.5 else -1.0
		if id != "smithy":      # 铁匠铺两侧山墙分别是敞棚和烟囱，不放柴堆 / 木桶
			var sp := _lx(n, yaw, Vector3(sx * (hw + 1.1 * S), 0, b.rng.randf_range(-hd * 0.4, hd * 0.2)))
			b.prop("wood_pile", sp.x, sp.z, yaw + 90, Vector3(1.8, 1.0, 1.4), Color("a07a4a"), Color("a07a4a"), Color("7a5a3a"), 0, "", 0.0, "Props")
			var bp := _lx(n, yaw, Vector3(sx * (hw + 0.9 * S), 0, hd * 0.55))
			b.prop("barrel", bp.x, bp.z, 0, Vector3(0.9, 1.1, 0.9), Color.WHITE, Color.WHITE, wood, 0, "", 0.0, "Props")
			b.prop("crate", bp.x + 0.9, bp.z + 0.2, b.rng.randf() * 90, Vector3(0.8, 0.8, 0.8), Color.WHITE, Color.WHITE, wood, 0, "", 0.0, "Props")
		if id in ["tavern", "tailor", "store"]:
			# 店铺门前小露台：桌椅
			var t := _lx(n, yaw, Vector3(dx - 4.2 * S, 0, hd + 3.6 * S))
			b.prop("table", t.x, t.z, yaw, Vector3(1.6, 0.9, 0.9), Color.WHITE, Color.WHITE, wood, 0, "", 0.0, "Props")
			for k in [-1.0, 1.0]:
				var st := _lx(n, yaw, Vector3(dx - 4.2 * S + k * 0.6 * S, 0, hd + 3.6 * S + 0.9))
				b.prop("stool", st.x, st.z, 0, Vector3(0.5, 0.5, 0.5), Color.WHITE, Color.WHITE, wood, 0, "", 0.0, "Props")
		var fs := -1.0 if dx > 0.0 else 1.0       # 往房屋中心那一侧放杂物，别挡在门前
		if is_home:
			# 菜畦 + 手推车（栅栏在房屋模型里）
			var gp := _lx(n, yaw, Vector3(dx + fs * 5.4 * S, 0, hd + 2.5 * S))
			_field(b, gp.x, gp.z, 3.6 * S, 2.4 * S, yaw, Color("7ab050") if b.rng.randf() < 0.5 else Color("e0a040"), 2)
			if b.rng.randf() < 0.6:
				var wb := _lx(n, yaw, Vector3(dx + fs * 2.9 * S, 0, hd + 2.9 * S))
				b.prop("wheelbarrow", wb.x, wb.z, yaw + 40, Vector3(0.8, 0.8, 1.8), Color.WHITE, Color.WHITE, wood, 0, "", 0.0, "Props")
		if id == "stable":
			var tr := _lx(n, yaw, Vector3(dx + fs * 4.4 * S, 0, hd + 2.2 * S))
			b.prop("trough", tr.x, tr.z, yaw, Vector3(2.2, 0.7, 0.7), Color.WHITE, Color.WHITE, wood, 0, "", 0.0, "Props")
			for k in 3:
				var hb := _lx(n, yaw, Vector3(dx - fs * (4.2 + k * 1.3) * S, 0, hd + 2.2 * S))
				b.prop("haystack", hb.x, hb.z, b.rng.randf() * 360, Vector3(1.8, 1.4, 1.8), Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
		if id == "guard":
			for s in [-1.0, 1.0]:
				var bz := _lx(n, yaw, Vector3(s * 2.8 * S, 0, hd + 1.6 * S))
				b.prop("brazier", bz.x, bz.z, 0, Vector3.ONE, Color.WHITE, Color("ff9030"), Color.WHITE, 0, "", 0.0, "Props")
	# 镇周围：果树 / 橡树、灌木、野花、岩石
	# 广场与门前空地不种树：中心 r48 留空，各房屋按尺寸留空；果树林与灌木在外圈
	b.block(cx, cz, 36.0 * ZoneBuilder.OBJ_SCALE)
	for id in houses:
		var hn: Node3D = houses[id].node
		b.block(hn.position.x, hn.position.z, maxf(float(houses[id].m.w), float(houses[id].m.d)) * 0.75)
	b.forest("oak", b.scatter(cx, cz, 82.0, 36, 14.0, 0.4), Color("6aa03a"), 0.9, 1.25)
	b.forest("birch", b.scatter(cx, cz, 74.0, 14, 14.0, 0.4), Color("8ac050"))
	b.forest("bush", b.scatter(cx, cz, 68.0, 46, 4.5, 0.5), Color("4a8a3a"), 0.8, 1.4, false)
	b.forest("flower", b.scatter(cx, cz, 64.0, 100, 2.2, 0.5, true, 0.5), Color("fff0a0"), 0.9, 1.4, false)
	b.forest("flower", b.scatter(cx, cz, 64.0, 80, 2.2, 0.5, true, 0.5), Color("ff90b0"), 0.9, 1.4, false)
	b.forest("flower", b.scatter(cx, cz, 64.0, 56, 2.2, 0.5, true, 0.5), Color("a98aff"), 0.9, 1.4, false)
	b.forest("rock", b.scatter(cx, cz, 76.0, 8, 16.0, 0.7, true, 0.0), Color("9a968c"), 0.6, 1.5)
	# 小动物：野兔与小鹿在镇外草地
	b.spawner("rabbit", cx - 100, cz + 70, 5, 30)
	b.spawner("rabbit", cx + 95, cz - 60, 4, 28)
	b.spawner("rabbit", cx + 70, cz + 100, 4, 25)
	b.spawner("deer", cx - 120, cz - 70, 3, 40)

# ================================================================ 麦浪农庄
static func _field(b: ZoneBuilder, cx: float, cz: float, w: float, d: float, yaw: float, crop: Color, variant: int = 0) -> bool:
	# 农田统一入口：四角水位/坡度检查 → 压平 → 涂层 → 田垄模型 → 地块阻挡。
	var ang := deg_to_rad(yaw)
	var ca := cos(ang)
	var sa := sin(ang)
	for q in [[-0.5, -0.5], [0.5, -0.5], [0.5, 0.5], [-0.5, 0.5]]:
		var px: float = cx + (float(q[0]) * w) * ca - (float(q[1]) * d) * sa
		var pz: float = cz + (float(q[0]) * w) * sa + (float(q[1]) * d) * ca
		if b.h(px, pz) <= WATER + 1.2 or b.slope(px, pz) > 0.48:
			return false
	var ground := b.h(cx, cz)
	b.flatten_rect(cx, cz, w, d, ground, 8.0, -ang)
	b.paint_rect(cx, cz, w, d, 6, yaw)
	b.prop("field", cx, cz, yaw, Vector3(w, 1, d), Color.WHITE, crop, Color.WHITE, variant, "", 0.0, "Props")
	b.block(cx, cz, maxf(w, d) * 0.55)
	return true

static func _field_fence(b: ZoneBuilder, cx: float, cz: float, w: float, d: float, yaw: float) -> void:
	var ang := deg_to_rad(yaw)
	var ex := Vector2(cos(ang), sin(ang)) * (w * 0.5 + 0.6)
	var ey := Vector2(-sin(ang), cos(ang)) * (d * 0.5 + 0.6)
	b.prop("fence", cx - ey.x, cz - ey.y, yaw, Vector3(w + 1.2, 1, 1), Color.WHITE, Color.WHITE, Color("8a6a40"), 0, "", 0.0, "Props")
	b.prop("fence", cx + ey.x, cz + ey.y, yaw, Vector3(w + 1.2, 1, 1), Color.WHITE, Color.WHITE, Color("8a6a40"), 0, "", 0.0, "Props")
	b.prop("fence", cx - ex.x, cz - ex.y, yaw + 90.0, Vector3(d + 1.2, 1, 1), Color.WHITE, Color.WHITE, Color("8a6a40"), 0, "", 0.0, "Props")
	b.prop("fence", cx + ex.x, cz + ex.y, yaw + 90.0, Vector3(d + 1.2, 1, 1), Color.WHITE, Color.WHITE, Color("8a6a40"), 0, "", 0.0, "Props")

static func _farms(b: ZoneBuilder) -> void:
	_kit_house(b, "farmhouse", 210, 410, Vector2(222, 446), "霍布的农舍")
	_kit_house(b, "barn", 248, 462, Vector2(210, 450), "谷仓")
	_kit_house(b, "home_thatch", 150, 410, Vector2(175, 440))
	_modular(b.building("windmill", 150, 440, 30, Vector3(6, 14, 6), Color("f0e4c8"), Color("8a4a3a"), Color("6a4a30")), "windmill")
	_field(b, 170, 450, 42, 22, 0, Color("e0c050"), 0)
	_field(b, 222, 445, 30, 18, 0, Color("e08030"), 1)
	_field(b, 250, 420, 26, 18, 0, Color("80c050"), 2)
	_field(b, 145, 475, 28, 20, 0, Color("e0c050"), 0)
	_field_fence(b, 170, 450, 42, 22, 0)
	_field_fence(b, 222, 445, 30, 18, 0)
	_field_fence(b, 250, 420, 26, 18, 0)
	_field_fence(b, 145, 475, 28, 20, 0)
	for p in [[190, 430], [205, 495], [225, 430], [140, 455]]:
		b.prop("haystack", p[0], p[1], 0, Vector3(3.5, 2, 3.5), Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	b.npc("hob", 205, 420, 200)
	b.npc("martha", 214, 420, 160)
	b.poi("poi_farm", "麦浪农庄", 200, 445, 80, 3)
	# 灰巾帮废弃农舍
	b.building("house", 105, 372, 120, Vector3(12, 6, 9), Color("8a8070"), Color("5a4a3a"), Color("3a2a1a"), 1)
	for p in [[120, 395], [92, 395], [130, 370]]:
		b.prop("tent", p[0], p[1], b.rng.randf() * 360, Vector3(4, 2.6, 4), Color.WHITE, Color("6a6a70"), Color.WHITE, 0, "", 0.0, "Props")
	b.prop("campfire", 112, 388, 0, Vector3.ONE, Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	for i in 6:
		b.prop("crate", 95 + b.rng.randf() * 30, 380 + b.rng.randf() * 25, b.rng.randf() * 90, Vector3(1.2, 1.2, 1.2), Color.WHITE, Color.WHITE, Color("7a5a3a"), 0, "", 0.0, "Props")
	b.poi("poi_bandit_farm", "灰巾帮废弃农舍", 110, 385, 40, 6)
	b.spawner("bandit_thug", 140, 395, 6, 28)
	b.spawner("bandit_thug", 105, 410, 4, 18)
	b.spawner("bandit_rogue", 120, 360, 4, 20)
	b.spawner("bandit_apprentice", 95, 385, 4, 16)
	b.spawner("stark", 100, 372, 1, 0, 0, 180)
	b.spawner("boar", 270, 430, 6, 40)
	b.spawner("boar", 180, 520, 6, 40)
	b.spawner("boar", 300, 500, 4, 30)
	b.spawner("rot_boar", 320, 430, 1, 30, 20, 600)

# ================================================================ 深石矿坑
static var _mabi_meta: Dictionary = {}

## 洛奇M 衍生摆件（tools/blender/village_kit/build_mabi_props.py 导出的 GLB，尺寸 [宽, 高, 深] 在 mabi_props.json）
static func _mabi_prop(b: ZoneBuilder, name: String, x: float, z: float, yaw: float, sc: float = 1.0) -> Node3D:
	if _mabi_meta.is_empty():
		_mabi_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/mabi/mabi_props.json"))
	var s: Array = _mabi_meta[name].size
	var node: Node3D = b.building("house", x, z, yaw, Vector3(float(s[0]), float(s[1]), float(s[2])) * sc, Color.WHITE, Color.WHITE, Color.WHITE, 0, "")
	node.set("asset_scene", "res://assets/models/mabi/%s.glb" % name)
	node.scale = Vector3.ONE * sc * b.obj_scale
	return node

## 采场局部坐标（u 沿坡道朝东，v 垂直）→ 世界 xz。采场中心 (220, 610)，yaw -28°
static func _mq(u: float, v: float) -> Vector2:
	return Vector2(220.0, 610.0) + Vector2(0.883, -0.469) * u + Vector2(0.469, 0.883) * v

static func _mine(b: ZoneBuilder) -> void:
	# v2：西南山梁 100×58 的 9 级台阶坑；坑底 / 台地 / 坑壁分散布置摆件；
	# 怪物按「组」拉开距离（组与组间隔 ≥ 45m，大于怪物 13m 仇恨半径 + 7m 连锁半径），一次最多拉到 2 只，不会再一进去就被围殴。
	var c := Vector2(220.0, 610.0)
	# 坑壁隧道口（朝向坑心）
	for e in [[-100.0, -20.0], [-45.0, 52.0], [35.0, -50.0], [-20.0, 56.0]]:
		var p := _mq(e[0], e[1])
		b.prop("mine_entrance", p.x, p.y, rad_to_deg(atan2(c.x - p.x, c.y - p.y)), Vector3.ONE, Color.WHITE, Color.WHITE, Color("6a4a30"), 0, "深石矿坑" if e[0] == -100.0 else "", 0.0, "Buildings")
	# 路灯：沿坡道 + 坑底一圈
	for i in 5:
		var p := _mq(30.0 + i * 20.0, -6.0 if i % 2 == 0 else 6.0)
		b.prop("lamp", p.x, p.y, 0, Vector3(1, 3.5, 1), Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	for i in 12:
		var a := i * TAU / 12.0
		var p := _mq(cos(a) * 62.0, sin(a) * 32.0)
		b.prop("lamp", p.x, p.y, 0, Vector3(1, 3.5, 1), Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	# 矿车 / 木箱成堆（4 处）
	for g in [[-30.0, 18.0], [58.0, -24.0], [-82.0, 30.0], [10.0, -38.0]]:
		var p := _mq(g[0], g[1])
		for i in 2:
			b.prop("cart", p.x + b.rng.randf_range(-4, 4), p.y + b.rng.randf_range(-4, 4), b.rng.randf() * 360, Vector3.ONE, Color.WHITE, Color.WHITE, Color("6a5040"), 0, "", 0.0, "Props")
		for i in 5:
			b.prop("crate", p.x + b.rng.randf_range(-5, 5), p.y + b.rng.randf_range(-5, 5), b.rng.randf() * 90, Vector3(1.1, 1.1, 1.1), Color.WHITE, Color.WHITE, Color("7a5a3a"), 0, "", 0.0, "Props")
	# 营地（坡道顶）
	var camp := _mq(112.0, 20.0)
	b.prop("tent", camp.x, camp.y, 250, Vector3(4, 2.6, 4), Color.WHITE, Color("a08a60"), Color.WHITE, 0, "", 0.0, "Props")
	var cf := _mq(106.0, 10.0)
	b.prop("campfire", cf.x, cf.y, 0, Vector3.ONE, Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	var gb := _mq(108.0, 4.0)
	b.npc("gib", gb.x, gb.y, 250)
	# 洛奇M 衍生摆件：木支架塔 / 栈桥 / 门架 / 栅栏 / 大石块 / 水晶簇
	var pr := _mq(80.0, 42.0)
	_mabi_prop(b, "mine_tower", pr.x, pr.y, 200)
	pr = _mq(-60.0, -34.0)
	_mabi_prop(b, "mine_scaffold", pr.x, pr.y, 40)
	pr = _mq(-10.0, 4.0)
	_mabi_prop(b, "mine_trestle", pr.x, pr.y, 118)
	pr = _mq(-100.0, 12.0)
	_mabi_prop(b, "mine_gate", pr.x, pr.y, 90)
	for q in [[88.0, -24.0, 118.0], [92.0, 24.0, 60.0], [60.0, -48.0, 90.0]]:
		var f := _mq(q[0], q[1])
		_mabi_prop(b, "mine_fence", f.x, f.y, q[2])
	for i in 14:
		var rp := _mq(b.rng.randf_range(-110.0, 100.0), b.rng.randf_range(-58.0, 58.0))
		if b.near_road(rp.x, rp.y):
			continue
		_mabi_prop(b, "mine_rock", rp.x, rp.y, b.rng.randf() * 360, b.rng.randf_range(0.7, 1.5))
	for i in 11:
		var cp := _mq(b.rng.randf_range(-115.0, 60.0), b.rng.randf_range(-56.0, 56.0))
		if b.near_road(cp.x, cp.y):
			continue
		_mabi_prop(b, ["mine_crystal_a", "mine_crystal_b", "mine_crystal_c"][i % 3], cp.x, cp.y, b.rng.randf() * 360, b.rng.randf_range(0.8, 1.4))
	# POI
	b.poi("poi_mine", "深石矿坑", c.x, c.y, 150, 4)
	var deep := _mq(-96.0, 4.0)
	b.poi("poi_mine_deep", "矿坑深处", deep.x, deep.y, 34, 8)
	# 采集：矿脉三处 + 矿工遗骸
	for g in [[0.0, 0.0], [-60.0, 14.0], [40.0, 34.0]]:
		var gp := _mq(g[0], g[1])
		b.gather("ore", gp.x, gp.y, 4, 30, 60)
	var mb := _mq(-70.0, -10.0)
	b.gather("miner_body", mb.x, mb.y, 1, 4, 20)
	# 怪物：每组 1–2 只，组间距 ≥ 45m；越往里越强，最里面是首领
	var gl: Array = [
		["ratman_digger", 62.0, -20.0, 2, 8.0], ["ratman_digger", 22.0, 36.0, 2, 8.0], ["ratman_digger", -22.0, -28.0, 2, 8.0], ["ratman_digger", -62.0, 28.0, 2, 8.0],
		["ratman_geomancer", -40.0, 8.0, 1, 5.0], ["ratman_geomancer", -78.0, -22.0, 1, 5.0],
		["ratman_foreman", -90.0, 22.0, 1, 5.0], ["ratman_foreman", -34.0, -52.0, 1, 5.0],
	]
	for g in gl:
		var sp := _mq(g[1], g[2])
		b.spawner(g[0], sp.x, sp.y, g[3], g[4])
	var bs := _mq(-108.0, 2.0)
	b.spawner("grizzik", bs.x, bs.y, 1, 0, 0, 180)
# ================================================================ 镜湖
static func _lake(b: ZoneBuilder) -> void:
	# 2026-10-10：湖面扩大约 3 倍（东西 ≈ 230m、南北 ≈ 260m 的多瓣大湖），渔夫小屋挪到西南岸，蛙人营地在东岸
	b.building("cottage", 640, 398, 0, Vector3(8, 5, 7), Color("e8dcc0"), Color("8a7a4a"), Color("6a4a30"), 1, "渔夫小屋")
	b.prop("pier", 646, 362, 0, Vector3(3, 1.4, 22), Color.WHITE, Color.WHITE, Color("8a6a40"), 0, "", 0.0, "Props", WATER - 0.5)
	b.prop("boat", 656, 342, 30, Vector3(1.6, 1, 4), Color.WHITE, Color.WHITE, Color("8a5a30"), 0, "", 0.0, "Props", WATER - 0.2)
	b.prop("boat", 700, 236, 80, Vector3(1.6, 1, 4), Color.WHITE, Color.WHITE, Color("7a5a38"), 0, "", 0.0, "Props", WATER - 0.2)
	b.npc("bob", 648, 388, 0)
	for p in [[858, 268], [872, 300], [850, 338], [868, 242]]:
		b.prop("tent", p[0], p[1], b.rng.randf() * 360, Vector3(3.5, 2.4, 3.5), Color.WHITE, Color("6a8a5a"), Color.WHITE, 0, "", 0.0, "Props")
	b.prop("campfire", 855, 295, 0, Vector3.ONE, Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	b.poi("poi_lake", "镜湖", 735, 290, 160, 2)
	b.spawner("frogman_scout", 806, 380, 4, 25)
	b.spawner("frogman_fisher", 850, 285, 5, 25)
	b.spawner("frogman_scout", 622, 222, 3, 20)
	b.spawner("frogman_priest", 878, 305, 3, 15)
	b.spawner("gurglu", 880, 288, 1, 0, 0, 180)
	b.gather("fishing_net", 818, 300, 6, 25)
	b.gather("fishing_net", 640, 352, 4, 14)
# ================================================================ 林风伐木场
static func _lumber(b: ZoneBuilder) -> void:
	b.building("cottage", 815, 465, 270, Vector3(10, 5, 8), Color("c8a878"), Color("6a5a3a"), Color("4a3a2a"), 0, "伐木场")
	b.building("house", 795, 490, 0, Vector3(12, 5, 8), Color("b89868"), Color("6a5a3a"), Color("4a3a2a"), 1, "锯木坊")
	b.prop("tent", 790, 455, 90, Vector3(4, 2.6, 4), Color.WHITE, Color("8a7a5a"), Color.WHITE, 0, "", 0.0, "Props")
	b.prop("campfire", 800, 470, 0, Vector3.ONE, Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	b.prop("platform", 828, 488, 0, Vector3(10, 1.2, 10), Color("b8a888"), Color.WHITE, Color("6a4a30"), 0, "", 0.0, "Buildings")
	b.npc("thad", 805, 472, 270)
	b.npc("pip_fp", 826, 482, 270)
	b.spawn_point("fp_lumber", 822, 478, 270)
	b.spawn_point("gy_east", 780, 520, 0)
	b.gather("lumber_pile", 760, 440, 6, 30)
	b.poi("poi_lumber", "林风伐木场", 805, 475, 40, 4)
	b.poi("poi_woods", "东部林地", 760, 560, 150, 0)
	b.spawner("prowler", 700, 400, 5, 35)
	b.spawner("prowler", 650, 520, 5, 35)
	b.spawner("forest_spider", 860, 600, 6, 35)
	b.spawner("forest_spider", 780, 620, 5, 30)
	b.spawner("weaver", 875, 645, 1, 0, 0, 180)
	b.spawner("grizzly", 720, 640, 5, 40)
	b.spawner("grizzly", 840, 520, 4, 35)
	for i in 8:
		b.prop("web", 860 + b.rng.randf_range(-25, 25), 640 + b.rng.randf_range(-25, 25), b.rng.randf() * 360, Vector3(4, 4, 1), Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 1.0, "Props")
	b.poi("poi_spider", "蛛巢", 870, 640, 40, 4)

# ================================================================ 村庄小物件（build_props2.py：桌椅、木桶、麻袋、篮子、柴堆等）
static func _small(b: ZoneBuilder, kind: String, x: float, z: float, yaw: float, s: float = 1.0, v: int = 0) -> void:
	b.prop(kind, x, z, yaw, Vector3.ONE * s, Color.WHITE, Color.WHITE, Color("9a7048"), v, "", 0.0, "Props")

static func _dress(b: ZoneBuilder) -> void:
	var S := ZoneBuilder.OBJ_SCALE
	var cx := 435.0
	var cz := 470.0
	var r := b.rng
	# 旅店门前露天座位
	for t in [[cx + 14 * S, cz - 14 * S], [cx + 19 * S, cz - 9 * S]]:
		_small(b, "table", t[0], t[1], 45)
		_small(b, "chair", t[0] - 1.1, t[1] + 0.2, 135)
		_small(b, "chair", t[0] + 1.1, t[1] - 0.2, 315)
		_small(b, "stool", t[0] + 0.3, t[1] + 1.2, r.randf() * 360)
	for i in 3:
		_small(b, "barrel", cx + 33 * S + i * 1.1, cz - 15 * S - i * 0.9, r.randf() * 360, 1.0, i % 2)
	_small(b, "crate", cx + 36.5 * S, cz - 18.5 * S, 20, 1.0, 2)
	# 铁匠铺：柴堆、水桶、货箱
	_small(b, "wood_pile", cx - 38 * S, cz - 10 * S, 45, 1.4)
	_small(b, "bucket", cx - 20 * S, cz - 11 * S, 0)
	_small(b, "barrel", cx - 34 * S, cz - 14 * S, 0, 0.9, 1)
	_small(b, "crate", cx - 36 * S, cz - 16 * S, 30, 1.0, 0)
	# 杂货铺门口：货箱、麻袋、果篮
	_small(b, "crate", cx - 22 * S, cz + 29 * S, 10, 1.0, 1)
	_small(b, "crate", cx - 20.6 * S, cz + 30.2 * S, 40, 0.9, 0)
	_small(b, "sack", cx - 24.5 * S, cz + 27 * S, 60, 1.2)
	_small(b, "basket", cx - 21 * S, cz + 27.5 * S, 0, 0.8)
	_small(b, "barrel", cx - 26 * S, cz + 30 * S, 0, 1.0, 0)
	# 货摊旁
	_small(b, "basket", cx - 11.5 * S, cz - 24 * S, 0, 0.8)
	_small(b, "crate", cx - 17 * S, cz - 24.5 * S, 15, 0.9, 1)
	_small(b, "basket", cx + 11.5 * S, cz + 26 * S, 0, 0.8)
	_small(b, "sack", cx + 17 * S, cz + 27 * S, 200, 1.1)
	# 马厩：水槽、手推车
	_small(b, "trough", cx + 47 * S, cz + 9.5 * S, 0, 1.8)
	_small(b, "wheelbarrow", cx + 44 * S, cz + 1 * S, 200)
	_small(b, "bucket", cx + 49.5 * S, cz + 11 * S, 0)
	# 广场长椅旁的花箱
	for p in [[cx + 9 * S, cz - 14 * S], [cx - 9 * S, cz + 14 * S], [cx + 15 * S, cz + 6 * S], [cx - 15 * S, cz - 6 * S]]:
		b.prop("flower_pot", p[0], p[1], rad_to_deg(atan2(p[0] - cx, p[1] - cz)), Vector3.ONE, Color.WHITE, Color.WHITE, Color("9a7048"), 0, "", 0.0, "Props")
	# 麦浪农庄
	_small(b, "wheelbarrow", 201, 426, 120)
	_small(b, "sack", 216, 427, 30, 1.2)
	_small(b, "sack", 218, 429.5, 160, 1.1)
	_small(b, "barrel", 219, 416, 0, 1.0, 1)
	_small(b, "crate", 233, 441, 10, 1.0, 1)
	_small(b, "crate", 234.3, 442.5, 50, 1.0, 0)
	_small(b, "crate", 233.6, 441.7, 25, 0.8, 2)
	_small(b, "trough", 228, 468, 90, 1.8)
	_small(b, "basket", 196, 447, 0, 0.8)
	_small(b, "basket", 197.2, 447.6, 0, 0.7)
	# Clear the new farmhouse's projecting stone footings.
	_small(b, "bench", 206.812, 416.517, 160, 2.2)
	# 林风伐木场
	for i in 3:
		_small(b, "wood_pile", 808 + i * 3.2, 452 + r.randf_range(-0.5, 0.5), 90 + r.randf_range(-8, 8), 1.4)
	_small(b, "wheelbarrow", 798, 462, 30)
	_small(b, "crate", 792, 470, 20, 1.0, 2)
	_small(b, "barrel", 794, 472, 0, 1.0, 1)
	_small(b, "stool", 803, 468, 0)
	_small(b, "stool", 797, 469, 0)

# ================================================================ 蔚蓝之塔与魔导工坊
static func _tower(b: ZoneBuilder) -> void:
	b.building("tower", 620, 780, 300, Vector3(12, 30, 12), Color("e8e4f0"), Color("4a5ac0"), Color("c0a060"), 0, "蔚蓝之塔")
	b.npc("selena", 612, 772, 300)
	b.poi("poi_tower", "蔚蓝之塔", 620, 780, 30, 5)
	b.building("hall", 770, 820, 200, Vector3(22, 9, 16), Color("8a7a6a"), Color("5a4a3a"), Color("4a3a2a"), 2, "魔导工坊")
	b.prop("pipe", 755, 800, 30, Vector3(1.0, 2.5, 18), Color.WHITE, Color.WHITE, Color("8a6a40"), 0, "", 0.0, "Props")
	b.prop("pipe", 790, 835, 110, Vector3(0.8, 3.5, 14), Color.WHITE, Color.WHITE, Color("8a6a40"), 0, "", 0.0, "Props")
	for i in 6:
		b.prop("crate", 750 + b.rng.randf() * 40, 805 + b.rng.randf() * 30, b.rng.randf() * 90, Vector3(1.3, 1.3, 1.3), Color.WHITE, Color.WHITE, Color("6a5a4a"), 0, "", 0.0, "Props")
	b.prop("crystal", 785, 805, 0, Vector3(2, 3, 2), Color.WHITE, Color("60c0ff"), Color.WHITE, 0, "", 0.0, "Props")
	b.poi("poi_workshop", "废弃魔导工坊", 770, 820, 45, 5)
	b.spawner("rogue_golem", 760, 790, 5, 30)
	b.spawner("rogue_golem", 800, 840, 5, 25)
	b.spawner("gear_spider", 740, 830, 5, 25)
	b.spawner("mk0", 775, 828, 1, 0, 0, 300)
	b.spawn_point("gy_south", 560, 760, 0)

# ================================================================ 狂牙岭
static func _hyena(b: ZoneBuilder) -> void:
	for p in [[190, 790], [215, 810], [175, 815], [230, 780]]:
		b.prop("tent", p[0], p[1], b.rng.randf() * 360, Vector3(4.5, 3, 4.5), Color.WHITE, Color("9a7a50"), Color.WHITE, 0, "", 0.0, "Props")
	b.prop("campfire", 205, 795, 0, Vector3.ONE, Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	for i in 6:
		b.prop("obelisk", 180 + b.rng.randf() * 50, 770 + b.rng.randf() * 50, b.rng.randf() * 90, Vector3(0.8, 3, 0.8), Color("a08a60"), Color("ff4030"), Color("e0d0b0"), 0, "", 0.0, "Props")
	b.prop("throne", 150, 852, 30, Vector3.ONE, Color.WHITE, Color.WHITE, Color("8a6a40"), 0, "", 0.0, "Props")
	b.npc("vick", 230, 720, 200)
	b.prop("tent", 236, 714, 200, Vector3(3.5, 2.4, 3.5), Color.WHITE, Color("6a8a5a"), Color.WHITE, 0, "", 0.0, "Props")
	b.poi("poi_hyena", "狂牙岭", 200, 800, 70, 4)
	b.spawner("hyena_warrior", 200, 790, 6, 30)
	b.spawner("hyena_warrior", 250, 830, 5, 25)
	b.spawner("hyena_thrower", 180, 810, 5, 25)
	b.spawner("grok", 152, 848, 1, 0, 0, 300)

static func _exit(b: ZoneBuilder) -> void:
	# 西境关口：晨露谷与潮风高地交界的大路上（无缝大世界，直接走过去）
	b.prop("arch", 38, 488, 90, Vector3(10, 7, 3), Color("b0a890"), Color("8a4a3a"), Color("6a4a30"))
	b.prop("sign", 62, 500, 90, Vector3.ONE, Color.WHITE, Color.WHITE, Color("6a4a30"), 0, "← 潮风高地 · 晴岚港", 0.0, "Props")
	b.npc("elin", 70, 474, 90)
	b.spawn_point("from_tidewind", 30, 490, 90)
	b.poi("poi_pass", "西境关口", 45, 488, 40, 3)

# ================================================================ 野外
static func _wild(b: ZoneBuilder) -> void:
	# 修道院山谷（1-5）
	b.spawner("young_wolf", 400, 180, 7, 35)
	b.spawner("young_wolf", 420, 250, 5, 30)
	b.spawner("timber_wolf", 380, 140, 4, 25)
	b.spawner("jelly_slime", 420, 90, 6, 30)
	b.spawner("rabbit", 520, 190, 4, 40)
	b.spawner("rabbit", 300, 380, 4, 50)
	b.spawner("deer", 560, 380, 3, 50)
	b.spawner("ratman_worker", 600, 125, 7, 25)
	b.spawner("ratman_worker", 630, 160, 4, 20)
	b.spawner("bandit_thug_s", 575, 245, 6, 30)
	b.spawner("bandit_thug_s", 600, 270, 4, 20)
	b.spawner("garrok", 610, 255, 1, 0, 0, 120)
	b.spawner("greymane", 380, 300, 1, 40, 25, 600)
	b.building("cottage", 612, 262, 200, Vector3(8, 5, 7), Color("d8c8a0"), Color("7a5a3a"), Color("5a3a2a"), 1)
	_field(b, 575, 245, 42, 30, 0, Color("7a3a9a"), 1)
	_field_fence(b, 575, 245, 42, 30, 0)
	b.gather("grape_crate", 575, 245, 8, 28)
	b.gather("herb_dew", 430, 160, 4, 30)
	b.gather("herb_dew", 520, 180, 4, 30)
	b.gather("herb_dew", 450, 240, 3, 25)
	b.poi("poi_vineyard", "米洛的葡萄园", 575, 245, 45, 5)
	b.poi("poi_ratcamp", "鼠人营地", 610, 130, 40, 5)
	b.prop("mine_entrance", 640, 110, 220, Vector3.ONE, Color.WHITE, Color.WHITE, Color("6a4a30"), 0, "", 0.0, "Buildings")
	for i in 5:
		b.prop("brazier", 590 + b.rng.randf() * 30, 115 + b.rng.randf() * 25, 0, Vector3.ONE, Color.WHITE, Color("ffd040"), Color.WHITE, 0, "", 0.0, "Props")
	# 金穗镇周边草地
	b.spawner("young_wolf", 520, 380, 4, 30)
	b.spawner("boar", 560, 540, 4, 35)
	b.spawner("rabbit", 600, 600, 3, 40)
	b.gather("herb", 560, 420, 6, 80, 90)
	b.gather("herb", 300, 300, 5, 80, 90)
	b.gather("ore", 230, 760, 3, 40, 90)
	b.poi("poi_river", "银溪", 440, 655, 40, 1)

# ================================================================ 植被
static func _vegetation(b: ZoneBuilder) -> void:
	var oak := Color("4f8f3a")
	var oak2 := Color("5f9f3a")
	# 东部森林（密）
	var pts := b.scatter(760, 560, 190, 320, 7.0, 0.4)
	b.forest("oak", pts, oak)
	b.forest("pine", b.scatter(870, 420, 90, 80, 7.0, 0.5), Color("3a6a3a"))
	# 修道院山谷周边与山脊
	b.forest("pine", b.scatter(485, 165, 230, 140, 8.0, 0.55), Color("3f7040"))
	b.forest("birch", b.scatter(400, 200, 80, 40, 9.0, 0.35), Color("8ac050"))
	# 零散树木
	b.forest("oak", b.scatter(480, 480, 420, 200, 14.0, 0.35), oak2)
	b.forest("oak", b.scatter(300, 300, 140, 60, 10.0, 0.35), oak)
	# 边缘丘陵上的成片林带（噪声成簇，中间留出草坡，让视线能看到远处的山）
	var mpts := []
	var opts := []
	for i in 2600:
		var x := b.rng.randf() * W
		var z := b.rng.randf() * W
		var de := minf(z, W - x)   # 西边是与潮风高地的接缝、南边是海岸，都不起边缘丘陵
		if de > 175.0 or de < 6.0 or b.slope(x, z) > 0.55 or b.near_road(x, z) or b.h(x, z) < WATER + 1.0:
			continue
		var cl := b.n2(x * 1.6 + 77.0, z * 1.6) * 0.5 + 0.5
		if b.rng.randf() > smoothstep(0.42, 0.62, cl):
			continue
		if b.rng.randf() < 0.65:
			mpts.append(Vector2(x, z))
		else:
			opts.append(Vector2(x, z))
	b.forest("pine", mpts, Color("3a6a3a"), 0.9, 1.6)
	b.forest("oak", opts, Color("4a8a38"), 0.9, 1.4)
	b.forest("rock", b.scatter(480, 480, 480, 160, 12.0, 0.9, true, 0.0).filter(func(p): return minf(minf(p.x, p.y), minf(W - p.x, W - p.y)) < 170.0), Color("a8a296"), 1.2, 3.2)
	# 狂牙岭枯树与岩石
	b.forest("deadtree", b.scatter(200, 800, 100, 30, 10.0, 0.5), Color("5a4a3a"))
	b.forest("rock", b.scatter(200, 800, 110, 50, 6.0, 0.7, true, 0.0), Color("9a968c"), 0.8, 2.2)
	b.forest("rock", b.scatter(480, 480, 450, 140, 10.0, 0.5, true, 0.0), Color("9a968c"), 0.6, 1.8)
	b.forest("bush", b.scatter(480, 480, 450, 300, 6.0, 0.4), Color("4a8a3a"), 0.7, 1.3, false)
	# 草丛与花
	b.forest("grass", b.scatter(480, 480, 470, 2600, 2.0, 0.4, true, 0.5), Color("5a9a3a"), 0.8, 1.5, false)
	b.forest("flower", b.scatter(485, 170, 140, 600, 1.5, 0.35, true, 0.5), Color("ff90b0"), 0.8, 1.3, false)
	b.forest("flower", b.scatter(485, 170, 140, 400, 1.5, 0.35, true, 0.5), Color("fff0a0"), 0.8, 1.3, false)
	b.forest("flower", b.scatter(480, 480, 450, 500, 2.0, 0.35, true, 0.5), Color("e0e0ff"), 0.8, 1.2, false)
	# 湖边芦苇
	b.forest("grass", b.scatter(760, 300, 100, 300, 1.5, 0.5, true, -0.5), Color("7a9a4a"), 1.2, 2.0, false)

## GPT abbey_kit_v3 组合：三块运行时包共用一个组合原点（局部坐标取自 Blender 装配：Chapel(4,0)、BellTower(-9,-4)、Courtyard(0,0)，
## glTF 转 Godot 时 Blender (x,y) → Godot (x,-z)）。
static func _abbey_group(b: ZoneBuilder, ox: float, oz: float, yaw: float, stone: Color, slate: Color, wood: Color, sc := 1.0) -> void:
	var parts := [["abbey_chapel", "chapel", Vector2(4, 0), Vector3(11, 12, 24)],
		["abbey_campanile", "belltower", Vector2(-9, 4), Vector3(5.2, 15, 5.2)],
		["abbey_chapel", "courtyard", Vector2(0, 0), Vector3(13, 6, 19)]]   # kind 需是 ModelProp 已登记的，否则会生成 Prop 而丢失 asset_scene
	var yr := deg_to_rad(yaw)
	sc *= b.obj_scale
	for p in parts:
		var l: Vector2 = p[2] * sc
		# 绕 Y 轴旋转：x' = x cos + z sin，z' = -x sin + z cos
		var wx := ox + l.x * cos(yr) + l.y * sin(yr)
		var wz := oz - l.x * sin(yr) + l.y * cos(yr)
		var node := b.building(p[0], wx, wz, yaw, p[3] * sc / b.obj_scale, stone, slate, wood)
		_modular(node, p[1])
		node.scale = Vector3.ONE * sc   # 整组等比放大（GPT 原尺寸相对角色偏小）

## 构件库院墙：从 a 到 b 铺 4.8m 墙段（模型沿 +X、原点在左端），段数取整后沿长度方向微调缩放
static func _kit_wall(b: ZoneBuilder, a: Vector2, e: Vector2, stone: Color, slate: Color, wood: Color) -> void:
	var d := e - a
	var n := maxi(1, int(round(d.length() / 4.8)))
	var seg := d.length() / n
	var yaw := rad_to_deg(atan2(-d.y, d.x))   # Godot 绕 Y：+X 转向 (cos, -sin)
	var ids := ["abbey_wall_seg", "abbey_wall_seg_b", "abbey_wall_seg_c"]
	for i in n:
		var p := a + d.normalized() * seg * i
		var node := b.prop("abbey_wall", p.x, p.y, yaw, Vector3(seg, 2.6, 0.9), stone, slate, wood, 0, "", 0.0, "Buildings")
		_kit(node, ids[(i * 7 + int(a.x + a.y)) % 3])
		node.scale = Vector3(seg / 4.8, b.obj_scale, b.obj_scale)     # 长度保持（首尾相接），高度 / 厚度按世界比例放大

## 修道院范围内的旧路灯 / 柏树换成构件库模型（abbey_lamp → 铁艺路灯，cypress → 两款柏树按高度缩放）
static func _kit_dress(b: ZoneBuilder, rect: Rect2) -> void:
	var i := 0
	for n in b.root.find_children("*", "", true, false):
		if not (n is ModelProp) or not rect.has_point(Vector2(n.position.x, n.position.z)):
			continue
		var mp := n as ModelProp
		if mp.kind == "abbey_lamp":
			_kit(mp, "lamp_post_iron")
		elif mp.kind == "cypress":
			var h := mp.size.y
			_kit(mp, "cypress_kit" if i % 2 == 0 else "cypress_kit_b")
			mp.scale = Vector3.ONE * h / (7.0 if i % 2 == 0 else 6.0) * b.obj_scale
			i += 1

## 构件库装配（assets/models/modkit/<id>.glb，原生米制，K| 材质由 ModelProp._apply_kit 换成建筑着色器）
static func _kit(building_node: Node3D, asset_id: String) -> void:
	building_node.set("asset_scene", "res://assets/models/modkit/" + asset_id + ".glb")
	building_node.position.y -= 0.05

## Selected assemblies keep native metres and sit directly on the flattened terrain.
static func _modular(building_node: Node3D, asset_id: String) -> void:
	building_node.set("asset_scene", "res://assets/models/vale_runtime_v1/build001/" + asset_id + ".scn")
	building_node.position.y -= 0.05











