class_name IconView
extends Control
## 程序化图标（矢量绘制）：技能/物品/光环。支持品质边框、数量、冷却遮罩。

var icon := "":
	set(v):
		icon = v
		queue_redraw()
var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()
var quality := -1:
	set(v):
		quality = v
		queue_redraw()
var count := 0:
	set(v):
		count = v
		queue_redraw()
var cooldown := 0.0:
	set(v):
		cooldown = v
		queue_redraw()
var dim := false:
	set(v):
		dim = v
		queue_redraw()
var fallback := ""
var corner := 2
var highlight := false:
	set(v):
		highlight = v
		queue_redraw()
var hotkey := "":
	set(v):
		hotkey = v
		queue_redraw()
var cd_text := "":
	set(v):
		cd_text = v
		queue_redraw()
## 动效：悬停金色光圈 / 使用时白色闪光（0-1，由 Slot 用 Tween 驱动）
var hover_a := 0.0:
	set(v):
		hover_a = v
		queue_redraw()
var flash_a := 0.0:
	set(v):
		flash_a = v
		queue_redraw()

func _draw_fx(r: Rect2) -> void:
	if flash_a > 0.01:
		var fb := StyleBoxFlat.new()
		fb.set_corner_radius_all(corner)
		fb.bg_color = Color(1, 1, 0.92, 0.55 * flash_a)
		draw_style_box(fb, r)
	if hover_a > 0.01:
		var hb := StyleBoxFlat.new()
		hb.set_corner_radius_all(corner + 2)
		hb.draw_center = false
		hb.set_border_width_all(2)
		hb.border_color = Color(UITheme.GOLD, 0.9 * hover_a)
		hb.shadow_size = int(8 * hover_a)
		hb.shadow_color = Color(UITheme.GOLD, 0.35 * hover_a)
		draw_style_box(hb, r.grow(1.5))

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = false

func setup(key: String, c: Color, q: int = -1, n: int = 0, fb: String = "") -> IconView:
	icon = key
	color = c
	quality = q
	count = n
	fallback = fb
	return self

