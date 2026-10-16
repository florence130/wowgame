extends Node
## 转职系统验证：数据完整性、15 级门槛、选择 / 改换 / 费用、被动汇总、特性触发、法师两条道路的属性、存档迁移。
## 不写存档（slot = -1）。
var root3d: Node3D
var p: Player
var failures := 0

func _ready() -> void:
	if not has_meta("runner"):
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print(("SPEC PASS " if ok else "SPEC FAIL ") + label)

func character(cls: String, level: int = 20) -> void:
	Game.slot_index = -1
	Game.new_character("转职验证", cls, DB.random_appearance(7, "f"))
	Game.pd["new"] = false
	Game.pd["level"] = level
	Specs.invalidate()

func make_player(cls: String, level: int = 20) -> Player:
	character(cls, level)
	var unit := Player.new()
	root3d.add_child(unit)
	unit.set_physics_process(false)
	unit.set_process(false)
	Game.player = unit
	return unit

func dummy(hp: float = 100000.0) -> Unit:
	var d := Unit.new()
	root3d.add_child(d)
	d.position = Vector3(0, 0, -10)
	d.max_hp = hp
	d.hp = hp
	d.level = 20
	d.set_physics_process(false)
	d.set_process(false)
	return d

func data_checks() -> void:
	var specs: Dictionary = DataSpecs.specs()
	var ids := {}
	var shape_ok := true
	var text_ok := true
	var key_ok := true
	var grant_ok := true
	var icon_ok := true
	var allowed := Specs.MAP_KEYS + Specs.SCALAR_KEYS + ["id", "name", "desc"]
	for cls in specs:
		if not DB.classes.has(cls) or specs[cls].size() < 2:
			shape_ok = false
		for sd in specs[cls]:
			if ids.has(sd["id"]):
				shape_ok = false
			ids[sd["id"]] = true
			if str(sd.get("name", "")) == "" or str(sd.get("desc", "")) == "" or str(sd.get("role", "")) == "":
				text_ok = false
			if IconArt.texture("skills/" + str(sd.get("icon", ""))) == null:
				icon_ok = false
				print("SPEC ICON MISSING ", sd["id"], " -> ", sd.get("icon", ""))
			for g in sd.get("grants", []):
				if not DB.spells.has(g):
					grant_ok = false
			for p_ in sd.get("passives", []):
				for k in p_:
					if not k in allowed:
						key_ok = false
						print("SPEC BAD PASSIVE KEY ", sd["id"], " ", k)
			for t in sd.get("traits", []):
				for k in t.get("mods", {}):
					if not k in Specs.MAP_KEYS + Specs.SCALAR_KEYS:
						key_ok = false
				for k in t:
					if not k in ["id", "name", "desc", "trigger", "value", "mods", "taken_per_gauge"]:
						key_ok = false
						print("SPEC BAD TRAIT KEY ", sd["id"], " ", k)
				if not str(t.get("trigger", "")) in ["", "self_hp_below", "target_hp_below", "target_slowed"]:
					key_ok = false
	check(shape_ok, "每个职业至少两个转职，id 唯一")
	check(text_ok, "每个转职都有名称 / 描述 / 定位")
	check(icon_ok, "每个转职的图标文件都存在")
	check(key_ok, "被动与特性的效果键都在允许集合内")
	check(grant_ok, "转职授予的技能都存在于技能表")
	check(DB.spec_index.size() == ids.size(), "DB.spec_index 建立完整")
	var mage_ids := []
	for sd in specs["mage"]:
		mage_ids.append(sd["id"])
	check("elementalist" in mage_ids and "dark_mage" in mage_ids, "法师有元素法师与黑魔法师两条道路")
	var el: Dictionary = DB.spec_index["elementalist"]
	var dm: Dictionary = DB.spec_index["dark_mage"]
	check(el["schools"] == ["water", "lightning", "light"], "元素法师 = 水 / 雷 / 光")
	check(dm["schools"] == ["fire", "frost", "shadow"], "黑魔法师 = 火 / 冰 / 暗")

