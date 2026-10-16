class_name MountWindow
extends UIWindow
## 坐骑收藏（J）：列出全部坐骑的模型速度、获取来源与收集状态，已收集的可以在这里直接召唤/收起。
## 数据在 src/data/data_mounts.gd，收藏判定与召唤在 src/core/mounts.gd。

var list_box: VBoxContainer
var head: RichTextLabel
var footer: Label

func _init() -> void:
	_init_window("坐骑收藏", Vector2(720, 540), "mounts")
	head = RichTextLabel.new()
	head.bbcode_enabled = true
	head.fit_content = true
	head.scroll_active = false
	head.custom_minimum_size = Vector2(0, 44)
	body.add_child(head)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(660, 380)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 6)
	sc.add_child(list_box)
	footer = UITheme.label("在马厩商人处学会初级骑术（10 级）后即可骑乘；坐骑可以在骑乘中按对应技能或这里直接召唤、收起。", 14, UITheme.TEXT_DIM)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.custom_minimum_size = Vector2(660, 0)
	body.add_child(footer)
	Game.spells_changed.connect(func(): if visible: refresh())

func open_window() -> void:
	super()
	refresh()

func refresh() -> void:
	if Game.pd.is_empty():
		return
	var n := Mounts.learned_count()
	var total := DataMounts.ids().size()
	var rid := Mounts.riding_ok()
	head.text = "[font_size=24][b][color=#ffd100]%d[/color][/b][/font_size][color=#a8adb8]/%d 已收集[/color]    " % [n, total] \
		+ ("[color=#80ff80]已掌握初级骑术[/color]" if rid else "[color=#ff9060]尚未学习骑术（10 级后找马厩商人）[/color]")
	for c in list_box.get_children():
		list_box.remove_child(c)
		c.queue_free()
	for id in DataMounts.ids():
		list_box.add_child(_row(String(id)))

func _row(id: String) -> Control:
	var md := DataMounts.get_mount(id)
	var got := Mounts.learned(id)
	var riding := Mounts.current() == id
	var col := DataMounts.quality_color(id) if got else UITheme.TEXT_DIM
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.sb(UITheme.BG2 if not riding else UITheme.BG3, 8, 1,
		Color(col.r, col.g, col.b, 0.45 if got else 0.12), 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	var t := HBoxContainer.new()
	t.add_theme_constant_override("separation", 8)
	info.add_child(t)
	t.add_child(UITheme.label(("★ " if got else "☆ ") + String(md.get("name", id)), 17, col, got))
	t.add_child(UITheme.label("速度 %s" % DataMounts.speed_text(id), 15, UITheme.GOLD_D))
	t.add_child(UITheme.label("（%s）" % ("已收集" if got else "未收集"), 14, UITheme.TEXT_DIM))
	var d := UITheme.label(String(md.get("desc", "")), 14, UITheme.TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(430, 0)
	info.add_child(d)
	info.add_child(UITheme.label("来源：" + Mounts.source_text(id), 13, Color("8fb0d0")))
	var b := UITheme.button("收起" if riding else "召唤", func(): _use(id), 92)
	b.disabled = not got
	b.tooltip_text = "召唤 %s" % String(md.get("name", id)) if got else "尚未收集"
	row.add_child(b)
	return p

func _use(id: String) -> void:
	Mounts.summon(id)
	await get_tree().create_timer(0.3).timeout
	refresh()
