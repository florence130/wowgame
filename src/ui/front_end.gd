extends Node3D
## 开始界面：角色选择 + 角色创建（捏脸）

var avatar: Avatar
var stage: Node3D
var ui: Control
var panel_right: PanelContainer
var right_body: VBoxContainer
var mode := "title"
var backdrop: MenuBackdrop
var avatar_view: TextureRect
var avatar_viewport: SubViewport
var settings_window: MenuWindow
var settings_overlay: ColorRect
var settings_previous_focus: Control
var camp_avatars: Array[Avatar] = []
var avatar_environment: Environment
var avatar_sun: DirectionalLight3D
var avatar_fire: OmniLight3D
const TITLE_FONT = preload("res://assets/fonts/cinzel_decorative/CinzelDecorative-Bold.ttf")
var saves: Array = []
var sel_index := 0
var cam: Camera3D
# 创建参数
var c_class := "warrior"
var c_app := {}
var c_name := ""
var c_tab := "class"
var name_edit: LineEdit
var _rot_drag := false
var _t := 0.0
var cam_target := Vector3(0, 1.0, 4.2)
var cam_look := Vector3(0, 0.95, 0)

func _ready() -> void:
	EnvironmentWeather.reset_globals()
	Game.world = null
	Game.player = null
	Game.zone = null
	Game.hud = null
	Game.pd = {}
	Sfx.set_ambience("")
	Sfx.set_music("menu")
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.theme = UITheme.build()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	backdrop = MenuBackdrop.new()
	ui.add_child(backdrop)
	_build_stage()
	saves = Game.list_saves()
	if Game.get_meta("front_end_select", false):
		Game.remove_meta("front_end_select")
		_start_game()
	else:
		_show_title()

