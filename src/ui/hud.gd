class_name HUD
extends Control
## 主界面：头像框、动作条、施法条、经验条、聊天框、小地图、任务追踪、名牌、窗口管理

var player_frame: UnitFrame
var job_gauge: Control
var target_frame: UnitFrame
var tot_frame: UnitFrame
var pet_frame: UnitFrame
var party_box: VBoxContainer
var party_frames := {}
var bar_slots: Array[Slot] = []
var cast_bar: ProgressBar
var cast_label: Label
var cast_panel: PanelContainer
var xp_bar: ProgressBar
var xp_label: Label
var chat: RichTextLabel
var chat_input: LineEdit
var minimap: Minimap
var zone_label: Label
var clock_label: Label
var coord_label: Label
var tracker: VBoxContainer
var buff_box: HFlowContainer
var target_buffs: HFlowContainer
var error_label: Label
var center_label: Label
var center_sub: Label
var nameplates: Nameplates
var windows_layer: Control
var money_label: RichTextLabel
var bag_btn_label: Label
var mail_btn: Button
var fps_label: Label
var combo_box: HBoxContainer
var target_cast: ProgressBar
var progress_label: Label
var rested_label: Label
var _error_t := 0.0
var _center_t := 0.0
var _progress_t := 0.0
var _cast_fade := 0.0
var win := {}
var death_panel: PanelContainer
var loot_win: UIWindow
var ui_hidden := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.build()
	nameplates = Nameplates.new()
	add_child(nameplates)
	_build_frames()
	_build_bars()
	_build_chat()
	_build_minimap()
	_build_tracker()
	_build_misc()
	windows_layer = Control.new()
	windows_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	windows_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(windows_layer)
	_build_windows()
	var fx := UIFx.new()
	fx.name = "UIFx"
	add_child(fx)
	fx.build_toasts(self)
	_connect()

func _connect() -> void:
	Game.chat.connect(add_chat)
	Game.error_text.connect(show_error)
	Game.center_text.connect(show_center)
	Game.target_changed.connect(func(u): target_frame.set_unit(u); _refresh_target_buffs())
	Game.xp_changed.connect(_refresh_xp)
	Game.level_up.connect(func(_l): _refresh_xp(); _refresh_bars())
	Game.money_changed.connect(_refresh_money)
	Game.inventory_changed.connect(_refresh_money)
	Game.mail_changed.connect(_refresh_mail_badge)
	Game.inventory_changed.connect(_refresh_bars)
	Game.bars_changed.connect(_refresh_bars)
	Game.spells_changed.connect(_refresh_bars)
	Game.quest_log_changed.connect(_refresh_tracker)
	Game.quest_progress.connect(func(_q, t): show_progress(t); UIFx.inst.toast(t, Color("ffd860")))
	Game.item_looted.connect(func(id, n):
		var it := DB.get_item(id)
		UIFx.inst.toast("%s%s" % [it.get("name", "?"), (" ×%d" % n) if n > 1 else ""], U.quality_color(it.get("q", 1)), id, n))
	Game.subzone_changed.connect(func(s): _refresh_zone_label())

func on_zone_loaded() -> void:
	var p: Player = Game.player
	player_frame.set_unit(p)
	if not p.auras_changed.is_connected(_refresh_buffs):
		p.auras_changed.connect(_refresh_buffs)
		p.cast_started.connect(_on_cast_start)
		p.cast_stopped.connect(_on_cast_stop)
	minimap.build_from_zone(Game.zone)
	if win.has("map"):
		win["map"].build_from_zone(Game.zone)
	_refresh_all()

func _refresh_all() -> void:
	_refresh_xp()
	_refresh_money()
	_refresh_mail_badge()
	_refresh_bars()
	_refresh_tracker()
	_refresh_buffs()
	_refresh_zone_label()

# ================================================================ 头像框
func _build_frames() -> void:
	player_frame = UnitFrame.new()
	player_frame.is_player_frame = true
	player_frame.horizontal_resources = true
	player_frame.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	player_frame.custom_minimum_size = Vector2(576, 54)
	player_frame.offset_left = -288
	player_frame.offset_right = 288
	player_frame.offset_top = -86
	player_frame.offset_bottom = -32
	add_child(player_frame)
	job_gauge = preload("res://src/ui/job_gauge.gd").new()
	job_gauge.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	job_gauge.offset_left = -620
	job_gauge.offset_right = -360
	job_gauge.offset_top = -466
	job_gauge.offset_bottom = -242
	add_child(job_gauge)
	target_frame = UnitFrame.new()
	target_frame.position = Vector2(420, 18)
	add_child(target_frame)
	tot_frame = UnitFrame.new()
	tot_frame.small = true
	tot_frame.position = Vector2(800, 50)
	add_child(tot_frame)
	pet_frame = UnitFrame.new()
	pet_frame.small = true
	pet_frame.position = Vector2(20, 78)
	add_child(pet_frame)
	party_box = VBoxContainer.new()
	party_box.position = Vector2(20, 144)
	party_box.add_theme_constant_override("separation", 6)
	add_child(party_box)
	buff_box = HFlowContainer.new()
	buff_box.position = Vector2(1300, 22)
	buff_box.size = Vector2(330, 120)
	buff_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	buff_box.offset_left = -620
	buff_box.offset_right = -290
	buff_box.offset_top = 22
	buff_box.alignment = FlowContainer.ALIGNMENT_END
	buff_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(buff_box)
	target_buffs = HFlowContainer.new()
	target_buffs.position = Vector2(420, 128)
	target_buffs.size = Vector2(360, 40)
	target_buffs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(target_buffs)
	target_cast = UITheme.bar(Color("e0a040"), 14)
	target_cast.position = Vector2(470, 170)
	target_cast.size = Vector2(300, 14)
	target_cast.visible = false
	add_child(target_cast)
	combo_box = HBoxContainer.new()
	combo_box.position = Vector2(560, 112)
	combo_box.add_theme_constant_override("separation", 4)
	add_child(combo_box)

