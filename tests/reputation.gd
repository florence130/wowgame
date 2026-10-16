extends Node
## 声望阵营验证：数据完整性、等级与进度、任务/击杀来源、军需官门槛与折扣、角色面板声望条、真实 NPC 路径。
## 不写存档（slot = -1）。
var checks: Array = []
var out := "res://.local/rep_20261008"
var root3d: Node3D
var p: Player

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
	print(("REP PASS " if ok else "REP FAIL ") + label)

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func character(cls: String, level: int = 20) -> void:
	Game.slot_index = -1
	Game.new_character("声望验证", cls, DB.random_appearance(11, "m"))
	Game.pd["new"] = false
	Game.pd["level"] = level

# ================================================================ 数据
func data_checks() -> void:
	var facs: Dictionary = DataRep.factions()
	check(facs.size() == 5, "共 5 个阵营（实际 %d）" % facs.size())
	var struct_ok := true
	var qm_ok := true
	var fams := {}
	for mid in DB.mobs:
		fams[str(DB.mobs[mid].get("fam", ""))] = true
	for fid in facs:
		var f: Dictionary = facs[fid]
		for k in ["name", "color", "desc", "qm", "qm_name", "npcs", "fams"]:
			if not f.has(k):
				struct_ok = false
				print("REP FIELD MISSING ", fid, " -> ", k)
		var qm: String = str(f.get("qm", ""))
		if not DB.npcs.has(qm):
			qm_ok = false
			print("REP QM UNKNOWN ", fid, " -> ", qm)
		if not f["npcs"].has(qm):
			qm_ok = false
			print("REP QM NOT MEMBER ", fid, " -> ", qm)
		if DB.vendors.get("qm_" + fid, []).is_empty():
			qm_ok = false
			print("REP QM VENDOR MISSING ", fid)
		for fam in f["fams"]:
			if not fams.has(fam):
				struct_ok = false
				print("REP FAM UNKNOWN ", fid, " -> ", fam)
	check(struct_ok, "每个阵营都有名称/描述/颜色/军需官/成员/怪物家族，且家族都存在")
	check(qm_ok, "军需官都是真实 NPC、属于本阵营，并有对应货单")
	var npc_ok := true
	var seen := {}
	for fid in facs:
		for nid in facs[fid]["npcs"]:
			if not DB.npcs.has(nid):
				npc_ok = false
				print("REP NPC UNKNOWN ", nid)
			if seen.has(nid):
				npc_ok = false
				print("REP NPC DUPLICATE ", nid)
			seen[nid] = fid
			if DB.npc_faction.get(nid, "") != fid:
				npc_ok = false
				print("REP NPC INDEX MISSING ", nid)
	check(npc_ok, "成员 NPC 都存在、不重复，且已建立索引")
	var tiers_ok := true
	for i in DataRep.TIERS.size():
		if i > 0 and int(DataRep.TIERS[i][1]) <= int(DataRep.TIERS[i - 1][1]):
			tiers_ok = false
	check(DataRep.TIERS.size() == 5 and tiers_ok and DataRep.floor_points(0) == 0, "五级声望门槛递增（0/500/1500/3000/5000）")
	var items_ok := true
	var gated := 0
	for fid in facs:
		for e in DB.vendors.get("qm_" + fid, []):
			var ed: Dictionary = Rep.entry(e)
			if DB.get_item(ed["id"]).is_empty():
				items_ok = false
				print("REP ITEM UNKNOWN ", fid, " -> ", ed["id"])
			if ed.has("rep"):
				gated += 1
				var r: Array = ed["rep"]
				if not facs.has(str(r[0])) or int(r[1]) < 1 or int(r[1]) >= DataRep.TIERS.size():
					items_ok = false
					print("REP GATE INVALID ", fid, " -> ", str(r))
	check(items_ok, "军需品都能生成物品，门槛阵营与等级合法")
	# 16 件装备/消耗品 + 2 件坐骑（晨露白鹿 · 修道院崇敬 / 灰巾座狼 · 公会崇敬）
	check(gated == 18, "共有 18 件声望等级解锁的军需品（实际 %d）" % gated)
	check(DB.fam_faction.get("bandit", "") == "city" and DB.fam_faction.get("ratman", "") == "goldshire", "怪物家族已挂靠阵营（灰巾帮→晴岚港、鼠人→金穗镇）")

