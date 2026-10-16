class_name GenTidewind
extends RefCounted
## 潮风高地（10-15级）生成器：西侧主城晴岚港 v7（tools/gen_city_v7.gd，v5 的 gen_solenne.gd 保留未用）、南岸沙滩、中部风车农庄、
## 北部灰巾帮哨营、旧铁路站场、东部鸣风崖、东南风语旧圣堂入口。
## 地形 1280×1280：原 960×960 野外坐标不变，向西扩 320m（海与主城）、向北/南各扩 160m。

const W := 960.0
const WATER := 8.0
const ORIGIN := Vector2(-1040, -760)   # 2026-10-09 晴岚港 v7 向北扩建：地形整体北移 600m（原点 -1040,-160 → -760），仍为 2000×2000

static func build() -> void:
	var b := ZoneBuilder.new("tidewind", 800, 2.5, 20261005, ORIGIN)
	b.obj_scale = ZoneBuilder.OBJ_SCALE      # 门高 2.8m 世界比例（同晨露谷）
	b.data.water_level = WATER
	b.data.layer_colors = PackedColorArray(ArtStyle.TERRAIN_COLORS)
	_terrain(b)
	_roads(b)
	_paint(b)
	_outpost(b)
	var os := b.obj_scale
	b.obj_scale = 1.0        # 晴岚港本身就是按 MMO 地标尺度（门洞 9-12m）规划的城市，不再放大（否则楼栋互相重叠）
	GenCityV7.build(b)
	b.obj_scale = os
	_beach(b)
	_farm(b)
	_camp(b)
	_railyard(b)
	_cliffs(b)
	_sanctum(b)
	_vegetation(b)
	# 2026-10-10 地形抛光（城区 / 城外人工台地不动）：热侵蚀去针刺 / 锯齿（断崖保留：坡度上限 1.7≈60°）+ 水岸平滑
	var prot := func(x, z): return GenCityV7.in_city(x, z) or GenCityV7.extra_h(x, z) >= 0.0
	b.polish(WATER, 1.7, 4, 3.0, prot)
	WorldLayout.stitch(b, "tidewind")
	b.save("res://data/terrain/tidewind.res", "res://scenes/zones/tidewind_highlands.tscn")