func _process(delta: float) -> void:
	if Game.player == null or not is_instance_valid(Game.player):
		return
	var p: Player = Game.player
	# 目标的目标
	var t: Unit = p.target if p.target and is_instance_valid(p.target) else null
	var tot: Unit = null
	if t and t.target and is_instance_valid(t.target) and not t.dead:
		tot = t.target
	if tot_frame.unit != tot:
		tot_frame.set_unit(tot)
	# 宠物
	var pet := p.pet if p.pet and is_instance_valid(p.pet) else null
	if pet_frame.unit != pet:
		pet_frame.set_unit(pet)
	_update_party()
	# 目标施法条
	if t and t.is_casting():
		target_cast.visible = true
		target_cast.max_value = t.casting["total"]
		target_cast.value = t.casting["elapsed"] if not t.casting["channel"] else t.casting["total"] - t.casting["elapsed"]
	else:
		target_cast.visible = false
	# 连击点
	_update_combo(p)
	# 施法条
	if p.is_casting():
		var c := p.casting
		cast_panel.visible = true
		cast_panel.modulate.a = 1.0
		cast_bar.max_value = c["total"]
		cast_bar.value = c["elapsed"] if not c["channel"] else c["total"] - c["elapsed"]
		cast_label.text = "%s  %.1f" % [c["sp"]["name"], maxf(0.0, c["total"] - c["elapsed"])]
	elif _cast_fade > 0.0:
		_cast_fade -= delta
		cast_panel.modulate.a = clampf(_cast_fade / 0.4, 0.0, 1.0)
		if _cast_fade <= 0.0:
			cast_panel.visible = false
	# 动作条冷却
	for s in bar_slots:
		_update_slot_cd(s, p)
	# 文字提示
	if _error_t > 0.0:
		_error_t -= delta
		error_label.modulate.a = clampf(_error_t, 0.0, 1.0)
	if _center_t > 0.0:
		_center_t -= delta
		var a := clampf(_center_t, 0.0, 1.0)
		center_label.modulate.a = a
		center_sub.modulate.a = a
	if _progress_t > 0.0:
		_progress_t -= delta
		progress_label.modulate.a = clampf(_progress_t, 0.0, 1.0)
	# 时钟与坐标
	var tod := Game.time_of_day
	clock_label.text = "%s %02d:%02d" % ["☀" if tod >= 6.0 and tod < 19.0 else "☾", int(tod), int(fmod(tod, 1.0) * 60.0)]
	if Game.zone and Game.zone.terrain and p.is_inside_tree():
		var s: float = Game.zone.terrain.data.world_size()
		var o: Vector3 = Game.zone.terrain.global_position
		coord_label.text = "%.1f, %.1f" % [(p.global_position.x - o.x) / s * 100.0, (p.global_position.z - o.z) / s * 100.0]
	if fps_label.visible:
		fps_label.text = "FPS %d" % Engine.get_frames_per_second()
	if Engine.get_process_frames() % 15 == 0:
		_refresh_buff_times()

func _update_party() -> void:
	var allies := get_tree().get_nodes_in_group("allies")
	for a in allies:
		if a.role == "pet":
			continue
		if not party_frames.has(a):
			var f := UnitFrame.new()
			f.small = true
			f.custom_minimum_size = Vector2(260, 52)
			party_box.add_child(f)
			f.set_unit(a)
			party_frames[a] = f
	for k in party_frames.keys():
		if not is_instance_valid(k):
			party_frames[k].queue_free()
			party_frames.erase(k)

func _update_combo(p: Player) -> void:
	var want := p.combo if (p.power_type == "energy" and p.combo_target == p.target and p.target != null) else 0
	if Game.pd["class"] != "rogue" or p.spec != "":
		combo_box.visible = false
		return
	combo_box.visible = true
	if combo_box.get_child_count() != 5:
		for i in 5:
			var r := Panel.new()
			r.custom_minimum_size = Vector2(16, 16)
			combo_box.add_child(r)
	for i in 5:
		var pnl: Panel = combo_box.get_child(i)
		pnl.add_theme_stylebox_override("panel", UITheme.sb(Color("ffcf30") if i < want else Color(0.1, 0.1, 0.15, 0.8), 8, 1, Color(1, 1, 1, 0.3), 0))

