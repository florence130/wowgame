class_name AchievWindow
extends UIWindow
## 成就（Y）：左侧分类、右侧条目列表；顶部是总点数与完成度，条目显示进度与奖励。
## 数据在 src/data/data_achiev.gd，判定与奖励在 src/core/achieve.gd。

const CAT_W := 196.0

var cat_box: VBoxContainer
var list_box: VBoxContainer
var head: RichTextLabel
var footer: Label
var cur := "all"

func _init() -> void:
	_init_window("成就", Vector2(780, 560), "achiev")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	body.add_child(top)
	head = RichTextLabel.new()
	head.bbcode_enabled = true
	head.fit_content = true
	head.scroll_active = false
	head.custom_minimum_size = Vector2(0, 44)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(head)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(h)
	cat_box = VBoxContainer.new()
	cat_box.custom_minimum_size = Vector2(CAT_W, 0)
	cat_box.add_theme_constant_override("separation", 4)
	h.add_child(cat_box)
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(520, 400)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(sc)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 6)
	sc.add_child(list_box)
	footer = UITheme.label("成就由任务、击杀、首领、探索、采集制造、交易所成交、声望与持币等玩法自动记录；达成即刻结算奖励。", 14, UITheme.TEXT_DIM)
	body.add_child(footer)
	Game.achieve_changed.connect(func(): if visible: refresh())

func open_window() -> void:
	super()
	Achieve.check()
	refresh()

func refresh() -> void:
	if Game.pd.is_empty():
		return
	_render_head()
	_render_cats()
	_render_list()

func _render_head() -> void:
	var n := Achieve.count_done()
	var total := DataAchiev.LIST.size()
	var pts := Achieve.total_points()
	var cap := Achieve.all_points()
	head.text = "[font_size=24][b][color=#ffd100]%d[/color][/b][/font_size] [color=#a8adb8]成就点数[/color]    [color=#ecebe6]%d/%d[/color] [color=#a8adb8]已完成[/color]\n[color=#a8adb8]全部成就合计可达 %d 点[/color]" % [pts, n, total, cap]

func _render_cats() -> void:
	for c in cat_box.get_children():
		cat_box.remove_child(c)
		c.queue_free()
	var rows := [{"id": "all", "name": "全部", "color": UITheme.GOLD}]
	for cid in DataAchiev.CATS:
		rows.append({"id": cid, "name": String(DataAchiev.CATS[cid]["name"]), "color": Color(DataAchiev.CATS[cid]["color"])})
	for r in rows:
		var cid := String(r["id"])
		var entries: Array = DataAchiev.LIST if cid == "all" else DataAchiev.by_cat(cid)
		var got := 0
		var pts := 0
		var cap := 0
		for a in entries:
			cap += int(a["pts"])
			if Achieve.is_done(String(a["id"])):
				got += 1
				pts += int(a["pts"])
		var b := UITheme.tab_button("%s    %d/%d    %d 点" % [String(r["name"]), got, entries.size(), pts], cid == cur)
		b.custom_minimum_size = Vector2(CAT_W, 44)
		b.add_theme_color_override("font_color", Color(r["color"]) if cid == cur else UITheme.TEXT)
		b.tooltip_text = "本类共 %d 点" % cap
		var key := cid
		b.pressed.connect(func(): cur = key; refresh())
		cat_box.add_child(b)

func _render_list() -> void:
	for c in list_box.get_children():
		list_box.remove_child(c)
		c.queue_free()
	var entries: Array = Achieve.visible_entries() if cur == "all" else DataAchiev.by_cat(cur)
	for a in entries:
		if a.get("hidden", false) and not Achieve.is_done(String(a["id"])):
			continue
		list_box.add_child(_row(a))

func _row(a: Dictionary) -> Control:
	var id := String(a["id"])
	var is_done := Achieve.is_done(id)
	var cat: Dictionary = DataAchiev.CATS.get(String(a["cat"]), {})
	var col: Color = Color(cat.get("color", UITheme.GOLD))
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.sb(UITheme.BG2 if not is_done else UITheme.BG3, 8, 1, Color(col.r, col.g, col.b, 0.35 if is_done else 0.12), 8))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 8)
	v.add_child(r1)
	var mark := UITheme.label(("★ " if is_done else "☆ "), 18, col if is_done else UITheme.TEXT_DIM)
	r1.add_child(mark)
	var name_l := UITheme.label(String(a["name"]), 17, col if is_done else UITheme.TEXT, is_done)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(name_l)
	r1.add_child(UITheme.label("%d 点" % int(a["pts"]), 15, UITheme.GOLD_D))
	var desc := UITheme.label(String(a["desc"]), 14, UITheme.TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(460, 0)
	v.add_child(desc)
	var r3 := HBoxContainer.new()
	r3.add_theme_constant_override("separation", 10)
	v.add_child(r3)
	r3.add_child(UITheme.label(Achieve.progress_text(a), 14, Color("80ff80") if is_done else UITheme.BEIGE))
	var rw: Dictionary = a.get("reward", {})
	if is_done and not rw.is_empty():
		var parts := []
		if int(rw.get("money", 0)) > 0:
			parts.append(U.money_text(int(rw["money"])))
		for st in rw.get("items", []):
			parts.append("%s ×%d" % [DB.get_item(String(st[0])).get("name", st[0]), int(st[1])])
		r3.add_child(UITheme.label("奖励：" + "、".join(parts), 13, UITheme.TEXT_DIM))
	if is_done:
		var d := int(Achieve.done().get(id, 0))
		r3.add_child(UITheme.label("（第 %d 天达成）" % d, 13, UITheme.TEXT_DIM))
	return p
