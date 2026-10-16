class_name NpcWindow
extends UIWindow
## NPC 对话：闲谈/任务/商人/训练师/旅店/飞行/骑术

var npc: NPC = null
var mode := "gossip"
var cur_quest := ""
var choice := ""
var content: VBoxContainer
var scroll: ScrollContainer
var _vendor_tab := "buy"
## 军需官模式：非空时商人页显示 "qm_" + 阵营 id 的货单（条目可带声望门槛）
var _qm := ""
var _topic := 0

func _init() -> void:
	_init_window("对话", Vector2(560, 620), "npc")
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(530, 540)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	Game.inventory_changed.connect(func(): if visible and mode == "vendor": _render())
	Game.money_changed.connect(func(): if visible and mode in ["vendor", "trainer"]: _render())

func _process(_d: float) -> void:
	if visible and mode == "waystone":
		if not is_instance_valid(ws) or Game.player == null or Game.player.global_position.distance_to(ws.global_position) > 7.0:
			close_window()
		return
	if visible and npc != null:
		if not is_instance_valid(npc) or Game.player == null or not Game.player.is_inside_tree() or not npc.is_inside_tree() \
				or Game.player.global_position.distance_to(npc.global_position) > 9.0:
			close_window()

## 城内传送石：复用对话窗口列出同区域的其他传送石
var ws: Node3D = null

func show_waystone(w: Node3D) -> void:
	npc = null
	ws = w
	mode = "waystone"
	open_window()
	_render()

func show_npc(n: NPC) -> void:
	npc = n
	ws = null
	mode = "gossip"
	_qm = ""
	open_window()
	_render()

func show_quest_offer(qid: String, n: NPC) -> void:
	npc = n
	cur_quest = qid
	mode = "offer"
	open_window()
	_render()

func refresh() -> void:
	pass

func _clear() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()