# ================================================================ 动作条
func _build_bars() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	root.name = "ActionBars"
	root.offset_left = -288
	root.offset_right = 288
	root.offset_top = -178
	root.offset_bottom = -67
	root.add_theme_constant_override("separation", 3)
	add_child(root)
	# 经验条
	var xpw := Control.new()
	xpw.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	xpw.offset_left = -288
	xpw.offset_right = 288
	xpw.offset_top = -22
	xpw.offset_bottom = -12
	add_child(xpw)
	xp_bar = UITheme.bar(UITheme.SP, 10)
	xp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	xp_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	xpw.add_child(xp_bar)
	xp_label = UITheme.label("", 12, Color.WHITE)
	xp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_label.add_theme_constant_override("outline_size", 2)
	xpw.add_child(xp_label)
	var xp_title := UITheme.label("经验", 10, Color.WHITE)
	xp_title.position = Vector2(1, -13)
	xp_title.add_theme_constant_override("outline_size", 2)
	xp_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xpw.add_child(xp_title)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.sb(Color(0.09, 0.085, 0.075, 0.45), 2, 1, Color(0.72, 0.64, 0.49, 0.25), 5))
	root.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	panel.add_child(rows)
	for r in 2:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 3)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		rows.add_child(h)
		for i in 12:
			var s := Slot.new()
			s.kind = "bar"
			s.index = (1 - r) * 12 + i
			s.custom_minimum_size = Vector2(44, 44)
			s.corner = 2
			s.left_clicked.connect(func(sl): Game.player.use_bar_slot(sl.index))
			s.right_clicked.connect(func(sl): Game.player.use_bar_slot(sl.index))
			h.add_child(s)
			bar_slots.append(s)
	bar_slots.sort_custom(func(a, b): return a.index < b.index)

func _refresh_bars() -> void:
	if Game.pd.is_empty():
		return
	var names := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="]
	for s in bar_slots:
		var b = Game.pd["bars"][s.index]
		s.hotkey = names[s.index % 12] if s.index < 12 else "S" + names[s.index % 12]
		if b == null:
			s.set_spell("")
			s.set_item("")
		elif b["t"] == "spell":
			s.set_spell(b["id"])
		else:
			s.set_item(b["id"], Game.count_item(b["id"]))
			s.dim = Game.count_item(b["id"]) == 0

func _update_slot_cd(s: Slot, p: Player) -> void:
	var b = Game.pd["bars"][s.index]
	if b == null:
		if s.cooldown != 0.0:
			s.cooldown = 0.0
		return
	var frac := 0.0
	var txt := ""
	if b["t"] == "spell":
		var sid: String = b["id"]
		var sp: Dictionary = DB.spells.get(sid, {})
		var remaining := p.cooldown_remaining(sp)
		if remaining > 0.0:
			var r := DB.spell(sid, Game.spell_rank(sid))
			var tot: float = r.get("cd", 1.0)
			frac = clampf(remaining / maxf(tot, 0.1), 0.0, 1.0)
			if remaining > 1.6:
				txt = U.time_text(remaining)
		elif p.gcd > 0.0 and sp.get("gcd", 1.5) > 0.0:
			frac = p.gcd / maxf(p.gcd_total, 0.1)
		var usable := true
		var r2 := DB.spell(sid, maxi(1, Game.spell_rank(sid)))
		usable = Specs.spell_allowed(sid, p.spec)
		var requirements: Dictionary = r2.get("requires", {})
		if requirements.has("stamina_min") and p.stamina < float(requirements["stamina_min"]) + p.dodge_streak * 20:
			usable = false
		if requirements.has("has_aura_self") and p.get_aura(requirements["has_aura_self"]).is_empty():
			usable = false
		if requirements.has("no_aura_self") and not p.get_aura(requirements["no_aura_self"]).is_empty():
			usable = false
		if requirements.get("shield", false) and not p._has_shield():
			usable = false
		if requirements.has("weapon") and p._main_weapon_type() != requirements["weapon"]:
			usable = false
		if requirements.get("dual_daggers", false) and (p._main_weapon_type() != "dagger" or p._off_weapon_type() != "dagger"):
			usable = false
		usable = usable and p._can_pay(r2)
		for key in requirements.get("gauge_min", {}):
			if p.gauge(str(key)) < float(requirements["gauge_min"][key]): usable = false
		for key in r2.get("requires", {}).get("gauge_max", {}):
			if p.gauge(str(key)) > float(r2["requires"]["gauge_max"][key]):
				usable = false
		var resource_cost: Variant = r2.get("cost", 0)
		if resource_cost is Dictionary:
			for resource in resource_cost:
				if resource == "stamina" and float(resource_cost[resource]) > p.stamina + 0.01:
					usable = false
				elif resource == p.spec_resource_type and float(resource_cost[resource]) > p.spec_resource + 0.01:
					usable = false
				elif resource == p.power_type and float(resource_cost[resource]) > p.power + 0.01:
					usable = false
		elif float(resource_cost) > p.power + 0.01 and p.max_power > 0.0:
			usable = false
		var rng_ok := true
		if p.target and is_instance_valid(p.target) and r2.get("target", "") == "enemy" and not p.target.dead and p.is_enemy(p.target):
			rng_ok = p.edge_dist(p.target) <= p.spell_range(r2)
		s.dim = not usable or not rng_ok
		s.highlight = (sid == "attack" and p.auto_attack) or (sid == "auto_shot" and p.auto_shoot) or (not p.next_melee.is_empty() and p.next_melee.get("id", "") == sid) or (not p.get_aura(sid).is_empty() and r2.get("effects", [{}])[0].get("aura", {}).get("toggle", false))
		var proc: String = {"pd_shield_bash": "pd_oath", "pd_radiant_strike": "pd_counter", "bk_rend_slash": "bk_flow", "el_water_bolt": "el_return", "cl_light_guard": "cl_afterglow", "cl_radiant_mend": "cl_afterglow", "ms_arcane_edge": "ms_shadow_edge", "ms_shadow_bolt": "ms_echo", "as_venomous_cut": "as_edge", "cannon_steady": "cannon_breach", "mech_piston": "mech_cooled"}.get(sid, "")
		if proc != "" and usable and remaining <= 0.0:
			s.highlight = not p.get_aura(proc).is_empty()
	else:
		if Game.item_cooldowns.has("potion") and DB.get_item(b["id"]).get("type", "") == "potion":
			frac = Game.item_cooldowns["potion"] / 120.0
			txt = U.time_text(Game.item_cooldowns["potion"])
		elif b["id"] == "hearthstone" and p.cooldowns.has("hearthstone_cast"):
			frac = p.cooldowns["hearthstone_cast"] / 300.0
			txt = U.time_text(p.cooldowns["hearthstone_cast"])
	if absf(s.cooldown - frac) > 0.003:
		s.cooldown = frac
	if s.cd_text != txt:
		s.cd_text = txt