static func _terrain(b: ZoneBuilder) -> void:
	b.set_heights(func(x, z):
		if GenCityV7.in_city(x, z):
			return GenCityV7.city_h(b.noise, x, z)
		var base := 20.0 + b.n2(x, z) * 10.0 + b.n2(x * 2.5 + 200.0, z * 2.5) * 3.0
		# 丘陵起伏（脊状噪声，草原上点缀几道缓岗；必须在海岸混合之前加，否则海里会冒出小岛）
		base += pow(b.ridge(x * 0.8, z * 0.8), 2.4) * 10.0 * (1.0 - plateau(b, x, z)) * smoothstep(100.0, 200.0, x)
		# 西侧大海：海岸线与晴岚港规划一致（城北一段沿城市西海岸向北延伸）
		var cx := GenCityV7.coast_x(clampf(z, 200.0, 1040.0))
		base = lerpf(base, 2.0, 1.0 - smoothstep(cx - 5.0, cx + 60.0, x))
		# 南岸海：城东一段按规划的湾东海岸，其余同原高地南岸
		var sz := GenCityV7.south_coast_z(x) if x < 520.0 else 900.0
		base = lerpf(base, 2.5, smoothstep(sz - 30.0, sz + 22.0, z))
		# 东南角与晨露谷南岸连成同一条海岸线（世界 z≈960 起入海）
		base = lerpf(base, 2.5, smoothstep(790.0, 850.0, z) * smoothstep(800.0, 900.0, x))
		# 北缘山脊（向北扩出的部分保持山脊高度；西侧海面上不起山）。东边是与晨露谷的接缝，不起山墙
		# 与 WorldLayout.world_base 同一套北部群山（世界 z = 区域 z + 160），山脚线随噪声起伏，不再是笔直的台地
		var wz: float = z + WorldLayout.offset("tidewind").z
		var foot: float = 220.0 + b.n2(x * 0.8 + 900.0, 13.0) * 70.0
		base += pow(clampf((foot - wz) / foot, 0.0, 1.0), 1.6) * (44.0 + b.n2(x * 1.5, 400.0) * 18.0) * smoothstep(cx + 40.0, cx + 160.0, x)
		# 局部高原（2026-10-05 用户选定“局部高地”）：北半部抬升约 30m，南缘是一道带岩壁的断崖，
		# 西缘俯瞰晴岚港，东端在接缝前降回世界基础高度；南半部保持缓丘草原与海岸
		base += plateau(b, x, z) * 30.0 * (0.75 + 0.5 * (b.n2(x * 0.9 + 55.0, z * 0.9) * 0.5 + 0.5))   # 高原高度沿断崖起伏 22–38m
		base = GenCityV7.surround(b, base, x, z)
		# v7.2：矩形外的人工台地（西侧离岸岛 / 栈桥头、北苑叠园）把地形压平到台面 - 0.6
		var eh := GenCityV7.extra_h(x, z)
		if eh >= 0.0:
			return eh
		# 晴岚河出城段（水关以东 70m 到河源）
		if x < 372.0 and z > 559.0 and z < 615.0:   # v7.1 城市 0.8 缩放后河道中心 z=587、宽 42m
			base = lerpf(base, 2.0, (1.0 - smoothstep(352.0, 372.0, x)) * (1.0 - smoothstep(18.0, 25.0, absf(z - 587.0))))
		return base)
	# 无缝大世界：东边与晨露谷相接，向世界基础高度过渡
	WorldLayout.apply_seam(b, "tidewind")
	# 上高原的山口路：旧铁路站场 / 灰巾帮哨营方向
	b.ramp(Vector2(438, 452), Vector2(400, 330), 9.0)
	b.platform(700, 370, 50, 22.0, 26, 0.3)     # 东门哨站（断崖脚下）
	b.platform(560, 600, 82, 18.0, 32, 0.25, 0.5)  # 风车农庄
	b.platform(430, 120, 50, b.h(430, 120), 26, 0.35)   # 灰巾帮哨营（v7 城市北扩后东移出城墙）
	b.platform(390, 310, 64, b.h(390, 310), 28, 0.3)    # 旧铁路站场（高原上）
	# 鸣风崖：东南一道陡峭石岭（哈比的巢在岭顶岩丘），不是圆锥平顶山
	b.ridge_line([Vector2(780, 500), Vector2(840, 560), Vector2(895, 605), Vector2(935, 670)], 85.0, 42.0, 1.15)
	b.platform(890, 600, 18, b.h(890, 600), 12, 0.4, 0.6)
	b.platform(790, 790, 50, 19.0, 26, 0.3)     # 圣堂入口
	b.carve_path([Vector2(905, 330), Vector2(800, 345)], 8.0, 20.0, 8.0)

## 局部高原遮罩 0..1：南缘断崖沿折线 zb(x) 起伏，宽度随脊状噪声变化（有的地方是陡壁、有的地方是陡坡）
const PLATEAU_EDGE := [Vector2(290, 330), Vector2(400, 385), Vector2(520, 350), Vector2(640, 315), Vector2(760, 285), Vector2(860, 230), Vector2(960, 200)]
static func plateau(b: ZoneBuilder, x: float, z: float) -> float:
	var zb := 0.0
	for i in PLATEAU_EDGE.size() - 1:
		var a: Vector2 = PLATEAU_EDGE[i]
		var c: Vector2 = PLATEAU_EDGE[i + 1]
		if x <= c.x or i == PLATEAU_EDGE.size() - 2:
			zb = lerpf(a.y, c.y, clampf((x - a.x) / (c.x - a.x), 0.0, 1.0))
			break
	zb += b.n2(x * 2.0 + 71.0, 33.0) * 28.0
	var wide := 18.0 + 30.0 * b.ridge(x * 1.4, z * 1.4)
	var south := 1.0 - smoothstep(zb - wide, zb + 8.0, z)
	var west := smoothstep(300.0, 372.0, x + b.n2(17.0, z * 2.0) * 22.0)
	var east := 1.0 - smoothstep(820.0, 905.0, x + b.n2(91.0, z * 2.0) * 25.0)
	return south * west * east

