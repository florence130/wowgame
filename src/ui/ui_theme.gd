class_name UITheme
extends RefCounted
## Reference-inspired charcoal panels, restrained ivory tabs and fine bronze rules.

const BG := Color(0.105, 0.104, 0.096, 0.95)
const BG2 := Color(0.145, 0.14, 0.13, 0.96)
const BG3 := Color(0.21, 0.20, 0.185, 0.96)
const LINE := Color(1, 1, 1, 0.08)
const GOLD := Color("d6c3a2")
const GOLD_D := Color("8f7c60")
const BEIGE := Color("b9afa1")
const TEXT := Color("ecebe6")
const TEXT_DIM := Color("a9a49b")
const HP := Color("ce6289")
const MP := Color("657fcd")
const SP := Color("e8b04a")
const XP := Color("a070e0")
const RAGE := Color("d84040")
const ENERGY := Color("f0d040")

static var font: SystemFont
static var font_bold: SystemFont

static func get_font(bold: bool = false) -> Font:
	if font == null:
		font = SystemFont.new()
		font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "Source Han Sans SC", "WenQuanYi Micro Hei", "SimHei", "sans-serif"])
		font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		font.hinting = TextServer.HINTING_LIGHT
		font_bold = SystemFont.new()
		font_bold.font_names = font.font_names
		font_bold.font_weight = 700
	return font_bold if bold else font