func flash_bar(i: int) -> void:
	for s in bar_slots:
		if s.index == i:
			var tw := s.create_tween()
			s.modulate = Color(1.6, 1.5, 1.1)
			tw.tween_property(s, "modulate", Color.WHITE, 0.25)

# ================================================================ 施法条/经验
func _build_misc() -> void:
	cast_panel = PanelContainer.new()
	cast_panel.add_theme_stylebox_override("panel", UITheme.sb(Color(0.05, 0.06, 0.1, 0.85), 10, 1, Color(UITheme.GOLD, 0.4), 4))
	cast_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cast_panel.offset_left = -190
	cast_panel.offset_right = 190
	cast_panel.offset_top = -250
	cast_panel.offset_bottom = -216
	cast_panel.visible = false
	add_child(cast_panel)
	var cw := Control.new()
	cw.custom_minimum_size = Vector2(370, 24)
	cast_panel.add_child(cw)
	cast_bar = UITheme.bar(Color("f0c040"), 24)
	cast_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cw.add_child(cast_bar)
	cast_label = UITheme.label("", 15, Color.WHITE)
	cast_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cast_label.add_theme_constant_override("outline_size", 4)
	cw.add_child(cast_label)
	error_label = UITheme.label("", 22, Color("ff4a3a"), true)
	error_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	error_label.offset_left = -400
	error_label.offset_right = 400
	error_label.offset_top = 170
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.add_theme_constant_override("outline_size", 6)
	error_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(error_label)
	center_label = UITheme.label("", 46, Color("ffd76a"), true)
	center_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	center_label.offset_left = -500
	center_label.offset_right = 500
	center_label.offset_top = 230
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.add_theme_constant_override("outline_size", 10)
	center_label.add_theme_color_override("font_outline_color", Color(0.25, 0.15, 0.0, 0.9))
	center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_label)
	center_sub = UITheme.label("", 24, Color("fff2c8"), false)
	center_sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	center_sub.offset_left = -500
	center_sub.offset_right = 500
	center_sub.offset_top = 296
	center_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_sub.add_theme_constant_override("outline_size", 6)
	center_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_sub)
	progress_label = UITheme.label("", 20, Color("ffe060"), false)
	progress_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	progress_label.offset_left = -400
	progress_label.offset_right = 400
	progress_label.offset_top = 205
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_constant_override("outline_size", 6)
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(progress_label)
	# 右下：菜单按钮与金钱
	var br := VBoxContainer.new()
	br.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br.name = "MicroMenu"
	br.offset_left = -448
	br.offset_top = -92
	br.offset_right = -16
	br.offset_bottom = -50
	br.alignment = BoxContainer.ALIGNMENT_END
	add_child(br)
	var mrow := HBoxContainer.new()
	mrow.name = "MoneyAndBag"
	mrow.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mrow.offset_left = -448
	mrow.offset_right = -16
	mrow.offset_top = -36
	mrow.offset_bottom = -12
	add_child(mrow)
	money_label = RichTextLabel.new()
	money_label.bbcode_enabled = true
	money_label.fit_content = true
	money_label.scroll_active = false
	money_label.custom_minimum_size = Vector2(260, 24)
	money_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mrow.add_child(money_label)
	bag_btn_label = UITheme.label("", 12, UITheme.TEXT_DIM)
	bag_btn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mrow.add_child(bag_btn_label)
	var micro := HBoxContainer.new()
	micro.alignment = BoxContainer.ALIGNMENT_END
	micro.add_theme_constant_override("separation", 2)
	br.add_child(micro)
	for e in [["角色", "C", "char"], ["背包", "B", "bag"], ["技能", "P", "spells"], ["转职", "N", "talents"], ["成就", "Y", "achiev"], ["坐骑", "J", "mounts"], ["邮箱", "O", "mail"], ["专业", "K", "prof"], ["任务", "L", "quests"], ["副本", "I", "dungeon"], ["地图", "M", "map"], ["菜单", "Esc", "menu"]]:
		var b := Button.new()
		b.text = e[0]
		b.tooltip_text = "%s (%s)" % ["地下城查找器" if e[2] == "dungeon" else e[0], e[1]]
		b.custom_minimum_size = Vector2(34, 34)
		IconArt.decorate_button(b, e[2], e[0], true)
		b.focus_mode = Control.FOCUS_NONE
		var id: String = e[2]
		b.pressed.connect(func(): Sfx.play("click"); toggle_window(id))
		micro.add_child(b)
		if id == "mail":
			mail_btn = b
	fps_label = UITheme.label("", 13, UITheme.TEXT_DIM)
	fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fps_label.offset_left = -360
	fps_label.offset_top = 2
	fps_label.visible = Game.settings.get("show_fps", true)
	add_child(fps_label)
	rested_label = UITheme.label("", 12, Color("80b0ff"))

