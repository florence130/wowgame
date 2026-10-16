extends Control
## Independent job instruments. Vitals and ordinary mana/energy remain in UnitFrame.
const GOLD := Color("edce86")
const ICE := Color("88d7f0")
const DARK := Color("b49aee")
const WATER := Color("69d4d8")
const FIRE := Color("ee9363")
const EMPTY := Color("263442")
const INK := Color("101c2b")
var unit: Unit
var pulse := 0.0

func _init() -> void:
	custom_minimum_size = Vector2(260, 224)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	unit = Game.player
	visible = is_instance_valid(unit) and unit.spec != ""
	pulse += delta
	if visible: queue_redraw()

func _text(at: Vector2, value: String, font_size: int = 17, color: Color = Color("efe9da")) -> void:
	var font := UITheme.get_font()
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string_outline(font, at - Vector2(width * 0.5, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.04, 0.06, 0.09, 0.9))
	draw_string(font, at - Vector2(width * 0.5, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _diamond(at: Vector2, radius_: float, filled: bool, color: Color) -> void:
	var points := PackedVector2Array([at + Vector2(0, -radius_), at + Vector2(radius_ * 0.68, 0), at + Vector2(0, radius_), at + Vector2(-radius_ * 0.68, 0)])
	if filled: draw_circle(at, radius_ * 1.3, Color(color, 0.09), true, -1, true)
	draw_colored_polygon(points, color if filled else EMPTY)
	points.append(points[0])
	draw_polyline(points, color.lightened(0.25) if filled else color.darkened(0.2), 1.8, true)
	if filled: draw_line(at + Vector2(-radius_ * 0.3, 0), at + Vector2(0, -radius_ * 0.6), color.lightened(0.5), 1.8, true)

func _ring(at: Vector2, radius_: float, fraction: float, color: Color, start: float = PI * 0.75, sweep: float = PI * 1.5) -> void:
	draw_circle(at, radius_ + 10, Color(INK, 0.8), true, -1, true)
	draw_arc(at, radius_, start, start + sweep, 64, EMPTY, 11, true)
	draw_arc(at, radius_, start, start + sweep, 64, color.darkened(0.25), 1, true)
	if fraction > 0:
		draw_arc(at, radius_, start, start + sweep * clampf(fraction, 0, 1), 64, Color(color, 0.15), 17, true)
		draw_arc(at, radius_, start, start + sweep * clampf(fraction, 0, 1), 64, color, 7, true)
	draw_arc(at, radius_ + 9, start, start + sweep, 64, Color(color, 0.65), 1.5, true)
	for end in [start, start + sweep]: _diamond(at + Vector2.from_angle(end) * radius_, 4, true, color)

func _ready_text(value: String, ready_: bool, color: Color = GOLD) -> void:
	var glow := color.lightened(0.12 + sin(pulse * 4) * 0.08) if ready_ else Color("b3bec6")
	draw_line(Vector2(28, 186), Vector2(232, 186), Color(color, 0.35), 1, true)
	_text(Vector2(130, 210), value, 16, glow)

func _aura(id: String) -> bool:
	return not unit.get_aura(id).is_empty()

func _target_aura(id: String) -> bool:
	return is_instance_valid(unit.target) and not unit.target.get_aura(id).is_empty()

func _draw() -> void:
	if not is_instance_valid(unit) or unit.spec == "": return
	var center := Vector2(130, 106)
	var job: String = unit.spec
	var title: String = {"paladin": "誓约之盾", "berserker": "血性战意", "dark_mage": "冰火回路", "elementalist": "水雷共鸣", "radiant": "水华祈愿", "shadow_priest": "双辉天秤", "assassin": "毒刃连击", "duelist": "魔刃回响", "marksman": "枪械弹仓", "gadgeteer": "外装甲温控"}.get(job, "职业量谱")
	var accent: Color = {"berserker": FIRE, "dark_mage": ICE, "elementalist": WATER, "radiant": WATER, "assassin": Color("c4dc7c"), "duelist": DARK, "gadgeteer": FIRE}.get(job, GOLD)
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color(INK, 0.78)
	backdrop.set_corner_radius_all(18)
	draw_style_box(backdrop, Rect2(8, 8, 244, 212))
	_text(Vector2(130, 33), title, 20, accent.lightened(0.3))
	for side in [-1, 1]:
		draw_polyline(PackedVector2Array([Vector2(130 + side * 103, 48), Vector2(130 + side * 111, 40), Vector2(130 + side * 111, 25), Vector2(130 + side * 101, 17)]), Color(accent, 0.65), 1.5, true)
	match job:
		"paladin":
			var shield := PackedVector2Array([Vector2(43, 58), Vector2(217, 58), Vector2(205, 124), Vector2(130, 151), Vector2(55, 124), Vector2(43, 58)])
			draw_colored_polygon(shield, Color(GOLD, 0.06))
			draw_polyline(shield, GOLD.darkened(0.2), 2, true)
			for i in 5: _diamond(Vector2(62 + i * 34, 98), 19, unit.gauge("holy_power") > i, GOLD)
			_text(Vector2(130, 175), "神圣之力  %d / 5" % int(unit.gauge("holy_power")), 17, GOLD)
			_ready_text("盾反强化 · 圣光冲击" if _aura("pd_counter") else ("3力 · 圣光冲击" if unit.gauge("holy_power") >= 3 else ("誓约接续 · 盾击 +2" if _aura("pd_oath") else "誓约斩 → 盾击")), _aura("pd_counter") or unit.gauge("holy_power") >= 3)
		"berserker":
			_ring(center, 46, unit.gauge("fury") / 100, FIRE)
			_diamond(center, 23, _aura("bk_flow"), FIRE)
			_text(center + Vector2(0, 7), "%d" % int(unit.gauge("fury")), 24)
			_text(Vector2(130, 175), "30嗜血 · 50处决", 17, FIRE)
			_ready_text("嗜血接续 · 斩裂 +18" if _aura("bk_flow") else ("狂怒充足 · 消耗攻击" if unit.gauge("fury") >= 30 else "斩裂积攒狂怒"), _aura("bk_flow") or unit.gauge("fury") >= 30, FIRE)
		"dark_mage":
			for i in 5: _diamond(Vector2(62 + i * 34, 72), 16, unit.gauge("ice_mark") > i, ICE)
			_text(Vector2(130, 106), "冰 %d / 5 · 火法加速" % int(unit.gauge("ice_mark")), 17, ICE)
			for i in 3:
				var at := Vector2(86 + i * 44, 131)
				draw_circle(at, 13, DARK if unit.gauge("ember") > i else EMPTY, true, -1, true)
				draw_arc(at, 16, 0, TAU, 32, DARK.darkened(0.1), 1.8, true)
				if unit.gauge("ember") > i: draw_circle(at - Vector2(3, 4), 3, DARK.lightened(0.5), true, -1, true)
			_text(Vector2(130, 175), "余烬  %d / 3" % int(unit.gauge("ember")), 17, DARK)
			_ready_text("3余烬 · 虚空脉冲" if unit.gauge("ember") >= 3 else "霜刺 → 火法 → 暗爆发", unit.gauge("ember") >= 3, DARK)
		"elementalist":
			_ring(center, 43, unit.gauge("tide") / 5, WATER, PI * 0.6, PI * 1.8)
			for i in 5:
				var at := center + Vector2.from_angle(-PI * 0.7 + i * PI * 0.35) * 43
				_diamond(at, 9, unit.gauge("tide") > i, WATER)
			_text(center + Vector2(0, 8), "%d / 5" % int(unit.gauge("tide")), 23, WATER)
			_text(Vector2(130, 175), "浸水连携" if _target_aura("el_wet") else "水法铺设浸水", 17, WATER)
			_ready_text("回流 · 水弹加速 / +2" if _aura("el_return") else ("2潮涌 · 雷击 / 连锁" if unit.gauge("tide") >= 2 else "水弹积攒潮涌"), _aura("el_return") or unit.gauge("tide") >= 2, WATER)
		"radiant":
			draw_arc(center, 73, PI * 0.13, PI * 0.87, 32, Color(WATER, 0.5), 1.5, true)
			for i in 3:
				var at := Vector2(76 + i * 54, 99)
				var active := unit.gauge("bloom") > i
				for petal in 4: _diamond(at + Vector2.from_angle(petal * PI * 0.5) * 12, 13, active, WATER)
				draw_circle(at, 5, GOLD if active else EMPTY, true, -1, true)
			_text(Vector2(130, 175), "水华  %d / 3" % int(unit.gauge("bloom")), 17, WATER)
			_ready_text("3水华 · 免费快速圣光" if unit.gauge("bloom") >= 3 else "水祝福 → 有效风治疗", unit.gauge("bloom") >= 3, WATER)
		"shadow_priest":
			draw_polyline(PackedVector2Array([Vector2(62, 67), Vector2(130, 49), Vector2(198, 67)]), GOLD.darkened(0.2), 2, true)
			draw_line(Vector2(130, 50), Vector2(130, 142), GOLD.darkened(0.4), 2, true)
			for i in 2:
				var key := "light" if i == 0 else "bolt"
				var color := GOLD if i == 0 else DARK
				var x := 63 + i * 110
				draw_rect(Rect2(x - 3, 57, 31, 89), color.darkened(0.45))
				draw_rect(Rect2(x, 60, 25, 83), EMPTY)
				var fill := unit.gauge(key) * 0.83
				draw_rect(Rect2(x, 143 - fill, 25, fill), color)
				for threshold in [20, 40]:
					var y: float = 143 - threshold * 0.83
					draw_line(Vector2(x - 5, y), Vector2(x + 30, y), color.lightened(0.3), 1.5, true)
				_text(Vector2(x + 12, 175), "%s %d" % ["光" if i == 0 else "雷", int(unit.gauge(key))], 18, color)
			_diamond(center, 17, _aura("cl_thunder_brand"), GOLD.lerp(DARK, 0.5))
			var release := unit.gauge("light") >= 40 and unit.gauge("bolt") >= 40 and _aura("cl_thunder_brand")
			_ready_text("余光 · 治疗 / 壁垒二选一" if _aura("cl_afterglow") else ("双40 + 附魔 · 破击" if release else ("雷附魔 → 积攒双40" if _aura("cl_thunder_brand") else "锤击积攒 → 20雷附魔")), _aura("cl_afterglow") or release, GOLD)
		"assassin":
			draw_polyline(PackedVector2Array([Vector2(38, 73), Vector2(130, 58), Vector2(222, 73)]), Color(accent, 0.6), 2, true)
			for i in 5: _diamond(Vector2(62 + i * 34, 97), 19, unit.combo > i and unit.combo_target == unit.target, accent)
			var poison := _target_aura("as_poison")
			var bleed := _target_aura("as_bleed")
			_text(Vector2(130, 148), "毒 %s    出血 %s" % ["●" if poison else "○", "●" if bleed else "○"], 17, accent)
			_text(Vector2(130, 175), "当前目标连击", 16)
			_ready_text("终结接续 · 双刺 +2" if _aura("as_edge") else ("毒血连携 · 跳伤回能" if poison and bleed else "维持毒与出血"), _aura("as_edge") or (poison and bleed), accent)
		"duelist":
			_ring(center, 43, unit.gauge("resonance") / 100, DARK)
			draw_line(center + Vector2(-15, 27), center + Vector2(15, -27), DARK.lightened(0.2), 3, true)
			_diamond(center + Vector2(-12, 22), 8, _aura("ms_shadow_edge") or _aura("ms_echo"), DARK)
			_text(center + Vector2(0, 8), "%d" % int(unit.gauge("resonance")), 25)
			_text(Vector2(130, 175), "共鸣 · 60贯穿", 17, DARK)
			_ready_text("60共鸣 · 无相贯穿" if unit.gauge("resonance") >= 60 else ("暗刃 · 强化刺击" if _aura("ms_shadow_edge") else ("剑鸣 · 瞬发暗影" if _aura("ms_echo") else "暗影矢 → 刺击")), unit.gauge("resonance") >= 60 or _aura("ms_shadow_edge") or _aura("ms_echo"), DARK)
		"marksman":
			draw_rect(Rect2(43, 91, 174, 13), GOLD.darkened(0.5))
			for i in 6:
				var x := 46 + i * 29
				var color := GOLD if unit.gauge("ammo") > i else EMPTY
				var cartridge := PackedVector2Array([Vector2(x, 67), Vector2(x + 9, 54), Vector2(x + 18, 67), Vector2(x + 18, 99), Vector2(x, 99), Vector2(x, 67)])
				draw_colored_polygon(cartridge, color)
				draw_polyline(cartridge, GOLD.darkened(0.2), 1.5, true)
				draw_line(Vector2(x, 93), Vector2(x + 18, 93), GOLD.darkened(0.35), 2)
			for i in 2: _diamond(Vector2(107 + i * 46, 131), 12, unit.gauge("aim") > i, FIRE)
			_text(Vector2(130, 175), "弹药 %d / 6 · 瞄准 %d / 2" % [int(unit.gauge("ammo")), int(unit.gauge("aim"))], 17, GOLD)
			_ready_text("换弹中 · 每次装3发" if unit.casting.get("sp", {}).get("id", "") == "cannon_reload" else ("瞄准充足 · 强化炮弹" if unit.gauge("aim") >= 2 and unit.gauge("ammo") >= 2 else ("弹仓不足 · 手动换弹" if unit.gauge("ammo") < 2 else "点射 → 瞄准 → 炮弹")), unit.gauge("aim") >= 2 and unit.gauge("ammo") >= 2, GOLD)
		"gadgeteer":
			var heat := unit.gauge("heat")
			var color := FIRE if heat < 82 else Color("ff776c")
			_ring(center, 46, heat / 100, color)
			for threshold in [50, 60, 82]:
				var dir := Vector2.from_angle(PI * 0.75 + PI * 1.5 * threshold / 100.0)
				draw_line(center + dir * 39, center + dir * 59, color.lightened(0.2), 2, true)
			_text(center + Vector2(0, 8), "%d°" % int(heat), 28, color)
			_text(Vector2(130, 175), "50强化 · 60贯击排热", 17, color)
			_ready_text("外装甲未展开" if not _aura("mech_armor") else ("高热 · 贯击 / 主动散热" if heat >= 82 else ("60热 · 魔导贯击" if heat >= 60 else ("回压 · 下一拳强化" if _aura("mech_cooled") else "攻击升温"))), _aura("mech_armor") and (heat >= 60 or _aura("mech_cooled")), color)