static func _roads(b: ZoneBuilder) -> void:
	b.road([Vector2(962, 330), Vector2(930, 330), Vector2(820, 350), Vector2(700, 370), Vector2(580, 400), Vector2(430, 420), Vector2(320, 432), Vector2(298, 430)], 7.0)
	b.road([Vector2(700, 370), Vector2(640, 480), Vector2(570, 590)], 5.5)
	b.road([Vector2(570, 590), Vector2(680, 700), Vector2(790, 790)], 5.5)
	b.road([Vector2(570, 590), Vector2(520, 720), Vector2(480, 860)], 4.5)
	b.road([Vector2(430, 420), Vector2(400, 330), Vector2(420, 220), Vector2(430, 150)], 5.5)
	for zz in range(-398, -550, -6):
		b.paint_circle(244, zz, 5, 2, 0.9, 0.3)   # 北门隘口路（坡面由 GenCityV7.surround 塑形，不再用 road 磨平）
	b.road([Vector2(700, 370), Vector2(790, 450), Vector2(850, 560)], 5.0)

static func _paint(b: ZoneBuilder) -> void:
	b.paint_where(4, func(_x, _z, hv): return 1.0 - smoothstep(WATER + 0.4, WATER + 2.4, hv) if hv > WATER - 3.0 else 0.0)
	b.paint_where(7, func(x, z, _hv): return (1.0 - smoothstep(150.0, 260.0, Vector2(x - 560.0, z - 560.0).length())) * (0.5 + 0.5 * b.n2(x * 5.0, z * 5.0)))
	b.paint_where(3, func(x, z, hv): return smoothstep(0.35, 0.7, b.slope(x, z)))
	b.paint_circle(700, 370, 40, 5, 1.0, 0.3)
	b.paint_circle(430, 120, 40, 2, 0.9, 0.5)
	b.paint_circle(390, 310, 55, 3, 0.7, 0.5)
	b.paint_circle(790, 790, 40, 5, 0.8, 0.4)
	b.paint_circle(890, 600, 40, 8, 0.8, 0.5)
	for f in [[520, 570, 60, 40], [610, 625, 50, 36], [530, 640, 44, 30]]:
		b.paint_rect(f[0], f[1], f[2], f[3], 6)

