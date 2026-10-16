class_name Tips
extends RefCounted
## 魔兽式鼠标提示（物品/技能/光环）

static func _panel() -> Array:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.sb(Color(0.04, 0.05, 0.09, 0.96), 10, 1, Color(UITheme.GOLD, 0.35), 12))
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size = Vector2(300, 0)
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_size_override("normal_font_size", 16)
	r.add_theme_font_size_override("bold_font_size", 18)
	p.add_child(r)
	return [p, r]

static func item_bb(id: String, extra: Dictionary = {}) -> String:
	var it := DB.get_item(id)
	if it.is_empty():
		return ""
	var q: int = it.get("q", 1)
	var t := "[b][color=#%s]%s[/color][/b]\n" % [U.quality_color(q).to_html(false), it["name"]]
	if it.get("quest_item", false):
		t += "[color=#ffffff]任务物品[/color]\n"
	if it.has("starts_quest"):
		t += "[color=#ffd040]这件物品将会触发一个任务[/color]\n"
	if it.get("soulbound", false) or q >= 2:
		t += "拾取后绑定\n"
	var slot: String = it.get("slot", "")
	if slot != "":
		var sn: String = DataItems.SLOT_NAMES.get(slot, slot)
		var tn: String = DataItems.TYPE_NAMES.get(it.get("type", ""), "")
		if it.get("type", "") == "misc":
			tn = ""
		t += "%s[right]%s[/right]\n" % [sn, tn] if tn != "" else "%s\n" % sn
	if it.has("dmg"):
		var d: Array = it["dmg"]
		var spd: float = it.get("speed", 2.0)
		t += "%d - %d 伤害   速度 %.2f\n" % [d[0], d[1], spd]
		t += "(每秒伤害 %.1f)\n" % ((d[0] + d[1]) * 0.5 / spd)
	if it.get("armor", 0) > 0:
		t += "%d点护甲\n" % it["armor"]
	var names := {"str": "力量", "agi": "敏捷", "sta": "耐力", "int": "智力", "spi": "精神"}
	for k in ["str", "agi", "sta", "int", "spi"]:
		if it.get("stats", {}).has(k):
			t += "+%d %s\n" % [it["stats"][k], names[k]]
	if it.get("req", 1) > 1:
		var ok: bool = Game.pd.is_empty() or Game.pd["level"] >= it["req"]
		t += "[color=#%s]需要等级 %d[/color]\n" % ["ffffff" if ok else "ff4040", it["req"]]
	if it.get("sp", 0) > 0:
		t += "[color=#1eff00]装备：法术伤害和治疗效果提高最多%d点。[/color]\n" % it["sp"]
	if it.get("crit", 0) > 0:
		t += "[color=#1eff00]装备：使你造成致命一击的几率提高%d%%。[/color]\n" % it["crit"]
	if it.has("desc"):
		var dc := "1eff00" if it.has("use") else "ffd100"
		t += "[color=#%s]%s[/color]\n" % [dc, it["desc"]] if it.has("use") else "[color=#ffd100]\"%s\"[/color]\n" % it["desc"]
	if not Game.pd.is_empty() and slot != "" and it.get("equip", "") != "" and not Game.can_equip(it, false) and it.get("req", 1) <= Game.pd["level"]:
		t += "[color=#ff4040]你的职业无法使用[/color]\n"
	if Game.pd.has("appearances") and slot != "" and it.get("equip", "") != "":
		if not Game.pd["appearances"].has(id):
			t += "[color=#c080ff]你尚未收集此外观[/color]\n"
	var price: int = it.get("price", 0)
	if extra.has("buy"):
		t += "\n价格：%s" % U.money_bb(extra["buy"])
	elif price > 0 and q > 0 and not it.get("quest_item", false):
		t += "\n出售价格：%s" % U.money_bb(price * extra.get("n", 1))
	elif price > 0 and q == 0:
		t += "\n出售价格：%s" % U.money_bb(price * extra.get("n", 1))
	return t.strip_edges()

static func item(id: String, extra: Dictionary = {}) -> Control:
	var pr := _panel()
	pr[1].text = item_bb(id, extra)
	# 对比当前装备
	var it := DB.get_item(id)
	if extra.get("compare", true) and not Game.pd.is_empty() and it.get("equip", "") != "" and not extra.get("equipped", false):
		var slot: String = it["equip"]
		var eslot := slot
		if slot == "finger":
			eslot = "finger1"
		elif slot == "trinket":
			eslot = "trinket1"
		if Game.pd["equip"].has(eslot) and Game.pd["equip"][eslot] != id:
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 6)
			h.add_child(pr[0])
			var pr2 := _panel()
			pr2[1].text = "[color=#a0a0a0]当前装备[/color]\n" + item_bb(Game.pd["equip"][eslot], {"equipped": true})
			h.add_child(pr2[0])
			return h
	return pr[0]