func _build_stage() -> void:
	avatar_view = TextureRect.new()
	avatar_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	avatar_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(avatar_view)
	avatar_viewport = SubViewport.new()
	avatar_viewport.own_world_3d = true
	avatar_viewport.transparent_bg = true
	avatar_viewport.msaa_3d = Viewport.MSAA_2X
	avatar_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	avatar_view.add_child(avatar_viewport)
	avatar_view.texture = avatar_viewport.get_texture()
	avatar_view.resized.connect(func(): avatar_viewport.size = Vector2i(avatar_view.size))
	avatar_viewport.size = Vector2i(1920, 1080)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	avatar_environment = env
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.82, 0.95)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	we.environment = env
	avatar_viewport.add_child(we)
	var sun := DirectionalLight3D.new()
	avatar_sun = sun
	sun.rotation_degrees = Vector3(-40, 25, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	avatar_viewport.add_child(sun)
	avatar_fire = OmniLight3D.new()
	avatar_fire.position = Vector3(0, 1.1, 1.0)
	avatar_fire.light_color = Color("ffbd78")
	avatar_fire.light_energy = 2.6
	avatar_fire.omni_range = 8.5
	avatar_viewport.add_child(avatar_fire)
	cam = Camera3D.new()
	cam.position = cam_target
	cam.fov = 38
	avatar_viewport.add_child(cam)
	cam.look_at(cam_look)
	stage = Node3D.new()
	avatar_viewport.add_child(stage)
	avatar = Avatar.new()
	avatar.rotation.y = PI
	stage.add_child(avatar)

func _process(delta: float) -> void:
	RenderingServer.global_shader_parameter_set("env_motion_time", _t)
	_t += delta
	if avatar and mode != "title":
		avatar.animate(delta, {})
	for a in camp_avatars:
		a.animate(delta, {})
	cam.position = cam.position.lerp(cam_target, clampf(delta * 5.0, 0.0, 1.0))
	cam.look_at(cam_look)

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel"):
		if is_instance_valid(settings_window) and settings_window.visible:
			settings_window.close_window()
		elif mode == "create" and not saves.is_empty():
			_show_select()
		elif mode != "title":
			_show_title()
		get_viewport().set_input_as_handled()
		return
	if mode == "title":
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_rot_drag = ev.pressed
	elif ev is InputEventMouseMotion and _rot_drag:
		avatar.rotation.y += ev.relative.x * 0.01
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_UP:
		cam_target = Vector3(0, 1.45, 1.5)
		cam_look = Vector3(0, 1.4, 0)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		cam_target = Vector3(0, 1.0, 4.2)
		cam_look = Vector3(0, 0.95, 0)

func _clear_ui() -> void:
	_rot_drag = false
	for c in ui.get_children():
		if c != backdrop and c != avatar_view:
			ui.remove_child(c)
			c.queue_free()
	avatar_view.visible = mode != "title"
	avatar_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if avatar_view.visible else SubViewport.UPDATE_DISABLED
	backdrop.set_selection(mode != "title")
	for c in backdrop.camp.get_children():
		if c.name.begins_with("CampContactShadow"):
			c.queue_free()
	for a in camp_avatars:
		a.queue_free()
	camp_avatars.clear()
	avatar_environment.ambient_light_energy = 0.64
	avatar_environment.ambient_light_color = Color("91afcb")
	avatar_sun.light_color = Color("aac9f5")
	avatar_sun.light_energy = 0.65
	avatar_fire.light_energy = 1.0 if mode == "select" else 0.0
	if mode == "create":
		avatar_environment.ambient_light_color = Color("e1ded8")
		avatar_environment.ambient_light_energy = 0.85
		avatar_sun.light_color = Color("fff1de")
		avatar_sun.light_energy = 0.9

func _start_game() -> void:
	cam_target = Vector3(0, 1.0, 4.2)
	cam_look = Vector3(0, 0.95, 0)
	stage.rotation = Vector3.ZERO
	if saves.is_empty():
		_start_create()
	else:
		_show_select()

func _show_title() -> void:
	mode = "title"
	_clear_ui()
	var title := Control.new()
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.offset_left = -520
	title.offset_right = 520
	title.offset_top = -250
	title.offset_bottom = 80
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(title)
	var crest := Control.new()
	crest.set_script(preload("res://src/ui/title_ornament.gd"))
	crest.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.add_child(crest)
	for row in [["Canticum", 70, 42], ["Turris", 112, 132]]:
		var l := UITheme.label(row[0], row[1], Color("eef8ff"))
		l.add_theme_font_override("font", TITLE_FONT)
		l.add_theme_color_override("font_shadow_color", Color(0.06, 0.13, 0.28, 0.75))
		l.add_theme_constant_override("shadow_offset_y", 4)
		l.add_theme_constant_override("shadow_outline_size", 10)
		l.add_theme_constant_override("outline_size", 1)
		l.add_theme_color_override("font_outline_color", Color("a2b9da"))
		l.set_anchors_preset(Control.PRESET_TOP_WIDE)
		l.offset_top = row[2]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_child(l)
	var caption := UITheme.label("T H E   S O N G   O F   T H E   T O W E R", 13, Color("bbd3ee"))
	caption.set_anchors_preset(Control.PRESET_TOP_WIDE)
	caption.offset_top = 275
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_child(caption)
	var menu := VBoxContainer.new()
	menu.name = "TitleMenu"
	menu.set_anchors_preset(Control.PRESET_CENTER)
	menu.offset_left = -145
	menu.offset_right = 145
	menu.offset_top = 155
	menu.offset_bottom = 345
	menu.add_theme_constant_override("separation", 13)
	ui.add_child(menu)
	for e in [["开始游戏", _start_game], ["设置", _open_settings], ["退出游戏", func(): get_tree().quit()]]:
		var b := UITheme.button(e[0], e[1])
		b.custom_minimum_size = Vector2(290, 48)
		b.add_theme_font_size_override("font_size", 19)
		b.add_theme_stylebox_override("normal", UITheme.sb(Color(0.10, 0.19, 0.33, 0.38), 2, 1, Color(0.74, 0.85, 0.97, 0.26), 10))
		b.add_theme_stylebox_override("hover", UITheme.sb(Color(0.51, 0.66, 0.83, 0.3), 2, 1, Color("deedff"), 10))
		b.add_theme_stylebox_override("focus", UITheme.sb(Color(0.48, 0.63, 0.82, 0.16), 2, 1, Color("deedff"), 10))
		b.add_theme_stylebox_override("pressed", UITheme.sb(Color(0.12, 0.24, 0.41, 0.62), 2, 1, Color("9dbfe7"), 10))
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		menu.add_child(b)
	var footer := UITheme.label("CANTICUM TURRIS  /  序章", 12, Color(0.8, 0.88, 1.0, 0.65))
	footer.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position = Vector2(32, -36)
	ui.add_child(footer)
	var hint := UITheme.label("移动鼠标 · 微风之间", 12, Color(0.8, 0.88, 1.0, 0.6))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -185
	hint.offset_top = -36
	ui.add_child(hint)

func _open_settings() -> void:
	settings_previous_focus = get_viewport().gui_get_focus_owner()
	var title_menu := ui.get_node_or_null("TitleMenu")
	if title_menu:
		for b in title_menu.get_children():
			b.disabled = true
	if is_instance_valid(settings_window):
		settings_overlay.show()
		settings_window.page = "settings"
		settings_window.refresh()
		settings_window.show()
		settings_window.body.get_child(0).get_child(1).grab_focus()
		return
	settings_overlay = ColorRect.new()
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.color = Color(0.025, 0.045, 0.085, 0.52)
	settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(settings_overlay)
	settings_window = MenuWindow.new()
	settings_window.front_end = true
	settings_window.page = "settings"
	settings_overlay.add_child(settings_window)
	settings_window.refresh()
	settings_window.set_anchors_preset(Control.PRESET_CENTER)
	settings_window.offset_left = -300
	settings_window.offset_right = 300
	settings_window.offset_top = -330
	settings_window.offset_bottom = 330
	settings_window.closed.connect(func():
		settings_overlay.hide()
		var menu := ui.get_node_or_null("TitleMenu")
		if menu:
			for b in menu.get_children():
				b.disabled = false
		if is_instance_valid(settings_previous_focus):
			settings_previous_focus.grab_focus())
	settings_window.body.get_child(0).get_child(1).grab_focus()

func _title(text: String) -> void:
	var l := UITheme.label(text, 30, Color("fff4d8"), true)
	l.position = Vector2(40, 30)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.15, 0.3, 0.8))
	ui.add_child(l)
	var sub := UITheme.label("Canticum Turris", 16, Color("cadcf3"))
	sub.add_theme_font_override("font", TITLE_FONT)
	sub.position = Vector2(44, 76)
	sub.add_theme_constant_override("outline_size", 6)
	ui.add_child(sub)

