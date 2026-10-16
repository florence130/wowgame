class_name TransmogWindow
extends UIWindow
## 幻化：把已装备物品的外观替换为衣柜（pd.appearances）里收集到的外观
## 规则：护甲须同类型（布/皮/锁）；武器须同手持方式且同一武器族；头/肩/背/衬衣/战袍可隐藏

const COST := 100
const SLOTS := [["head", "头部"], ["back", "背部"], ["chest", "胸部"], ["shirt", "衬衣"], ["tabard", "战袍"],
	["wrist", "手腕"], ["hands", "手"], ["waist", "腰部"], ["legs", "腿部"], ["feet", "脚"], ["main", "主手"], ["off", "副手"], ["ranged", "远程"]]
const HIDEABLE := ["head", "back", "shirt", "tabard"]
const ARMOR := ["cloth", "leather", "mail", "plate"]
const WEAPON_FAMILY := {"sword": "one", "axe": "one", "mace": "one", "dagger": "dagger", "sword2": "two", "axe2": "two", "mace2": "two",
	"staff": "staff", "polearm": "polearm", "gun": "ranged", "bow": "ranged", "shield": "shield", "offhand": "offhand"}

var service_npc: NPC = null
var cur := "chest"
var slot_btns := {}
var head_info: RichTextLabel
var grid: GridContainer
var hide_btn: Button
var reset_btn: Button
var footer: RichTextLabel

func _init() -> void:
	_init_window("幻化", Vector2(720, 600), "transmog")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(h)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 3)
	h.add_child(left)
	for e in SLOTS:
		var b := UITheme.tab_button(e[1], e[0] == cur)
		b.custom_minimum_size = Vector2(110, 34)
		var key: String = e[0]
		b.pressed.connect(func(): _select(key))
		left.add_child(b)
		slot_btns[key] = b
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	h.add_child(right)
	head_info = RichTextLabel.new()
	head_info.bbcode_enabled = true
	head_info.fit_content = true
	head_info.scroll_active = false
	right.add_child(head_info)
	var btns := HBoxContainer.new()
	right.add_child(btns)
	reset_btn = UITheme.button("恢复原样", _reset)
	btns.add_child(reset_btn)
	hide_btn = UITheme.button("隐藏此部位", _hide)
	btns.add_child(hide_btn)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(540, 380)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc)
	grid = GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	sc.add_child(grid)
	footer = RichTextLabel.new()
	footer.bbcode_enabled = true
	footer.fit_content = true
	footer.scroll_active = false
	right.add_child(footer)
	Game.equipment_changed.connect(func(): if visible: refresh())
	Game.money_changed.connect(func(): if visible: refresh())

func _process(_d: float) -> void:
	if visible and service_npc != null:
		if not is_instance_valid(service_npc) or not service_npc.is_inside_tree() or Game.player == null or not Game.player.is_inside_tree() \
				or Game.player.global_position.distance_to(service_npc.global_position) > 9.0:
			close_window()

func _select(s: String) -> void:
	cur = s
	for k in slot_btns:
		slot_btns[k].button_pressed = k == s
	refresh()

static func eligible(slot: String, app_id: String) -> bool:
	var eq_id = Game.pd["equip"].get(slot)
	if eq_id == null or app_id == eq_id:
		return false
	var eq := DB.get_item(eq_id)
	var ap := DB.get_item(app_id)
	if ap.is_empty() or ap.get("equip", "") != eq.get("equip", ""):
		return false
	if slot in ["main", "off", "ranged"]:
		return ap.get("slot", "") == eq.get("slot", "") and WEAPON_FAMILY.get(ap.get("type", ""), "?") == WEAPON_FAMILY.get(eq.get("type", ""), "!")
	var t: String = eq.get("type", "")
	if t in ARMOR and slot != "back":
		return ap.get("type", "") == t
	return true

## 装备变化后清理失效的幻化
static func validate() -> void:
	var tm: Dictionary = Game.pd.get("tmog", {})
	for s in tm.keys():
		if tm[s] == "hidden":
			continue
		if not eligible(s, tm[s]):
			tm.erase(s)

func refresh() -> void:
	if Game.pd.is_empty():
		return
	if not Game.pd.has("tmog"):
		Game.pd["tmog"] = {}
	var tm: Dictionary = Game.pd["tmog"]
	var eq_id = Game.pd["equip"].get(cur)
	var name := ""
	for e in SLOTS:
		if e[0] == cur:
			name = e[1]
	var t := "[font_size=19][b]%s[/b][/font_size]\n" % name
	if eq_id == null:
		t += "[color=#a8adb8]这个部位没有装备，无法幻化。[/color]"
	else:
		var it := DB.get_item(eq_id)
		t += "已装备：[color=#%s]%s[/color]\n" % [U.color_hex(U.quality_color(it.get("q", 1))), it["name"]]
		var cur_tm = tm.get(cur)
		if cur_tm == "hidden":
			t += "当前外观：[color=#ffb060]已隐藏[/color]"
		elif cur_tm != null:
			var ti := DB.get_item(cur_tm)
			t += "当前外观：[color=#%s]%s[/color]" % [U.color_hex(U.quality_color(ti.get("q", 1))), ti.get("name", "?")]
		else:
			t += "当前外观：[color=#a8adb8]原样[/color]"
	head_info.text = t
	reset_btn.disabled = not tm.has(cur)
	hide_btn.visible = cur in HIDEABLE
	hide_btn.disabled = eq_id == null or tm.get(cur) == "hidden"
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	var n := 0
	if eq_id != null:
		var ids: Array = Game.pd.get("appearances", {}).keys()
		ids.sort_custom(func(a, b): return DB.get_item(a).get("q", 1) > DB.get_item(b).get("q", 1))
		for id in ids:
			if not eligible(cur, id):
				continue
			var s := Slot.new()
			s.kind = "info"
			s.custom_minimum_size = Vector2(54, 54)
			s.set_item(id)
			if tm.get(cur) == id:
				s.modulate = Color(1.0, 0.95, 0.6)
			var aid: String = id
			s.left_clicked.connect(func(_sl): _apply(aid))
			grid.add_child(s)
			n += 1
	var msg := "衣柜中可用于此部位的外观：%d 件。点击外观即可幻化，每次 %s。" % [n, U.money_bb(COST)]
	if n == 0 and eq_id != null:
		msg = "[color=#a8adb8]衣柜里还没有同类型的外观。获得过的装备都会自动收入衣柜。[/color]"
	footer.text = msg + "\n[right]%s[/right]" % U.money_bb(Game.pd["money"])

func _apply(id: String) -> void:
	if Game.pd["money"] < COST:
		Game.err("你没有足够的钱。")
		return
	Game.add_money(-COST, true)
	Game.pd["tmog"][cur] = id
	_after()
	Game.msg("幻化成功：%s → %s" % [DB.get_item(Game.pd["equip"][cur])["name"], DB.get_item(id)["name"]], Color("ff90e0"))

func _hide() -> void:
	Game.pd["tmog"][cur] = "hidden"
	_after()

func _reset() -> void:
	Game.pd["tmog"].erase(cur)
	_after()

func _after() -> void:
	Sfx.play("learn")
	if Game.player:
		Game.player.refresh_visuals()
		Vfx.burst(Game.zone, Game.player.global_position + Vector3(0, 1, 0), Color("ff90e0"), 1.2)
	Game.appearance_changed.emit()
	refresh()