func _draw() -> void:
	var s := size
	var r := Rect2(Vector2.ZERO, s)
	# 背景
	var bg := StyleBoxFlat.new()
	bg.set_corner_radius_all(corner)
	if icon == "":
		bg.bg_color = Color(0.05, 0.06, 0.1, 0.75)
		bg.set_border_width_all(1)
		bg.border_color = Color(1, 1, 1, 0.08)
		draw_style_box(bg, r)
		_draw_hotkey()
		_draw_fx(r)
		return
	var base := color.darkened(0.55)
	bg.bg_color = base
	bg.set_border_width_all(2)
	bg.border_color = U.quality_color(quality) if quality >= 0 else Color(1, 1, 1, 0.18)
	if quality == 1:
		bg.border_color = Color(1, 1, 1, 0.35)
	draw_style_box(bg, r)
	var m := minf(s.x, s.y)
	var c := s * 0.5
	var k := m / 64.0
	var col := color.lightened(0.25)
	var dark := color.darkened(0.7)
	var art := IconArt.texture(icon) if icon.begins_with("skills/") else null
	if art != null:
		draw_texture_rect(art, r.grow(-2), false)
	else:
		_glyph(icon, c, k, col, dark)
	if dim:
		var d := StyleBoxFlat.new()
		d.set_corner_radius_all(corner)
		d.bg_color = Color(0.3, 0.0, 0.0, 0.45)
		draw_style_box(d, r)
	if cooldown > 0.0:
		_draw_cooldown(r, cooldown)
	if highlight:
		var hb := StyleBoxFlat.new()
		hb.set_corner_radius_all(corner)
		hb.bg_color = Color(1, 1, 0.7, 0.18)
		hb.set_border_width_all(2)
		hb.border_color = Color(1, 0.95, 0.6, 0.9)
		draw_style_box(hb, r)
	if count > 1:
		var f := UITheme.get_font(true)
		var txt := str(count)
		var fs := int(maxf(11.0, m * 0.28))
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(f, Vector2(s.x - w - 4, s.y - 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
		draw_string(f, Vector2(s.x - w - 4, s.y - 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	if cd_text != "":
		var f2 := UITheme.get_font(true)
		var fs2 := int(m * 0.36)
		var w2 := f2.get_string_size(cd_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var p2 := Vector2((s.x - w2) * 0.5, s.y * 0.5 + fs2 * 0.35)
		draw_string_outline(f2, p2, cd_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 5, Color(0, 0, 0, 1))
		draw_string(f2, p2, cd_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color("fff4c0"))
	_draw_hotkey()
	_draw_fx(r)

func _draw_hotkey() -> void:
	if hotkey == "":
		return
	var f := UITheme.get_font(true)
	var fs := int(maxf(10.0, size.x * 0.22))
	draw_string_outline(f, Vector2(4, fs + 1), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
	draw_string(f, Vector2(4, fs + 1), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("e0e0e0"))

func _draw_cooldown(r: Rect2, frac: float) -> void:
	var c := r.size * 0.5
	var rad := r.size.length() * 0.5
	var pts := PackedVector2Array([c])
	var start := -PI * 0.5
	var end := start + TAU * frac
	var steps := 32
	for i in steps + 1:
		var a := lerpf(start, end, float(i) / steps)
		var p := c + Vector2(cos(a), sin(a)) * rad
		p.x = clampf(p.x, 2, r.size.x - 2)
		p.y = clampf(p.y, 2, r.size.y - 2)
		pts.append(p)
	draw_colored_polygon(pts, Color(0, 0, 0, 0.62))

func _poly(pts: Array, c: Color, center: Vector2, k: float) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(center + Vector2(p[0], p[1]) * k)
	draw_colored_polygon(arr, c)

func _line(a: Array, b: Array, c: Color, center: Vector2, k: float, w: float = 3.0) -> void:
	draw_line(center + Vector2(a[0], a[1]) * k, center + Vector2(b[0], b[1]) * k, c, w * k, true)

func _circle(p: Array, r: float, c: Color, center: Vector2, k: float) -> void:
	draw_circle(center + Vector2(p[0], p[1]) * k, r * k, c)

func _ring(p: Array, r: float, c: Color, center: Vector2, k: float, w: float = 3.0) -> void:
	draw_arc(center + Vector2(p[0], p[1]) * k, r * k, 0, TAU, 32, c, w * k, true)

func _glyph(key: String, c: Vector2, k: float, col: Color, dark: Color) -> void:
	var W := Color(1, 1, 1, 0.95)
	match key:
		"sword":
			_poly([[-4, 14], [16, -18], [20, -22], [18, -14], [0, 18]], W, c, k)
			_line([-12, 6], [6, 22], col, c, k, 5)
			_line([-8, 14], [-18, 24], dark.lightened(0.3), c, k, 5)
		"dagger":
			_poly([[-2, 8], [14, -14], [16, -16], [14, -10], [2, 12]], W, c, k)
			_line([-8, 4], [6, 16], col, c, k, 4)
			_line([-4, 12], [-12, 20], dark.lightened(0.3), c, k, 5)
		"axe":
			_line([-16, 20], [10, -14], Color("a07040"), c, k, 5)
			_poly([[2, -18], [18, -10], [20, 6], [10, -2]], W, c, k)
		"mace":
			_line([-16, 20], [6, -4], Color("a07040"), c, k, 5)
			_circle([10, -10], 10, W, c, k)
			_circle([10, -10], 5, col, c, k)
		"staff":
			_line([-14, 22], [10, -14], Color("c09060"), c, k, 4)
			_circle([12, -16], 8, col, c, k)
			_circle([12, -16], 4, W, c, k)
		"spear":
			_line([-18, 20], [12, -12], Color("a07040"), c, k, 3)
			_poly([[8, -10], [20, -20], [14, -6]], W, c, k)
		"gun":
			_poly([[-20, 6], [8, -6], [22, -6], [22, -1], [6, 2], [-2, 12], [-10, 16], [-16, 12]], Color("8a6040"), c, k)
			_line([0, -4], [22, -4], Color("c0c0c8"), c, k, 4)
			_circle([-2, 4], 3, col, c, k)
		"bow":
			draw_arc(c + Vector2(-6, 0) * k, 20 * k, -1.2, 1.2, 20, Color("c09060"), 4 * k, true)
			_line([3, -18], [3, 18], W, c, k, 1.5)
			_line([-16, 0], [18, 0], W, c, k, 2)
		"shield":
			_poly([[-16, -18], [16, -18], [16, 0], [0, 20], [-16, 0]], col, c, k)
			_poly([[-10, -12], [10, -12], [10, 0], [0, 12], [-10, 0]], dark.lightened(0.2), c, k)
			_circle([0, -2], 4, W, c, k)
		"book":
			_poly([[-16, -18], [14, -18], [14, 18], [-16, 18]], col, c, k)
			_poly([[-12, -14], [12, -14], [12, 14], [-12, 14]], Color("f0e8d0"), c, k)
			_circle([0, 0], 5, color, c, k)
		"fire", "explosion":
			_poly([[0, -22], [10, -6], [14, 8], [6, 20], [-6, 20], [-14, 8], [-8, -4], [-4, 4]], Color("ff7020"), c, k)
			_poly([[0, -8], [6, 4], [4, 16], [-4, 16], [-6, 6]], Color("ffe060"), c, k)
			if key == "explosion":
				for i in 8:
					var a := i * TAU / 8.0
					_line([cos(a) * 16, sin(a) * 16], [cos(a) * 24, sin(a) * 24], Color("fff0a0"), c, k, 3)
		"frost":
			for i in 3:
				var a := i * PI / 3.0
				_line([cos(a) * -20, sin(a) * -20], [cos(a) * 20, sin(a) * 20], Color("e0f8ff"), c, k, 4)
			_circle([0, 0], 5, Color("a0e0ff"), c, k)
		"arcane", "missiles", "blink":
			var pts := []
			for i in 10:
				var a := i * TAU / 10.0 - PI * 0.5
				var rr := 20.0 if i % 2 == 0 else 8.0
				pts.append([cos(a) * rr, sin(a) * rr])
			_poly(pts, Color("f0c0ff"), c, k)
			if key == "missiles":
				_circle([-14, 14], 5, W, c, k)
				_circle([14, 14], 5, W, c, k)
		"holy":
			_circle([0, 0], 10, Color("fff0a0"), c, k)
			for i in 8:
				var a2 := i * TAU / 8.0
				_line([cos(a2) * 13, sin(a2) * 13], [cos(a2) * 22, sin(a2) * 22], Color("ffe070"), c, k, 3)
		"shadow", "brain":
			_circle([0, 0], 17, Color("6030a0"), c, k)
			_circle([6, -4], 13, color.darkened(0.55), c, k)
			_circle([-6, 4], 4, Color("d0a0ff"), c, k)
		"nature", "herb", "wind":
			_poly([[0, -20], [14, -6], [10, 12], [0, 20], [-10, 12], [-14, -6]], Color("70d050"), c, k)
			_line([0, -16], [0, 20], Color("306020"), c, k, 2)
		"heal":
			_poly([[-6, -20], [6, -20], [6, -6], [20, -6], [20, 6], [6, 6], [6, 20], [-6, 20], [-6, 6], [-20, 6], [-20, -6], [-6, -6]], Color("fffbe0"), c, k)
		"renew":
			_poly([[0, -20], [14, -4], [8, 14], [-8, 14], [-14, -4]], Color("90ff90"), c, k)
			_line([0, -8], [0, 10], W, c, k, 4)
			_line([-8, 1], [8, 1], W, c, k, 4)
		"pwshield", "fort", "armor":
			_ring([0, 0], 18, Color("fff0a0"), c, k, 4)
			_poly([[-10, -10], [10, -10], [10, 2], [0, 14], [-10, 2]], Color("fff8d0"), c, k)
		"stealth":
			_poly([[-18, 0], [0, -12], [18, 0], [0, 12]], Color("c0c0e0"), c, k)
			_circle([0, 0], 6, dark, c, k)
			_line([-20, 14], [20, -14], Color("202030"), c, k, 4)
		"sprint", "charge", "jump":
			_poly([[-18, -6], [4, -6], [4, -16], [20, 0], [4, 16], [4, 6], [-18, 6]], W, c, k)
		"evade":
			draw_arc(c, 16 * k, 0.3, 5.2, 24, W, 4 * k, true)
			_poly([[14, -12], [22, -4], [12, -2]], W, c, k)
		"kick":
			_poly([[-10, -20], [2, -20], [2, 6], [18, 8], [18, 18], [-10, 18]], Color("c0a070"), c, k)
		"poison", "water", "bleed":
			var dc := Color("80e060") if key == "poison" else (Color("80c0ff") if key == "water" else Color("e03030"))
			_poly([[0, -22], [12, 2], [10, 14], [0, 20], [-10, 14], [-12, 2]], dc, c, k)
			_circle([-4, 6], 3, W, c, k)
		"mark":
			_ring([0, 0], 16, Color("ff5050"), c, k, 3)
			_ring([0, 0], 7, Color("ff5050"), c, k, 3)
			_line([0, -22], [0, 22], Color("ff8080"), c, k, 2)
			_line([-22, 0], [22, 0], Color("ff8080"), c, k, 2)
		"pet", "claw", "fang":
			_circle([0, 8], 10, Color("f0d0a0"), c, k)
			for p in [[-12, -6], [-4, -14], [6, -14], [13, -6]]:
				_circle(p, 5, Color("f0d0a0"), c, k)
		"nova":
			_ring([0, 0], 18, Color("c0e0ff"), c, k, 4)
			_ring([0, 0], 10, Color("e0f0ff"), c, k, 3)
			_circle([0, 0], 4, W, c, k)
		"sheep":
			_circle([2, 2], 15, Color("f8f8f0"), c, k)
			_circle([-12, -6], 7, Color("3a3a3a"), c, k)
		"scream", "shout":
			_poly([[-18, -6], [-6, -6], [6, -16], [6, 16], [-6, 6], [-18, 6]], W, c, k)
			draw_arc(c + Vector2(6, 0) * k, 10 * k, -0.8, 0.8, 10, W, 3 * k, true)
			draw_arc(c + Vector2(6, 0) * k, 17 * k, -0.8, 0.8, 10, W, 3 * k, true)
		"bread", "cheese":
			_poly([[-18, 8], [-14, -8], [0, -14], [14, -8], [18, 8]], Color("e0a050") if key == "bread" else Color("f0d050"), c, k)
			_line([-8, -6], [-4, 4], Color("a06020"), c, k, 2)
			_line([4, -8], [6, 2], Color("a06020"), c, k, 2)
		"meat":
			_circle([-4, -4], 13, Color("b05030"), c, k)
			_line([6, 6], [18, 18], Color("f0e8d8"), c, k, 5)
		"potion_red", "potion_blue":
			var pc := Color("e04040") if key == "potion_red" else Color("4060ff")
			_circle([0, 6], 13, pc, c, k)
			_poly([[-5, -18], [5, -18], [5, -4], [-5, -4]], Color("e0e8f0"), c, k)
			_circle([-4, 2], 3, W, c, k)
		"chest", "shirt", "tabard":
			_poly([[-18, -16], [-6, -18], [0, -12], [6, -18], [18, -16], [22, 0], [14, 2], [14, 20], [-14, 20], [-14, 2], [-22, 0]], col, c, k)
			if key == "tabard":
				_poly([[-6, -10], [6, -10], [6, 18], [-6, 18]], Color("e8c27a"), c, k)
		"legs":
			_poly([[-14, -18], [14, -18], [16, 20], [4, 20], [0, -4], [-4, 20], [-16, 20]], col, c, k)
		"head":
			draw_circle(c + Vector2(0, 2) * k, 18 * k, col)
			_poly([[-20, 4], [20, 4], [20, 10], [-20, 10]], col.darkened(0.2), c, k)
			_poly([[-3, 2], [3, 2], [3, 18], [-3, 18]], dark, c, k)
		"feet":
			_poly([[-8, -20], [6, -20], [6, 6], [20, 10], [20, 18], [-8, 18]], col, c, k)
		"hands":
			_poly([[-12, 18], [-12, -4], [-16, -14], [-10, -16], [-6, -8], [-6, -20], [0, -20], [0, -8], [4, -20], [10, -18], [6, -6], [12, -12], [16, -8], [10, 4], [8, 18]], col, c, k)
		"wrist":
			_poly([[-14, -10], [14, -10], [14, 10], [-14, 10]], col, c, k)
			_line([-14, 0], [14, 0], Color("e8c27a"), c, k, 3)
		"waist":
			_poly([[-22, -6], [22, -6], [22, 6], [-22, 6]], col, c, k)
			_poly([[-6, -9], [6, -9], [6, 9], [-6, 9]], Color("e8c27a"), c, k)
		"back":
			_poly([[-10, -20], [10, -20], [18, 20], [-18, 20]], col, c, k)
		"ring":
			_ring([0, 4], 13, Color("ffd060"), c, k, 5)
			_circle([0, -12], 6, col, c, k)
		"neck", "trinket":
			draw_arc(c + Vector2(0, -8) * k, 16 * k, 0.2, PI - 0.2, 16, Color("ffd060"), 3 * k, true)
			_circle([0, 10], 8, col, c, k)
		"letter", "scroll", "map":
			_poly([[-18, -12], [18, -12], [18, 14], [-18, 14]], Color("f0e6c8"), c, k)
			_line([-18, -12], [0, 2], Color("a08a60"), c, k, 2)
			_line([18, -12], [0, 2], Color("a08a60"), c, k, 2)
			if key == "letter":
				_circle([0, 4], 4, Color("c03030"), c, k)
		"ore", "gem", "coin":
			var oc := Color("d08050") if key == "ore" else (Color("ffd040") if key == "coin" else col)
			_poly([[0, -18], [16, -4], [10, 16], [-10, 16], [-16, -4]], oc, c, k)
			_poly([[0, -12], [8, -4], [0, 4], [-8, -4]], W.lerp(oc, 0.4), c, k)
		"candle":
			_poly([[-6, -6], [6, -6], [6, 20], [-6, 20]], Color("f0e8c0"), c, k)
			_poly([[0, -20], [5, -10], [0, -6], [-5, -10]], Color("ffb030"), c, k)
		"crate", "bag":
			_poly([[-18, -16], [18, -16], [18, 18], [-18, 18]], Color("b07a40"), c, k)
			_line([-18, -16], [18, 18], Color("6a4020"), c, k, 3)
			_line([-18, 18], [18, -16], Color("6a4020"), c, k, 3)
		"gear":
			for i in 8:
				var a3 := i * TAU / 8.0
				_circle([cos(a3) * 15, sin(a3) * 15], 5, Color("c0b090"), c, k)
			_circle([0, 0], 14, Color("c0b090"), c, k)
			_circle([0, 0], 6, dark, c, k)
		"feather":
			_poly([[-14, 18], [12, -18], [18, -14], [-8, 18]], Color("d0e0f0"), c, k)
			_line([-16, 20], [14, -16], W, c, k, 1.5)
		"web":
			for i in 4:
				var a4 := i * PI / 4.0
				_line([cos(a4) * -20, sin(a4) * -20], [cos(a4) * 20, sin(a4) * 20], W, c, k, 1.5)
			_ring([0, 0], 8, W, c, k, 1.5)
			_ring([0, 0], 16, W, c, k, 1.5)
		"hearth":
			_circle([0, 0], 17, Color("6080c0"), c, k)
			_circle([0, 0], 11, Color("a0c8ff"), c, k)
			_circle([-4, -4], 4, W, c, k)
		"flower":
			for i in 5:
				var a5 := i * TAU / 5.0
				_circle([cos(a5) * 9, sin(a5) * 9 - 4], 7, col, c, k)
			_circle([0, -4], 5, Color("ffe060"), c, k)
			_line([0, 4], [0, 22], Color("4a9a3a"), c, k, 3)
		"bone":
			_line([-14, 14], [14, -14], Color("f0e8d8"), c, k, 6)
			for p in [[-16, 10], [-10, 16], [10, -16], [16, -10]]:
				_circle(p, 5, Color("f0e8d8"), c, k)
		"cloth", "leather":
			_poly([[-16, -14], [16, -18], [18, 14], [-14, 18]], col, c, k)
			_line([-10, -6], [12, -10], col.lightened(0.3), c, k, 2)
		"fin":
			_poly([[-18, 16], [0, -18], [18, 16]], col, c, k)
			_line([0, -14], [0, 14], dark, c, k, 2)
		"horse":
			_poly([[-16, 18], [-12, -4], [-2, -18], [10, -16], [16, -8], [8, -6], [4, 6], [6, 18]], Color("c08a5a"), c, k)
			_circle([6, -12], 2, dark, c, k)
		"deer":
			_poly([[-14, 20], [-10, -2], [-2, -14], [10, -12], [14, -4], [6, 0], [4, 20]], Color("e0dcc8"), c, k)
			_line([-10, -6], [-6, -22], Color("c8c0a0"), c, k, 3)
			_line([-6, -22], [-14, -22], Color("c8c0a0"), c, k, 3)
			_line([-3, -8], [4, -24], Color("c8c0a0"), c, k, 3)
			_line([4, -24], [12, -22], Color("c8c0a0"), c, k, 3)
			_circle([7, -7], 2, dark, c, k)
		"wolf":
			_poly([[-16, 14], [-12, -6], [-4, -18], [4, -6], [12, -10], [16, 2], [8, 16], [-6, 18]], Color("6a6a72"), c, k)
			_poly([[-6, -12], [-10, -24], [-2, -16]], Color("4a4a52"), c, k)
			_poly([[-2, -14], [4, -24], [6, -12]], Color("4a4a52"), c, k)
			_circle([2, -4], 2, Color("e05050"), c, k)
			_line([16, 2], [22, 6], Color("3a3a42"), c, k, 3)
		"bear":
			_circle([0, 4], 13, Color("6a4a30"), c, k)
			_circle([-10, -11], 6, Color("6a4a30"), c, k)
			_circle([10, -11], 6, Color("6a4a30"), c, k)
			_circle([0, 5], 7, Color("8a6a4a"), c, k)
			_circle([0, 7], 3, Color("2a1a10"), c, k)
		_:
			var f := UITheme.get_font(true)
			var t := fallback if fallback != "" else key.substr(0, 1).to_upper()
			if t.length() > 0:
				t = t.substr(0, 1)
			var fs := int(30 * k)
			var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, c + Vector2(-w * 0.5, fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, W)