# ================================================================ 角色选择
func _show_select() -> void:
	mode = "select"
	_clear_ui()
	cam_target = Vector3(0, 2.7, 9.6)
	cam_look = Vector3(0, 1.4, -5)
	cam.position = cam_target
	stage.rotation = Vector3.ZERO
	avatar.rotation = Vector3(0, PI, 0)
	avatar.position = Vector3(-1.7, 0, -0.25)
	_add_contact_shadow(avatar.position)
	_title("角色选择")
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	p.offset_left = -390
	p.offset_right = -30
	p.offset_top = -610
	p.offset_bottom = -36
	p.add_theme_stylebox_override("panel", UITheme.sb(Color(0.075,0.09,0.085,0.88), 3, 1, Color(UITheme.GOLD, 0.25), 14))
	ui.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UITheme.label("旅人营地", 20, UITheme.GOLD, true))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.y = 220
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var characters := VBoxContainer.new()
	characters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	characters.add_theme_constant_override("separation", 6)
	sc.add_child(characters)
	for i in saves.size():
		var d: Dictionary = saves[i]["data"]
		var cd: Dictionary = DB.classes.get(d["class"], {})
		var b := UITheme.tab_button("%s\n%d级 %s · %s" % [d["name"], d["level"], cd.get("name", ""), DB.zones.get(d.get("zone", "vale"), {}).get("name", "")], i == sel_index)
		b.custom_minimum_size = Vector2(320, 64)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx := i
		b.pressed.connect(func(): sel_index = idx; _show_select())
		characters.add_child(b)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	if saves.size() < 8:
		v.add_child(UITheme.button("创建新角色", _start_create))
	if saves.size() > 0:
		var del := UITheme.button("删除角色", func(): _confirm_delete())
		v.add_child(del)
	v.add_child(UITheme.button("退出游戏", func(): get_tree().quit()))
	v.add_child(UITheme.button("返回开始界面", _show_title))
	# 进入游戏按钮
	var enter := UITheme.button("进 入 游 戏", _enter_game)
	enter.custom_minimum_size = Vector2(320, 46)
	enter.add_theme_font_size_override("font_size", 20)
	enter.add_theme_stylebox_override("normal", UITheme.sb(Color("c9d9ed"), 3, 1, Color("f3f8ff"), 12))
	enter.add_theme_stylebox_override("hover", UITheme.sb(Color("e5eef9"), 3, 1, Color.WHITE, 12))
	enter.add_theme_color_override("font_color", Color("293c58"))
	v.add_child(enter)
	if saves.size() > 0:
		var d2: Dictionary = saves[sel_index]["data"]
		avatar.setup(d2["app"], _gear_of(d2))
		avatar.set_combat_ready(false)
		var others := 0
		for i in saves.size():
			if i == sel_index or others >= 2:
				continue
			var other := Avatar.new()
			stage.add_child(other)
			var data: Dictionary = saves[i]["data"]
			other.setup(data["app"], _gear_of(data))
			other.set_combat_ready(false)
			other.position = Vector3(1.4, 0, -1.4) if others == 0 else Vector3(-3.8, 0, -1.3)
			other.rotation.y = PI
			_add_contact_shadow(other.position)
			camp_avatars.append(other)
			others += 1
		var info := UITheme.label("%s  ·  %d级 %s" % [d2["name"], d2["level"], DB.classes[d2["class"]]["name"]], 24, Color.WHITE, true)
		info.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		info.offset_left = -410
		info.offset_right = 90
		info.offset_top = -70
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.add_theme_constant_override("outline_size", 8)
		ui.add_child(info)