func _rt(t: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.text = t
	r.add_theme_font_size_override("normal_font_size", 17)
	content.add_child(r)
	return r

func _opt(text: String, icon_txt: String, col: Color, cb: Callable) -> void:
	var b := Button.new()
	b.text = "%s  %s" % [icon_txt, text]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("font_color", col)
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(func(): Sfx.play("click"); cb.call())
	content.add_child(b)

func _render() -> void:
	_clear()
	scroll.scroll_vertical = 0
	var nm := npc.unit_name if npc and is_instance_valid(npc) else ""
	title_label.text = nm if nm != "" else "任务"
	if mode == "waystone":
		_render_waystone()
		return
	match mode:
		"gossip": _render_gossip()
		"offer": _render_offer()
		"progress": _render_progress()
		"complete": _render_complete()
		"vendor": _render_vendor()
		"trainer": _render_trainer()
		"flight": _render_flight()
		"portal": _render_portal()
		"prof": _render_prof()
		"topic": _render_topic()
		"guild": _render_guild()

func _render_gossip() -> void:
	var nd: Dictionary = npc.nd
	if nd.get("sub", "") != "":
		_rt("[color=#a8adb8]<%s>[/color]" % nd["sub"])
	_rt(nd.get("greet", "你好，旅行者。"))
	var nid := npc.npc_id
	var added := false
	for qid in DB.quests_by_turnin.get(nid, []):
		if Game.pd["quests"].has(qid) and Game.is_quest_complete(qid):
			var id: String = qid
			_opt(DB.quests[qid]["name"], "?", Color("ffd800"), func(): cur_quest = id; mode = "complete"; _render())
			added = true
	for qid in DB.quests_by_giver.get(nid, []):
		if Game.can_accept(qid):
			var id2: String = qid
			_opt("[%d] %s" % [DB.quests[qid]["lvl"], DB.quests[qid]["name"]], "!", Color("ffd800"), func(): cur_quest = id2; mode = "offer"; _render())
			added = true
	for qid in DB.quests_by_turnin.get(nid, []):
		if Game.pd["quests"].has(qid) and not Game.is_quest_complete(qid):
			var id3: String = qid
			_opt(DB.quests[qid]["name"], "?", Color("a0a0a0"), func(): cur_quest = id3; mode = "progress"; _render())
			added = true
	# 声望：该 NPC 所属阵营的当前关系
	var myfid := Rep.faction_of_npc(nid)
	if myfid != "" and not nd.get("ambient", false) and not nd.has("qm"):
		var pr2 := Rep.progress(myfid)
		_rt("[color=#a8adb8]%s：[color=#%s]%s[/color]  %d / %d[/color]" % [Rep.faction_name(myfid),
			U.color_hex(DataRep.tier_color(Rep.tier(myfid))), Rep.tier_name(myfid), int(pr2.x), int(pr2.y)])
	# 军需官：军需品货单（条目按声望等级解锁）
	if nd.has("qm") and DB.rep_factions.has(nd["qm"]):
		var fid: String = nd["qm"]
		var pr3 := Rep.progress(fid)
		_rt("[color=#a8adb8]%s：[color=#%s]%s[/color]  %d / %d[/color]" % [Rep.faction_name(fid),
			U.color_hex(DataRep.tier_color(Rep.tier(fid))), Rep.tier_name(fid), int(pr3.x), int(pr3.y)])
		_opt("让我看看军需品。（%s · %s）" % [Rep.faction_name(fid), Rep.tier_name(fid)], "🎖", UITheme.TEXT,
			func(): _qm = fid; _vendor_tab = "buy"; mode = "vendor"; _render())
	# 服务
	if nd.has("vendor"):
		_opt("让我看看你出售的货物。", "🛒", UITheme.TEXT, func(): _qm = ""; _vendor_tab = "buy"; mode = "vendor"; _render())
	if nd.has("trainer"):
		var tc: String = nd["trainer"]
		if tc == "all" or tc == Game.pd["class"]:
			_opt("我想学习新的技能。", "📖", UITheme.TEXT, func(): mode = "trainer"; _render())
		else:
			_rt("[color=#a8adb8]我只训练%s。[/color]" % DB.classes[tc]["name"])
	if nd.get("innkeeper", false):
		_opt("将这里设为我的家。", "🏠", UITheme.TEXT, func():
			Game.bind_location(Game.pd["zone"], npc.global_position + npc.forward_dir() * 2.0, npc.unit_name + "的旅店")
			Vfx.column(Game.zone, Game.player.global_position, Color("80b0ff"), 3.0, 0.8)
			close_window())
	if nd.has("flight") and nd["flight"] != "":
		_opt("我需要搭乘飞艇。", "✈", UITheme.TEXT, func(): mode = "flight"; _render())
	if nd.get("riding", false):
		if Game.pd.get("riding", false):
			_rt("[color=#80ff80]你已经掌握了骑术。[/color]")
		else:
			var cost := 8000
			_opt("学习初级骑术（需要10级，%s）" % U.money_text(cost), "🐎", UITheme.TEXT, func():
				if Game.pd["level"] < 10:
					Game.err("你需要达到10级。")
				elif Game.pd["money"] < cost:
					Game.err("你没有足够的钱。")
				else:
					Game.add_money(-cost, true)
					Game.pd["riding"] = true
					Game.msg("你学会了初级骑术！现在可以使用坐骑了。", Color("ffff60"))
					Sfx.play("learn")
					_render())
	if nd.has("train"):
		_train_option(str(nd["train"]))
	if nd.has("service"):
		_service_option(str(nd["service"]))
	for i in nd.get("topics", []).size():
		var ti: int = i
		_opt(nd["topics"][i][0], "💬", Color("c8d8ff"), func(): _topic = ti; mode = "topic"; _render())
	if nd.has("prof"):
		var pn: String = DataProf.PROFS[nd["prof"]]["name"]
		_opt("我想学习%s。" % pn, "🔨" if nd["prof"] == "smith" else ("⚙" if nd["prof"] == "artisan" else "🍳"), UITheme.TEXT, func(): mode = "prof"; _render())
	if nd.get("bank", false):
		_opt("我想打开我的银行保险箱。", "🏦", UITheme.TEXT, func(): Game.hud.open_service("bank", npc))
	if nd.get("transmog", false):
		_opt("我想改变装备的外观。（幻化）", "✨", UITheme.TEXT, func(): Game.hud.open_service("transmog", npc))
	if nd.get("auction", false):
		_opt("我想看看交易所的拍卖品。", "⚖", UITheme.TEXT, func(): Game.hud.open_service("auction", npc))
	if nd.get("portal", false):
		_opt("请为我打开传送门。", "🌀", UITheme.TEXT, func(): mode = "portal"; _render())
	if not added and not nd.has("vendor") and not nd.has("trainer") and not nd.get("innkeeper", false):
		pass
	_opt("再见。", "✕", UITheme.TEXT_DIM, close_window)

static func quest_bb(qid: String, log_mode: bool) -> String:
	var q: Dictionary = DB.quests[qid]
	var t := "[font_size=22][b][color=#ffd100]%s[/color][/b][/font_size]\n" % q["name"]
	if q.get("main", false):
		t += "[color=#e8c27a]★ 主线任务[/color]  "
	if q.get("elite", false):
		t += "[color=#ff8040]◆ 精英[/color]  "
	if q.get("dungeon", false):
		t += "[color=#80c0ff]◆ 地下城[/color]  "
	t += "[color=#a8adb8]等级 %d[/color]\n\n" % q["lvl"]
	t += q.get("text", "") + "\n\n"
	t += "[b][color=#ffd100]任务目标[/color][/b]\n" + q.get("obj_text", "") + "\n"
	if log_mode and Game.pd["quests"].has(qid):
		var objs: Array = q.get("obj", [])
		for i in objs.size():
			var ok: bool = Game.objective_progress(qid, i) >= objs[i].get("n", 1)
			t += "[color=#%s]  • %s[/color]\n" % ["80ff80" if ok else "ffffff", Game.objective_text(qid, i)]
		if Game.is_quest_complete(qid):
			var tn: String = DB.npcs.get(q.get("turnin", ""), {}).get("name", "")
			t += "[color=#80ff80]  ✔ 回去找%s交任务。[/color]\n" % tn
	return t

static func fill_rewards(box: Container, qid: String, selectable: bool, win: NpcWindow) -> void:
	var q: Dictionary = DB.quests[qid]
	var hdr := RichTextLabel.new()
	hdr.bbcode_enabled = true
	hdr.fit_content = true
	hdr.scroll_active = false
	hdr.custom_minimum_size = Vector2(480, 0)
	var xp := DB.quest_xp(q, Game.pd["level"])
	hdr.text = "[b][color=#ffd100]任务奖励[/color][/b]\n经验值：%d    金钱：%s" % [xp, U.money_bb(DB.quest_money(q))]
	box.add_child(hdr)
	var choices := DB.quest_choice_ids(qid)
	if choices.size() > 0:
		var l := UITheme.label("你可以从这些奖励中选择一件：" if choices.size() > 1 else "你将得到：", 15, UITheme.TEXT_DIM)
		l.custom_minimum_size = Vector2(480, 0)
		box.add_child(l)
		for cid in choices:
			box.add_child(_reward_entry(cid, 1, selectable, win))
	var items: Array = q.get("items", [])
	if items.size() > 0:
		var l2 := UITheme.label("你还将得到：", 15, UITheme.TEXT_DIM)
		l2.custom_minimum_size = Vector2(480, 0)
		box.add_child(l2)
		for e in items:
			box.add_child(_reward_entry(e[0], e[1], false, null))

static func _reward_entry(id: String, n: int, selectable: bool, win: NpcWindow) -> Control:
	var it := DB.get_item(id)
	var p := PanelContainer.new()
	var sel := win != null and win.choice == id
	p.add_theme_stylebox_override("panel", UITheme.sb(Color(0.95, 0.85, 0.5, 0.25) if sel else Color(0.1, 0.13, 0.2, 0.9), 10, 2 if sel else 1, UITheme.GOLD if sel else UITheme.LINE, 6))
	p.custom_minimum_size = Vector2(235, 60)
	var h := HBoxContainer.new()
	p.add_child(h)
	var s := Slot.new()
	s.kind = "reward"
	s.set_item(id, n)
	s.dim = false
	h.add_child(s)
	var l := UITheme.label(it.get("name", id), 15, U.quality_color(it.get("q", 1)))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 160
	h.add_child(l)
	if selectable:
		var cb := func(_x = null):
			win.choice = id
			win._render()
		s.left_clicked.connect(cb)
		p.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: cb.call())
	return p

