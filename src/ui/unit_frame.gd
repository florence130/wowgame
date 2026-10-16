class_name UnitFrame
extends Control
## 头像框（洛奇M风格：粉色生命、蓝色法力、金色能量）

var unit: Unit = null
var small := false
var is_player_frame := false
var horizontal_resources := false
# 平滑显示：hp/power 显示值缓动，ghost 为掉血残影（延迟后追上）
var _hp_disp := 1.0
var _hp_ghost := 1.0
var _ghost_delay := 0.0
var _pw_disp := 1.0
var _t := 0.0

func _init() -> void:
	custom_minimum_size = Vector2(380, 96)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_unit(u: Unit) -> void:
	unit = u
	if small:
		custom_minimum_size = Vector2(260, 52)
		size = custom_minimum_size
	visible = u != null and is_instance_valid(u)
	if visible:
		_hp_disp = u.hp / maxf(1.0, u.max_hp)
		_hp_ghost = _hp_disp
		var primary := _primary_resource()
		_pw_disp = primary["value"] / maxf(1.0, primary["max"])
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	queue_redraw()

func _process(d: float) -> void:
	if unit != null and not is_instance_valid(unit):
		unit = null
		visible = false
	if visible and unit:
		_t += d
		var hp := unit.hp / maxf(1.0, unit.max_hp)
		_hp_disp = lerpf(_hp_disp, hp, minf(1.0, d * 14.0))
		if hp < _hp_ghost:
			_ghost_delay -= d
			if _ghost_delay <= 0.0:
				_hp_ghost = move_toward(_hp_ghost, hp, d * 0.6)
		else:
			_hp_ghost = hp
			_ghost_delay = 0.45
		if hp < _hp_disp - 0.01 and _ghost_delay <= 0.0:
			_ghost_delay = 0.45
		var primary := _primary_resource()
		_pw_disp = lerpf(_pw_disp, primary["value"] / maxf(1.0, primary["max"]), minf(1.0, d * 12.0))
		queue_redraw()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and unit and Game.player:
		Game.player.set_target(unit)

func _power_color(u: Unit) -> Color:
	if u.power_type == "none":
		return Color("b5d38e")
	match u.power_type:
		"rage": return UITheme.RAGE
		"energy": return UITheme.ENERGY
	return UITheme.MP

func _primary_resource() -> Dictionary:
	if unit.power_type == "none":
		return {"value": unit.stamina, "max": unit.max_stamina, "name": "耐力"}
	return {"value": unit.power, "max": unit.max_power, "name": {"rage": "怒气", "energy": "能量"}.get(unit.power_type, "法力")}

func _reaction_color(u: Unit) -> Color:
	if u.is_player:
		return Color("ffffff")
	if u.faction in ["friendly", "companion", "pet"]:
		return Color("60e060")
	if u.faction == "neutral":
		return Color("f0e040")
	return Color("ff5050")