static func _outpost(b: ZoneBuilder) -> void:
	var cx := 700.0
	var cz := 370.0
	b.spawn_point("from_vale", 905, 333, 270)
	b.spawn_point("fp_camp", cx + 6, cz + 20, 0)
	b.spawn_point("gy_camp", cx - 20, cz + 30, 0)
	b.prop("arch", 880, 338, 90, Vector3(10, 7, 3), Color("b0a890"), Color("4a6aa8"), Color("6a4a30"))
	b.prop("sign", 870, 346, 90, Vector3.ONE, Color.WHITE, Color.WHITE, Color("6a4a30"), 0, "← 晨露谷", 0.0, "Props")
	b.building("tower", cx - 25, cz - 22, 0, Vector3(7, 12, 7), Color("d8d0c0"), Color("4a6aa8"), Color("c0a060"), 0, "哨站")
	b.building("house", cx + 25, cz - 18, 180, Vector3(10, 5, 8), Color("e8dcc0"), Color("4a6aa8"), Color("6a4a30"), 0, "指挥所")
	for p in [[-12, 14], [4, 22], [18, 12], [-26, 12], [30, 10]]:
		b.prop("tent", cx + p[0], cz + p[1], b.rng.randf() * 360, Vector3(4, 2.6, 4), Color.WHITE, Color("c8b890"), Color.WHITE, 0, "", 0.0, "Props")
	b.prop("campfire", cx, cz + 6, 0, Vector3.ONE, Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	b.prop("stall", cx + 10, cz + 4, 200, Vector3(4, 3, 3), Color.WHITE, Color("e0a040"), Color("6a4a30"), 0, "", 0.0, "Props")
	for p in [[-6, -8], [8, -6], [-14, 2]]:
		b.prop("crate", cx + p[0], cz + p[1], b.rng.randf() * 90, Vector3(1.1, 1.1, 1.1), Color.WHITE, Color.WHITE, Color("8a6a40"), 0, "", 0.0, "Props")
	b.prop("fence", cx, cz - 34, 0, Vector3(60, 1, 1), Color.WHITE, Color.WHITE, Color("8a6a40"), 0, "", 0.0, "Props")
	b.block(cx, cz, 40)
	b.npc("loren", cx + 22, cz - 8, 180)
	b.npc("isa", cx + 6, cz - 6, 180)
	b.npc("pip", cx + 12, cz + 8, 200)
	b.npc("grace", cx - 10, cz + 12, 150)
	b.npc("oscar", cx - 4, cz - 4, 0)
	b.npc("bran", cx + 8, cz + 22, 0)
	b.npc("guard_city", cx - 18, cz - 16, 270)
	b.npc("guard_city", cx + 38, cz + 4, 90)
	b.poi("poi_camp", "东门哨站", cx, cz, 50, 6, true)
	# 周边
	b.spawner("scarecrow", 740, 430, 4, 30)
	b.gather("herb", 760, 330, 5, 70, 90)

static func _beach(b: ZoneBuilder) -> void:
	b.spawner("reef_crab", 420, 880, 8, 40)
	b.spawner("reef_crab", 560, 890, 7, 40)
	b.spawner("giant_crab", 500, 900, 3, 30)
	b.spawn_point("gy_beach", 480, 840, 0)
	b.prop("pier", 336, 958, 0, Vector3(3, 1.4, 22), Color.WHITE, Color.WHITE, Color("8a6a40"), 0, "", 0.0, "Props", WATER - 0.5)
	b.prop("boat", 306, 968, 40, Vector3(5, 2, 2.5), Color.WHITE, Color("e8e0d0"), Color("8a6a40"), 0, "", 0.0, "Props", WATER)
	b.poi("poi_beach", "礁石海滩", 490, 880, 90, 3)

static func _farm(b: ZoneBuilder) -> void:
	var cx := 560.0
	var cz := 600.0
	b.spawn_point("fp_windmill", cx + 8, cz + 26, 0)
	b.spawn_point("gy_farm", cx - 30, cz + 30, 0)
	b.building("windmill", cx - 20, cz - 6, 20, Vector3(6, 14, 6), Color("f0e4c8"), Color("8a4a3a"), Color("6a4a30"))
	b.building("cottage", cx + 14, cz + 6, 180, Vector3(9, 5, 8), Color("e8dcc0"), Color("8a4a3a"), Color("6a4a30"), 1, "格兰特农舍")
	b.building("house", cx + 32, cz - 4, 200, Vector3(10, 5, 8), Color("d8c8a0"), Color("7a5a3a"), Color("5a3a2a"), 1, "谷仓")
	for f in [[-40, -50, 60, 40], [26, -50, 50, 36], [-60, 36, 44, 30]]:
		b.prop("field", cx + f[0], cz + f[1], 0, Vector3(f[2], 1, f[3]), Color.WHITE, Color("d8b84a"), Color.WHITE, 0, "", 0.0, "Props")
	for p in [[-10, 22], [40, 30], [-44, -12]]:
		b.prop("haystack", cx + p[0], cz + p[1], 0, Vector3(3.5, 2, 3.5), Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	b.block(cx, cz, 38)
	b.npc("grant", cx + 14, cz + 18, 180)
	b.npc("mill_fp", cx + 6, cz + 30, 0)
	b.spawner("scarecrow", cx - 30, cz - 50, 7, 40)
	b.spawner("scarecrow", cx + 40, cz - 50, 6, 35)
	b.spawner("scarecrow", cx - 50, cz + 40, 5, 30)
	b.spawner("arsonist", cx + 70, cz + 70, 6, 35)
	b.spawner("arsonist", cx + 20, cz + 110, 5, 30)
	b.gather("crop_sample", cx - 20, cz - 40, 7, 70, 45)
	b.poi("poi_farm", "风车农庄", cx, cz, 60, 5, true)

static func _camp(b: ZoneBuilder) -> void:
	var cx := 430.0
	var cz := 120.0
	b.spawn_point("gy_bandit", 460, 185, 180)
	var wood := Color("6a4a30")
	b.building("tower", cx - 24, cz - 6, 0, Vector3(6, 14, 6), Color("8a8a90"), Color("5a5a60"), wood, 0, "")
	b.building("house", cx + 8, cz - 14, 180, Vector3(10, 5, 8), Color("a09a8a"), Color("5a5a60"), wood, 0, "")
	for i in 7:
		var a := i * TAU / 7.0
		b.prop("tent", cx + cos(a) * 24, cz + 12 + sin(a) * 18, a * 57.3, Vector3(4, 2.6, 4), Color.WHITE, Color("6a6a70"), Color.WHITE, 0, "", 0.0, "Props")
	b.prop("campfire", cx, cz + 12, 0, Vector3.ONE, Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	b.prop("fence", cx, cz + 44, 0, Vector3(56, 1, 1), Color.WHITE, Color.WHITE, wood, 0, "", 0.0, "Props")
	b.prop("banner", cx - 6, cz + 40, 0, Vector3(1, 6, 1), Color.WHITE, Color("5a5a60"), Color("c0a060"), 0, "", 0.0, "Props")
	b.spawner("bandit_sentry", cx - 20, cz + 20, 6, 30)
	b.spawner("bandit_sentry", cx + 30, cz + 5, 5, 25)
	b.spawner("bandit_gunner", cx, cz + 35, 6, 25)
	b.spawner("varga", cx + 4, cz - 30, 1, 0, 0, 300)
	b.poi("poi_banditcamp", "灰巾帮哨营", cx, cz, 60, 5)

static func _railyard(b: ZoneBuilder) -> void:
	var cx := 390.0
	var cz := 310.0
	b.spawn_point("gy_rail", cx + 40, cz + 60, 180)
	b.prop("rail", cx, cz, 0, Vector3(90, 1, 6), Color.WHITE, Color.WHITE, Color("6a5a4a"), 0, "", 0.0, "Props")
	b.prop("rail", cx, cz + 12, 0, Vector3(90, 1, 6), Color.WHITE, Color.WHITE, Color("6a5a4a"), 0, "", 0.0, "Props")
	b.building("house", cx + 30, cz - 30, 180, Vector3(12, 5, 8), Color("a8a090"), Color("6a5a4a"), Color("5a4a3a"), 0, "信号室")
	b.prop("signal_lamp", cx - 20, cz - 8, 0, Vector3.ONE, Color.WHITE, Color("40ff60"), Color.WHITE, 0, "", 0.0, "Props")
	b.prop("train", cx - 30, cz + 6, 0, Vector3(16, 4, 3.5), Color("7a6a5a"), Color("5a4a3a"), Color.WHITE, 0, "", 0.0, "Props")
	b.prop("crate", cx + 10, cz + 24, 30, Vector3(1.4, 1.4, 1.4), Color.WHITE, Color.WHITE, Color("8a6a40"), 0, "", 0.0, "Props")
	b.npc("howard", cx + 24, cz - 14, 200)
	b.spawner("rust_golem", cx - 20, cz + 30, 6, 35)
	b.spawner("rust_golem", cx + 40, cz + 20, 5, 30)
	b.spawner("steam_spider", cx + 10, cz + 55, 6, 35)
	b.gather("signal_part", cx, cz + 10, 6, 60, 45)
	b.gather("ore", cx + 50, cz + 60, 4, 45, 90)
	b.poi("poi_railyard", "旧铁路站场", cx, cz, 70, 4)

static func _cliffs(b: ZoneBuilder) -> void:
	b.spawn_point("gy_cliff", 810, 520, 0)
	b.npc("lilian", 800, 530, 90)
	b.prop("tent", 806, 538, 120, Vector3(3.5, 2.4, 3.5), Color.WHITE, Color("80a040"), Color.WHITE, 0, "", 0.0, "Props")
	b.prop("campfire", 796, 546, 0, Vector3.ONE, Color.WHITE, Color.WHITE, Color.WHITE, 0, "", 0.0, "Props")
	b.spawner("harpy", 850, 560, 7, 40)
	b.spawner("harpy", 880, 610, 6, 35)
	b.spawner("harpy_witch", 870, 585, 6, 30)
	b.spawner("harpy_matron", 890, 600, 1, 0, 0, 400)
	b.gather("ore", 830, 500, 4, 40, 90)
	b.gather("herb", 650, 700, 5, 70, 90)
	b.gather("herb", 420, 640, 4, 60, 90)
	b.poi("poi_cliffs", "鸣风崖", 870, 580, 90, 5)

static func _sanctum(b: ZoneBuilder) -> void:
	var cx := 790.0
	var cz := 790.0
	b.spawn_point("from_sanctum", cx - 10, cz - 14, 0)
	b.spawn_point("gy_sanctum", cx - 30, cz - 30, 0)
	b.prop("arch", cx, cz, 30, Vector3(12, 9, 3), Color("a8a490"), Color("5a6a4a"), Color("6a5a4a"))
	for p in [[-20, 6], [18, 10], [-10, 18], [26, -6]]:
		b.prop("ruin_wall", cx + p[0], cz + p[1], b.rng.randf() * 360, Vector3(6, 4, 1.5), Color("a8a490"), Color("5a6a4a"), Color("6a5a4a"))
	for p in [[-14, 0], [14, 4]]:
		b.prop("column", cx + p[0], cz + p[1], 0, Vector3(1.4, 8, 1.4), Color("b8b4a0"), Color.WHITE, Color.WHITE)
	b.npc("ed", cx - 12, cz - 20, 30)
	b.poi("poi_sanctum_gate", "风语旧圣堂入口", cx, cz, 50, 5, true)
	if ResourceLoader.exists("res://scenes/zones/windwhisper_sanctum.tscn"):
		b.portal("sanctum", "from_tidewind", "风语旧圣堂", cx, cz + 6, 7.0, 14)
		b.prop("portal_ring", cx + 3, cz + 5, 30, Vector3(5, 1, 5), Color.WHITE, Color("a0d0ff"), Color("8a8478"), 0, "", 0.0, "Props")

static func _vegetation(b: ZoneBuilder) -> void:
	var oak := Color("5a9a3a")
	b.forest("oak", b.scatter(560, 520, 260, 260, 8.0, 0.4), oak)
	b.forest("oak", b.scatter(380, 700, 200, 120, 9.0, 0.4), Color("6aa03a"))
	b.forest("birch", b.scatter(420, 260, 120, 60, 9.0, 0.35), Color("8ac050"))
	b.forest("pine", b.scatter(850, 200, 100, 120, 8.0, 0.55), Color("3f7040"))
	b.forest("pine", b.scatter(300, 90, 160, 120, 8.0, 0.55), Color("3a6a3a"))
	var epts := []
	for i in 900:
		var x := b.rng.randf() * W
		var z := b.rng.randf() * W
		var de := minf(z, W - x)
		if de < 85.0 and de > 8.0 and b.slope(x, z) < 0.6 and not b.near_road(x, z):
			epts.append(Vector2(x, z))
	b.forest("pine", epts, Color("3a6a3a"), 0.9, 1.5)
	b.forest("rock", b.scatter(860, 580, 110, 70, 6.0, 0.8, true, 0.0), Color("9a968c"), 0.8, 2.4)
	b.forest("rock", b.scatter(480, 480, 450, 120, 10.0, 0.5, true, 0.0), Color("9a968c"), 0.6, 1.8)
	b.forest("bush", b.scatter(480, 480, 450, 280, 6.0, 0.4), Color("4a8a3a"), 0.7, 1.3, false)
	b.forest("grass", b.scatter(480, 480, 470, 2600, 2.0, 0.4, true, 0.5), Color("68a43a"), 0.8, 1.5, false)
	b.forest("flower", b.scatter(480, 480, 450, 500, 2.0, 0.35, true, 0.5), Color("fff0a0"), 0.8, 1.3, false)
	b.forest("flower", b.scatter(480, 480, 450, 400, 2.0, 0.35, true, 0.5), Color("ff90b0"), 0.8, 1.3, false)
	b.forest("deadtree", b.scatter(790, 790, 80, 20, 10.0, 0.5), Color("5a4a3a"))
	# v7.2 北坡林带：城墙与山之间的缓坡上种松 / 橡（北苑叠园台地、城内由 block_fns 排除）
	b.forest("pine", b.scatter(-120, -560, 340, 640, 9.0, 0.5), Color("3f7040"), 0.9, 1.7)
	b.forest("oak", b.scatter(-160, -500, 300, 240, 12.0, 0.45), Color("5a9a3a"), 0.9, 1.4)
	b.forest("bush", b.scatter(-120, -520, 300, 300, 6.0, 0.5), Color("4a8a3a"), 0.7, 1.3, false)