func _render_offer() -> void:
	_rt(quest_bb(cur_quest, false))
	var box := HFlowContainer.new()
	content.add_child(box)
	fill_rewards(box, cur_quest, false, self)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 20)
	content.add_child(h)
	h.add_child(UITheme.button("接受", func():
		Game.accept_quest(cur_quest)
		if npc and is_instance_valid(npc):
			mode = "gossip"
			_render()
		else:
			close_window(), 140))
	h.add_child(UITheme.button("拒绝", func():
		if npc and is_instance_valid(npc):
			mode = "gossip"
			_render()
		else:
			close_window(), 140))

func _render_progress() -> void:
	var q: Dictionary = DB.quests[cur_quest]
	_rt("[font_size=22][b][color=#ffd100]%s[/color][/b][/font_size]\n\n%s" % [q["name"], q.get("progress", "你完成任务了吗？")])
	var t := "[b][color=#ffd100]任务目标[/color][/b]\n"
	var objs: Array = q.get("obj", [])
	for i in objs.size():
		t += "  • %s\n" % Game.objective_text(cur_quest, i)
	_rt(t)
	var b := UITheme.button("返回", func(): mode = "gossip"; _render(), 140)
	content.add_child(b)

func _render_complete() -> void:
	var q: Dictionary = DB.quests[cur_quest]
	_rt("[font_size=22][b][color=#ffd100]%s[/color][/b][/font_size]\n\n%s" % [q["name"], q.get("complete", "干得好！")])
	var choices := DB.quest_choice_ids(cur_quest)
	if choices.size() == 1:
		choice = choices[0]
	elif not choice in choices:
		choice = ""
	var box := HFlowContainer.new()
	content.add_child(box)
	fill_rewards(box, cur_quest, choices.size() > 1, self)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(h)
	var btn := UITheme.button("完成任务", func():
		if choices.size() > 1 and choice == "":
			Game.err("请先选择一件奖励。")
			return
		if Game.turn_in_quest(cur_quest, choice):
			choice = ""
			mode = "gossip"
			# 自动接续任务
			if npc and is_instance_valid(npc):
				for nq in DB.quests_by_giver.get(npc.npc_id, []):
					if Game.can_accept(nq) and cur_quest in DB.quests[nq].get("prev", []):
						cur_quest = nq
						mode = "offer"
						break
				_render()
			else:
				close_window(), 180)
	h.add_child(btn)