func rules_checks() -> void:
	p = make_player("mage", 14)
	check(not Specs.can_choose_level() and Specs.can_choose("elementalist") != "", "14 级不能转职")
	Game.pd["level"] = 15
	check(Specs.can_choose_level() and Specs.can_choose("elementalist") == "", "15 级可以转职")
	check(Specs.can_choose("paladin") != "", "不能选其他职业的转职")
	var money_before: int = Game.pd.get("money", 0)
	check(Specs.choose("elementalist", true) and Game.pd["spec"] == "elementalist", "选择元素法师")
	check(int(Game.pd.get("money", 0)) == money_before, "首次转职免费")
	check(Specs.can_choose("elementalist") != "", "不能重复选择同一转职")
	check(Specs.can_choose("dark_mage") != "", "钱不够时不能改换转职")
	Game.pd["money"] = Specs.CHANGE_COST + 5
	check(Specs.choose("dark_mage", true) and Game.pd["spec"] == "dark_mage" and int(Game.pd["money"]) == 5, "改换转职扣费 %d 铜" % Specs.CHANGE_COST)
	p.free()

func effect_checks() -> void:
	p = make_player("mage", 20)
	var d := dummy()
	p.stats["sp"] = 0.0
	Game.pd["spec"] = ""
	Specs.invalidate()
	p.recalc_stats()
	var base_fire := p.talent_dmg_mul("fire")
	check(is_equal_approx(base_fire, 1.0), "未转职时没有伤害加成")
	Game.pd["spec"] = "dark_mage"
	Specs.invalidate()
	p.recalc_stats()
	check(is_equal_approx(p.talent_dmg_mul("fire", d), 1.06), "黑魔法师：火焰伤害 +6%%（实际 %.3f）" % p.talent_dmg_mul("fire", d))
	check(is_equal_approx(p.talent_dmg_mul("water", d), 1.0), "黑魔法师：水系伤害无加成")
	d.hp = d.max_hp * 0.2
	check(is_equal_approx(p.talent_dmg_mul("fire", d), 1.21), "黑魔法师特性：目标低血时火焰伤害再 +15%%（实际 %.3f）" % p.talent_dmg_mul("fire", d))
	d.hp = d.max_hp
	Game.pd["spec"] = "elementalist"
	Specs.invalidate()
	p.recalc_stats()
	check(is_equal_approx(p.talent_dmg_mul("water", d), 1.06) and is_equal_approx(p.talent_dmg_mul("lightning", d), 1.06) and is_equal_approx(p.talent_dmg_mul("light", d), 1.06), "元素法师：水 / 雷 / 光各 +6%")
	check(is_equal_approx(p.talent_dmg_mul("lightning", d), 1.06), "目标未减速时导电特性不生效")
	d.add_aura({"id": "slow_t", "name": "减速", "icon": "frost", "dur": 5.0, "type": "debuff", "mods": {"speed": -0.4}}, p)
	check(is_equal_approx(p.talent_dmg_mul("lightning", d), 1.06), "导电由浸水连携处理，不再重复叠加被动 +20%%（实际 %.3f）" % p.talent_dmg_mul("lightning", d))
	check(p.tmod("regen") > 0.19, "元素法师被动：回复速度 +20%")
	p.free()
	p = make_player("warrior", 20)
	d = dummy()
	Game.pd["spec"] = "berserker"
	Specs.invalidate()
	p.recalc_stats()
	check(p.tmod("haste") > 0.09, "狂战士被动：攻击速度 +10%")
	p.hp = p.max_hp
	var calm := p.talent_dmg_mul("physical", d)
	p.hp = p.max_hp * 0.3
	check(p.talent_dmg_mul("physical", d) > calm + 0.2, "狂战士特性：自身低血时物理伤害提高")
	p.free()

