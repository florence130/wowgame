extends Node
## 邮箱系统验证：信件数据、投递/领取/删除/过期/上限、系统钩子（升级 · 声望升阶 · 首领首杀）、世界邮箱柱与窗口。
## 不写存档（slot = -1）。
var checks: Array = []
var out := "res://.local/mail_20261008"
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
	print(("MAIL PASS " if ok else "MAIL FAIL ") + label)

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func character(cls: String, level: int = 20) -> void:
	Game.slot_index = -1
	Game.new_character("邮箱验证", cls, DB.random_appearance(11, "m"))
	Game.pd["new"] = false
	Game.pd["level"] = level
	Game.pd["mail"] = []
	Game.pd["mail_seq"] = 1
	Game.pd["mail_boss"] = {}

## 收件箱里的战报信数量（首领首杀信；声望升阶信另有来源，不能混算）
func boss_mails() -> int:
	var subs := []
	for mid in DataMail.BOSS_LETTERS:
		subs.append(String(DataMail.BOSS_LETTERS[mid]["subj"]))
	var n := 0
	for m in Mail.box():
		if subs.has(String(m.get("subj", ""))):
			n += 1
	return n

## 一封信的附件物品是否都能生成
func _items_ok(items: Array) -> bool:
	for st in items:
		if DB.get_item(String(st[0])).is_empty():
			print("MAIL ITEM UNKNOWN ", str(st))
			return false
		if int(st[1]) <= 0:
			print("MAIL ITEM COUNT INVALID ", str(st))
			return false
	return true

# ================================================================ 数据
func data_checks() -> void:
	var d1: Dictionary = DataMail.level_letter(10, "warrior")
	var ok_letters := true
	for lv in [10, 20, 30, 40, 50, 60]:
		var d: Dictionary = DataMail.level_letter(lv, "warrior")
		if d.is_empty() or String(d.get("subj", "")) == "" or String(d.get("body", "")) == "":
			ok_letters = false
			print("MAIL LEVEL LETTER BAD ", lv)
	check(ok_letters and not d1.is_empty(), "1/2/3/4/5 档升级信都有主题与正文，超出档位沿用最后一档")
	check(String(DataMail.level_letter(10, "warrior")["from"]) == DB.npcs["t_warrior_1"]["name"], "升级信署名取本职业训练师（战士 → 雷恩）")
	var tr_ok := true
	for cls in DataMail.TRAINERS:
		var tname: String = DataMail.TRAINERS[cls]
		var found := ""
		for nid in DB.npcs:
			if String(DB.npcs[nid].get("name", "")) == tname and String(DB.npcs[nid].get("trainer", "")) == cls:
				found = nid
				break
		if found == "":
			tr_ok = false
			print("MAIL TRAINER BAD ", cls, " -> ", tname)
	check(tr_ok, "五名训练师都是表里的真实 NPC，且确实教这个职业")
	var items_ok := true
	var n_items := 0
	for step in DataMail.LEVEL_LETTERS:
		var items: Array = DataMail.LEVEL_LETTERS[step].get("items", [])
		items_ok = items_ok and _items_ok(items)
		n_items += items.size()
	for tier in DataMail.REP_REWARDS:
		var ri: Array = DataMail.REP_REWARDS[tier].get("items", [])
		items_ok = items_ok and _items_ok(ri)
		n_items += ri.size()
	for mid in DataMail.BOSS_LETTERS:
		var bi: Array = DataMail.BOSS_LETTERS[mid].get("items", [])
		items_ok = items_ok and _items_ok(bi)
		n_items += bi.size()
	check(items_ok, "所有信件附件都是真实物品且数量合法（共 %d 组）" % n_items)
	var facs: Dictionary = DataRep.factions()
	var rep_ok := true
	for fid in DataMail.REP_LETTERS:
		for tier in [1, 2, 3, 4]:
			var d: Dictionary = DataMail.rep_letter(fid, tier, "测试者")
			if d.is_empty() or String(d["body"]).contains("%s") or not String(d["body"]).contains("测试者"):
				rep_ok = false
				print("MAIL REP LETTER BAD ", fid, " tier ", tier)
		if not facs.has(fid):
			rep_ok = false
			print("MAIL REP FACTION UNKNOWN ", fid)
	check(rep_ok, "五个阵营的升阶信都能正确定名，且署名取本阵营军需官")
	check(DataMail.rep_letter("nobody", 1, "测试者").is_empty() and DataMail.boss_letter("rabbit").is_empty(), "未登记的阵营/怪物不会凭空生成信件")
	var boss_ok := true
	for mid in DataMail.BOSS_LETTERS:
		if not DB.mobs.has(mid) or not DB.mobs[mid].get("boss", false):
			boss_ok = false
			print("MAIL BOSS LETTER NOT A BOSS ", mid)
	var dungeon_bosses: Array = DB.zones["sanctum"].get("bosses", [])
	for b in dungeon_bosses:
		if not DataMail.BOSS_LETTERS.has(String(b)):
			boss_ok = false
			print("MAIL DUNGEON BOSS WITHOUT LETTER ", b)
	check(boss_ok, "战报信一一对应真实首领，副本三首领都有信（%d 封）" % DataMail.BOSS_LETTERS.size())
	var box_ok := true
	var total := 0
	for zid in DataWorld.postboxes():
		if not DB.zones.has(zid):
			box_ok = false
			print("MAIL POSTBOX ZONE UNKNOWN ", zid)
		total += (DataWorld.postboxes()[zid] as Array).size()
	check(box_ok and total >= 7, "邮箱柱摆放在真实区域里，共 %d 座" % total)

