class_name QuestLogWindow
extends UIWindow
## 任务日志

var list: VBoxContainer
var detail: RichTextLabel
var selected := ""
var abandon_btn: Button
var rewards_box: HFlowContainer

func _init() -> void:
	_init_window("任务日志", Vector2(820, 600), "quests")
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 10)
	body.add_child(h)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(290, 500)
	h.add_child(sc)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var rv := VBoxContainer.new()
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(rv)
	var sc2 := ScrollContainer.new()
	sc2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc2.custom_minimum_size = Vector2(480, 420)
	rv.add_child(sc2)
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc2.add_child(dv)
	detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.fit_content = true
	detail.scroll_active = false
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.add_child(detail)
	rewards_box = HFlowContainer.new()
	dv.add_child(rewards_box)
	abandon_btn = UITheme.button("放弃任务", func(): if selected != "": Game.abandon_quest(selected); selected = ""; refresh())
	rv.add_child(abandon_btn)
	Game.quest_log_changed.connect(func(): if visible: refresh())

func select(qid: String) -> void:
	selected = qid
	refresh()

func refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	var qs: Dictionary = Game.pd["quests"]
	if selected == "" or not qs.has(selected):
		selected = qs.keys()[0] if qs.size() > 0 else ""
	title_label.text = "任务日志 (%d/25)" % qs.size()
	for qid in qs:
		var q: Dictionary = DB.quests[qid]
		var b := UITheme.tab_button("[%d] %s%s" % [q["lvl"], q["name"], " ✔" if Game.is_quest_complete(qid) else ""], qid == selected)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", _lvl_color(q["lvl"]))
		var id: String = qid
		b.pressed.connect(func(): selected = id; refresh())
		list.add_child(b)
	for c in rewards_box.get_children():
		c.queue_free()
	if selected == "":
		detail.text = "[color=#a8adb8]你的任务日志是空的。去找头顶有黄色「!」的人物吧。[/color]"
		abandon_btn.visible = false
		return
	abandon_btn.visible = true
	detail.text = NpcWindow.quest_bb(selected, true)
	NpcWindow.fill_rewards(rewards_box, selected, false, null)

func _lvl_color(l: int) -> Color:
	var d = l - Game.pd["level"]
	if d >= 5: return Color("ff4040")
	if d >= 3: return Color("ff9030")
	if d >= -2: return Color("ffff40")
	if d >= -6: return Color("40ff40")
	return Color("a0a0a0")