func _on_cast_start(_name: String, _total: float, _ch: bool) -> void:
	cast_bar.add_theme_stylebox_override("fill", UITheme.sb(Color("f0c040") if not _ch else Color("70d070"), 4, 0, UITheme.LINE, 0))
	cast_panel.visible = true

func _on_cast_stop(success: bool) -> void:
	_cast_fade = 0.4
	if not success:
		cast_label.text = "已打断"
		cast_bar.add_theme_stylebox_override("fill", UITheme.sb(Color("d04040"), 4, 0, UITheme.LINE, 0))
	else:
		cast_bar.value = cast_bar.max_value

func _refresh_xp() -> void:
	if Game.pd.is_empty():
		return
	var need := DB.xp_to_next(Game.pd["level"])
	var leveled := xp_bar.max_value != maxi(1, need)
	xp_bar.max_value = maxi(1, need)
	if leveled:
		xp_bar.value = 0
	var tw := xp_bar.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(xp_bar, "value", float(Game.pd["xp"]), 0.6)
	var rested: float = Game.pd.get("rested", 0.0)
	if need <= 0:
		xp_label.text = "MAX"
	else:
		xp_label.text = "%d / %d" % [Game.pd["xp"], need]
	xp_bar.tooltip_text = "等级 %d · 经验 %d / %d%s" % [Game.pd["level"], Game.pd["xp"], need, (" · 精力充沛 +%d" % int(rested)) if rested > 1.0 else ""]

func _refresh_money() -> void:
	if Game.pd.is_empty():
		return
	money_label.text = U.money_bb(Game.pd["money"])
	bag_btn_label.text = "  背包 %d/%d" % [Game.BAG_SIZE - Game.free_bag_slots(), Game.BAG_SIZE]
	bag_btn_label.tooltip_text = "暂存战利品：%d 项；腾出空间后自动入包。" % Game.pd.get("pending_loot", []).size()

## 邮箱按钮上的未读角标
func _refresh_mail_badge() -> void:
	if mail_btn == null or Game.pd.is_empty():
		return
	var n := Mail.unread()
	mail_btn.text = ""
	var badge: Label = mail_btn.get_node_or_null("UnreadBadge")
	if badge == null:
		badge = UITheme.label("", 10, Color("ffe3a1"), true)
		badge.name = "UnreadBadge"
		badge.position = Vector2(23, -2)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_constant_override("outline_size", 3)
		mail_btn.add_child(badge)
	badge.text = str(n) if n > 0 else ""
	mail_btn.tooltip_text = "邮箱 (O)：%d 封未读 / 共 %d 封" % [n, Mail.box().size()]
	mail_btn.add_theme_color_override("font_color", UITheme.TEXT if n <= 0 else Color("ffd040"))

# ================================================================ 光环
func _refresh_buffs() -> void:
	for c in buff_box.get_children():
		c.queue_free()
	var p: Player = Game.player
	if p == null:
		return
	for a in p.auras:
		var d: Dictionary = a["def"]
		var iv := AuraIcon.new()
		iv.aura = a
		iv.setup(IconArt.spell_key(d.get("id", ""), d.get("icon", "arcane")), d.get("color", Color("8080c0")))
		iv.custom_minimum_size = Vector2(40, 40)
		iv.quality = -1
		iv.debuff = d.get("type", "") == "debuff"
		iv.unit = p
		buff_box.add_child(iv)

func _refresh_buff_times() -> void:
	for c in buff_box.get_children():
		if c is AuraIcon:
			c.queue_redraw()
	_refresh_target_buffs()

