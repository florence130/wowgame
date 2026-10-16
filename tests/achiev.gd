extends Node
## 成就系统验证：数据完整性、各判定方式、奖励结算、玩法钩子的真实链路、界面与探索判定。
## 不写存档（slot = -1）。
var checks: Array = []
var out := "res://.local/achiev_20261008"
var p: Player

## 允许在成就里出现的统计键（由玩法钩子累加）
const STAT_KEYS := ["quests", "quests_main", "kills", "elites", "rares", "bosses", "deaths", "craft", "gather",
	"auction_sold", "fps", "mails", "money_peak"]
const KINDS := ["stat", "kill", "level", "rep", "rep_any", "rep_all", "explored", "poi", "spells", "talents",
	"profs", "recipes", "money", "points", "mounts"]

func _ready() -> void:
	if not has_meta("runner"):
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks.append({"pass": ok, "label": label})
	print(("ACH PASS " if ok else "ACH FAIL ") + label)

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

## 进入世界并拿到新玩家：必须等到「新的 world + 新的 player」都就绪，
## 否则会拿到上一幕即将被释放的旧引用（previously freed）。
func enter_world() -> void:
	var old = Game.player
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player) or Game.player == old:
		await get_tree().process_frame
	p = Game.player
	Game.time_of_day = 12
	await wait(1.0)

func character(cls: String, level: int = 20) -> void:
	Game.slot_index = -1
	Game.new_character("成就验证", cls, DB.random_appearance(11, "m"))
	Game.pd["new"] = false
	Game.pd["level"] = level
	Game.pd["achiev"] = {}

func by_id(id: String) -> Dictionary:
	return DataAchiev.get_entry(id)

# ================================================================ 数据
func data_checks() -> void:
	check(DataAchiev.CATS.size() == 6, "共 6 个成就分类")
	var cat_ok := true
	for cid in DataAchiev.CATS:
		var e: Dictionary = DataAchiev.CATS[cid]
		if not e.has("name") or not e.has("color") or DataAchiev.by_cat(cid).is_empty():
			cat_ok = false
			print("ACH CAT BAD ", cid)
	check(cat_ok, "每个分类都有名称、配色与条目")
	var ids := {}
	var dup := false
	for a in DataAchiev.LIST:
		var id := String(a["id"])
		if ids.has(id):
			dup = true
			print("ACH DUP ID ", id)
		ids[id] = true
	check(not dup and DataAchiev.LIST.size() >= 45, "条目编号唯一，共 %d 条" % DataAchiev.LIST.size())
	var struct_ok := true
	for a in DataAchiev.LIST:
		for k in ["id", "cat", "name", "desc", "kind", "target", "pts"]:
			if not a.has(k):
				struct_ok = false
				print("ACH FIELD MISSING ", a.get("id", "?"), " -> ", k)
		if int(a.get("pts", 0)) < 1 or int(a.get("target", 0)) < 1:
			struct_ok = false
			print("ACH VALUE BAD ", a["id"])
		if not KINDS.has(String(a["kind"])):
			struct_ok = false
			print("ACH KIND UNKNOWN ", a["id"], " -> ", a["kind"])
		if not DataAchiev.CATS.has(String(a["cat"])):
			struct_ok = false
			print("ACH CAT UNKNOWN ", a["id"])
	check(struct_ok, "每条成就都有名称/描述/分类/判定方式，点数与目标为正")
	var key_ok := true
	for a in DataAchiev.LIST:
		match String(a["kind"]):
			"stat":
				if not STAT_KEYS.has(String(a.get("key", ""))):
					key_ok = false
					print("ACH STAT KEY UNKNOWN ", a["id"], " -> ", a.get("key", ""))
			"kill":
				if not DB.mobs.has(String(a.get("key", ""))):
					key_ok = false
					print("ACH KILL KEY UNKNOWN ", a["id"], " -> ", a.get("key", ""))
			"rep":
				if not DB.rep_factions.has(String(a.get("key", ""))):
					key_ok = false
					print("ACH REP KEY UNKNOWN ", a["id"], " -> ", a.get("key", ""))
			"poi":
				if not String(a.get("key", "")).begins_with("poi_"):
					key_ok = false
					print("ACH POI KEY BAD ", a["id"], " -> ", a.get("key", ""))
			"money":
				if int(a["target"]) < 10000:
					key_ok = false
					print("ACH MONEY TARGET TOO SMALL ", a["id"])
	check(key_ok, "统计键、怪物、阵营、地点 key 都指向真实内容")
	var rw_ok := true
	for a in DataAchiev.LIST:
		var rw: Dictionary = a.get("reward", {})
		for st in rw.get("items", []):
			if DB.get_item(String(st[0])).is_empty() or int(st[1]) < 1:
				rw_ok = false
				print("ACH REWARD ITEM UNKNOWN ", a["id"], " -> ", str(st))
	check(rw_ok, "成就奖励物品都能生成")
	var cap := Achieve.all_points()
	var meta_ok := true
	for a in DataAchiev.LIST:
		if String(a["kind"]) == "points" and int(a["target"]) > cap:
			meta_ok = false
			print("ACH POINTS TARGET UNREACHABLE ", a["id"])
	check(meta_ok and cap >= 250, "点数类成就目标在总点数（%d）之内，元成就可达" % cap)