func migration_checks() -> void:
	character("rogue", 20)
	Game.pd["talents"] = {"rg_malice": 2}
	Game.pd.erase("spec")
	Game.pd.erase("talents")
	if not Game.pd.has("spec"):
		Game.pd["spec"] = ""
	check(not Game.pd.has("talents") and Game.pd["spec"] == "", "旧存档：天赋点数被丢弃，转职默认为空")
	Specs.invalidate()
	check(Specs.mods()["school_dmg"].is_empty() and Specs.current().is_empty(), "未转职时被动汇总为空")

func shoulder_checks() -> void:
	check(not "shoulder" in Game.EQUIP_SLOTS, "装备槽里没有肩部")
	character("warrior", 20)
	Game.pd["money"] = 0
	Game.pd["equip"]["shoulder"] = "gen|shoulder|mail|green|15|bear"
	Game.pd["bag"][0] = {"id": "gen|shoulder|leather|blue|14|bear", "n": 1}
	Game.pd["equip"]["chest"] = "gen|chest|mail|green|15|bear"
	Game._retire_shoulder_slot()
	check(not Game.pd["equip"].has("shoulder"), "旧存档：已穿戴的肩部装备被移除")
	check(Game.pd["bag"][0] == null, "旧存档：背包里的肩部装备被移除")
	check(Game.pd["equip"].has("chest"), "其他部位装备不受影响")
	check(int(Game.pd["money"]) > 0 and Game.pd.get("shoulder_refund", {}).get("n", 0) == 2, "肩部装备按商人价折算成金币（%d 铜）" % int(Game.pd["money"]))
	var gen_ok := true
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in 300:
		var id: String = DB.random_gear(10, 2, rng)
		if "shoulder" in id:
			gen_ok = false
	check(gen_ok, "随机掉落不再生成肩部装备")
	var choice_ok := true
	for qid in DB.quests:
		for cid in DB.quest_choice_ids(qid):
			if "|shoulder|" in cid:
				choice_ok = false
	check(choice_ok, "任务奖励选项里没有肩部装备")

func _hit_until_damage(sp: Dictionary, target_unit: Unit) -> float:
	for i in 12:
		var before := target_unit.hp
		p.apply_effects(sp, target_unit)
		if target_unit.hp < before: return before - target_unit.hp
	return 0.0

func dark_mage_checks() -> void:
	p = make_player("mage", 15)
	var d := dummy()
	check(Game.spell_rank("dm_flame_bolt") == 0, "转职前不授予黑魔技能")
	check(Specs.choose("dark_mage", true), "转职黑魔法师")
	var fire := DB.spell("dm_flame_bolt", 1)
	check(is_equal_approx(p.cast_time(fire), 1.65), "无冰印记按完整时间咏唱")
	p.gauge_add("ice_mark", 5)
	check(is_equal_approx(p.cast_time(fire), 1.155), "冰印记逐枚提供固定30%加速，不叠成瞬发")
	p.face_towards(d.position)
	p.power = p.max_power
	check(p.begin_cast(fire, d), "黑魔开始真实火系咏唱")
	p._tick_cast(1.2)
	check(p.gauge("ice_mark") == 4, "完成火系咏唱只花一枚冰印记")
	await get_tree().create_timer(0.5).timeout
	check(is_equal_approx(p.spell_cost(fire), p.max_power * 0.14), "火法按最大法力比例支付，装备增长不冲掉冰火收支")
	p._tick_gauges(21)
	check(p.gauge("ice_mark") == 0, "冰印记会过期")
	check(DB.spell("dm_void_pulse", 1)["gauge_cost"]["gauge"] == "ember", "暗系爆发使用独立火法余烬，不抢冰印记")
	p.free()