func _refresh_target_buffs() -> void:
	var p: Player = Game.player
	var t: Unit = p.target if p and p.target and is_instance_valid(p.target) else null
	var want := t.auras.size() if t else 0
	if target_buffs.get_child_count() != want:
		for c in target_buffs.get_children():
			c.queue_free()
		if t:
			for a in t.auras:
				var iv := AuraIcon.new()
				iv.aura = a
				iv.setup(IconArt.spell_key(a["def"].get("id", ""), a["def"].get("icon", "arcane")), a["def"].get("color", Color("8080c0")))
				iv.custom_minimum_size = Vector2(30, 30)
				iv.debuff = a["def"].get("type", "") == "debuff"
				iv.unit = t
				target_buffs.add_child(iv)
	else:
		for c in target_buffs.get_children():
			c.queue_redraw()

# ================================================================ 聊天
func _build_chat() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.sb(Color(0.055, 0.05, 0.045, 0.26), 2, 0, UITheme.LINE, 6))
	p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	p.offset_left = 16
	p.offset_right = 490
	p.offset_top = -200
	p.offset_bottom = -16
	add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	chat = RichTextLabel.new()
	chat.bbcode_enabled = true
	chat.scroll_following = true
	chat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat.add_theme_font_size_override("normal_font_size", 15)
	chat.add_theme_constant_override("outline_size", 3)
	chat.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	chat.mouse_filter = Control.MOUSE_FILTER_PASS
	chat.selection_enabled = false
	v.add_child(chat)
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "按 Enter 输入聊天或命令（/help）"
	chat_input.visible = false
	chat_input.text_submitted.connect(_on_chat_submit)
	v.add_child(chat_input)
	add_chat("欢迎来到 Canticum Turris！输入 /help 查看命令。", Color("d6c3a2"))

func add_chat(text: String, color: Color) -> void:
	if chat == null:
		return
	chat.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text.replace("[", "[lb]")])
	if chat.get_paragraph_count() > 300:
		chat.remove_paragraph(0)

func _on_chat_submit(t: String) -> void:
	chat_input.text = ""
	chat_input.visible = false
	chat_input.release_focus()
	t = t.strip_edges()
	if t == "":
		return
	if t.begins_with("/"):
		Commands.run(t)
	else:
		add_chat("[%s]说：%s" % [Game.pd["name"], t], Color.WHITE)
		if Game.player:
			_bubble(Game.player, t)

func _bubble(u: Node3D, t: String) -> void:
	var b := Label3D.new()
	b.text = t
	b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	b.font_size = 34
	b.outline_size = 10
	b.pixel_size = 0.004
	b.position = Vector3(0, 2.3, 0)
	u.add_child(b)
	var tw := b.create_tween()
	tw.tween_interval(4.0)
	tw.tween_callback(b.queue_free)

# ================================================================ 小地图/追踪
func _build_minimap() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -270
	box.offset_right = -16
	box.offset_top = 12
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	var hdr := PanelContainer.new()
	hdr.add_theme_stylebox_override("panel", UITheme.sb(UITheme.BG, 2, 1, Color(UITheme.GOLD, 0.35), 6))
	box.add_child(hdr)
	zone_label = UITheme.label("", 16, Color("ffe7a8"), true)
	zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_child(zone_label)
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(254, 254)
	box.add_child(minimap)
	var row := HBoxContainer.new()
	box.add_child(row)
	clock_label = UITheme.label("", 14, UITheme.TEXT)
	clock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(clock_label)
	coord_label = UITheme.label("", 14, UITheme.TEXT_DIM)
	row.add_child(coord_label)

func _refresh_zone_label() -> void:
	var zid: String = Game.pd.get("zone", "vale")
	var zn: String = DB.zones.get(zid, {}).get("name", "")
	var sz = Game.player.current_subzone if Game.player else ""
	zone_label.text = sz if sz != "" else zn

func _build_tracker() -> void:
	tracker = VBoxContainer.new()
	tracker.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tracker.offset_left = -330
	tracker.offset_right = -16
	tracker.offset_top = 330
	tracker.add_theme_constant_override("separation", 2)
	add_child(tracker)

