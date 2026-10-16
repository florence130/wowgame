class_name CharWindow
extends UIWindow
## 角色与背包（C / B）：装备栏 + 3D 预览 + 属性 + 背包（180 格，每页 90 格）

const LEFT := ["head", "neck", "back", "chest", "shirt", "tabard", "wrist"]
const RIGHT := ["hands", "waist", "legs", "feet", "finger1", "finger2", "trinket1", "trinket2"]
const BOTTOM := ["main", "off", "ranged"]
const SLOT_ICON := {"head": "head", "neck": "neck", "back": "back", "chest": "chest", "shirt": "shirt", "tabard": "tabard", "wrist": "wrist",
	"hands": "hands", "waist": "waist", "legs": "legs", "feet": "feet", "finger1": "ring", "finger2": "ring", "trinket1": "trinket", "trinket2": "trinket", "main": "sword", "off": "shield", "ranged": "gun"}
var slots := {}
var stats_label: RichTextLabel
var vp: SubViewport
var preview: Avatar
var pivot: Node3D
var _rot_drag := false
var name_label: Label
## 声望条（阵营列表 + 等级与进度）
var rep_box: VBoxContainer
## 背包已并入本窗口：嵌入的 BagWindow（无窗口底与标题，见 UIWindow._init_window 的 embed）
var bag: BagWindow

func _init() -> void:
	_init_window("角色与背包", Vector2(1150, 690), "char")
	name_label = UITheme.label("", 18, UITheme.GOLD, true)
	body.add_child(name_label)
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	body.add_child(main)
	# ---------------------------------------------------------- 左：装备 / 预览 / 属性
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(left)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	left.add_child(h)
	var lv := VBoxContainer.new()
	h.add_child(lv)
	for s in LEFT:
		lv.add_child(_mk(s))
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 6)
	h.add_child(mid)
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(344, 396)
	svc.stretch = true
	svc.gui_input.connect(_on_preview_input)
	mid.add_child(svc)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	svc.add_child(vp)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.95, -3.4)
	cam.fov = 35
	cam.rotation_degrees = Vector3(0, 180, 0)
	vp.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 200, 0)
	light.light_energy = 1.1
	vp.add_child(light)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.92)
	env.ambient_light_energy = 0.8
	we.environment = env
	vp.add_child(we)
	pivot = Node3D.new()
	vp.add_child(pivot)
	var floor_m := MeshInstance3D.new()
	floor_m.mesh = U.cyl_mesh(0.8, 0.8, 0.04, 32)
	floor_m.material_override = U.unshaded(Color(0.9, 0.8, 0.5, 0.35), true)
	vp.add_child(floor_m)
	var rv := VBoxContainer.new()
	h.add_child(rv)
	for s in RIGHT:
		rv.add_child(_mk(s))
	var bh := HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.add_theme_constant_override("separation", 10)
	mid.add_child(bh)
	for s in BOTTOM:
		bh.add_child(_mk(s))
	stats_label = RichTextLabel.new()
	stats_label.bbcode_enabled = true
	stats_label.fit_content = true
	stats_label.scroll_active = false
	stats_label.custom_minimum_size = Vector2(520, 120)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	left.add_child(bottom)
	bottom.add_child(stats_label)
	rep_box = VBoxContainer.new()
	rep_box.add_theme_constant_override("separation", 3)
	rep_box.custom_minimum_size = Vector2(272, 0)
	bottom.add_child(rep_box)
	# ---------------------------------------------------------- 右：背包（嵌入）
	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.08)
	sep.custom_minimum_size = Vector2(1, 0)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.add_child(sep)
	bag = BagWindow.new(true)
	bag.custom_minimum_size = Vector2(520, 0)
	main.add_child(bag)
	Game.equipment_changed.connect(func(): if visible: refresh())
	Game.inventory_changed.connect(func(): if visible: _refresh_stats())
	Game.rep_changed.connect(func(): if visible: _refresh_rep())
	Game.level_up.connect(func(_l): if visible: refresh())

