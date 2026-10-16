class_name AuctionWindow
extends UIWindow
## 交易所：浏览（一口价购买）/ 出售（右键背包物品选中后上架）/ 我的拍卖（取回、清理已售）

var service_npc: NPC = null
var tab := "browse"
var tab_btns := {}
var page_box: VBoxContainer
var search: LineEdit
var cat := "all"
var sel_bag := -1
var dur_i := 1
var price_g: SpinBox
var price_s: SpinBox
var price_c: SpinBox

const CATS := [["all", "全部"], ["weapon", "武器"], ["armor", "护甲"], ["jewel", "饰品"], ["trade", "材料"], ["use", "消耗品"]]

func _init() -> void:
	_init_window("交易所", Vector2(760, 640), "auction")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	body.add_child(tabs)
	for e in [["browse", "浏览"], ["sell", "出售"], ["mine", "我的拍卖"]]:
		var b := UITheme.tab_button(e[1], e[0] == tab)
		b.custom_minimum_size.x = 110
		var key: String = e[0]
		b.pressed.connect(func(): _set_tab(key))
		tabs.add_child(b)
		tab_btns[key] = b
	page_box = VBoxContainer.new()
	page_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_box.add_theme_constant_override("separation", 6)
	body.add_child(page_box)
	Game.inventory_changed.connect(func(): if visible: refresh())
	Game.money_changed.connect(func(): if visible and tab != "sell": refresh())

func _process(_d: float) -> void:
	if visible and service_npc != null:
		if not is_instance_valid(service_npc) or not service_npc.is_inside_tree() or Game.player == null or not Game.player.is_inside_tree() \
				or Game.player.global_position.distance_to(service_npc.global_position) > 9.0:
			close_window()

func _set_tab(t: String) -> void:
	tab = t
	for k in tab_btns:
		tab_btns[k].button_pressed = k == t
	refresh()

## 背包右键：切到出售页并选中
func pick_for_sale(idx: int) -> void:
	var st = Game.pd["bag"][idx]
	if st == null:
		return
	if not Auction.can_sell(st["id"]):
		Game.err("这件物品不能拍卖。")
		return
	sel_bag = idx
	_set_tab("sell")
	_set_price(Auction.market_value(st["id"]) * st["n"])

func refresh() -> void:
	if Game.pd.is_empty():
		return
	for c in page_box.get_children():
		page_box.remove_child(c)
		c.queue_free()
	match tab:
		"browse": _browse()
		"sell": _sell()
		"mine": _mine()

func _scroll() -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(720, 420)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_box.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	sc.add_child(v)
	return v

func _row(parent: Control, id: String, n: int, cols: Array, btn_text: String, btn_cb: Callable, btn_enabled: bool = true) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.sb(UITheme.BG2, 8, 0, UITheme.LINE, 6))
	parent.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var s := Slot.new()
	s.kind = "info"
	s.custom_minimum_size = Vector2(42, 42)
	s.set_item(id, n if n > 1 else 0)
	h.add_child(s)
	var it := DB.get_item(id)
	var nm := RichTextLabel.new()
	nm.bbcode_enabled = true
	nm.fit_content = true
	nm.scroll_active = false
	nm.custom_minimum_size = Vector2(230, 0)
	nm.text = "[color=#%s]%s[/color]%s\n[color=#a8adb8][font_size=13]%s[/font_size][/color]" % [U.color_hex(U.quality_color(it.get("q", 1))), it.get("name", "?"),
		(" x%d" % n) if n > 1 else "", ("需要等级 %d" % it.get("req", 1)) if it.get("equip", "") != "" else str(it.get("desc", ""))]
	h.add_child(nm)
	for c in cols:
		var l := RichTextLabel.new()
		l.bbcode_enabled = true
		l.fit_content = true
		l.scroll_active = false
		l.custom_minimum_size = Vector2(c[1], 0)
		l.text = c[0]
		h.add_child(l)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	if btn_text != "":
		var b := UITheme.button(btn_text, btn_cb, 80)
		b.disabled = not btn_enabled
		h.add_child(b)