static func sb(c: Color, r: int = 10, border: int = 0, bc: Color = LINE, pad: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(r)
	s.set_border_width_all(border)
	s.border_color = bc
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	s.anti_aliasing = true
	return s

## 窗口面板：深色半透明 + 顶部金色细线 + 柔和投影
static func window_sb() -> StyleBoxFlat:
	var s := sb(BG, 3, 1, Color(0.52, 0.48, 0.4, 0.28), 14)
	s.border_width_top = 1
	s.shadow_size = 12
	s.shadow_color = Color(0, 0, 0, 0.32)
	s.shadow_offset = Vector2(0, 4)
	return s

static func build() -> Theme:
	var t := Theme.new()
	t.default_font = get_font()
	t.default_font_size = 17
	# Panel
	t.set_stylebox("panel", "Panel", sb(BG, 3, 1, LINE, 10))
	t.set_stylebox("panel", "PanelContainer", sb(BG, 3, 1, LINE, 10))
	# Button
	var bn := sb(BG3, 3, 1, Color(1, 1, 1, 0.08), 12)
	bn.shadow_size = 3
	bn.shadow_color = Color(0, 0, 0, 0.3)
	bn.shadow_offset = Vector2(0, 2)
	var bh := sb(Color(0.29, 0.275, 0.25, 0.98), 3, 1, Color(GOLD, 0.5), 12)
	bh.shadow_size = 8
	bh.shadow_color = Color(GOLD, 0.18)
	var bp := sb(BEIGE, 3, 1, GOLD, 12)
	var bd := sb(Color(0.12, 0.115, 0.10, 0.8), 3, 1, Color(1, 1, 1, 0.04), 12)
	t.set_stylebox("normal", "Button", bn)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("hover_pressed", "Button", bp)
	t.set_stylebox("disabled", "Button", bd)
	t.set_stylebox("focus", "Button", sb(Color.TRANSPARENT, 3, 1, Color(GOLD, 0.75), 0))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color("2a2418"))
	t.set_color("font_hover_pressed_color", "Button", Color("2a2418"))
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.3))
	# Label
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))
	t.set_constant("outline_size", "Label", 0)
	# LineEdit
	var le := sb(Color(0.03, 0.04, 0.07, 0.85), 8, 1, Color(1, 1, 1, 0.12), 8)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", sb(Color(0.03, 0.04, 0.07, 0.9), 8, 1, Color(GOLD, 0.7), 8))
	t.set_color("font_color", "LineEdit", TEXT)
	# ProgressBar
	t.set_stylebox("background", "ProgressBar", sb(Color(0, 0, 0, 0.55), 5, 0, LINE, 0))
	t.set_stylebox("fill", "ProgressBar", sb(HP, 5, 0, LINE, 0))
	t.set_color("font_color", "ProgressBar", Color.WHITE)
	# Scroll
	var sg := sb(Color(1, 1, 1, 0.25), 4, 0, LINE, 0)
	t.set_stylebox("grabber", "VScrollBar", sg)
	t.set_stylebox("grabber_highlight", "VScrollBar", sb(Color(GOLD, 0.6), 4, 0, LINE, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", sb(GOLD, 4, 0, LINE, 0))
	t.set_stylebox("scroll", "VScrollBar", sb(Color(0, 0, 0, 0.25), 4, 0, LINE, 0))
	# Tooltip
	var tip := sb(Color(0.05, 0.06, 0.1, 0.96), 10, 1, Color(GOLD, 0.35), 10)
	tip.shadow_size = 10
	tip.shadow_color = Color(0, 0, 0, 0.45)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	# RichTextLabel
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("bold_font", "RichTextLabel", get_font(true))
	# OptionButton / CheckBox
	t.set_stylebox("normal", "OptionButton", bn)
	t.set_stylebox("hover", "OptionButton", bh)
	t.set_stylebox("pressed", "OptionButton", bh)
	t.set_stylebox("panel", "PopupMenu", sb(BG2, 8, 1, LINE, 6))
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_pressed_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_color("font_hover_pressed_color", "CheckBox", Color.WHITE)
	t.set_color("font_focus_color", "CheckBox", Color.WHITE)
	t.set_stylebox("normal", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckBox", StyleBoxEmpty.new())
	# Slider
	t.set_stylebox("slider", "HSlider", sb(Color(0, 0, 0, 0.5), 4, 0, LINE, 2))
	t.set_stylebox("grabber_area", "HSlider", sb(GOLD_D, 4, 0, LINE, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", sb(GOLD, 4, 0, LINE, 2))
	# TabContainer-like buttons are plain buttons
	return t

## 带标题栏与关闭按钮的窗口面板
static func window(title: String, size: Vector2, closable: bool = true) -> Dictionary:
	var p := PanelContainer.new()
	p.custom_minimum_size = size
	p.add_theme_stylebox_override("panel", sb(BG, 16, 1, Color(1, 1, 1, 0.1), 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	var dot := Label.new()
	dot.text = "✦"
	dot.add_theme_color_override("font_color", GOLD)
	h.add_child(dot)
	var l := Label.new()
	l.text = title
	l.add_theme_font_override("font", get_font(true))
	l.add_theme_font_size_override("font_size", 21)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var close: Button = null
	if closable:
		close = Button.new()
		close.text = "✕"
		close.flat = true
		close.add_theme_font_size_override("font_size", 20)
		close.add_theme_color_override("font_color", TEXT_DIM)
		h.add_child(close)
	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.07)
	sep.custom_minimum_size = Vector2(0, 1)
	v.add_child(sep)
	return {"root": p, "body": v, "title": l, "close": close, "header": h}

static func label(text: String, size: int = 17, col: Color = TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if bold:
		l.add_theme_font_override("font", get_font(true))
	return l

static func button(text: String, cb: Callable = Callable(), min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	if min_w > 0.0:
		b.custom_minimum_size.x = min_w
	if cb.is_valid():
		b.pressed.connect(func(): Sfx.play("click"); cb.call())
	return b

static func tab_button(text: String, active: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = active
	b.add_theme_stylebox_override("normal", sb(Color(0.16, 0.155, 0.14, 0.9), 18, 0, LINE, 14))
	b.add_theme_stylebox_override("pressed", sb(BEIGE, 18, 0, LINE, 14))
	b.add_theme_stylebox_override("hover", sb(Color(0.28, 0.265, 0.24, 0.95), 18, 0, LINE, 14))
	b.add_theme_stylebox_override("hover_pressed", sb(BEIGE, 18, 0, LINE, 14))
	return b

static func bar(fill: Color, h: float = 14.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_stylebox_override("fill", sb(fill, 1, 0, LINE, 0))
	b.add_theme_stylebox_override("background", sb(Color(0.07, 0.065, 0.06, 0.8), 1, 0, LINE, 0))
	return b