func elementalist_checks() -> void:
	p = make_player("mage", 15)
	var d := dummy()
	var d2 := dummy()
	d2.position = Vector3(3, 0, -10)
	check(Specs.choose("elementalist", true), "转职元素法师")
	check(p.check_cast(DB.spell("dm_flame_bolt", 1), d) != "", "元素不能借黑魔火法")
	_hit_until_damage(DB.spell("el_water_bolt", 1), d)
	check(p.gauge("tide") == 1 and not d.get_aura("el_wet").is_empty(), "水法同时准备潮涌和浸水")
	p.face_towards(d.position)
	check(p.check_cast(DB.spell("el_lightning", 1), d) != "", "雷击需要两点实际潮涌")
	p.gauge_add("tide", 1)
	p.gcd = 0
	p.begin_cast(DB.spell("el_lightning", 1), d)
	p._tick_cast(0.7)
	check(p.gauge("tide") == 0, "雷击真实扣除两点潮涌")
	_hit_until_damage(DB.spell("el_chain_lightning", 1), d)
	check(d2.hp < d2.max_hp, "连锁弹跳伤害生效")
	p.gauge_clear("tide")
	p.hp = p.max_hp
	var before := p.hp
	p.take_damage(100, "shadow", d, false, "", true)
	var loss := before - p.hp
	p.hp = p.max_hp
	p.gauge_add("tide", 5)
	p.take_damage(100, "shadow", d, false, "", true)
	check(p.max_hp - p.hp < loss, "持有潮涌提供有限减伤")
	p.free()

func paladin_checks() -> void:
	p = make_player("warrior", 15)
	var d := dummy()
	d.position = Vector3(0, 0, -2)
	check(Specs.choose("paladin", true), "转职圣骑士")
	check(p.power_type == "none" and p.spec_resource_type == "", "圣骑不再背负无用途的怒气和势能")
	p.force_shield = true
	p.face_towards(d.position)
	p.apply_effects(DB.spell("pd_riposte", 1), p)
	check(is_equal_approx(p.riposte_window, 0.55), "盾反为0.55秒预判窗口")
	d.deal_melee_damage(p, 50, "预判测试")
	check(p.gauge("holy_power") == 2 and p.riposte_window == 0, "盾反成功获得两点，窗口只处理一击")
	p.gauge_add("holy_power", 1)
	p.gcd = 0
	p.begin_cast(DB.spell("pd_radiant_strike", 1), d)
	p._tick_action(0.21)
	check(p.gauge("holy_power") == 0, "圣光冲击在接触帧消耗三点")
	check(p.aura_mod("dmg_taken") < 0, "圣光消耗提供有限防护而非反复自疗")
	p.free()

func berserker_checks() -> void:
	p = make_player("warrior", 15)
	var d := dummy()
	d.position = Vector3(0, 0, -2)
	check(Specs.choose("berserker", true), "转职狂战士")
	_hit_until_damage(DB.spell("bk_rend_slash", 1), d)
	check(p.gauge("fury") == 12, "斩裂真实命中生成狂怒")
	_hit_until_damage(DB.spell("bk_bloodthirst", 1), d)
	p.gauge_clear("fury")
	_hit_until_damage(DB.spell("bk_rend_slash", 1), d)
	check(p.gauge("fury") == 18, "嗜血返回强化斩裂")
	p.gauge_clear("fury")
	p.gauge_add("fury", 50)
	p.in_combat = false
	p._tick_gauges(2)
	check(p.gauge("fury") == 40, "脱战衰减仍生效")
	p.apply_effects(DB.spell("bk_frenzy", 1), p)
	check(is_equal_approx(p.aura_mod("attack_speed"), 0.2) and p.aura_mod("skill_haste") > 0, "狂乱同时加速普攻和技能间隔")
	p.free()

func _clear_units() -> void:
	for c in root3d.get_children():
		if c is Unit:
			c.free()

func run() -> void:
	root3d = Node3D.new()
	add_child(root3d)
	data_checks()
	rules_checks()
	effect_checks()
	migration_checks()
	shoulder_checks()
	await dark_mage_checks()
	_clear_units()
	await elementalist_checks()
	_clear_units()
	paladin_checks()
	_clear_units()
	berserker_checks()
	_clear_units()
	print("SPEC DONE")
	get_tree().quit(1 if failures > 0 else 0)