func _add_contact_shadow(at: Vector3) -> void:
	# A soft ground decal anchors the sharp avatar preview to the matching camp camera.
	var decal := MeshInstance3D.new()
	decal.name = "CampContactShadow"
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.8, 0.55)
	decal.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/ui/camp_contact.gdshader")
	decal.material_override = mat
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decal.position = at + Vector3(0, 0.025, 0)
	backdrop.camp.add_child(decal)

func _gear_of(d: Dictionary) -> Dictionary:
	var old := Game.pd
	Game.pd = d
	var g := Game.gear_visuals()
	Game.pd = old
	return g

func _confirm_delete() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = "确定要删除角色「%s」吗？此操作无法撤销。" % saves[sel_index]["data"]["name"]
	dlg.ok_button_text = "删除"
	dlg.cancel_button_text = "取消"
	ui.add_child(dlg)
	dlg.confirmed.connect(func():
		Game.delete_character(saves[sel_index]["slot"])
		saves = Game.list_saves()
		sel_index = 0
		if saves.is_empty():
			_start_create()
		else:
			_show_select())
	dlg.popup_centered()

func _enter_game() -> void:
	if saves.is_empty():
		return
	if Game.load_character(saves[sel_index]["slot"]):
		get_tree().change_scene_to_file("res://scenes/world.tscn")