# ================================================================ 等级与进度
func tier_checks() -> void:
	character("warrior", 20)
	check(Rep.tier("city") == 0 and Rep.tier_name("city") == "中立", "未接触过的阵营是中立")
	Rep.gain("city", 499)
	check(Rep.tier("city") == 0, "499 点仍是中立")
	Rep.gain("city", 1)
	check(Rep.tier("city") == 1 and Rep.tier_name("city") == "友善", "500 点升为友善")
	Rep.gain("city", 300)
	var pr := Rep.progress("city")
	check(int(pr.x) == 300 and int(pr.y) == 1000 and is_equal_approx(Rep.ratio("city"), 0.3), "友善区间进度按 300/1000 计算")
	Rep.gain("city", 700)
	check(Rep.tier("city") == 2, "1500 点升为尊敬")
	Rep.gain("city", 999999)
	check(Rep.points("city") == DataRep.MAX_POINTS and Rep.tier("city") == 4, "声望上限 5000（崇拜）")
	check(Rep.at_least("city", 4) and not Rep.at_least("abbey", 1), "等级比较可用")

# ================================================================ 来源：任务与击杀
func source_checks() -> void:
	character("warrior", 20)
	check(Rep.quest_gain({"lvl": 10, "w": 1.0}) == 120, "任务声望 = (40 + 8×等级) × 权重")
	check(Rep.quest_gain({"lvl": 15, "w": 2.2}) == 352, "高权重任务给更多声望")
	check(Rep.kill_gain(DB.mobs["rabbit"], 1) == 0, "小动物不给声望")
	check(Rep.kill_gain(DB.mobs["bandit_thug_s"], 5) == 3, "普通怪物按等级给声望（5 级 → 3）")
	var named: int = Rep.kill_gain(DB.mobs["garrok"], 6)
	check(named >= 10, "命名怪给 3 倍声望（%d）" % named)
	var boss: int = Rep.kill_gain(DB.mobs["boss_victor"], 16)
	check(boss >= 45, "首领给 5 倍声望（%d）" % boss)
	Game.on_kill("bandit_thug_s", 4)
	check(Rep.points("city") == 2, "击杀灰巾帮给晴岚港声望")
	Game.on_kill("rabbit", 1)
	check(Rep.points("city") == 2, "击杀小动物不改变声望")
	Game.on_kill("boss_victor", 16)
	check(Rep.points("city") == 402, "击杀副本首领按显式归属给出声望（+400）")
	Game.on_kill("boss_rootguard", 15)
	check(Rep.points("abbey") == 300, "树妖首领给晨钟修道院声望")
	# 真实任务链路：接受 → 收集 → 交付，检查交付 NPC 阵营的声望
	var qid := ""
	for q in DB.quests:
		var qd: Dictionary = DB.quests[q]
		var objs: Array = qd.get("obj", [])
		if objs.size() != 1 or objs[0].get("type", "") != "collect":
			continue
		if Rep.faction_of_npc(str(qd.get("turnin", ""))) == "":
			continue
		if qd.has("prev") or qd.has("starter_item"):
			continue
		qid = q
		break
	check(qid != "", "找到一条可自动完成的收集任务用于验证（%s）" % qid)
	if qid != "":
		var q: Dictionary = DB.quests[qid]
		var fid := Rep.faction_of_npc(str(q["turnin"]))
		var before := Rep.points(fid)
		var obj: Dictionary = q["obj"][0]
		Game.pd["bag"].fill(null)
		Game.accept_quest(qid)
		Game.add_item(str(obj["item"]), int(obj["n"]), true)
		check(Game.is_quest_complete(qid), "任务条件满足（%s）" % str(obj["item"]))
		check(Game.turn_in_quest(qid), "任务交付成功")
		check(Rep.points(fid) == before + Rep.quest_gain(q), "交付任务给 %s 声望 +%d" % [Rep.faction_name(fid), Rep.quest_gain(q)])

