class_name SpecPanel
extends VBoxContainer
## 转职面板：15 级选择一条道路。每个转职列出被动、特性和授予的主动技能。
## 作为技能书窗口的第二个页签嵌入，见 src/ui/win_spells.gd（文件名沿用旧天赋面板，窗口 id 仍是 "talents"）

var box: VBoxContainer
var status: Label

func _init() -> void:
	add_theme_constant_override("separation", 8)
	status = UITheme.label("", 15, UITheme.GOLD)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(732, 520)
	add_child(sc)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)

func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

func _lines(items: Array) -> String:
	var s := ""
	for it in items:
		s += "  [color=#ffe9a8]%s[/color]：%s\n" % [it.get("name", ""), it.get("desc", "")]
	return s

func refresh() -> void:
	if Game.pd.is_empty():
		return
	_clear(box)
	var cur := Specs.current_id()
	if not Specs.can_choose_level():
		status.text = "转职将在 %d 级开放。" % DataSpecs.CHOOSE_LEVEL
	elif cur == "":
		status.text = "你可以选择一条道路。选定后会立刻获得它的被动与特性。"
	else:
		status.text = "当前：%s。改换转职需要 %s。" % [Specs.current().get("name", ""), U.money_text(Specs.CHANGE_COST)]
	for sd in Specs.options():
		box.add_child(_card(sd, cur))

func _card(sd: Dictionary, cur: String) -> Control:
	var sid: String = sd["id"]
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.sb(Color(0.14, 0.13, 0.1, 0.9) if sid != cur else Color(0.16, 0.14, 0.08, 0.95),
		10, 1, Color(UITheme.GOLD, 0.55) if sid == cur else UITheme.LINE, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var art := IconArt.texture("skills/" + str(sd.get("icon", "")))
	if art != null:
		var ir := TextureRect.new()
		ir.texture = art
		ir.custom_minimum_size = Vector2(44, 44)
		ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head.add_child(ir)
	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text = "[font_size=19][b][color=#%s]%s[/color][/b][/font_size]    [color=#a8adb8]%s[/color]\n[color=#c8c8c8]%s[/color]" % [
		U.color_hex(sd.get("color", UITheme.GOLD)), sd["name"], sd.get("role", ""), sd.get("desc", "")]
	head.add_child(title)
	var why := Specs.can_choose(sid)
	var b := UITheme.button("已转职" if sid == cur else "选择", func():
		Specs.choose(sid)
		refresh(), 96)
	b.disabled = why != ""
	b.tooltip_text = why
	head.add_child(b)
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	var txt := ""
	if sd.has("schools"):
		var names := []
		for s in sd["schools"]:
			names.append({"water": "水", "lightning": "雷", "light": "光", "fire": "火", "frost": "冰", "shadow": "暗"}.get(s, s))
		txt += "[color=#80d0ff]擅长属性：%s[/color]\n" % "、".join(names)
	txt += "[color=#80ff80]被动[/color]\n" + _lines(sd.get("passives", []))
	if not sd.get("traits", []).is_empty():
		txt += "[color=#ffb060]特性[/color]\n" + _lines(sd["traits"])
	if not sd.get("grants", []).is_empty():
		var gn := []
		for g in sd["grants"]:
			gn.append(DB.spell(g).get("name", g))
		txt += "[color=#ffd040]习得技能：[/color]%s\n" % "、".join(gn)
	body.text = txt
	v.add_child(body)
	return pc
