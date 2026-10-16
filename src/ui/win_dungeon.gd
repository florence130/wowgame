class_name DungeonWindow
extends UIWindow
## 地下城查找器（I）：列出地下城、首领、相关任务；一键进入（自动召集同伴）/ 离开

var list_box: VBoxContainer
var detail: RichTextLabel
var action_box: HBoxContainer
var cur := ""

func _init() -> void:
	_init_window("地下城查找器", Vector2(760, 560), "dungeon")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(h)
	list_box = VBoxContainer.new()
	list_box.custom_minimum_size = Vector2(200, 0)
	list_box.add_theme_constant_override("separation", 4)
	h.add_child(list_box)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(520, 420)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc)
	detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.fit_content = true
	detail.scroll_active = false
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(detail)
	action_box = HBoxContainer.new()
	action_box.alignment = BoxContainer.ALIGNMENT_END
	action_box.add_theme_constant_override("separation", 8)
	right.add_child(action_box)
	Game.quest_log_changed.connect(func(): if visible: refresh())

static func dungeons() -> Array:
	var out := []
	for z in DB.zones:
		if DB.zones[z].get("dungeon", false):
			out.append(z)
	return out

func refresh() -> void:
	if Game.pd.is_empty():
		return
	for c in list_box.get_children():
		list_box.remove_child(c)
		c.queue_free()
	var ds := dungeons()
	if cur == "" and not ds.is_empty():
		cur = ds[0]
	for z in ds:
		var zd: Dictionary = DB.zones[z]
		var b := UITheme.tab_button("%s\n[%s]" % [zd["name"], zd.get("levels", "")], z == cur)
		b.custom_minimum_size = Vector2(200, 56)
		var key: String = z
		b.pressed.connect(func(): cur = key; refresh())
		list_box.add_child(b)
	if cur == "":
		detail.text = "暂无开放的地下城。"
		return
	_render_detail()

func _render_detail() -> void:
	var zd: Dictionary = DB.zones[cur]
	var lvl: int = Game.pd["level"]
	var minl: int = zd.get("min_level", 1)
	var t := "[font_size=24][b][color=#ffd100]%s[/color][/b][/font_size]\n" % zd["name"]
	t += "[color=#a8adb8]建议等级 %s    最低进入等级 %d    入口：%s[/color]\n\n" % [zd.get("levels", "?"), minl, zd.get("entrance_name", "?")]
	t += zd.get("desc", "") + "\n\n"
	t += "[b][color=#ffd100]首领[/color][/b]\n"
	for bid in zd.get("bosses", []):
		var m: Dictionary = DB.mobs.get(bid, {})
		var sub: String = m.get("sub", "")
		t += "  ◆ [color=#ff9060]%s[/color]%s  [color=#a8adb8]%d级[/color]\n" % [m.get("name", bid), ("  <%s>" % sub) if sub != "" else "", m.get("lvl", [0])[0]]
		var drops: Array = m.get("loot", {}).get("items", [])
		if not drops.is_empty():
			var names := []
			for d in drops:
				var it := DB.get_item(d)
				names.append("[color=#%s]%s[/color]" % [U.color_hex(U.quality_color(it.get("q", 2))), it.get("name", d)])
			t += "     [font_size=13]可能掉落：%s[/font_size]\n" % "、".join(names)
	t += "\n[b][color=#ffd100]相关任务[/color][/b]\n"
	var any := false
	for qid in DB.quests:
		var q: Dictionary = DB.quests[qid]
		if not q.get("dungeon", false):
			continue
		any = true
		var state := "[color=#a8adb8]未接取[/color]"
		if Game.pd["qdone"].has(qid):
			state = "[color=#80ff80]已完成[/color]"
		elif Game.pd["quests"].has(qid):
			state = "[color=#80ff80]可交付[/color]" if Game.is_quest_complete(qid) else "[color=#80c0ff]进行中[/color]"
		elif Game.can_accept(qid):
			var giver: String = DB.npcs.get(q.get("giver", ""), {}).get("name", "?")
			state = "[color=#ffd800]可接取[/color]（%s）" % giver
		t += "  • [%d] %s    %s\n" % [q["lvl"], q["name"], state]
	if not any:
		t += "  [color=#a8adb8]无[/color]\n"
	t += "\n[color=#80c0ff]进入地下城时，盾卫加隆、修女艾莉亚和游侠芙蕾会作为同伴加入你的队伍。[/color]"
	detail.text = t
	for c in action_box.get_children():
		action_box.remove_child(c)
		c.queue_free()
	var inside: bool = Game.pd.get("zone", "") == cur
	if inside:
		action_box.add_child(UITheme.button("离开地下城", _leave, 160))
	else:
		var b := UITheme.button("进入地下城", _enter, 160)
		b.disabled = lvl < minl
		if lvl < minl:
			action_box.add_child(UITheme.label("需要达到 %d 级" % minl, 15, Color("ff8060")))
		action_box.add_child(b)

func _enter() -> void:
	var zd: Dictionary = DB.zones[cur]
	if Game.player == null or Game.player.dead:
		return
	if Game.player.in_combat:
		Game.err("你正处于战斗中！")
		return
	if not ResourceLoader.exists(zd["scene"]):
		Game.err("%s尚未开放。" % zd["name"])
		return
	close_window()
	Vfx.column(Game.zone, Game.player.global_position, Color("80b0ff"), 3.0, 0.8)
	Sfx.play("portal")
	Game.world.travel(cur, zd.get("spawn_in", ""))

func _leave() -> void:
	var zd: Dictionary = DB.zones[cur]
	var ent: Array = zd.get("entrance", [])
	if ent.size() < 2:
		return
	close_window()
	Sfx.play("portal")
	Game.world.travel(ent[0], ent[1])