# ================================================================ 判定与奖励
func core_checks() -> void:
	character("warrior", 1)
	Achieve.check()
	check(Achieve.count_done() == 0 and Achieve.total_points() == 0, "新角色没有已完成成就")
	check(Achieve.visible_entries().size() == DataAchiev.LIST.size() - 2, "隐藏成就未完成前不出现在列表里（%d 条可见）" % Achieve.visible_entries().size())
	# 统计不够时不解锁
	Achieve.bump("kills")
	check(not Achieve.is_done("combat_50") and Achieve.value(by_id("combat_50")) == 1, "击杀 1 次不会解锁「斩杀者」")
	# 达成的瞬间结算：点数 + 金钱 + 物品 + 记录天数
	Game.pd["money"] = 0
	Achieve.bump("kills", 49)
	check(Achieve.is_done("combat_50") and Achieve.total_points() == 5, "击杀 50 次解锁「斩杀者」并计入 5 点")
	check(Game.pd["money"] == 500, "成就奖励的金钱立即到账（+500 铜）")
	check(int(Achieve.done()["combat_50"]) == Achieve.now_day(), "达成记录游戏内天数")
	Achieve.bump("kills", 500)
	check(Achieve.is_done("combat_200") and Achieve.is_done("combat_500"), "一次大批量击杀会连续补上多档成就")
	check(Achieve.count_done() == 3, "已达成数量正确（%d）" % Achieve.count_done())
	# 重复判定不会重复发奖励
	var money0: int = Game.pd["money"]
	Achieve.bump("kills", 200)
	check(Game.pd["money"] == money0, "同一成就不会重复结算奖励")
	# 等级：一次性补发四级
	character("warrior", 20)
	Game.pd["money"] = 0
	Game.pd["bag"].fill(null)
	Achieve.check()
	check(Achieve.is_done("prog_5") and Achieve.is_done("prog_10") and Achieve.is_done("prog_15") and Achieve.is_done("prog_20"), "20 级一次补发四级成长成就")
	check(Game.pd["money"] == 500 + 2000 + 6000 + 20000, "四级成就的金钱奖励合计入账（28500 铜）")
	check(Game.count_item("potion_heal2") == 7, "成就附带的物品也进了背包（2+5 瓶）")
	# 藏起来的那两条：达成后才出现在列表里
	var hidden_before := Achieve.visible_entries().size()
	Achieve.bump("deaths")
	check(Achieve.is_done("combat_death_1") and Achieve.visible_entries().size() == hidden_before + 1, "阵亡成就达成后出现在列表里")
	check(String(by_id("combat_death_1").get("desc", "")) != "", "隐藏成就也有完整描述")
	# 持币峰值：目标是「一次性持有 10 金」，用 1 级角色避开等级成就的奖励干扰
	character("warrior", 1)
	Achieve.check()
	check(not Achieve.is_done("prof_money_10"), "1 级新角色没有触发持币成就")
	Game.add_money(99999)
	Achieve.check()
	check(not Achieve.is_done("prof_money_10") and Achieve.value(by_id("prof_money_10")) == 99999, "差 1 铜不算持有 10 金（进账只记峰值，判定交给定期结算）")
	Game.add_money(1)
	Achieve.check()
	check(Achieve.is_done("prof_money_10"), "持币到 10 金后结算解锁「小有积蓄」")
	Game.add_money(-200000)
	check(Achieve.value(by_id("prof_money_10")) == 100000, "花光钱后峰值仍记录在案（100000 铜）")
	# 技能 / 专业 / 配方 / 天赋
	character("warrior", 20)
	Game.pd["spells"] = {}
	for sid in DB.classes["warrior"]["spells"]:
		Game.pd["spells"][sid] = 1
	Game.pd["prof"] = {"smith": {"skill": 75, "rank": 0}, "cook": {"skill": 10, "rank": 0}}
	Game.pd["recipes"] = {}
	var rid_list := DB.recipes.keys()
	for i in mini(8, rid_list.size()):
		Game.pd["recipes"][rid_list[i]] = true
	Game.pd["talents"] = {}
	var tid := ""
	for t in DB.talent_index:
		tid = t
		break
	Game.pd["talents"][tid] = 3
	Achieve.check()
	check(Achieve.is_done("prog_spells"), "学会 10 个技能解锁「术业有专攻」")
	check(Achieve.is_done("prof_learn_2"), "学会 2 个专业解锁「多面手」")
	check(Achieve.is_done("prog_recipes"), "学会 8 张配方解锁「配方收藏家」")
	check(Achieve.value(by_id("prog_talent")) == 3 and not Achieve.is_done("prog_talent"), "天赋点数按投入量计数（3/5）")
	# 探索：地点数
	character("warrior", 20)
	for i in 50:
		Game.pd["explored"]["poi_test_%d" % i] = true
	Achieve.check()
	check(Achieve.is_done("explore_5") and Achieve.is_done("explore_15") and Achieve.is_done("explore_30") and Achieve.is_done("explore_50"), "发现 50 个地点补上全部探索成就")
	check(not Achieve.is_done("explore_abbey"), "伪造的地点不会误判成具体地点成就")
	# 声望
	character("warrior", 20)
	Rep.gain("city", 500)
	check(Achieve.is_done("rep_first"), "任一阵营友善解锁「第一次被记住」")
	check(not Achieve.is_done("rep_abbey") and not Achieve.is_done("rep_city"), "未达标的阵营成就仍锁着")
	Rep.gain("city", 1000)
	check(Achieve.is_done("rep_city"), "晴岚港尊敬解锁「港口的贵客」")
	check(Achieve.is_done("rep_1500"), "任一势力尊敬再解锁「声名远扬」")
	check(not Achieve.is_done("rep_all_friendly"), "其余四个阵营还是中立，五方通吃未达成")
	for fid in DataRep.factions():
		Rep.gain(fid, 5000)
	check(Achieve.is_done("rep_all_friendly") and Achieve.is_done("rep_5000"), "五阵营崇拜解锁「五方通吃」与「活着的传说」")
	# 元成就：点数达标后连带解锁
	character("warrior", 20)
	var guard := 0
	while Achieve.total_points() < 100 and guard < 40:
		guard += 1
		Achieve.bump("quests", 5)
		Achieve.bump("quests_main", 3)
		Achieve.bump("kills", 50)
	check(Achieve.is_done("meta_100"), "点数跨过 100 后自动解锁「成就猎人」（当前 %d 点）" % Achieve.total_points())
	check(String(by_id("meta_100").get("name", "")) == "成就猎人" and int(Achieve.done()["meta_100"]) >= 0, "元成就的达成记录可用")
	Achieve.bump("quests", 100)
	Achieve.bump("quests_main", 100)
	Achieve.bump("kills", 2000)
	Achieve.bump("elites", 20)
	Achieve.bump("rares", 10)
	Achieve.bump("craft", 100)
	Achieve.bump("gather", 200)
	Achieve.bump("deaths", 20)
	Achieve.bump("auction_sold", 5)
	Achieve.bump("fps", 9)
	Achieve.bump("mails", 20)
	Achieve.check()
	var stats_ok := true
	for id in ["quest_1", "quest_10", "quest_25", "quest_50", "quest_main_5", "quest_main_10", "combat_50", "combat_200",
			"combat_500", "combat_elite_10", "combat_named_5", "combat_death_1", "combat_death_10", "prof_craft_1",
			"prof_craft_10", "prof_craft_50", "prof_gather_25", "prof_gather_100", "prof_auction_1", "explore_fp",
			"prof_mail_10", "meta_250"]:
		if not Achieve.is_done(id):
			stats_ok = false
			print("ACH NOT UNLOCKED ", id)
	check(stats_ok, "所有靠统计累积的条目都能达成（含两条隐藏成就）")
	var locked_ok := true
	for id in ["prog_spells", "prof_learn_1", "explore_5", "rep_first", "combat_boss_1"]:
		if Achieve.is_done(id):
			locked_ok = false
			print("ACH UNEXPECTED UNLOCK ", id, " money=", Game.pd["money"], " pts=", Achieve.total_points())
	check(locked_ok, "没有被统计到的条目（技能/专业/探索/声望/首领）仍然锁着")
	# 持币成就由上面这一串成就奖励本身推过 10 金（109600 铜），顺带验证「奖赏也会计入持币峰值」
	check(Achieve.is_done("prof_money_10") and Achieve.value(by_id("prof_money_10")) >= 100000, "成就要发的钱本身也计入持币峰值（%d 铜）" % Achieve.value(by_id("prof_money_10")))