func _draw() -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var f := UITheme.get_font()
	var fb := UITheme.get_font(true)
	if horizontal_resources:
		_draw_resources(f)
		return
	var w := size.x
	var h := size.y
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.08, 0.13, 0.86)
	bg.set_corner_radius_all(14)
	bg.set_border_width_all(1)
	bg.border_color = Color(1, 1, 1, 0.1)
	if unit == (Game.player.target if Game.player else null) and not is_player_frame and small:
		bg.border_color = Color(UITheme.GOLD, 0.8)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	var x0 := 10.0
	if not small:
		# 头像
		var pc := Vector2(48, h * 0.5)
		var ring := Color(1, 1, 1, 0.25)
		if unit.is_boss or unit.is_elite:
			ring = UITheme.GOLD
		if unit.is_rare:
			ring = Color("d0d8e8")
		if unit.in_combat:
			ring = ring.lerp(Color("ff5040"), 0.5 + 0.5 * sin(_t * 6.0))
		draw_circle(pc, 38, ring)
		var pcol := Color("3a4a6a")
		var glyph := ""
		if unit.is_player:
			pcol = DB.class_color(Game.pd["class"]).darkened(0.35)
			glyph = DB.classes[Game.pd["class"]]["name"].substr(0, 1)
		else:
			pcol = _reaction_color(unit).darkened(0.6)
			glyph = unit.unit_name.substr(0, 1)
		draw_circle(pc, 35, pcol)
		draw_circle(pc + Vector2(-8, -10), 18, Color(1, 1, 1, 0.08))
		var gs := 30
		var gw := fb.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x
		draw_string(fb, pc + Vector2(-gw * 0.5, 11), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, gs, Color.WHITE)
		# 等级圆标
		var lc := pc + Vector2(26, 28)
		draw_circle(lc, 13, Color(0.05, 0.06, 0.1, 0.95))
		draw_arc(lc, 13, 0, TAU, 20, ring, 1.5, true)
		var lt := str(unit.level) if not (unit.is_boss and not unit.is_player) else "??"
		var lcol := Color.WHITE
		if not unit.is_player and Game.player:
			var diff = unit.level - Game.player.level
			lcol = Color("ff4040") if diff >= 5 else (Color("ff9030") if diff >= 3 else (Color("ffff40") if diff >= -2 else (Color("40ff40") if diff >= -7 else Color("a0a0a0"))))
		var lw := fb.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(fb, lc + Vector2(-lw * 0.5, 5), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, lcol)
		x0 = 96.0
	var bw := w - x0 - 12.0
	# 名字
	var name_t := unit.unit_name
	if unit.is_elite and not unit.is_player:
		name_t += " ◆精英" if not unit.is_boss else " ◆首领"
	if unit.is_rare:
		name_t += " ◇稀有"
	var ns := 15 if small else 18
	draw_string(fb, Vector2(x0, (18 if small else 26)), name_t, HORIZONTAL_ALIGNMENT_LEFT, bw - 60, ns, _reaction_color(unit) if not unit.is_player else Color("ffe9b0"))
	if small:
		draw_string(f, Vector2(w - 52, 18), "Lv%d" % unit.level, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.TEXT_DIM)
	elif unit.sub_name != "" and not unit.is_player:
		draw_string(f, Vector2(x0 + fb.get_string_size(name_t, HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x + 8, 26), "<%s>" % unit.sub_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.TEXT_DIM)
	# 生命条
	var hy := 26.0 if small else 36.0
	var hh := 12.0 if small else 18.0
	_bar(Rect2(x0, hy, bw, hh), _hp_disp, UITheme.HP if not unit.dead else Color(0.4, 0.4, 0.4), _hp_ghost)
	var ht := "%d / %d" % [int(unit.hp), int(unit.max_hp)]
	if unit.dead:
		ht = "死亡"
	elif not unit.is_player and not unit.faction in ["companion", "pet"]:
		ht = "%d%%" % int(100.0 * unit.hp / maxf(1.0, unit.max_hp))
		if not small:
			ht = "%d / %d  (%s)" % [int(unit.hp), int(unit.max_hp), ht]
	var tw := f.get_string_size(ht, HORIZONTAL_ALIGNMENT_LEFT, -1, 12 if small else 14).x
	_text_outline(f, Vector2(x0 + (bw - tw) * 0.5, hy + hh - (2 if small else 3)), ht, 12 if small else 14)
	# 能量条
	if unit.max_power > 0.0:
		var py := hy + hh + 4
		var ph := 8.0 if small else 14.0
		_bar(Rect2(x0, py, bw, ph), _pw_disp, _power_color(unit))
		if not small:
			var primary := _primary_resource()
			var pt := "%s %d / %d" % [primary["name"], int(primary["value"]), int(primary["max"])]
			var pw := f.get_string_size(pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			_text_outline(f, Vector2(x0 + (bw - pw) * 0.5, py + ph - 2), pt, 12)
	if unit.in_combat and not small:
		draw_string(fb, Vector2(w - 34, 26), "⚔", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ff6050"))

func _bar(r: Rect2, frac: float, c: Color, ghost: float = -1.0) -> void:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(0.02, 0.03, 0.06, 0.85)
	b.set_corner_radius_all(int(r.size.y * 0.5))
	draw_style_box(b, r)
	if ghost > frac + 0.002:
		var gsb := StyleBoxFlat.new()
		gsb.bg_color = Color(1.0, 0.92, 0.85, 0.75)
		gsb.set_corner_radius_all(int(r.size.y * 0.5))
		draw_style_box(gsb, Rect2(r.position, Vector2(maxf(r.size.y, r.size.x * clampf(ghost, 0.0, 1.0)), r.size.y)))
	if frac > 0.0:
		var fsb := StyleBoxFlat.new()
		fsb.bg_color = c
		fsb.set_corner_radius_all(int(r.size.y * 0.5))
		draw_style_box(fsb, Rect2(r.position, Vector2(maxf(r.size.y, r.size.x * clampf(frac, 0.0, 1.0)), r.size.y)))
		var hl := StyleBoxFlat.new()
		hl.bg_color = Color(1, 1, 1, 0.18)
		hl.set_corner_radius_all(int(r.size.y * 0.25))
		draw_style_box(hl, Rect2(r.position + Vector2(3, 2), Vector2(maxf(0.0, r.size.x * clampf(frac, 0.0, 1.0) - 6), r.size.y * 0.35)))

func _draw_resources(f: Font) -> void:
	var gap := 26.0
	var width := (size.x - gap) * 0.5
	var primary := _primary_resource()
	var power_name: String = primary["name"]
	for i in 2:
		var x := i * (width + gap)
		var rect := Rect2(x, 17, width, 10)
		var fraction := _hp_disp if i == 0 else _pw_disp
		var col := UITheme.HP if i == 0 else _power_color(unit)
		draw_rect(rect, Color(0.09, 0.08, 0.075, 0.85))
		if i == 0 and _hp_ghost > fraction:
			draw_rect(Rect2(rect.position, Vector2(width * _hp_ghost, 10)), Color("ecd3d2"))
		draw_rect(Rect2(rect.position, Vector2(width * clampf(fraction, 0.0, 1.0), 10)), col)
		draw_line(rect.position, rect.position + Vector2(width, 0), Color(1, 1, 1, 0.2), 1)
		var text := "%d / %d" % [int(unit.hp), int(unit.max_hp)] if i == 0 else "%d / %d" % [int(primary["value"]), int(primary["max"])]
		if unit.dead and i == 0:
			text = "死亡"
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_text_outline(f, Vector2(x + (width - tw) * 0.5, 25), text, 12)
		_text_outline(f, Vector2(x + 1, 12), "生命" if i == 0 else power_name, 10)
	tooltip_text = "%s · Lv%d\n生命 %d / %d\n%s %d / %d" % [unit.unit_name, unit.level, int(unit.hp), int(unit.max_hp), power_name, int(primary["value"]), int(primary["max"])]
	var resources: Array = []
	if unit.spec == "" and unit.spec_resource_type == "momentum":
		resources.append("momentum")
	if unit.power_type != "none": resources.append("stamina")
	if resources.is_empty(): return
	var rw := (size.x - 12 * (resources.size() - 1)) / resources.size()
	for i in resources.size():
		var key: String = resources[i]
		var value := unit.gauge(key)
		var maximum: float = Unit.GAUGE_MAX.get(key, 100)
		var label: String = Unit.GAUGE_NAMES.get(key, key)
		var col: Color = {"ice_mark": Color("83cfff"), "tide": Color("64c9dd"), "holy_power": Color("ffe095"), "light": Color("ffe095"),
			"bolt": Color("bcadff"), "fury": Color("ed8a71"), "heat": Color("ed9d68"), "ammo": Color("e5cc9a"), "resonance": Color("bf9ddb")}.get(key, Color("b5d38e"))
		if key == "stamina":
			value = unit.stamina
			maximum = unit.max_stamina
			label = "耐力"
			if value < 30:
				col = Color("f08b79")
		elif key == "momentum":
			value = unit.spec_resource
			maximum = unit.max_spec_resource
			label = "势能"
		elif key == "combo":
			value = unit.combo
			maximum = 5.0
			label = "连击点"
		elif key == "heat" and value > 77:
			col = Color("ff6555")
		var x := i * (rw + 12)
		draw_rect(Rect2(x, 43, rw, 7), Color(0.09, 0.08, 0.075, 0.85))
		draw_rect(Rect2(x, 43, rw * clampf(value / maximum, 0.0, 1.0), 7), col)
		_text_outline(f, Vector2(x, 39), "%s %d/%d" % [label, int(value), int(maximum)], 11)
		tooltip_text += "\n%s %d / %d" % [label, int(value), int(maximum)]

func _text_outline(f: Font, p: Vector2, t: String, s: int) -> void:
	draw_string_outline(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, s, 4, Color(0, 0, 0, 0.85))
	draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, s, Color.WHITE)
