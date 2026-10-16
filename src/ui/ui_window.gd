class_name UIWindow
extends PanelContainer
## 可拖动窗口基类

signal closed

var body: VBoxContainer
var title_label: Label
var header: HBoxContainer
var _drag := false
var _drag_off := Vector2.ZERO
var win_id := ""

func _init_window(title: String, min_size: Vector2, id: String, embed: bool = false) -> void:
	win_id = id
	custom_minimum_size = min_size
	if embed:
		# 嵌入式面板：不画窗口底、不带头部与拖动，只保留 body，供并进其他窗口使用
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		mouse_filter = Control.MOUSE_FILTER_PASS
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)
		add_child(vb)
		body = vb
		return
	add_theme_stylebox_override("panel", UITheme.window_sb())
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	header = HBoxContainer.new()
	v.add_child(header)
	var dot := UITheme.label("✦", 18, UITheme.GOLD)
	header.add_child(dot)
	var art := IconArt.texture("ui/" + id)
	if art != null:
		# Keep the original glyph's footprint, including its font metrics.
		var icon := TextureRect.new()
		icon.texture = art
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.add_theme_color_override("font_color", Color.TRANSPARENT)
		dot.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_label = UITheme.label(title, 21, UITheme.TEXT, true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(title_label)
	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(close_window)
	header.add_child(close)
	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.07)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sep)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	header.gui_input.connect(_on_header_input)

func _on_header_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_drag = ev.pressed
		_drag_off = get_global_mouse_position() - global_position
		if ev.pressed:
			get_parent().move_child(self, -1)
	elif ev is InputEventMouseMotion and _drag:
		global_position = get_global_mouse_position() - _drag_off
		var vs := get_viewport_rect().size
		position.x = clampf(position.x, -size.x + 80, vs.x - 80)
		position.y = clampf(position.y, 0, vs.y - 60)

func close_window() -> void:
	if visible:
		UIFx.window_close(self)
	visible = false
	Sfx.play("close")
	closed.emit()

func open_window() -> void:
	var was := visible
	visible = true
	if get_parent():
		get_parent().move_child(self, -1)
	refresh()
	if not was:
		UIFx.window_open(self)
	Sfx.play("open")

func toggle() -> void:
	if visible:
		close_window()
	else:
		open_window()

func refresh() -> void:
	pass

func clear_body() -> void:
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