# ---------------------------------------------------------------- 商人
func _price(id: String) -> int:
	var base := maxi(1, DB.get_item(id).get("price", 1) * 4)
	# 声望折扣：与该 NPC 所属阵营的声望等级挂钩
	if npc != null:
		var d := Rep.discount_for_npc(npc.npc_id)
		if d > 0.0:
			base = maxi(1, int(round(base * (1.0 - d))))
	return base

## 当前应显示的货单：军需官模式用 qm_<阵营>，否则用 NPC 的 vendor id
func _vendor_list() -> Array:
	if _qm != "":
		return DB.vendors.get("qm_" + _qm, [])
	return DB.vendors.get(npc.nd.get("vendor", ""), []) if npc != null else []

func _render_vendor() -> void:
	var tabs := HBoxContainer.new()
	content.add_child(tabs)
	var b1 := UITheme.tab_button("购买", _vendor_tab == "buy")
	b1.pressed.connect(func(): _vendor_tab = "buy"; _render())
	tabs.add_child(b1)
	var b2 := UITheme.tab_button("回购", _vendor_tab == "buyback")
	b2.pressed.connect(func(): _vendor_tab = "buyback"; _render())
	tabs.add_child(b2)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(sp)
	tabs.add_child(UITheme.button("出售灰色物品", sell_junk))
	var disc := Rep.discount_for_npc(npc.npc_id) if npc != null else 0.0
	if _qm != "":
		var pr := Rep.progress(_qm)
		_rt("[b][color=#%s]%s[/color][/b]    [color=#%s]%s[/color]  %d / %d\n[color=#a8adb8]军需品需要达到对应声望等级（友善 / 尊敬 / 崇敬 / 崇拜），声望同时带来购买折扣。[/color]" % [
			U.color_hex(Rep.faction_color(_qm)), Rep.faction_name(_qm), U.color_hex(DataRep.tier_color(Rep.tier(_qm))),
			Rep.tier_name(_qm), int(pr.x), int(pr.y)])
	elif disc > 0.0:
		_rt("[color=#80ff80]你在%s的声望为你带来 %d%% 的购买折扣。[/color]" % [Rep.faction_name(Rep.faction_of_npc(npc.npc_id)), int(disc * 100)])
	_rt("[color=#a8adb8]左键点击购买（按住Shift购买5个）。在背包中右键点击物品即可出售。[/color]")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	content.add_child(grid)
	var list: Array = _vendor_list() if _vendor_tab == "buy" else Game.buyback
	for i in list.size():
		var entry: Dictionary = Rep.entry(list[i]) if _vendor_tab == "buy" else {"id": list[i]["id"], "n": list[i]["n"]}
		var id: String = entry["id"]
		var n: int = 1 if _vendor_tab == "buy" else int(entry["n"])
		var ok := _vendor_tab != "buy" or Rep.entry_ok(list[i])
		var it := DB.get_item(id)
		var price: int = _price(id) if _vendor_tab == "buy" else it.get("price", 1) * n
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UITheme.sb(Color(0.1, 0.13, 0.2, 0.9), 10, 1, UITheme.LINE, 6))
		p.custom_minimum_size = Vector2(255, 62)
		var h := HBoxContainer.new()
		p.add_child(h)
		var s := Slot.new()
		s.kind = "vendor"
		s.set_item(id, n)
		s.extra = {"buy": price}
		s.dim = not ok
		h.add_child(s)
		var v := VBoxContainer.new()
		var nl := UITheme.label(it.get("name", id), 15, U.quality_color(it.get("q", 1)) if ok else Color("808080"))
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size.x = 170
		v.add_child(nl)
		var pr := RichTextLabel.new()
		pr.bbcode_enabled = true
		pr.fit_content = true
		pr.scroll_active = false
		pr.custom_minimum_size = Vector2(170, 20)
		var afford: bool = Game.pd["money"] >= price
		pr.text = U.money_bb(price) if afford else "[color=#ff5050]%s[/color]" % U.money_text(price)
		if not ok:
			pr.text = "[color=#ff8060]%s[/color]" % Rep.entry_line(list[i])
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(pr)
		h.add_child(v)
		var idx := i
		var cb := func(_x = null): _buy(idx)
		s.left_clicked.connect(cb)
		s.right_clicked.connect(cb)
		grid.add_child(p)
	_opt("返回", "↩", UITheme.TEXT_DIM, func(): mode = "gossip"; _render())

