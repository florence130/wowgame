class_name ProfWindow
extends UIWindow
## 专业技能（K）：已学专业的配方列表 + 制造（读条，可连续制造）

var cur_prof := ""
var cur_rid := ""
var tabs: HBoxContainer
var list_box: VBoxContainer
var detail: VBoxContainer
var qty: SpinBox
var queue_left := 0

func _init() -> void:
	_init_window("专业技能", Vector2(760, 580), "prof")
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	body.add_child(tabs)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(h)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(290, 460)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(sc)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 3)
	sc.add_child(list_box)
	detail = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 8)
	h.add_child(detail)
	Game.inventory_changed.connect(func(): if visible: refresh())

func refresh() -> void:
	if Game.pd.is_empty():
		return
	for c in tabs.get_children():
		tabs.remove_child(c)
		c.queue_free()
	var learned := []
	for p in DataProf.PROFS:
		if Prof.known(p):
			learned.append(p)
	if not learned.has(cur_prof):
		cur_prof = learned[0] if not learned.is_empty() else ""
	for p in learned:
		var b := UITheme.tab_button(DataProf.PROFS[p]["name"], p == cur_prof)
		b.custom_minimum_size.x = 100
		var key: String = p
		b.pressed.connect(func(): cur_prof = key; cur_rid = ""; refresh())
		tabs.add_child(b)
	_clear(list_box)
	_clear(detail)
	if cur_prof == "":
		var l := UITheme.label("你还没有学会任何专业。\n\n可以向以下训练师学习：\n  锻造 — 金穗镇铁匠阿尔戈、晴岚港锻铁匠行会格里姆\n  精工 — 金穗镇飞艇管理员菲兹、晴岚港精工行会伊格纳兹\n  烹饪 — 金穗旅店法莉亚、晴岚港烹饪师行会玛格丽特", 16, UITheme.TEXT_DIM)
		detail.add_child(l)
		return
	var rids := Prof.recipes_of(cur_prof, true)
	if cur_rid == "" or not rids.has(cur_rid):
		cur_rid = rids[0] if not rids.is_empty() else ""
	for rid in rids:
		var diff := Prof.difficulty(rid)
		var n := Prof.craftable_count(rid)
		var b := Button.new()
		b.text = "%s%s" % [Prof.recipe_name(rid), ("  [%d]" % n) if n > 0 else ""]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_pressed = rid == cur_rid
		b.add_theme_color_override("font_color", Prof.DIFF_COLORS[diff])
		b.add_theme_color_override("font_hover_color", Prof.DIFF_COLORS[diff].lightened(0.3))
		var r2: String = rid
		b.pressed.connect(func(): cur_rid = r2; refresh())
		list_box.add_child(b)
	_render_detail()

func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