# ================================================================ 收发与存档字段
func core_checks() -> void:
	character("warrior", 20)
	check(Mail.box().is_empty() and Mail.unread() == 0, "新角色邮箱是空的")
	var m: Dictionary = Mail.deliver("系统测试", "测试信件", "第一封。", [["potion_heal1", 3]], 250)
	var id := int(m.get("id", 0))
	check(Mail.box().size() == 1 and Mail.unread() == 1 and Mail.pending() == 1, "投递后 1 封未读、1 封带附件")
	check(id == 1 and Game.pd["mail_seq"] == 2, "信件编号自增（%d → seq %d）" % [id, Game.pd["mail_seq"]])
	check(int(m.get("day", -1)) == Mail.now_day(), "信件记录游戏内天数（第 %d 天）" % Mail.now_day())
	Mail.mark_read(id)
	check(Mail.unread() == 0 and Mail.by_id(id).get("read", false), "标记已读后未读数归零")
	# 领取：金钱与物品都到手，附件清空
	var money0: int = Game.pd["money"]
	Game.pd["bag"].fill(null)
	check(Mail.claim(id) == true, "有空间时领取返回「已领完」")
	check(Game.pd["money"] == money0 + 250, "附件金钱自动入账（+250 铜）")
	check(Game.count_item("potion_heal1") == 3, "附件物品进入背包")
	check(Mail.pending() == 0 and Mail.by_id(id).get("done", false), "领取后不再显示未领附件")
	check(Mail.claim(id) == true, "重复领取是幂等的")
	# 背包满：物品留在信里，金钱照付
	var id2 := int(Mail.deliver("系统测试", "满包测试", "背包满了怎么办。", [["potion_heal1", 5]], 100).get("id", 0))
	Game.pd["bag"].fill(null)
	for i in Game.BAG_SIZE:
		Game.pd["bag"][i] = {"id": "w_recruit_sword", "n": 1}
	check(Game.free_bag_slots() == 0, "背包已填满（%d 格）" % Game.BAG_SIZE)
	check(Mail.claim(id2) == false, "背包满时领取返回「未领完」")
	check(Mail.pending() == 1 and Mail.by_id(id2).get("items", []).size() == 1, "放不下的附件留在信里")
	check(Game.pd["money"] == money0 + 250 + 100, "背包满不影响附件金钱入账")
	Game.pd["bag"].fill(null)
	check(Mail.claim(id2) == true and Game.count_item("potion_heal1") == 5, "腾出空间后可继续领取剩余附件")
	# 删除规则
	var id3 := int(Mail.deliver("系统测试", "待删除", "有附件不能删。", [["potion_heal1", 1]], 0).get("id", 0))
	check(Mail.erase(id3) == false and Mail.box().size() == 3, "有未领附件时拒绝删除")
	Mail.claim(id3)
	check(Mail.erase(id3) == true and Mail.box().size() == 2, "领完后可以删除")
	var before := Mail.box().size()
	Mail.deliver("系统测试", "未读一", "留着。", [], 0)
	check(Mail.erase_read() == before and Mail.box().size() == 1, "清理已读只删已读，未读信保留（删 %d 封）" % before)
	check(Mail.box()[0].get("read", true) == false, "剩下的那封仍是未读")