func _buy(i: int) -> void:
	if _vendor_tab == "buy":
		var list: Array = _vendor_list()
		var id: String = Rep.entry_id(list[i])
		if not Rep.entry_ok(list[i]):
			Game.err("你的声望还不够。（%s）" % Rep.entry_line(list[i]))
			return
		var n := 5 if Input.is_key_pressed(KEY_SHIFT) and DB.get_item(id).get("stack", 1) >= 5 else 1
		var cost := _price(id) * n
		if Game.pd["money"] < cost:
			Game.err("你没有足够的钱。")
			return
		if Game.add_item(id, n, true) < n:
			Game.add_money(-cost, true)
			Sfx.play("coin")
			Game.msg("你购买了：%s x%d" % [DB.get_item(id)["name"], n], Color("ffffa0"))
	else:
		var e: Dictionary = Game.buyback[i]
		var it := DB.get_item(e["id"])
		var cost2: int = it.get("price", 1) * e["n"]
		if Game.pd["money"] < cost2:
			Game.err("你没有足够的钱。")
			return
		if Game.add_item(e["id"], e["n"], true) == 0:
			Game.add_money(-cost2, true)
			Game.buyback.remove_at(i)
			Sfx.play("coin")
	_render()

func sell(idx: int) -> void:
	var st = Game.pd["bag"][idx]
	if st == null:
		return
	var it := DB.get_item(st["id"])
	if it.get("quest_item", false) or it.get("price", 0) <= 0:
		Game.err("商人对这件物品不感兴趣。")
		return
	var v: int = it["price"] * st["n"]
	Game.buyback.append({"id": st["id"], "n": st["n"]})
	if Game.buyback.size() > 12:
		Game.buyback.pop_front()
	Game.remove_at(idx)
	Game.add_money(v, true)
	Game.msg("出售了%s，获得%s。" % [it["name"], U.money_text(v)], Color("ffffa0"))
	Sfx.play("coin")

func sell_junk() -> void:
	var total := 0
	for i in Game.BAG_SIZE:
		var st = Game.pd["bag"][i]
		if st != null and DB.get_item(st["id"]).get("q", 1) == 0:
			total += DB.get_item(st["id"])["price"] * st["n"]
			Game.pd["bag"][i] = null
	if total > 0:
		Game.add_money(total, true)
		Game.msg("出售所有灰色物品，获得%s。" % U.money_text(total), Color("ffffa0"))
		Sfx.play("coin")
		Game.inventory_changed.emit()

# ---------------------------------------------------------------- 训练师
func _render_trainer() -> void:
	var cls: String = Game.pd["class"]
	_rt("[color=#a8adb8]%s训练师可以教你以下技能：[/color]" % DB.classes[cls]["name"])
	var any := false
	for sid in DB.classes[cls]["spells"]:
		if not Specs.spell_allowed(sid, Specs.current_id()):
			continue
		var cur := Game.spell_rank(sid)
		var ranks: Array = DB.spells[sid].get("ranks", [])
		if cur >= ranks.size():
			continue
		var nr := cur + 1
		var lvl := DB.spell_rank_level(sid, nr)
		if lvl > Game.pd["level"] + 6:
			continue
		any = true
		var cost := DB.spell_rank_cost(sid, nr)
		var sp := DB.spell(sid, nr)
		var h := HBoxContainer.new()
		var s := Slot.new()
		s.kind = "trainer"
		s.set_spell(sid)
		h.add_child(s)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UITheme.label("%s%s" % [sp["name"], ("（等级 %d）" % nr) if ranks.size() > 1 else ""], 16, UITheme.TEXT if lvl <= Game.pd["level"] else Color("ff6060"), true))
		var info := RichTextLabel.new()
		info.bbcode_enabled = true
		info.fit_content = true
		info.scroll_active = false
		info.text = ("需要等级 %d    " % lvl) + U.money_bb(cost)
		v.add_child(info)
		h.add_child(v)
		var b := UITheme.button("学习", func():
			if not Specs.spell_allowed(sid, Specs.current_id()):
				Game.err("请学习当前转职可用的技能。")
			elif Game.pd["level"] < lvl:
				Game.err("你的等级不够。")
			elif Game.pd["money"] < cost:
				Game.err("你没有足够的钱。")
			else:
				Game.add_money(-cost, true)
				Game.learn_spell(sid, nr)
				_render(), 90)
		b.disabled = lvl > Game.pd["level"]
		h.add_child(b)
		content.add_child(h)
	if not any:
		_rt("我现在没有什么可以教你的了。等你变得更强再来吧。")
	# 转职：同一职业训练师处查看与改换
	if npc.nd.get("trainer", "") in ["all", Game.pd["class"]]:
		var cur := Specs.current()
		if not Specs.can_choose_level():
			_rt("[b][color=#ffd100]转职[/color][/b]    %d 级时可以选择自己的道路。" % DataSpecs.CHOOSE_LEVEL)
		else:
			_rt("[b][color=#ffd100]转职[/color][/b]    当前：[color=#ffd040]%s[/color]" % cur.get("name", "尚未转职"))
			_opt("打开转职面板。（按 N）", "✦", UITheme.TEXT, func():
				Game.hud.open_window("talents"))
	_opt("返回", "↩", UITheme.TEXT_DIM, func(): mode = "gossip"; _render())