func _mk(s: String) -> Slot:
	var sl := Slot.new()
	sl.kind = "equip"
	sl.slot_name = s
	sl.custom_minimum_size = Vector2(48, 48)
	sl.empty_hint = DataItems.SLOT_NAMES.get(s.trim_suffix("1").trim_suffix("2"), s)
	sl.right_clicked.connect(func(x): Game.unequip(x.slot_name))
	slots[s] = sl
	return sl

func _on_preview_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_rot_drag = ev.pressed
	elif ev is InputEventMouseMotion and _rot_drag:
		pivot.rotation.y += ev.relative.x * 0.01

func refresh() -> void:
	if Game.pd.is_empty():
		return
	var cd: Dictionary = DB.classes[Game.pd["class"]]
	name_label.text = "%s    %d级 %s" % [Game.pd["name"], Game.pd["level"], cd["name"]]
	for s in slots:
		var id = Game.pd["equip"].get(s)
		var sl: Slot = slots[s]
		if id == null:
			sl.set_item("")
			sl.icon = ""
		else:
			sl.set_item(id)
			sl.dim = false
	if preview:
		preview.queue_free()
	preview = Avatar.new()
	pivot.add_child(preview)
	preview.setup(Game.pd["app"], Game.gear_visuals())
	preview.set_combat_ready(false)
	if bag:
		bag.refresh()
	_refresh_stats()
	_refresh_rep()

func _process(delta: float) -> void:
	if visible and preview:
		preview.animate(delta, {})

## 声望：每个阵营一行（名称 + 等级 + 进度条 + 数值），未接触过的阵营显示为中立 0
func _refresh_rep() -> void:
	for c in rep_box.get_children():
		rep_box.remove_child(c)
		c.queue_free()
	var hdr := UITheme.label("声望", 16, UITheme.GOLD, true)
	rep_box.add_child(hdr)
	for fid in DataRep.factions():
		var pr := Rep.progress(fid)
		var t := Rep.tier(fid)
		var col := DataRep.tier_color(t)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 6)
		rep_box.add_child(top)
		var nm := UITheme.label(Rep.faction_name(fid), 14, Rep.faction_color(fid))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(nm)
		var tn := UITheme.label(DataRep.tier_name(t), 14, col, t > 0)
		top.add_child(tn)
		var bar := UITheme.bar(col, 7)
		bar.max_value = pr.y
		bar.value = pr.x
		rep_box.add_child(bar)
		var num := UITheme.label("%d / %d" % [int(pr.x), int(pr.y)], 12, UITheme.TEXT_DIM)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rep_box.add_child(num)

func _refresh_stats() -> void:
	var p: Player = Game.player
	if p == null:
		return
	var s := p.stats
	var t := "[table=4]"
	var rows := [
		["生命值", "%d" % p.max_hp], [{"mana": "法力值", "rage": "怒气", "energy": "能量"}[p.power_type], "%d" % p.max_power],
		["力量", "%d" % s.get("str", 0)], ["敏捷", "%d" % s.get("agi", 0)], ["耐力", "%d" % s.get("sta", 0)], ["智力", "%d" % s.get("int", 0)],
		["精神", "%d" % s.get("spi", 0)], ["护甲", "%d" % s.get("armor", 0)], ["攻击强度", "%d" % s.get("ap", 0)], ["远程攻击强度", "%d" % s.get("rap", 0)],
		["法术强度", "%d" % s.get("sp", 0)], ["致命一击", "%.1f%%" % s.get("crit", 0)], ["法术暴击", "%.1f%%" % s.get("spell_crit", 0)], ["躲闪", "%.1f%%" % s.get("dodge", 0)],
		["武器伤害", "%d-%d" % [int(p.wdmg.x + s.get("ap", 0) / 14.0 * p.wspeed), int(p.wdmg.y + s.get("ap", 0) / 14.0 * p.wspeed)]], ["攻击速度", "%.2f" % p.wspeed],
	]
	for r in rows:
		t += "[cell][color=#a8adb8]%s[/color]  [/cell][cell][b]%s[/b]      [/cell]" % [r[0], r[1]]
	t += "[/table]"
	stats_label.text = t