# ================================================================ 角色创建
func _start_create() -> void:
	mode = "create"
	cam_target = Vector3(0, 1.0, 4.2)
	cam_look = Vector3(0, 0.95, 0)
	avatar.position = Vector3.ZERO
	avatar.rotation = Vector3(0, PI, 0)
	stage.rotation = Vector3.ZERO
	c_app = DB.random_appearance(randi(), "f")
	c_app["hair"] = 7
	c_app["hair_color"] = DB.HAIR_COLORS[0]
	c_app["eye"] = 0
	c_class = "warrior"
	c_tab = "class"
	_show_create()

func _preview_gear() -> Dictionary:
	var cd: Dictionary = DB.classes[c_class]
	var g := {}
	for iid in cd["start_items"]:
		var it := DB.get_item(iid)
		var e: String = it.get("equip", "")
		if e == "":
			continue
		var v := DB.item_visual(iid)
		var s := e
		if e == "main" and g.has("main") and c_class == "rogue":
			s = "off"
		v["wtype"] = it.get("type", "")
		if it.get("slot", "") == "ranged":
			s = "ranged"
		g[s] = v
	return g

func _show_create() -> void:
	mode = "create"
	_clear_ui()
	_title("角色创建")
	avatar.setup(c_app, _preview_gear())
	avatar.set_combat_ready(c_tab == "class")
	# 左侧：大类按钮（参考洛奇M左侧圆形图标）
	var left := VBoxContainer.new()
	left.position = Vector2(40, 130)
	left.add_theme_constant_override("separation", 14)
	ui.add_child(left)
	for e in [["class", "职业"], ["body", "体型"], ["face", "脸部"], ["hair", "发型"], ["eyes", "眼睛"]]:
		var b := UITheme.tab_button(e[1], c_tab == e[0])
		b.custom_minimum_size = Vector2(120, 54)
		b.add_theme_font_size_override("font_size", 19)
		var key: String = e[0]
		b.pressed.connect(func():
			c_tab = key
			if key in ["face", "eyes", "hair"]:
				cam_target = Vector3(0, 1.45, 1.5)
				cam_look = Vector3(0, 1.38, 0)
			else:
				cam_target = Vector3(0, 1.0, 4.2)
				cam_look = Vector3(0, 0.95, 0)
			_show_create())
		left.add_child(b)
	var hint := UITheme.label("拖动鼠标旋转角色 · 滚轮切换近景", 14, Color(1, 1, 1, 0.7))
	hint.position = Vector2(40, 470)
	ui.add_child(hint)
	# 右侧面板
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	p.offset_left = -520
	p.offset_right = -30
	p.offset_top = 40
	p.offset_bottom = -40
	p.add_theme_stylebox_override("panel", UITheme.sb(UITheme.BG, 3, 1, Color(UITheme.GOLD, 0.24), 16))
	ui.add_child(p)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	sc.add_child(v)
	match c_tab:
		"class": _tab_class(v)
		"body": _tab_body(v)
		"face": _tab_face(v)
		"hair": _tab_hair(v)
		"eyes": _tab_eyes(v)
	# 底部：名字与创建
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.offset_left = -330
	bottom.offset_right = 330
	bottom.offset_top = -100
	bottom.offset_bottom = -40
	bottom.add_theme_constant_override("separation", 12)
	ui.add_child(bottom)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "输入角色名字"
	name_edit.text = c_name
	name_edit.max_length = 12
	name_edit.custom_minimum_size = Vector2(260, 52)
	name_edit.add_theme_font_size_override("font_size", 22)
	name_edit.text_changed.connect(func(t): c_name = t)
	bottom.add_child(name_edit)
	bottom.add_child(UITheme.button("随机", func(): c_name = _random_name(); name_edit.text = c_name))
	var ok := UITheme.button("创建角色", _create)
	ok.custom_minimum_size = Vector2(180, 52)
	ok.add_theme_font_size_override("font_size", 22)
	ok.add_theme_stylebox_override("normal", UITheme.sb(Color("c9d9ed"), 3, 1, Color("f3f8ff"), 12))
	ok.add_theme_stylebox_override("hover", UITheme.sb(Color("e5eef9"), 3, 1, Color.WHITE, 12))
	ok.add_theme_color_override("font_color", Color("293c58"))
	bottom.add_child(ok)
	var back := UITheme.button("返回", _show_select if saves.size() > 0 else _show_title)
	back.position = Vector2(40, 560)
	ui.add_child(back)