# ================================================================ 真实玩法链路
func gameplay_checks() -> void:
	# 任务：接受 → 收集 → 交付（真实链路）
	character("warrior", 20)
	var qid := ""
	for q in DB.quests:
		var qd: Dictionary = DB.quests[q]
		var objs: Array = qd.get("obj", [])
		if objs.size() != 1 or objs[0].get("type", "") != "collect":
			continue
		if qd.get("prev") or qd.get("starter_item"):
			continue
		qid = q
		break
	Game.pd["bag"].fill(null)
	Game.accept_quest(qid)
	Game.add_item(str(DB.quests[qid]["obj"][0]["item"]), int(DB.quests[qid]["obj"][0]["n"]), true)
	check(Game.turn_in_quest(qid), "真实交付一个任务（%s）" % qid)
	check(int(Achieve.stats().get("quests", 0)) == 1, "完成 1 个任务后计数为 1")
	check(Achieve.is_done("quest_1"), "解锁「第一次交差」")
	# 击杀：普通 / 精英 / 首领
	character("warrior", 20)
	var before: int = int(Achieve.stats().get("kills", 0))
	Game.on_kill("young_wolf", 2)
	Game.on_kill("young_wolf", 2)
	check(int(Achieve.stats().get("kills", 0)) == before + 2, "击杀普通怪累加计数")
	Game.on_kill("d_gargoyle", 15)
	check(int(Achieve.stats().get("elites", 0)) >= 1, "精英怪单独计数")
	Game.on_kill("boss_rootguard", 15)
	check(int(Achieve.stats().get("bosses", 0)) == 1 and Achieve.is_done("combat_boss_root") and Achieve.is_done("combat_boss_1"), "首领击杀计数并解锁首领成就")
	check(Achieve.is_done("combat_boss_3") == false, "只打掉一个首领时「三面旗帜」仍锁着")
	Game.on_kill("boss_lake", 15)
	Game.on_kill("boss_victor", 16)
	check(Achieve.is_done("combat_boss_3") and Achieve.is_done("combat_boss_victor"), "打满三个首领解锁「三面旗帜」与维克托成就")
	# 制造：真实 finish_craft
	character("warrior", 20)
	var money_before: int = Game.pd["money"]
	Game.pd["prof"] = {"smith": {"skill": 75, "rank": 0}}
	Game.pd["recipes"] = {"sm_bar": true}
	Game.add_item("mat_copper", 4, true)
	check(Prof.finish_craft("sm_bar"), "真实制造 1 件（熔炼铜锭）")
	check(int(Achieve.stats().get("craft", 0)) == 1 and Achieve.is_done("prof_craft_1"), "制造计数 +1 并解锁「第一件作品」")
	check(Game.pd["money"] > money_before, "成就奖励随制造同时入账")
	# 交易所：挂钩成交结算
	character("warrior", 20)
	Game.pd["played"] = 5.0
	Game.pd["ah"] = {"market": [], "gen_at": 0.0, "mine": [{"id": "mat_copper_bar", "n": 1, "price": 1000, "state": "active",
		"start": 1.0, "dur": 100000.0, "sell_at": 1.0}]}
	Auction.tick()
	check(int(Achieve.stats().get("auction_sold", 0)) == 1 and Achieve.is_done("prof_auction_1"), "交易所成交后解锁「第一笔生意」")
	# 邮箱：真实投递
	character("warrior", 20)
	for i in 10:
		Mail.deliver("系统测试", "测试信 %d" % i, "正文", [], 0, "", true)
	check(int(Achieve.stats().get("mails", 0)) >= 10 and Achieve.is_done("prof_mail_10"), "收到 10 封信解锁「信箱常客」")
	# 飞行点：真实发现链路
	character("warrior", 20)
	var fids := DB.flight_paths.keys()
	for i in mini(4, fids.size()):
		Game.discover_fp(String(fids[i]))
	check(int(Achieve.stats().get("fps", 0)) == mini(4, fids.size()) and Achieve.is_done("explore_fp"), "发现 4 个飞行点解锁「飞行常客」")