## 传送门法师的目的地：[名称, 区域, 出生点, 费用(铜)]
const PORTALS := [["晨钟修道院", "vale", "start", 500], ["金穗镇", "vale", "fp_goldenear", 500],
	["东门哨站", "tidewind", "fp_camp", 300], ["风语旧圣堂入口", "tidewind", "from_sanctum", 300]]
## 魔导列车线路：key → [区域, 出生点, 站名, 需要完成的任务, 需要的标记]
const TRAIN_LINES := {
	"goldenear": ["vale", "fp_goldenear", "金穗镇", "q_c12", ""],
	"solenne": ["tidewind", "st_solenne", "晴岚港 · 中央车站", "q_c12", "city_access"],
}
const TRAIN_COST := 200

func _train_option(key: String) -> void:
	if not TRAIN_LINES.has(key):
		return
	var line: Array = TRAIN_LINES[key]
	_opt("乘坐魔导列车前往%s。（%s）" % [line[2], U.money_text(TRAIN_COST)], "🚂", UITheme.TEXT, func():
		if line[3] != "" and not Game.pd["qdone"].has(line[3]):
			Game.err("铁路信号系统尚未修复，列车停运中。（完成霍华德的任务「%s」后恢复）" % DB.quests[line[3]]["name"])
			return
		if line[4] != "" and not Game.has_flag(line[4]):
			Game.err("你还没有晴岚港的市民证，无法乘坐这条线路。")
			return
		if Game.pd["money"] < TRAIN_COST:
			Game.err("你没有足够的钱。")
			return
		Game.add_money(-TRAIN_COST, true)
		close_window()
		Sfx.play("train")
		Game.world.ride_train(line[0], line[1], line[2]))

func _render_topic() -> void:
	var tp: Array = npc.nd.get("topics", [])
	if _topic >= tp.size():
		mode = "gossip"
		_render()
		return
	_rt("[color=#c8d8ff]「%s」[/color]" % tp[_topic][0])
	_rt(tp[_topic][1])
	_opt("返回", "↩", UITheme.TEXT_DIM, func(): mode = "gossip"; _render())

const BATH_COST := 300
const OPERA_COST := 500
const GUILD_COST := 10000

static func game_day() -> int:
	return int(Game.pd.get("played", 0.0) / (maxf(1.0, Game.settings.get("day_minutes", 48.0)) * 60.0))

func _buff(id: String, name: String, icon: String, col: Color, stats: Dictionary, dur: float) -> void:
	Game.player.add_aura({"id": id, "name": name, "icon": icon, "color": col, "dur": dur, "type": "buff", "stats": stats}, Game.player)
	Vfx.burst(Game.zone, Game.player.global_position + Vector3(0, 1, 0), col, 1.2)