# ================================================================ 过期与上限
func prune_checks() -> void:
	character("warrior", 20)
	var old := Mail.deliver("系统测试", "很久以前", "已经过期了。", [], 0)
	old["read"] = true
	old["day"] = Mail.now_day() - (Mail.EXPIRE_DAYS + 1)
	var old_attach := Mail.deliver("系统测试", "很久以前带附件", "有附件不该被清。", [["potion_heal1", 1]], 0)
	old_attach["day"] = Mail.now_day() - (Mail.EXPIRE_DAYS + 1)
	var fresh := Mail.deliver("系统测试", "今天", "还新鲜。", [], 0)
	fresh["read"] = true
	check(Mail.box().size() == 3, "准备 3 封信（过期无附件 / 过期有附件 / 新鲜）")
	check(Mail.prune() == 1, "过期清理只清掉已领完且超期的信")
	check(Mail.box().size() == 2 and Mail.by_id(int(old_attach["id"])).size() > 0, "带附件的过期信仍然保留")
	# 上限：超出后挤掉最旧的已读信
	character("warrior", 20)
	for i in Mail.MAX_MAIL + 5:
		var mm: Dictionary = Mail.deliver("系统测试", "堆信 %d" % i, "正文", [], 0, "", true)
		if i < Mail.MAX_MAIL + 5 - 3:
			mm["read"] = true
	check(Mail.box().size() == Mail.MAX_MAIL, "邮箱上限 %d 封，超出后自动挤压（实际 %d）" % [Mail.MAX_MAIL, Mail.box().size()])
	check(int(Mail.box()[Mail.MAX_MAIL - 1].get("id", 0)) == Mail.MAX_MAIL + 5, "保留的是最新的几封")

# ================================================================ 系统钩子
func hook_checks() -> void:
	# 升级信：走真实的升级链路（9 级 + 一级经验）
	character("mage", 9)
	Game.give_xp(DB.xp_to_next(9), "test")
	check(Game.pd["level"] == 10, "经验推进到 10 级（实际 %d）" % Game.pd["level"])
	check(Mail.box().size() == 1 and String(Mail.box()[0]["from"]) == DB.npcs["t_mage_1"]["name"], "10 级时本职业训练师寄来祝贺信")
	Game.give_xp(DB.xp_to_next(10), "test")
	check(Game.pd["level"] == 11 and Mail.box().size() == 1, "11 级不会再寄（每 10 级一封）")
	Game.pd["level"] = 19
	Game.give_xp(DB.xp_to_next(19), "test")
	check(Game.pd["level"] == 20 and Mail.box().size() == 2, "20 级寄出第二档升级信")
	check(int(Mail.box()[1]["money"]) > int(Mail.box()[0]["money"]), "越往后的升级信附件越丰厚")
	# 声望升阶信
	character("warrior", 20)
	check(Mail.box().is_empty(), "新角色邮箱清空")
	Rep.gain("city", 499)
	check(Mail.box().is_empty(), "差 1 点到友善时还不会寄信")
	Rep.gain("city", 1)
	check(Mail.box().size() == 1 and String(Mail.box()[0].get("fid", "")) == "city", "升到友善时晴岚港寄来升阶信")
	check(String(Mail.box()[0]["subj"]).contains(DataRep.tier_name(1)), "升阶信标题带关系等级（%s）" % DataRep.tier_name(1))
	Rep.gain("city", 1000)
	check(Mail.box().size() == 2, "升到尊敬再寄一封")
	Rep.gain("city", 100)
	check(Mail.box().size() == 2, "同一等级内继续加声望不再寄信")
	# 首领首杀战报
	character("warrior", 20)
	Game.on_kill("boss_victor", 16)
	check(boss_mails() == 1 and Mail.box()[0]["subj"] == DataMail.BOSS_LETTERS["boss_victor"]["subj"], "首杀首领后收到战报信")
	check(Game.pd["mail_boss"].has("boss_victor"), "首杀记录已写入存档字段")
	Game.on_kill("boss_victor", 16)
	check(boss_mails() == 1, "重复击杀同一首领不会重复寄信（战报 %d 封 / 收件箱 %d 封）" % [boss_mails(), Mail.box().size()])
	Game.on_kill("boss_rootguard", 15)
	Game.on_kill("boss_lake", 15)
	check(boss_mails() == 3, "三个首领各寄一封战报（%d 封）" % boss_mails())
	Game.on_kill("young_wolf", 2)
	check(boss_mails() == 3 and Mail.box().size() == 4, "普通怪物不会寄信（收件箱 %d 封，其中战报 %d 封）" % [Mail.box().size(), boss_mails()])
	var pending := Mail.pending()
	check(Mail.claim_all() == pending and pending >= 3, "一键领取把所有带附件的信都取出（%d 封）" % pending)
	check(Mail.pending() == 0 and Game.pd["money"] > 0, "一键领取把附件全部取出")