func _refresh_tracker() -> void:
	for c in tracker.get_children():
		c.queue_free()
	if Game.pd.is_empty():
		return
	var n := 0
	var hdr := UITheme.label("任务追踪", 17, UITheme.GOLD, true)
	tracker.add_child(hdr)
	for qid in Game.pd["quests"]:
		if n >= 8:
			break
		n += 1
		var q: Dictionary = DB.quests[qid]
		var done := Game.is_quest_complete(qid)
		var b := Button.new()
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = ("★ " if q.get("main", false) else "") + "[%d] %s%s" % [q["lvl"], q["name"], "（完成）" if done else ""]
		b.add_theme_color_override("font_color", Color("80ff80") if done else Color("ffd100"))
		b.add_theme_constant_override("outline_size", 4)
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		b.add_theme_font_size_override("font_size", 16)
		b.focus_mode = Control.FOCUS_NONE
		var id: String = qid
		b.pressed.connect(func(): open_window("quests"); win["quests"].select(id))
		tracker.add_child(b)
		if done:
			var tn: String = DB.npcs.get(q.get("turnin", ""), {}).get("name", "")
			var l := UITheme.label("    - 回去找%s" % tn, 14, Color("d0d0d0"))
			l.add_theme_constant_override("outline_size", 4)
			tracker.add_child(l)
		else:
			var objs: Array = q.get("obj", [])
			if objs.is_empty():
				var l2 := UITheme.label("    - " + q.get("obj_text", ""), 14, Color("e0e0e0"))
				l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l2.custom_minimum_size.x = 300
				l2.add_theme_constant_override("outline_size", 4)
				tracker.add_child(l2)
			for i in objs.size():
				var have := Game.objective_progress(qid, i)
				var ok: bool = have >= objs[i].get("n", 1)
				var l3 := UITheme.label("    - " + Game.objective_text(qid, i), 14, Color("909090") if ok else Color("f0f0f0"))
				l3.add_theme_constant_override("outline_size", 4)
				tracker.add_child(l3)

# ================================================================ 文字提示
func show_error(t: String) -> void:
	error_label.text = t
	error_label.modulate.a = 1.0
	_error_t = 2.0
	UIFx.shake(error_label)

func show_center(t: String, sub: String) -> void:
	center_label.text = t
	center_sub.text = sub
	center_label.modulate.a = 1.0
	center_sub.modulate.a = 1.0
	_center_t = 3.5
	UIFx.pop(center_label)

func show_progress(t: String) -> void:
	progress_label.text = t
	progress_label.modulate.a = 1.0
	_progress_t = 2.5

func show_intro() -> void:
	var cd: Dictionary = DB.classes[Game.pd["class"]]
	show_center("晨露谷 · 晨钟修道院", "%s的冒险从这里开始" % cd["name"])
	add_chat("提示：WASD 移动，按住鼠标右键转动视角并转身，左键点击选择目标，右键点击NPC对话/攻击敌人。", Color("80d0ff"))
	add_chat("提示：头顶有黄色「!」的NPC可以接受任务。按 L 打开任务日志，B 打开背包，C 打开角色面板。", Color("80d0ff"))
	add_chat("职业循环：" + cd.get("rotation", ""), Color("92daca"))
	add_chat("怪物掉落自动入包；背包满时暂存，腾出空间后自动补入。", Color("80d0ff"))
	add_chat("提示：10 级起每级获得 1 点天赋点数，按 N 打开天赋面板分配；在职业训练师处可以重置。", Color("80d0ff"))
	add_chat("提示：按 O 打开邮箱，训练师与各方势力的来信和附件都在那里。", Color("80d0ff"))

# ================================================================ 窗口
## 窗口别名：背包已并入角色页、天赋已并入技能书页签（面板本身见 win_char / win_spells）
const WIN_ALIAS := {"bag": "char", "talents": "spells"}

func _win_id(id: String) -> String:
	return WIN_ALIAS.get(id, id)

func _build_windows() -> void:
	win["char"] = CharWindow.new()
	win["quests"] = QuestLogWindow.new()
	win["spells"] = SpellbookWindow.new()
	win["npc"] = NpcWindow.new()
	win["map"] = WorldMapWindow.new()
	win["menu"] = MenuWindow.new()
	win["loot"] = LootWindow.new()
	win["bank"] = BankWindow.new()
	win["transmog"] = TransmogWindow.new()
	win["auction"] = AuctionWindow.new()
	win["dungeon"] = DungeonWindow.new()
	win["prof"] = ProfWindow.new()
	win["mail"] = MailWindow.new()
	win["achiev"] = AchievWindow.new()
	win["mounts"] = MountWindow.new()
	for k in win:
		var w: UIWindow = win[k]
		w.visible = false
		windows_layer.add_child(w)
	win["char"].position = Vector2(30, 40)
	win["quests"].position = Vector2(560, 120)
	win["spells"].position = Vector2(get_viewport_rect().size.x * 0.5 - 386, 70)
	win["npc"].position = Vector2(60, 140)
	win["map"].position = Vector2(400, 60)
	win["menu"].position = Vector2(get_viewport_rect().size.x * 0.5 - 200, 220)
	win["loot"].position = Vector2(get_viewport_rect().size.x * 0.5 + 120, 300)
	win["bank"].position = Vector2(60, 140)
	win["transmog"].position = Vector2(60, 120)
	win["auction"].position = Vector2(40, 100)
	win["dungeon"].position = Vector2(get_viewport_rect().size.x * 0.5 - 380, 110)
	win["prof"].position = Vector2(get_viewport_rect().size.x * 0.5 - 380, 130)
	win["mail"].position = Vector2(60, 120)
	win["achiev"].position = Vector2(60, 80)
	win["mounts"].position = Vector2(240, 90)
	_build_death()

func toggle_window(id: String) -> void:
	var rid := _win_id(id)
	if win.has(rid):
		if win[rid].visible:
			win[rid].close_window()
		else:
			open_window(id)