func _service_option(s: String) -> void:
	var p: Player = Game.player
	match s:
		"bath":
			_opt("泡个热水澡。（%s）" % U.money_text(BATH_COST), "♨", UITheme.TEXT, func():
				if Game.pd["money"] < BATH_COST:
					Game.err("你没有足够的钱。")
					return
				Game.add_money(-BATH_COST, true)
				p.set_hp(p.max_hp)
				p.add_power(p.max_power)
				_buff("buff_bath", "温泉暖意", "heal", Color("ffb080"), {"sta": 3, "spi": 3}, 1800.0)
				Sfx.play("heal")
				Game.msg("热水驱散了旅途的疲惫。你获得了「温泉暖意」：耐力+3，精神+3，持续30分钟。", Color("ffd0a0"))
				close_window())
		"heal":
			_opt("请帮我治疗伤口。（免费）", "✚", UITheme.TEXT, func():
				p.set_hp(p.max_hp)
				Vfx.column(Game.zone, p.global_position, Color("a0ffa0"), 2.0, 0.6)
				Sfx.play("heal")
				Game.msg("贝尔纳为你包扎好了伤口。", Color("a0ffa0"))
				close_window())
		"welfare":
			var claimed: bool = Game.pd.get("welfare_day", -1) == game_day()
			_opt("申请今天的冒险者补助。" + ("（今天已领取）" if claimed else ""), "📦", UITheme.TEXT if not claimed else UITheme.TEXT_DIM, func():
				if Game.pd.get("welfare_day", -1) == game_day():
					Game.err("你今天已经领过补助了，明天再来吧。")
					return
				if Game.free_bag_slots() < 3:
					Game.err("背包空间不足。")
					return
				Game.pd["welfare_day"] = game_day()
				var lv: int = Game.pd["level"]
				var food := "food_bread" if lv < 5 else ("food_meat" if lv < 15 else "food_cheese")
				var drink := "drink_water" if lv < 5 else ("drink_juice" if lv < 15 else "drink_milk")
				Game.add_item(food, 5)
				Game.add_item(drink, 5)
				Game.add_item("potion_heal1" if lv < 9 else "potion_heal2", 2)
				_render())
			_opt("我的休息经验还有多少？", "☾", UITheme.TEXT, func():
				_rt("你当前积累的精力充沛（双倍击杀经验）：[color=#80c0ff]%d[/color] 点。在旅店或城市里下线、休息时会慢慢积累。" % int(Game.pd.get("rested", 0.0))))
		"guild":
			_opt("公会事务", "🛡", UITheme.TEXT, func(): mode = "guild"; _render())
		"opera":
			_opt("购买今晚《迎海女神》的戏票。（%s）" % U.money_text(OPERA_COST), "🎭", UITheme.TEXT, func():
				if Game.pd["money"] < OPERA_COST:
					Game.err("你没有足够的钱。")
					return
				Game.add_money(-OPERA_COST, true)
				_clear()
				_rt("[i]灯光暗下，海浪声从舞台两侧涌来。\n\n港务长独自站在船头，风暴吞没了所有的星光。他高声呼唤，却只听见雷鸣。\n\n就在桅杆即将折断的那一刻——海面深处亮起一道蓝光。光芒化作一位张开双翼的女子，她举起手中的水晶，为迷途的船只照亮了回家的海湾。\n\n帷幕落下，全场起立鼓掌。[/i]")
				_buff("buff_opera", "灵感", "arcane", Color("c0a0ff"), {"int": 3, "spi": 3}, 1800.0)
				Game.msg("你看完了《迎海女神》，获得了「灵感」：智力+3，精神+3，持续30分钟。", Color("e0c0ff"))
				_opt("离开剧院", "✕", UITheme.TEXT_DIM, close_window))
		"research":
			var n_chip := Game.count_item("j_stone_chip")
			_opt("上交 10 块雕像碎石供研究，换取 1 枚以太碎晶。（持有 %d）" % n_chip, "🔬", UITheme.TEXT if n_chip >= 10 else UITheme.TEXT_DIM, func():
				if Game.count_item("j_stone_chip") < 10:
					Game.err("你需要 10 块雕像碎石。（风语旧圣堂的石像鬼会掉落）")
					return
				Game.remove_item("j_stone_chip", 10)
				Game.add_item("mat_aether", 1)
				Game.msg("奥古斯丁：「这些碎石里残留着以太刻印……非常有价值。拿着，这是你应得的。」", Color("ffe9a8"))
				_render())
		"time":
			_opt("现在几点了？", "🕰", UITheme.TEXT, func():
				var tod := Game.time_of_day
				var phase := "清晨" if tod < 8.0 else ("白天" if tod < 17.0 else ("黄昏" if tod < 20.0 else "夜晚"))
				_rt("提奥看了看钟面：「现在是 [color=#ffd040]%02d:%02d[/color]，%s。」" % [int(tod), int(fmod(tod, 1.0) * 60.0), phase]))
		"routes":
			_opt("我想乘船出海。", "⚓", UITheme.TEXT, func():
				Game.err("近海与远洋航线都还没有开放。陆路请前往中央车站。"))

func _render_guild() -> void:
	var g: String = Game.pd.get("guild", "")
	if g != "":
		_rt("你是公会 [color=#80ff80]<%s>[/color] 的会长。" % g)
		_opt("解散公会", "✕", Color("ff9080"), func():
			Game.pd.erase("guild")
			Game.msg("公会 <%s> 已解散。" % g, Color("ffb060"))
			_render())
	else:
		_rt("创建公会需要 %s 登记费。公会名称为 2-12 个字。" % U.money_bb(GUILD_COST))
		var le := LineEdit.new()
		le.placeholder_text = "输入公会名称"
		le.max_length = 12
		content.add_child(le)
		_opt("登记创建", "🛡", UITheme.TEXT, func():
			var nm := le.text.strip_edges()
			if nm.length() < 2:
				Game.err("公会名称至少需要 2 个字。")
				return
			if Game.pd["money"] < GUILD_COST:
				Game.err("你没有足够的钱。")
				return
			Game.add_money(-GUILD_COST, true)
			Game.pd["guild"] = nm
			Sfx.play("quest_done")
			Game.msg("公会 <%s> 成立了！" % nm, Color("80ff80"))
			_render())
	_opt("返回", "↩", UITheme.TEXT_DIM, func(): mode = "gossip"; _render())