# ================================================================ 世界里的真实链路与界面
## 只进一次世界：阵亡、采集、地点发现、窗口。多次 change_scene 会在换场时踩到旧引用。
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")

func world_checks() -> void:
	character("warrior", 20)
	Game.pd["money"] = 30000
	await enter_world()
	# 阵亡：玩家真实死亡路径
	p._on_death(null)
	await wait(0.3)
	check(int(Achieve.stats().get("deaths", 0)) == 1 and Achieve.is_done("combat_death_1"), "玩家阵亡后解锁隐藏成就「第一次阵亡」")
	# 采集：真实采集节点
	var node: GatherNode = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is GatherNode:
			node = n
			break
	check(node != null, "场景里找到可采集节点")
	if node != null:
		var g0: int = int(Achieve.stats().get("gather", 0))
		node._complete(p)
		await wait(0.2)
		check(int(Achieve.stats().get("gather", 0)) == g0 + 1, "采集一次后计数 +1")
	check(Game.keybinds.get("achiev", 0) == KEY_Y, "Y 键绑定到成就")
	Achieve.check()
	var d := Achieve.data()
	check(d.has("done") and d.has("stats") and d.has("pts"), "成就存档结构在首次判定时自动建立（老存档兼容）")
	check(int(d["pts"]) == Achieve.total_points(), "累计点数与存档字段一致（%d）" % int(d["pts"]))
	# 真实发现：走到修道院 POI
	var poi: POI = null
	for n in get_tree().get_nodes_in_group("poi"):
		if n.poi_id == "poi_abbey":
			poi = n
			break
	check(poi != null, "场景里找到晨钟修道院兴趣点")
	if poi != null:
		var spot: Vector3 = poi.global_position
		p.global_position = Vector3(spot.x, U.ground_height(get_tree(), spot.x, spot.z, spot.y) + 0.1, spot.z)
		await wait(0.8)
		check(Game.pd["explored"].has("poi_abbey"), "走到修道院后地点进入已探索列表")
		check(Achieve.is_done("explore_abbey"), "真实发现修道院解锁「晨钟之下」")
	# 窗口
	Game.hud.open_window("achiev")
	await wait(0.5)
	var w = Game.hud.win["achiev"]
	check(w.visible, "成就窗口可以打开")
	check(w.cat_box.get_child_count() == 1 + DataAchiev.CATS.size(), "左侧有「全部」加 6 个分类（%d 行）" % w.cat_box.get_child_count())
	check(w.list_box.get_child_count() == Achieve.visible_entries().size(), "「全部」页签列出所有可见条目（%d 条）" % w.list_box.get_child_count())
	check(w.head.text.contains("成就点数"), "顶部显示成就点数与完成度")
	await shot("achiev_all")
	# 切到「探索」分类
	var clicked := false
	for c in w.cat_box.get_children():
		if c is Button and c.text.begins_with("探索"):
			c.pressed.emit()
			clicked = true
			break
	check(clicked, "可以点开「探索」分类")
	await wait(0.4)
	check(w.list_box.get_child_count() == DataAchiev.by_cat("explore").size(), "分类页只列出该类条目（%d 条）" % w.list_box.get_child_count())
	check(w.cat_box.get_child_count() == 1 + DataAchiev.CATS.size(), "窗口在分类切换后仍完整")
	await shot("achiev_explore")
	Game.hud.close_all()
	await wait(0.3)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	data_checks()
	core_checks()
	gameplay_checks()
	if not "core" in OS.get_cmdline_user_args():
		await world_checks()
	var failures := checks.filter(func(c): return not c["pass"]).size()
	FileAccess.open(out + "/results.json", FileAccess.WRITE).store_string(JSON.stringify(checks, "\t"))
	print("ACHIEV RESULT %d PASS / %d FAIL" % [checks.size() - failures, failures])
	Game.slot_index = -1
	get_tree().quit(1 if failures else 0)