func _match(it: Dictionary) -> bool:
	if search and search.text.strip_edges() != "" and not str(it.get("name", "")).contains(search.text.strip_edges()):
		return false
	var slot: String = it.get("slot", "")
	match cat:
		"weapon": return slot in ["one", "two", "ranged", "off"]
		"armor": return slot in ["chest", "legs", "head", "feet", "hands", "waist", "wrist", "back"]
		"jewel": return slot in ["finger", "neck", "trinket"]
		"trade": return it.get("type", "") == "trade"
		"use": return it.has("use") or it.get("type", "") in ["food", "drink", "potion"]
	return true

# ---------------------------------------------------------------- 浏览
func _browse() -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	page_box.add_child(top)
	var old := search.text if search else ""
	search = LineEdit.new()
	search.placeholder_text = "搜索物品名"
	search.text = old
	search.custom_minimum_size = Vector2(180, 0)
	search.text_submitted.connect(func(_t): refresh())
	top.add_child(search)
	for e in CATS:
		var b := UITheme.tab_button(e[1], e[0] == cat)
		var key: String = e[0]
		b.pressed.connect(func(): cat = key; refresh())
		top.add_child(b)
	var v := _scroll()
	var m: Array = Auction.market()
	var shown := 0
	for i in m.size():
		var e: Dictionary = m[i]
		var it := DB.get_item(e["id"])
		if not _match(it):
			continue
		var idx := i
		var afford: bool = Game.pd["money"] >= e["price"]
		var price_txt := U.money_bb(e["price"]) if afford else "[color=#ff5050]%s[/color]" % U.money_text(e["price"])
		var ref: int = Auction.market_value(e["id"]) * e["n"]
		var deal := "[color=#80ff80]低于市价[/color]" if e["price"] < ref * 0.92 else ("[color=#ffb060]高于市价[/color]" if e["price"] > ref * 1.2 else "[color=#a8adb8]市价[/color]")
		_row(v, e["id"], e["n"], [["[color=#a8adb8]%s[/color]" % e["seller"], 90], [price_txt + "\n[font_size=12]" + deal + "[/font_size]", 150]], "购买", func(): Auction.buy(idx); refresh(), afford)
		shown += 1
	if shown == 0:
		v.add_child(UITheme.label("没有找到符合条件的拍卖品。", 16, UITheme.TEXT_DIM))
	var left := int(Auction.REFRESH - (Auction.now() - Auction.data()["gen_at"]))
	page_box.add_child(UITheme.label("货架将在 %s 后刷新（按游戏时长计）    你的金钱：%s" % [U.time_text(maxf(left, 0.0)), U.money_text(Game.pd["money"])], 14, UITheme.TEXT_DIM))

# ---------------------------------------------------------------- 出售
func _set_price(total: int) -> void:
	if price_g:
		price_g.value = total / 10000
		price_s.value = (total / 100) % 100
		price_c.value = total % 100

func _get_price() -> int:
	if price_g == null:
		return 0
	return int(price_g.value) * 10000 + int(price_s.value) * 100 + int(price_c.value)