## 专业训练师：学习/提升等级、购买配方
func _render_prof() -> void:
	var p: String = npc.nd["prof"]
	var pd_: Dictionary = DataProf.PROFS[p]
	if Prof.known(p):
		_rt("[b]%s[/b]    技能 [color=#ffd040]%d[/color] / %d\n[color=#a8adb8]%s[/color]" % [Prof.profession_name(p), Prof.skill(p), Prof.cap(p), pd_["desc"]])
	else:
		_rt("[b]%s[/b]\n[color=#a8adb8]%s[/color]" % [pd_["name"], pd_["desc"]] + ("\n需要在%s旁边制造。" % pd_["station_name"] if pd_["station"] != "" else ""))
	var nr := Prof.rank(p) + 1
	if nr < DataProf.RANKS.size():
		var rk: Array = DataProf.RANKS[nr]
		var why := Prof.next_rank_block(p)
		var txt := "%s%s（技能上限 %d）    %s" % ["学习" if nr == 0 else "提升为", rk[0] + pd_["name"] if nr > 0 else pd_["name"], rk[1], U.money_text(rk[4])]
		_opt(txt + (("    [" + why + "]") if why != "" else ""), "📖", UITheme.TEXT if why == "" else UITheme.TEXT_DIM, func():
			if Prof.learn_rank(p):
				_render())
	if Prof.known(p):
		_rt("[b][color=#ffd100]可学习的配方[/color][/b]")
		var any := false
		for rid in Prof.recipes_of(p, false):
			if Game.pd["recipes"].has(rid):
				continue
			any = true
			var r: Dictionary = DB.recipes[rid]
			var why2 := Prof.can_learn_recipe(rid)
			var id: String = rid
			_opt("[%d] %s    %s%s" % [r["skill"], Prof.recipe_name(rid), U.money_text(r["cost"]), ("    [" + why2 + "]") if why2 != "" else ""], "📜",
				UITheme.TEXT if why2 == "" else UITheme.TEXT_DIM, func():
					if Prof.learn_recipe(id):
						_render())
		if not any:
			_rt("[color=#a8adb8]你已经学会了这里的全部配方。[/color]")
		_rt("[color=#a8adb8]按 K 打开专业技能面板进行制造。[/color]")
	_opt("返回", "↩", UITheme.TEXT_DIM, func(): mode = "gossip"; _render())

func _render_portal() -> void:
	_rt("[color=#a8adb8]传送门已校准。请选择目的地：[/color]")
	for p in PORTALS:
		var e: Array = p
		_opt("%s    %s" % [e[0], U.money_text(e[3])], "🌀", Color("c0a0ff"), func():
			if Game.player.in_combat:
				Game.err("你正处于战斗中！")
				return
			if Game.pd["money"] < e[3]:
				Game.err("你没有足够的钱。")
				return
			Game.add_money(-e[3], true)
			close_window()
			Vfx.column(Game.zone, Game.player.global_position, Color("c0a0ff"), 3.0, 0.8)
			Sfx.play("portal")
			Game.world.travel(e[1], e[2]))
	_opt("返回", "↩", UITheme.TEXT_DIM, func(): mode = "gossip"; _render())

func _render_waystone() -> void:
	if not is_instance_valid(ws):
		return
	title_label.text = "传送石 · %s" % ws.title
	_rt("[color=#a8adb8]符文环在你掌心下亮起。选择城内的目的地：[/color]")
	for w in ws.destinations():
		var dest: Node3D = w
		_opt(dest.title, "◆", Color("bff0ff"), func():
			close_window()
			dest.arrive())
	_opt("离开", "↩", UITheme.TEXT_DIM, func(): close_window())

func _render_flight() -> void:
	var here: String = npc.nd.get("flight", "")
	_rt("[color=#a8adb8]选择目的地（只能前往已发现的飞行点）：[/color]")
	var any := false
	for fp in DB.flight_paths:
		if fp == here or not Game.pd["fps"].has(fp):
			continue
		var d: Dictionary = DB.flight_paths[fp]
		if d.has("needs") and not Game.has_flag(d["needs"]):
			continue
		any = true
		var id: String = fp
		var cost: int = d["cost"]
		_opt("%s    %s" % [d["name"], U.money_text(cost)], "✈", UITheme.TEXT, func():
			if Game.pd["money"] < cost:
				Game.err("你没有足够的钱。")
				return
			Game.add_money(-cost, true)
			close_window()
			Game.world.fly_to(id))
	if not any:
		_rt("你还没有发现其他飞行点。去和其他驿站的管理员交谈来发现它们。")
	_opt("返回", "↩", UITheme.TEXT_DIM, func(): mode = "gossip"; _render())