# ================================================================ 门槛与折扣
func gate_checks() -> void:
	character("warrior", 20)
	var e1 := {"id": "gen|back|cloth|blue|15|owl", "rep": ["city", 1]}
	var e4 := {"id": "gen|sword2|purple|20|tiger", "rep": ["city", 4]}
	check(Rep.entry_ok(e1) == false, "中立时看不到友善军需品")
	check(Rep.entry_line(e4) == "需要：晴岚港 · 崇拜", "门槛文案正确（%s）" % Rep.entry_line(e4))
	Rep.gain("city", 500)
	check(Rep.entry_ok(e1) and not Rep.entry_ok(e4), "友善后解锁友善档，但崇拜档仍锁着")
	check(is_equal_approx(Rep.discount_for_npc("harbor_master"), 0.05), "晴岚港友善 → 港务军需处 5% 折扣")
	check(is_equal_approx(Rep.discount_for_npc("duke"), 0.0), "未接触金穗镇时没有折扣")
	Rep.gain("goldshire", 3000)
	check(is_equal_approx(Rep.discount_for_npc("duke"), 0.15), "金穗镇崇敬 → 治安官 15% 折扣")
	check(is_equal_approx(Rep.discount_for_npc("nobody"), 0.0), "不属于任何阵营的 NPC 没有折扣")
	check(Rep.faction_of_npc("harbor_master") == "city" and Rep.faction_of_npc("bob") == "goldshire", "NPC 阵营归属正确")

# ================================================================ UI
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")

func ui_checks() -> void:
	character("warrior", 20)
	Game.pd["money"] = 200000
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):
		await get_tree().process_frame
	p = Game.player
	Game.time_of_day = 12
	await wait(1.0)
	# 角色面板里的声望条
	Game.hud.open_window("char")
	await wait(0.5)
	var cw = Game.hud.win["char"]
	check(cw.rep_box.get_child_count() == 1 + DataRep.factions().size() * 3, "角色面板给出每个阵营一行的声望条（%d 行）" % cw.rep_box.get_child_count())
	Rep.gain("abbey", 1800)
	await wait(0.4)
	check(cw.rep_box.get_child_count() == 1 + DataRep.factions().size() * 3, "声望变化后声望条重建")
	await shot("rep_panel")
	Game.hud.close_all()
	await wait(0.3)
	# 军需官：真实 NPC（修道院军需官汤姆）
	var qm_npc: Node = null
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.npc_id == "tom":
			qm_npc = n
			break
	check(qm_npc != null, "找到修道院军需官汤姆")
	if qm_npc != null:
		var spot: Vector3 = qm_npc.global_position + Vector3(1.6, 0.4, 0)
		p.global_position = spot + Vector3(0, U.ground_height(get_tree(), spot.x, spot.z, spot.y) + 0.1 - spot.y, 0)
		await wait(0.5)
		Game.hud.open_npc(qm_npc)
		await wait(0.4)
		var npcw = Game.hud.win["npc"]
		var has_qm := false
		for c in npcw.content.get_children():
			if c is Button and c.text.contains("军需品"):
				has_qm = true
				c.pressed.emit()
				break
		check(has_qm, "军需官对话里有军需品入口")
		await wait(0.5)
		var list: Array = npcw._vendor_list()
		check(npcw._qm == "abbey" and list.size() == 6, "军需品货单为 qm_abbey（%d 件，含晨露白鹿）" % list.size())
		await shot("rep_quartermaster")
		# 门槛未达：第 2 件需要尊敬（此时崇敬，已解锁）
		Rep.gain("abbey", 5000)
		npcw._render()
		await wait(0.3)
		var money0: int = Game.pd["money"]
		var gated_id: String = Rep.entry_id(list[2])
		var price: int = npcw._price(gated_id)
		npcw._buy(2)
		await wait(0.3)
		check(Game.pd["money"] == money0 - price and Game.count_item(gated_id) == 1, "声望达到崇敬以上后可以买下崇敬档军需品（%s，%s）" % [DB.get_item(gated_id).get("name", gated_id), U.money_text(price)])
		check(price < DB.get_item(gated_id).get("price", 1) * 4, "声望折扣已作用于军需品价格（原价 %s → %s）" % [U.money_text(DB.get_item(gated_id).get("price", 1) * 4), U.money_text(price)])
		# 门槛不足：把声望降回中立后不能购买
		Game.pd["rep"]["abbey"] = 0
		Game.rep_changed.emit()
		npcw._render()
		await wait(0.3)
		var money1: int = Game.pd["money"]
		npcw._buy(1)
		await wait(0.3)
		check(Game.pd["money"] == money1, "声望不足时买不到军需品")
		await shot("rep_blocked")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	data_checks()
	tier_checks()
	source_checks()
	gate_checks()
	if not "core" in OS.get_cmdline_user_args():
		await ui_checks()
	var failures := checks.filter(func(c): return not c["pass"]).size()
	FileAccess.open(out + "/results.json", FileAccess.WRITE).store_string(JSON.stringify(checks, "\t"))
	print("REP RESULT %d PASS / %d FAIL" % [checks.size() - failures, failures])
	Game.slot_index = -1
	get_tree().quit(1 if failures else 0)
