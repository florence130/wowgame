class_name SpellbookWindow
extends UIWindow
## 技能书与转职（P / N）：同一窗口的两个页签。技能页拖动图标到动作条；转职页见 SpecPanel。

var tab := "spells"
var grid: GridContainer
var hint: Label
var tab_hint: Label
var tab_btns := {}
var spells_page: VBoxContainer
var talents: SpecPanel

func _init() -> void:
	_init_window("技能与转职", Vector2(772, 700), "spells")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	body.add_child(tabs)
	for e in [["spells", "技能"], ["talents", "转职"]]:
		var b := UITheme.tab_button(e[1], e[0] == tab)
		b.custom_minimum_size.x = 126
		b.focus_mode = Control.FOCUS_NONE
		var key: String = e[0]
		b.pressed.connect(func(): set_tab(key))
		tabs.add_child(b)
		tab_btns[e[0]] = b
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(sp)
	tab_hint = UITheme.label("", 15, UITheme.GOLD)
	tab_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tabs.add_child(tab_hint)
	# ---------------------------------------------------------- 技能页
	spells_page = VBoxContainer.new()
	spells_page.add_theme_constant_override("separation", 6)
	spells_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spells_page)
	hint = UITheme.label("拖动技能图标到动作条上使用。去职业训练师处学习新技能与更高等级。", 14, UITheme.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spells_page.add_child(hint)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(740, 540)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	spells_page.add_child(sc)
	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(grid)
	# ---------------------------------------------------------- 天赋页
	talents = SpecPanel.new()
	talents.visible = false
	talents.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(talents)
	Game.spells_changed.connect(func(): if visible: refresh())
	Game.level_up.connect(func(_l): if visible: refresh())

## 切换页签："spells" / "talents"
func set_tab(t: String) -> void:
	tab = t if t in ["spells", "talents"] else "spells"
	refresh()

func refresh() -> void:
	if Game.pd.is_empty():
		return
	for k in tab_btns:
		tab_btns[k].button_pressed = k == tab
	spells_page.visible = tab == "spells"
	talents.visible = tab == "talents"
	tab_hint.text = Specs.current().get("name", "") if Specs.current_id() != "" else ("%d 级可转职" % DataSpecs.CHOOSE_LEVEL)
	if tab == "spells":
		_refresh_spells()
	else:
		talents.refresh()

func _refresh_spells() -> void:
	hint.tooltip_text = Specs.current().get("desc", DB.classes[Game.pd["class"]].get("rotation", ""))
	for c in grid.get_children():
		c.queue_free()
	var ids := ["dodge_roll"]
	if DB.classes[Game.pd["class"]].get("melee", false) or Specs.current_id() == "shadow_priest":
		ids.push_front("attack")
	for sid in DB.classes[Game.pd["class"]]["spells"]:
		if Game.pd["spells"].has(sid):
			ids.append(sid)
	for sid in Game.pd["spells"]:
		if not sid in ids:
			ids.append(sid)
	for sid in ids:
		if not Specs.spell_allowed(str(sid), Specs.current_id()):
			continue
		var h := HBoxContainer.new()
		h.custom_minimum_size = Vector2(340, 54)
		var s := Slot.new()
		s.kind = "spell"
		s.set_spell(sid)
		s.left_clicked.connect(func(sl): Game.player.cast_spell_id(sl.spell_id))
		h.add_child(s)
		var v := VBoxContainer.new()
		var sp := DB.spell(sid, maxi(1, Game.spell_rank(sid)))
		v.add_child(UITheme.label(sp.get("name", sid), 17, UITheme.TEXT, true))
		var rk := Game.spell_rank(sid)
		v.add_child(UITheme.label("等级 %d" % rk if sp.get("max_rank", 1) > 1 else "", 13, UITheme.TEXT_DIM))
		h.add_child(v)
		grid.add_child(h)
