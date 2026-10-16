extends Node
## 坐骑系统验证：坐骑表完整性、骑术门槛、物品学习、召唤/收起与速度、收藏成就、收藏窗口。
## 不写存档（slot = -1）。
var checks: Array = []
var out := "res://.local/mounts_20261008"
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
	print(("MOUNT PASS " if ok else "MOUNT FAIL ") + label)

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func character(cls: String, level: int = 20) -> void:
	Game.slot_index = -1
	Game.new_character("坐骑验证", cls, DB.random_appearance(11, "m"))
	Game.pd["new"] = false
	Game.pd["level"] = level
	Game.pd["money"] = 200000
	Game.pd["achiev"] = {}

# ================================================================ 数据
func data_checks() -> void:
	check(DataMounts.ids().size() == 5, "共 5 个坐骑（%s）" % ", ".join(DataMounts.ids()))
	var field_ok := true
	var spell_ok := true
	var item_ok := true
	var speed_ok := true
	for id in DataMounts.ids():
		var md := DataMounts.get_mount(String(id))
		for k in ["name", "model", "color", "color2", "speed", "spell", "item", "q", "src", "desc"]:
			if not md.has(k):
				field_ok = false
				print("MOUNT FIELD MISSING ", id, " -> ", k)
		var sp: String = String(md["spell"])
		if not DB.spells.has(sp):
			spell_ok = false
			print("MOUNT SPELL UNKNOWN ", id, " -> ", sp)
		else:
			var effs: Array = DB.spells[sp].get("effects", [])
			if effs.is_empty() or effs[0].get("type", "") != "mount" or DataMounts.from_effect(effs[0]) != id:
				spell_ok = false
				print("MOUNT SPELL EFFECT BAD ", id, " -> ", str(effs))
			if String(DB.spells[sp].get("name", "")) != String(md["name"]):
				spell_ok = false
				print("MOUNT SPELL NAME MISMATCH ", id)
		var it := DB.get_item(String(md["item"]))
		if it.is_empty() or it.get("use", {}).get("learn", "") != sp:
			item_ok = false
			print("MOUNT ITEM BAD ", id, " -> ", String(md["item"]))
		var spd: float = float(md["speed"])
		if spd < 0.5 or spd > 1.2:
			speed_ok = false
			print("MOUNT SPEED OUT OF RANGE ", id, " -> ", spd)
	check(field_ok, "每个坐骑都有名称/模型/配色/速度/来源/描述/品质")
	check(spell_ok, "召唤技能都存在、名称一致、效果指向本坐骑（含旧 model 写法兼容）")
	check(item_ok, "学习物品都存在且 use.learn 指向对应技能")
	check(speed_ok, "速度加成在 50%–120% 之间")
	check(DataMounts.speed_text("horse") == "+60%" and DataMounts.speed_text("bear") == "+90%", "速度文案按表生成（骏马 +60% / 战熊 +90%）")
	check(DataMounts.by_spell("mount_wolf") == "wolf" and DataMounts.by_spell("nope") == "", "技能反查坐骑 id 可用")
	# 获取途径：至少一条商人在卖、两条声望军需、一条成就奖励
	check(DB.vendors.get("stable", []).has("mount_horse_item"), "马厩商人出售高地骏马")
	var deer_gate := false
	for e in DB.vendors.get("qm_abbey", []):
		if e is Dictionary and String(e.get("id", "")) == "mount_deer_item":
			deer_gate = (e["rep"][0] == "abbey" and int(e["rep"][1]) == 3)
	check(deer_gate, "晨露白鹿是修道院崇敬档军需品")
	var wolf_gate := false
	for e in DB.vendors.get("qm_guild", []):
		if e is Dictionary and String(e.get("id", "")) == "mount_wolf_item":
			wolf_gate = (e["rep"][0] == "guild" and int(e["rep"][1]) == 3)
	check(wolf_gate, "灰巾座狼是冒险者公会崇敬档军需品")
	var bear_rw := false
	for st in DataAchiev.get_entry("meta_100").get("reward", {}).get("items", []):
		if String(st[0]) == "mount_bear_item":
			bear_rw = true
	check(bear_rw, "铁鬃战熊由成就「成就猎人」发放")

# ================================================================ 收藏与成就
func core_checks() -> void:
	character("warrior", 20)
	check(Mounts.learned_count() == 0 and not Mounts.learned("horse"), "新角色没有收集任何坐骑")
	check(not Mounts.riding_ok(), "新角色没有骑术")
	Game.learn_spell("mount_horse", 1)
	check(Mounts.learned("horse") and Mounts.learned_count() == 1, "学会召唤技能即视为已收集（无需额外存档字段）")
	Achieve.check()
	check(Achieve.is_done("mount_1"), "收集 1 个坐骑解锁「第一匹坐骑」")
	Achieve.bump("quests", 1)
	check(not Achieve.is_done("mount_3"), "只有 1 个坐骑时「马厩里没空位了」仍锁着")
	for mid in ["deer", "wolf"]:
		Game.learn_spell(String(DataMounts.get_mount(mid)["spell"]), 1)
	Achieve.check()
	check(Achieve.is_done("mount_3") and not Achieve.is_done("mount_5"), "收集 3 个坐骑解锁第二档，第三档还差两个")
	for mid in ["mech", "bear"]:
		Game.learn_spell(String(DataMounts.get_mount(mid)["spell"]), 1)
	Achieve.check()
	check(Achieve.is_done("mount_5") and Mounts.learned_count() == 5, "收集全部 5 个坐骑解锁「坐骑收藏家」")
	# 未收集时的召唤会被拒绝（需要玩家在场，这里只验证逻辑分支的判定函数）
	check(DataMounts.by_spell("mount_bear") == "bear" and DataMounts.from_effect({"model": "bear"}) == "bear", "坐骑与技能一一对应，旧 model 写法也能解析")

