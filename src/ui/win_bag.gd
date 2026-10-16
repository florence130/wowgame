class_name BagWindow
extends UIWindow
## 统一大背包：180 格，每页 90 格（10×9），共 2 页
## embed = true 时作为面板嵌进角色窗口（不画窗口底与标题），见 UIWindow._init_window

var page := 0
var filter := "all"
var slots: Array[Slot] = []
var grid: GridContainer
var page_btns: Array[Button] = []
var filter_btns := {}
var info: RichTextLabel

func _init(embed: bool = false) -> void:
	_init_window("背包", Vector2(520, 600), "bag", embed)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	body.add_child(tabs)
	for e in [["all", "全部"], ["equip", "装备"], ["use", "消耗"], ["mat", "材料"], ["quest", "任务"]]:
		var b := UITheme.tab_button(e[1], e[0] == "all")
		b.custom_minimum_size.x = 70
		var key: String = e[0]
		b.pressed.connect(func(): _set_filter(key))
		tabs.add_child(b)
		filter_btns[key] = b
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(sp)
	tabs.add_child(UITheme.button("整理", func(): Game.sort_bag()))
	grid = GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	body.add_child(grid)
	for i in Game.BAG_PAGE:
		var s := Slot.new()
		s.kind = "bag"
		s.custom_minimum_size = Vector2(48, 48)
		s.corner = 2
		s.right_clicked.connect(func(sl): Game.hud.bag_right_click(sl.index))
		s.left_clicked.connect(_on_left)
		grid.add_child(s)
		slots.append(s)
	var bottom := HBoxContainer.new()
	body.add_child(bottom)
	for p in 2:
		var b2 := UITheme.tab_button("第%d页" % (p + 1), p == 0)
		var pi := p
		b2.pressed.connect(func(): _set_page(pi))
		bottom.add_child(b2)
		page_btns.append(b2)
	info = RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.scroll_active = false
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(info)
	Game.inventory_changed.connect(func(): if visible: refresh())
	Game.money_changed.connect(func(): if visible: refresh())

func _on_left(sl: Slot) -> void:
	if Input.is_key_pressed(KEY_SHIFT) and sl.item_id != "":
		Game.hud.chat_input.visible = true
		Game.hud.chat_input.text += "[%s]" % DB.get_item(sl.item_id)["name"]
		Game.hud.chat_input.grab_focus()

func _set_page(p: int) -> void:
	page = p
	for i in page_btns.size():
		page_btns[i].button_pressed = i == p
	refresh()

func _set_filter(f: String) -> void:
	filter = f
	for k in filter_btns:
		filter_btns[k].button_pressed = k == f
	refresh()

func _match(it: Dictionary) -> bool:
	match filter:
		"equip": return it.get("equip", "") != ""
		"use": return it.has("use")
		"mat": return it.get("type", "") in ["trade", "junk"]
		"quest": return it.get("quest_item", false) or it.has("starts_quest")
	return true

func refresh() -> void:
	if Game.pd.is_empty():
		return
	var bag: Array = Game.pd["bag"]
	for i in Game.BAG_PAGE:
		var idx := page * Game.BAG_PAGE + i
		var s := slots[i]
		s.index = idx
		var st = bag[idx]
		if st == null:
			s.set_item("")
			s.modulate = Color.WHITE
		else:
			s.set_item(st["id"], st["n"])
			s.modulate = Color.WHITE if _match(DB.get_item(st["id"])) else Color(1, 1, 1, 0.25)
	var used := Game.BAG_SIZE - Game.free_bag_slots()
	info.text = "[right]%s    [color=#a8adb8]%d/%d[/color][/right]" % [U.money_bb(Game.pd["money"]), used, Game.BAG_SIZE]