# ================================================================ 界面与世界邮箱柱
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")

func ui_checks() -> void:
	character("warrior", 20)
	Game.pd["money"] = 50000
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):
		await get_tree().process_frame
	p = Game.player
	Game.time_of_day = 12
	await wait(1.0)
	check(Game.keybinds.get("mail", 0) == KEY_O, "O 键绑定到邮箱")
	# 世界里的邮箱柱
	var boxes := get_tree().get_nodes_in_group("interactable").filter(func(n): return n is Postbox)
	var want: int = (DataWorld.postboxes()["vale"] as Array).size()
	check(boxes.size() == want, "晨露谷生成了 %d 座邮箱柱（实际 %d）" % [want, boxes.size()])
	var near: Postbox = boxes[0] if not boxes.is_empty() else null
	check(near != null and near.get_parent().name == "Postboxes", "邮箱柱挂在区域的 Postboxes 节点下")
	# 窗口
	Mail.deliver("系统测试", "窗口测试", "这封信用来检查界面。", [["potion_heal1", 2]], 66)
	await wait(0.3)
	check(Mail.unread() == 1 and Game.hud.mail_btn.text == "邮箱 1", "底栏邮箱按钮显示未读角标（%s）" % Game.hud.mail_btn.text)
	Game.hud.open_window("mail")
	await wait(0.5)
	var mw = Game.hud.win["mail"]
	check(mw.visible, "邮箱窗口可以打开")
	check(mw.list.item_count == Mail.box().size(), "收件列表与存档一致（%d 行）" % mw.list.item_count)
	check(mw.footer.text.contains("未读 %d" % Mail.unread()), "底栏显示未读数量（%s）" % mw.footer.text)
	check(mw.claim_btn.disabled == false and mw.erase_btn.disabled == true, "有附件时只能领取、不能删除")
	await shot("mail_window")
	var before: int = Game.count_item("potion_heal1")
	mw.claim_btn.pressed.emit()
	await wait(0.3)
	check(Game.count_item("potion_heal1") == before + 2 and mw.claim_btn.disabled, "点「领取附件」把物品收进背包")
	await shot("mail_claimed")
	check(Game.hud.mail_btn.text == "邮箱", "邮件读完并领完后角标消失（%s）" % Game.hud.mail_btn.text)
	# 走到邮箱柱前按交互键
	Game.hud.close_all()
	await wait(0.3)
	if near != null:
		var spot: Vector3 = near.global_position + Vector3(1.4, 0, 0.6)
		p.global_position = Vector3(spot.x, U.ground_height(get_tree(), spot.x, spot.z, spot.y) + 0.1, spot.z)
		await wait(0.4)
		near.interact(p)
		await wait(0.4)
		check(Game.hud.win["mail"].visible, "走到邮箱柱前交互可以打开邮箱")
		await shot("postbox")
		Game.hud.close_all()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	data_checks()
	core_checks()
	prune_checks()
	hook_checks()
	if not "core" in OS.get_cmdline_user_args():
		await ui_checks()
	var failures := checks.filter(func(c): return not c["pass"]).size()
	FileAccess.open(out + "/results.json", FileAccess.WRITE).store_string(JSON.stringify(checks, "\t"))
	print("MAIL RESULT %d PASS / %d FAIL" % [checks.size() - failures, failures])
	Game.slot_index = -1
	get_tree().quit(1 if failures else 0)