func open_window(id: String) -> void:
	var rid := _win_id(id)
	if not win.has(rid):
		return
	# 技能书与天赋是同一窗口的两个页签：按入口决定先显示哪一页
	if rid == "spells":
		win["spells"].set_tab("talents" if id == "talents" else "spells")
	if not win[rid].visible:
		win[rid].open_window()

func any_window_open() -> bool:
	for k in win:
		if win[k].visible:
			return true
	return false

func close_all() -> bool:
	var any := false
	for k in win:
		if win[k].visible:
			win[k].close_window()
			any = true
	return any

func open_npc(n: NPC) -> void:
	win["npc"].show_npc(n)

func open_waystone(w: Node3D) -> void:
	win["npc"].show_waystone(w)

func open_quest_offer(qid: String, n: NPC) -> void:
	win["npc"].show_quest_offer(qid, n)

func open_loot(m: Mob) -> void:
	win["loot"].show_loot(m)

func loot_source_gone(m: Node) -> void:
	if win["loot"].source == m:
		win["loot"].close_window()

func bag_right_click(idx: int) -> void:
	var st = Game.pd["bag"][idx]
	if st == null:
		return
	if win["npc"].visible and win["npc"].mode == "vendor":
		win["npc"].sell(idx)
		return
	if win["bank"].visible:
		Game.bank_deposit(idx)
		return
	if win["auction"].visible:
		win["auction"].pick_for_sale(idx)
		return
	Game.player.use_bag_item(idx)

func bag_to_bank(a: int, b: int) -> void:
	Game.bank_deposit(a, b)

func bank_to_bag(a: int, b: int) -> void:
	Game.bank_withdraw(a, b)

## 由 NPC 服务打开的窗口（银行/幻化/拍卖），离开 NPC 太远时自动关闭
func open_service(id: String, n: NPC) -> void:
	win["npc"].visible = false
	var w = win[id]
	w.service_npc = n
	w.open_window()
	if id in ["bank", "auction"]:
		open_window("char")

func show_death() -> void:
	death_panel.visible = true

func _build_death() -> void:
	death_panel = PanelContainer.new()
	death_panel.add_theme_stylebox_override("panel", UITheme.sb(UITheme.BG, 16, 1, Color(UITheme.GOLD, 0.4), 18))
	death_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	death_panel.offset_left = -220
	death_panel.offset_right = 220
	death_panel.offset_top = 300
	death_panel.visible = false
	add_child(death_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	death_panel.add_child(v)
	var l := UITheme.label("你已经死亡", 26, Color("ff6060"), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var l2 := UITheme.label("本作取消了死亡惩罚：不会损失经验、金钱或装备耐久。", 15, UITheme.TEXT_DIM)
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l2)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	h.add_child(UITheme.button("在墓地复活", func(): death_panel.visible = false; Game.world.revive_player(true), 160))
	h.add_child(UITheme.button("原地复活", func(): death_panel.visible = false; Game.world.revive_player(false), 160))

# ================================================================ 输入
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.keycode
	if chat_input.has_focus():
		if k == KEY_ESCAPE:
			chat_input.text = ""
			chat_input.visible = false
			chat_input.release_focus()
			get_viewport().set_input_as_handled()
		return
	if k == KEY_ENTER or k == KEY_KP_ENTER:
		chat_input.visible = true
		chat_input.grab_focus()
		get_viewport().set_input_as_handled()
		return
	if k == KEY_SLASH and not event.shift_pressed and Game.keybinds.get("walk", 0) != KEY_SLASH:
		chat_input.visible = true
		chat_input.text = "/"
		chat_input.grab_focus()
		chat_input.caret_column = 1
		get_viewport().set_input_as_handled()
		return
	if k == KEY_ESCAPE:
		if close_all():
			pass
		elif Game.player and Game.player.target:
			Game.player.set_target(null)
		else:
			open_window("menu")
		get_viewport().set_input_as_handled()
		return
	var kb := Game.keybinds
	var map := {kb["char"]: "char", kb["bags"]: "bag", kb["quests"]: "quests", kb["spellbook"]: "spells", kb["map"]: "map", kb["dungeon"]: "dungeon",
		kb.get("prof", KEY_K): "prof", kb.get("talents", KEY_N): "talents", kb.get("mail", KEY_O): "mail",
		kb.get("achiev", KEY_Y): "achiev", kb.get("mounts", KEY_J): "mounts"}
	if map.has(k):
		toggle_window(map[k])
		get_viewport().set_input_as_handled()
	elif k == kb["nameplates"]:
		Game.settings["nameplates"] = not Game.settings.get("nameplates", true)
	elif k == kb["toggle_ui"] and event.alt_pressed:
		ui_hidden = not ui_hidden
		for c in get_children():
			if c != nameplates:
				c.visible = not ui_hidden
	elif k == kb["screenshot"]:
		var img := get_viewport().get_texture().get_image()
		var path := "user://screenshot_%d.png" % Time.get_unix_time_from_system()
		img.save_png(path)
		add_chat("截图已保存：%s" % ProjectSettings.globalize_path(path), Color("80d0ff"))
	elif k == KEY_ENTER and event.alt_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