func _sell() -> void:
	if sel_bag >= 0 and (Game.pd["bag"][sel_bag] == null or not Auction.can_sell(Game.pd["bag"][sel_bag]["id"])):
		sel_bag = -1
	page_box.add_child(UITheme.label("右键背包里的物品，或点击下方物品选择要出售的物品。", 15, UITheme.TEXT_DIM))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	page_box.add_child(h)
	var s := Slot.new()
	s.kind = "info"
	s.custom_minimum_size = Vector2(64, 64)
	h.add_child(s)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 6)
	h.add_child(form)
	var keep := _get_price()
	var pr := HBoxContainer.new()
	form.add_child(pr)
	pr.add_child(UITheme.label("一口价：", 16))
	price_g = _spin(999)
	pr.add_child(price_g)
	pr.add_child(UITheme.label("金", 16, UITheme.GOLD))
	price_s = _spin(99)
	pr.add_child(price_s)
	pr.add_child(UITheme.label("银", 16, Color("c0c0c0")))
	price_c = _spin(99)
	pr.add_child(price_c)
	pr.add_child(UITheme.label("铜", 16, Color("c87a40")))
	var dr := HBoxContainer.new()
	form.add_child(dr)
	dr.add_child(UITheme.label("拍卖时长：", 16))
	for i in Auction.DURATIONS.size():
		var b := UITheme.tab_button(Auction.DURATIONS[i][1], i == dur_i)
		var di := i
		b.pressed.connect(func(): dur_i = di; refresh())
		dr.add_child(b)
	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.scroll_active = false
	info.custom_minimum_size = Vector2(520, 0)
	form.add_child(info)
	var post := UITheme.button("上架", _post, 120)
	form.add_child(post)
	if sel_bag >= 0:
		var st: Dictionary = Game.pd["bag"][sel_bag]
		s.set_item(st["id"], st["n"])
		var ref: int = Auction.market_value(st["id"]) * st["n"]
		if keep > 0:
			_set_price(keep)
		else:
			_set_price(ref)
		info.text = "[b]%s[/b]%s\n参考市价：%s    商店回收价：%s\n保管费：%s（不退还）    成交手续费：5%%\n[color=#a8adb8][font_size=13]售价越接近或低于市价，越容易在时限内卖出。[/font_size][/color]" % [
			DB.get_item(st["id"])["name"], (" x%d" % st["n"]) if st["n"] > 1 else "", U.money_bb(ref), U.money_bb(DB.get_item(st["id"]).get("price", 1) * st["n"]),
			U.money_bb(Auction.deposit_fee(st["id"], st["n"], dur_i))]
		var sug := UITheme.button("按市价", func(): _set_price(ref))
		pr.add_child(sug)
	else:
		post.disabled = true
		info.text = "[color=#a8adb8]尚未选择物品。[/color]"
	page_box.add_child(UITheme.label("背包中可出售的物品：", 15, UITheme.TEXT_DIM))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(720, 240)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_box.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 13
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	sc.add_child(grid)
	for i in Game.BAG_SIZE:
		var st2 = Game.pd["bag"][i]
		if st2 == null or not Auction.can_sell(st2["id"]):
			continue
		var bs := Slot.new()
		bs.kind = "info"
		bs.custom_minimum_size = Vector2(48, 48)
		bs.set_item(st2["id"], st2["n"])
		if i == sel_bag:
			bs.modulate = Color(1.0, 0.95, 0.6)
		var bi := i
		bs.left_clicked.connect(func(_sl): pick_for_sale(bi))
		grid.add_child(bs)

func _spin(mx: int) -> SpinBox:
	var sp := SpinBox.new()
	sp.min_value = 0
	sp.max_value = mx
	sp.step = 1
	sp.custom_minimum_size = Vector2(80, 0)
	return sp

func _post() -> void:
	if sel_bag < 0:
		return
	if Auction.post(sel_bag, _get_price(), dur_i):
		sel_bag = -1
		price_g.value = 0
		price_s.value = 0
		price_c.value = 0
		_set_tab("mine")

# ---------------------------------------------------------------- 我的拍卖
func _mine() -> void:
	var v := _scroll()
	var mine: Array = Auction.data()["mine"]
	if mine.is_empty():
		v.add_child(UITheme.label("你目前没有拍卖。", 16, UITheme.TEXT_DIM))
	var t := Auction.now()
	for i in mine.size():
		var e: Dictionary = mine[i]
		var idx := i
		match e["state"]:
			"active":
				var left: float = e["start"] + e["dur"] - t
				_row(v, e["id"], e["n"], [[U.money_bb(e["price"]), 150], ["[color=#80c0ff]进行中[/color]\n[font_size=12]剩余 %s[/font_size]" % U.time_text(maxf(left, 0.0)), 110]], "取消", func(): Auction.cancel(idx); refresh())
			"sold":
				_row(v, e["id"], e["n"], [[U.money_bb(e["price"]), 150], ["[color=#80ff80]已售出[/color]\n[font_size=12]金钱已到账[/font_size]", 110]], "", Callable())
			"expired":
				_row(v, e["id"], e["n"], [[U.money_bb(e["price"]), 150], ["[color=#ffb060]已过期[/color]", 110]], "取回", func(): Auction.cancel(idx); refresh())
	var bot := HBoxContainer.new()
	page_box.add_child(bot)
	bot.add_child(UITheme.button("清除已售记录", func(): Auction.clear_sold(); refresh()))