static func spell(sid: String, rank: int = -1) -> Control:
	var pr := _panel()
	if rank < 0:
		rank = maxi(1, Game.spell_rank(sid))
	var sp := DB.spell(sid, rank)
	var t := "[b]%s[/b]" % sp.get("name", sid)
	if sp.get("max_rank", 1) > 1:
		t += "[right][color=#a0a0a0]等级 %d[/color][/right]" % rank
	t += "\n"
	var line := ""
	var raw_cost: Variant = sp.get("cost", 0)
	var cost := int(raw_cost) if not raw_cost is Dictionary else 0
	if raw_cost is Dictionary:
		for key in raw_cost:
			line += "%d点%s " % [int(raw_cost[key]), {"stamina": "耐力", "momentum": "势能", "rage": "怒气"}.get(key, key)]
	var gc: Dictionary = sp.get("gauge_cost", {})
	if not gc.is_empty():
		line += "%d点%s " % [int(gc.get("amount", 0)), Unit.GAUGE_NAMES.get(gc.get("gauge", ""), "资源")]
	for key in sp.get("gauge_costs", {}):
		line += "%d点%s " % [int(sp["gauge_costs"][key]), Unit.GAUGE_NAMES.get(key, key)]
	if sp.has("cost_pct_max"):
		line += "%d%%最大法力 " % int(float(sp["cost_pct_max"]) * 100)
	if cost > 0:
		var pt := "法力值"
		if not Game.pd.is_empty():
			pt = {"mana": "法力值", "rage": "怒气", "energy": "能量"}.get(DB.classes[Game.pd["class"]]["power"], "法力值")
		line += "%d点%s" % [cost, pt]
	if sp.has("range") and sp.get("target", "") in ["enemy", "friend"]:
		var rg: float = sp["range"]
		line += ("    " if line != "" else "") + ("近战范围" if rg <= 5.0 else "%d码射程" % int(rg))
	if line != "":
		t += line + "\n"
	var ct := ""
	if sp.get("channel", 0.0) > 0.0:
		ct = "引导法术"
	elif sp.get("cast", 0.0) > 0.0:
		ct = "%.1f秒施法时间" % sp["cast"]
	elif sp.get("next_melee", false):
		ct = "下一次近战"
	else:
		ct = "瞬发"
	if sp.get("cd", 0.0) > 0.0:
		var cd: float = sp["cd"]
		ct += "    冷却时间：%s" % (("%d分钟" % int(cd / 60)) if cd >= 60 else ("%d秒" % int(cd)))
	t += ct + "\n"
	t += "[color=#ffd100]%s[/color]" % DB.spell_desc(sp)
	var req: Dictionary = sp.get("requires", {})
	if req.has("weapon"):
		t += "\n需要装备：" + str(DataItems.TYPE_NAMES.get(req["weapon"], req["weapon"]))
	if req.get("dual_daggers", false):
		t += "（双持匕首）"
	if sp.has("rotation_role"):
		t += "\n[color=#92daca]%s[/color]" % sp["rotation_role"]
	pr[1].text = t
	return pr[0]

static func aura(a: Dictionary) -> Control:
	var pr := _panel()
	var d: Dictionary = a["def"]
	var t := "[b][color=#%s]%s[/color][/b]\n" % ["ffd100" if d.get("type", "") == "buff" else "ff6060", d.get("name", "")]
	var parts := []
	var names := {"str": "力量", "agi": "敏捷", "sta": "耐力", "int": "智力", "spi": "精神", "armor": "护甲", "ap": "攻击强度", "rap": "远程攻击强度"}
	for k in d.get("stats", {}):
		parts.append("%s +%d" % [names.get(k, k), d["stats"][k]])
	var mods: Dictionary = d.get("mods", {})
	if mods.has("speed"):
		parts.append("移动速度 %+d%%" % int(mods["speed"] * 100))
	if mods.has("attack_speed"):
		parts.append("攻击速度 %+d%%" % int(mods["attack_speed"] * 100))
	if mods.has("dmg_done"):
		parts.append("造成伤害 %+d%%" % int(mods["dmg_done"] * 100))
	if mods.has("dmg_taken"):
		parts.append("受到伤害 %+d%%" % int(mods["dmg_taken"] * 100))
	if mods.has("dodge"):
		parts.append("躲闪 %+d%%" % int(mods["dodge"] * 100))
	if a.has("absorb"):
		parts.append("吸收 %d 点伤害" % int(a["absorb"]))
	if d.get("stun", false):
		parts.append("昏迷")
	if d.get("root", false):
		parts.append("被定身")
	if d.get("incap", false):
		parts.append("无法行动")
	if d.get("fear", false):
		parts.append("恐惧")
	if d.has("tick"):
		var tk: Dictionary = d["tick"]
		if tk.has("dmg"):
			parts.append("每%.0f秒受到伤害" % tk["interval"])
		if tk.has("heal"):
			parts.append("每%.0f秒恢复生命" % tk["interval"])
		if tk.has("mana"):
			parts.append("正在恢复法力值")
	if d.get("food", false):
		parts.append("正在进食，恢复生命值")
	if d.get("stealth", false):
		parts.append("潜行中")
	t += "，".join(parts)
	if d.get("dur", 0.0) > 0.0:
		t += "\n[color=#a0a0a0]剩余 %s[/color]" % U.time_text(a.get("rem", 0.0))
	pr[1].text = t
	return pr[0]

static func text(s: String) -> Control:
	var pr := _panel()
	pr[1].text = s
	return pr[0]