func _section(v: VBoxContainer, t: String) -> void:
	v.add_child(UITheme.label(t, 18, UITheme.GOLD, true))

func _choice_row(v: VBoxContainer, options: Array, cur, cb: Callable, cols: int = 4) -> void:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	v.add_child(g)
	for i in options.size():
		var o = options[i]
		var b := UITheme.tab_button(str(o[1]), o[0] == cur)
		b.custom_minimum_size = Vector2(108, 42)
		var val = o[0]
		b.pressed.connect(func(): cb.call(val); _show_create())
		g.add_child(b)

func _palette(v: VBoxContainer, colors: Array, key: String) -> void:
	var g := GridContainer.new()
	g.columns = 7
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	v.add_child(g)
	for c in colors:
		var b := Button.new()
		b.custom_minimum_size = Vector2(46, 46)
		var sel: bool = c_app.get(key, Color.WHITE).is_equal_approx(c)
		var sbx := UITheme.sb(c, 23, 3 if sel else 1, Color.WHITE if sel else Color(1, 1, 1, 0.2), 0)
		b.add_theme_stylebox_override("normal", sbx)
		b.add_theme_stylebox_override("hover", UITheme.sb(c.lightened(0.15), 23, 2, UITheme.GOLD, 0))
		b.add_theme_stylebox_override("pressed", sbx)
		var cc: Color = c
		b.pressed.connect(func(): c_app[key] = cc; _show_create())
		g.add_child(b)
	# 自定义颜色（HEX/RGB 显示，参考洛奇M）
	var cur: Color = c_app.get(key, Color.WHITE)
	var h := HBoxContainer.new()
	v.add_child(h)
	var cp := ColorPickerButton.new()
	cp.color = cur
	cp.edit_alpha = false
	cp.custom_minimum_size = Vector2(46, 36)
	cp.color_changed.connect(func(c): c_app[key] = c; avatar.setup(c_app, _preview_gear()))
	cp.popup_closed.connect(func(): _show_create())
	h.add_child(cp)
	h.add_child(UITheme.label("  %s   R%d G%d B%d" % [U.color_hex(cur), int(cur.r8), int(cur.g8), int(cur.b8)], 15, UITheme.TEXT_DIM))