# ================================================================ 世界：骑术、学习、召唤、速度、窗口
func enter_world() -> void:
	var old = Game.player
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player) or Game.player == old:
		await get_tree().process_frame
	p = Game.player
	Game.time_of_day = 12
	await wait(1.0)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")

func world_checks() -> void:
	character("warrior", 20)
	Game.pd["riding"] = false
	Game.pd["bag"].fill(null)
	Game.add_item("mount_deer_item", 1, true)
	await enter_world()
	check(Game.keybinds.get("mounts", 0) == KEY_J, "J 键绑定到坐骑收藏")
	# 没有骑术时用缰绳：报错且不消耗
	check(Game.count_item("mount_deer_item") == 1, "背包里有白鹿缰绳")
	p.use_item_id("mount_deer_item")
	await wait(0.3)
	check(Game.count_item("mount_deer_item") == 1 and not Mounts.learned("deer"), "没有骑术时无法学习坐骑，物品也不会被消耗")
	# 学会骑术后再用：技能到手、物品消耗
	Game.pd["riding"] = true
	p.use_item_id("mount_deer_item")
	await wait(0.3)
	check(Mounts.learned("deer") and Game.count_item("mount_deer_item") == 0, "学会骑术后使用缰绳：学会召唤技能并消耗物品")
	check(Achieve.is_done("mount_1"), "真实学习到坐骑后成就同步解锁")
	# 窗口（此时只收集了 1 个）
	Game.hud.open_window("mounts")
	await wait(0.5)
	var w = Game.hud.win["mounts"]
	check(w.visible, "坐骑收藏窗口可以打开")
	check(w.list_box.get_child_count() == DataMounts.ids().size(), "窗口列出全部 %d 个坐骑" % w.list_box.get_child_count())
	check(w.head.text.contains("/%d 已收集" % DataMounts.ids().size()) and Mounts.learned_count() == 1, "顶部显示收集进度（%d/%d）" % [Mounts.learned_count(), DataMounts.ids().size()])
	var enabled := 0
	for row in w.list_box.get_children():
		var btn: Button = null
		for c in row.get_child(0).get_children():
			if c is Button:
				btn = c
		if btn != null and not btn.disabled:
			enabled += 1
	check(enabled == 1, "未收集的坐骑按钮是灰的，只有已收集的可以点（%d 个可点）" % enabled)
	await shot("mounts_window")
	Game.hud.close_all()
	await wait(0.3)
	# 召唤：读条 1.5 秒后骑上
	check(Mounts.summon("deer"), "召唤晨露白鹿")
	await wait(2.4)
	check(p.mounted and Mounts.current() == "deer", "读条结束后处于骑乘状态，当前坐骑为白鹿")
	check(is_equal_approx(p.move_speed(), p.base_speed * 1.6), "骑乘白鹿时移动速度为 160%%（%.2f）" % p.move_speed())
	check(p.model != null and p.model.position.y > 0.0, "骑乘时角色被抬到坐骑背上")
	await shot("mount_deer")
	# 再点一次 = 收起
	check(Mounts.summon("deer"), "再次操作可以收起坐骑")
	await wait(0.4)
	check(not p.mounted and Mounts.current() == "", "已下马，速度回到基础值")
	check(is_equal_approx(p.move_speed(), p.base_speed), "下马后移动速度为 100%%（%.2f）" % p.move_speed())
	# 更快坐骑：战熊 +90%
	Game.pd["bag"].fill(null)
	Game.add_item("mount_bear_item", 1, true)
	p.use_item_id("mount_bear_item")
	await wait(0.3)
	check(Mounts.learned("bear"), "学习铁鬃战熊")
	Mounts.summon("bear")
	await wait(2.4)
	check(p.mounted and p.mount_id == "bear" and is_equal_approx(p.move_speed(), p.base_speed * 1.9), "骑乘战熊时速度为 190%%（%.2f）" % p.move_speed())
	await shot("mount_bear")
	# 战斗/死亡/游泳会下马
	p._on_death(null)
	await wait(0.3)
	check(not p.mounted, "阵亡会自动下马")
	Game.hud.open_window("mounts")
	await wait(0.4)
	w.refresh()
	check(w.list_box.get_child_count() == DataMounts.ids().size() and Mounts.learned_count() == 2, "刷新后窗口仍列出全部坐骑，收藏数为 %d" % Mounts.learned_count())
	Game.hud.close_all()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	data_checks()
	core_checks()
	if not "core" in OS.get_cmdline_user_args():
		await world_checks()
	var failures := checks.filter(func(c): return not c["pass"]).size()
	FileAccess.open(out + "/results.json", FileAccess.WRITE).store_string(JSON.stringify(checks, "\t"))
	print("MOUNTS RESULT %d PASS / %d FAIL" % [checks.size() - failures, failures])
	Game.slot_index = -1
	get_tree().quit(1 if failures else 0)