func _render_detail() -> void:
	var p := cur_prof
	var head := RichTextLabel.new()
	head.bbcode_enabled = true
	head.fit_content = true
	head.scroll_active = false
	head.text = "[font_size=19][b]%s[/b][/font_size]    技能 [color=#ffd040]%d[/color] / %d\n[color=#a8adb8][font_size=13]%s  ·  配方颜色：[color=#ff8040]橙[/color]必定提升、[color=#ffd040]黄[/color]大概率、[color=#40c040]绿[/color]小概率、[color=#909090]灰[/color]不再提升[/font_size][/color]" % [
		Prof.profession_name(p), Prof.skill(p), Prof.cap(p), DataProf.PROFS[p]["desc"]]
	detail.add_child(head)
	var bar := UITheme.bar(UITheme.XP, 10)
	bar.max_value = Prof.cap(p)
	bar.value = Prof.skill(p)
	detail.add_child(bar)
	if cur_rid == "":
		return
	var r: Dictionary = DB.recipes[cur_rid]
	var oh := HBoxContainer.new()
	oh.add_theme_constant_override("separation", 10)
	detail.add_child(oh)
	var os := Slot.new()
	os.kind = "info"
	os.custom_minimum_size = Vector2(60, 60)
	os.set_item(r["out"], r["n"] if r["n"] > 1 else 0)
	oh.add_child(os)
	var on := RichTextLabel.new()
	on.bbcode_enabled = true
	on.fit_content = true
	on.scroll_active = false
	on.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var it := DB.get_item(r["out"])
	var st_txt := ""
	if r["station"] != "":
		var ok := Prof.near_station(r["station"])
		st_txt = "\n需要：[color=#%s]%s[/color]" % ["80ff80" if ok else "ff6060", DataProf.PROFS[p]["station_name"]]
	on.text = "[color=#%s][b]%s[/b][/color]%s\n[color=#a8adb8]需要技能 %d[/color]%s" % [U.color_hex(U.quality_color(it.get("q", 1))), it.get("name", "?"),
		(" x%d" % r["n"]) if r["n"] > 1 else "", r["skill"], st_txt]
	oh.add_child(on)
	detail.add_child(UITheme.label("所需材料：", 16, UITheme.GOLD))
	var mg := GridContainer.new()
	mg.columns = 2
	mg.add_theme_constant_override("h_separation", 16)
	mg.add_theme_constant_override("v_separation", 6)
	detail.add_child(mg)
	for m in r["mats"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var ms := Slot.new()
		ms.kind = "info"
		ms.custom_minimum_size = Vector2(44, 44)
		ms.set_item(m[0])
		row.add_child(ms)
		var have := Game.count_item(m[0])
		var ml := RichTextLabel.new()
		ml.bbcode_enabled = true
		ml.fit_content = true
		ml.scroll_active = false
		ml.custom_minimum_size = Vector2(150, 0)
		ml.text = "%s\n[color=#%s]%d / %d[/color]" % [DB.get_item(m[0]).get("name", m[0]), "80ff80" if have >= m[1] else "ff6060", have, m[1]]
		row.add_child(ml)
		mg.add_child(row)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(sp)
	var ah := HBoxContainer.new()
	ah.alignment = BoxContainer.ALIGNMENT_END
	ah.add_theme_constant_override("separation", 8)
	detail.add_child(ah)
	var maxn := Prof.craftable_count(cur_rid)
	qty = SpinBox.new()
	qty.min_value = 1
	qty.max_value = maxi(1, maxn)
	qty.value = 1
	qty.custom_minimum_size = Vector2(90, 0)
	ah.add_child(UITheme.label("数量", 15, UITheme.TEXT_DIM))
	ah.add_child(qty)
	var b1 := UITheme.button("制造", func(): start(cur_rid, int(qty.value)), 100)
	var b2 := UITheme.button("全部制造", func(): start(cur_rid, Prof.craftable_count(cur_rid)), 110)
	var block := Prof.craft_block(cur_rid)
	b1.disabled = block != ""
	b2.disabled = block != ""
	if block != "":
		ah.add_child(UITheme.label(block, 15, Color("ff8060")))
	ah.add_child(b1)
	ah.add_child(b2)

## 开始制造 n 次（逐个读条）
func start(rid: String, n: int) -> void:
	if n <= 0:
		return
	cur_rid = rid
	queue_left = n
	_next()

func _next() -> void:
	if queue_left <= 0 or Game.player == null:
		return
	var why := Prof.craft_block(cur_rid)
	if why != "":
		Game.err(why)
		queue_left = 0
		return
	var p: Player = Game.player
	var sp := {"id": "craft", "name": "制造：%s" % Prof.recipe_name(cur_rid), "cast": 1.6, "gcd": 0.0, "target": "self", "effects": []}
	if p.begin_cast(sp, p):
		var rid := cur_rid
		var cb := func(ok: bool):
			if ok:
				Prof.finish_craft(rid)
				queue_left -= 1
				call_deferred("_next")
			else:
				queue_left = 0
		p.cast_stopped.connect(cb, CONNECT_ONE_SHOT)
	else:
		queue_left = 0