func _slider(v: VBoxContainer, label: String, key: String, mn: float, mx: float) -> void:
	var h := HBoxContainer.new()
	var l := UITheme.label(label, 16)
	l.custom_minimum_size.x = 80
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.01
	s.value = c_app.get(key, 1.0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size.y = 28
	s.value_changed.connect(func(x): c_app[key] = x; avatar.setup(c_app, _preview_gear()))
	h.add_child(s)
	v.add_child(h)

func _tab_class(v: VBoxContainer) -> void:
	_section(v, "种族")
	v.add_child(UITheme.label("人类 —— 晨露谷与晴岚港的子民，适应力强、意志坚定。", 15, UITheme.TEXT_DIM))
	_section(v, "职业")
	for cid in DB.classes:
		var cd: Dictionary = DB.classes[cid]
		var b := UITheme.tab_button("", cid == c_class)
		b.custom_minimum_size = Vector2(440, 92)
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 10
		h.offset_right = -10
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		var ic := IconView.new()
		ic.setup(cd["icon"], cd["color"])
		ic.custom_minimum_size = Vector2(56, 56)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
		var tv := VBoxContainer.new()
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nl := UITheme.label("%s   [%s]" % [cd["name"], cd["role"]], 18, cd["color"] if cid != c_class else Color("2a1a08"), true)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(nl)
		var dl := UITheme.label(cd["desc"], 13, UITheme.TEXT_DIM if cid != c_class else Color("4a3a20"))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size.x = 340
		dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(dl)
		h.add_child(tv)
		var key: String = cid
		b.pressed.connect(func(): c_class = key; _show_create())
		v.add_child(b)

func _tab_body(v: VBoxContainer) -> void:
	_section(v, "性别")
	_choice_row(v, [["f", "女性"], ["m", "男性"]], c_app.get("gender", "f"), func(x):
		c_app["gender"] = x
		c_app["blush"] = x == "f"
		if x == "m" and c_app["hair"] in [4, 6, 7, 8, 9]:
			c_app["hair"] = 1
		if x == "f":
			c_app["beard"] = false)
	_section(v, "肤色")
	_palette(v, DB.SKIN_TONES, "skin")
	_section(v, "身高与体型")
	_slider(v, "身高", "height", 0.88, 1.12)
	_slider(v, "体型", "build", 0.85, 1.2)
	if c_app.get("gender", "f") == "m":
		_section(v, "胡子")
		_choice_row(v, [[false, "无"], [true, "络腮胡"]], c_app.get("beard", false), func(x): c_app["beard"] = x)

func _tab_face(v: VBoxContainer) -> void:
	_section(v, "脸型")
	_choice_row(v, [[0, "圆润"], [1, "瓜子"], [2, "方正"]], c_app.get("face", 0), func(x): c_app["face"] = x, 3)
	_section(v, "眉毛")
	_choice_row(v, [[0, "平眉"], [1, "柔和"], [2, "英气"]], c_app.get("brow", 0), func(x): c_app["brow"] = x, 3)
	_section(v, "嘴型")
	_choice_row(v, [[0, "微笑"], [1, "平静"], [2, "小嘴"]], c_app.get("mouth", 0), func(x): c_app["mouth"] = x, 3)
	_section(v, "腮红")
	_choice_row(v, [[true, "有"], [false, "无"]], c_app.get("blush", false), func(x): c_app["blush"] = x, 2)

func _tab_hair(v: VBoxContainer) -> void:
	_section(v, "发型")
	var opts := []
	for i in DB.HAIR_STYLE_NAMES.size():
		opts.append([i, DB.HAIR_STYLE_NAMES[i]])
	_choice_row(v, opts, c_app.get("hair", 0), func(x): c_app["hair"] = x)
	_section(v, "发色")
	_palette(v, DB.HAIR_COLORS, "hair_color")

func _tab_eyes(v: VBoxContainer) -> void:
	_section(v, "眼型")
	_choice_row(v, [[0, "大眼"], [1, "圆眼"], [2, "细长"], [3, "笑眼"]], c_app.get("eye", 0), func(x): c_app["eye"] = x)
	_section(v, "瞳色")
	_palette(v, DB.EYE_COLORS, "eye_color")

func _random_name() -> String:
	var a := ["艾", "莉", "露", "希", "诺", "凯", "薇", "塔", "菲", "伊", "安", "洛", "缇", "妮", "卡", "雷", "奥", "西", "米", "拉"]
	var b := ["娅", "丝", "恩", "娜", "尔", "琳", "克", "斯", "卡", "莉", "德", "亚", "妮", "温", "特", "芙"]
	var n = a[randi() % a.size()] + b[randi() % b.size()]
	if randf() < 0.5:
		n += b[randi() % b.size()]
	return n

func _create() -> void:
	c_name = c_name.strip_edges()
	if c_name.length() < 2:
		_toast("名字至少需要2个字符。")
		return
	for s in saves:
		if s["data"]["name"] == c_name:
			_toast("这个名字已经被使用了。")
			return
	var slot := Game.free_slot()
	if slot < 0:
		_toast("角色栏位已满。")
		return
	Game.new_character(c_name, c_class, c_app.duplicate())
	Game.slot_index = slot
	Game.pd["new"] = true
	Game.save_game()
	Game.pd["new"] = true
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _toast(t: String) -> void:
	var l := UITheme.label(t, 22, Color("ff6050"), true)
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.offset_left = -300
	l.offset_right = 300
	l.offset_top = 120
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 6)
	ui.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
