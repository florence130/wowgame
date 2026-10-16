class_name Nameplates
extends Control
## 名牌：敌对单位显示名字+血条，友方显示名字与头衔

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var p: Player = Game.player
	# 切换区域时玩家会短暂离开场景树
	if p == null or not is_instance_valid(p) or not p.is_inside_tree() or p.camera == null:
		return
	if not Game.settings.get("nameplates", true):
		return
	var cam := p.camera
	var f := UITheme.get_font()
	var fb := UITheme.get_font(true)
	var units := get_tree().get_nodes_in_group("units")
	var pp := p.global_position
	for u in units:
		if u == p or not is_instance_valid(u):
			continue
		var d := pp.distance_to(u.global_position)
		var hostile: bool = p.is_enemy(u)
		var maxd := 45.0 if hostile else 28.0
		if u == p.target:
			maxd = 80.0
		if d > maxd:
			continue
		if u.is_critter and u != p.target and d > 15.0:
			continue
		var wp: Vector3 = u.head_pos()
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		var a := clampf(1.0 - (d - maxd * 0.75) / (maxd * 0.25), 0.0, 1.0)
		var is_t: bool = u == p.target
		var col: Color
		if u.faction in ["friendly", "companion", "pet"]:
			col = Color("70f070")
		elif u.faction == "neutral":
			col = Color("f0e040")
		else:
			col = Color("ff6050")
		if u.dead:
			col = Color(0.6, 0.6, 0.6)
		var name: String = u.unit_name
		var fs := 16 if is_t else 14
		var nw := fb.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var y := sp.y
		if (hostile and not u.dead) or (u.faction == "companion"):
			var bw := 110.0 if not u.is_elite else 130.0
			var r := Rect2(sp.x - bw * 0.5, y - 6, bw, 9)
			draw_rect(r.grow(1.5), Color(0, 0, 0, 0.75 * a))
			draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(u.hp / maxf(1.0, u.max_hp), 0.0, 1.0), r.size.y)), Color(col.r, col.g, col.b, a) if u.faction != "companion" else Color(0.3, 0.9, 0.3, a))
			if u.is_elite:
				draw_string(fb, Vector2(r.position.x - 16, r.position.y + 10), "◆", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UITheme.GOLD, a))
			if is_t:
				draw_rect(r.grow(2.5), Color(1, 1, 1, 0.9 * a), false, 1.5)
			if u.is_casting():
				var cr := Rect2(r.position + Vector2(0, 12), Vector2(bw, 6))
				draw_rect(cr.grow(1), Color(0, 0, 0, 0.7 * a))
				var c = u.casting
				var fr: float = c["elapsed"] / maxf(0.01, c["total"])
				draw_rect(Rect2(cr.position, Vector2(cr.size.x * clampf(fr, 0.0, 1.0), cr.size.y)), Color(1, 0.8, 0.2, a))
			var lvl := ("Lv%d " % u.level) if not u.is_boss else "?? "
			var lw := f.get_string_size(lvl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			_outlined(f, Vector2(sp.x - (nw + lw) * 0.5, y - 12), lvl, 12, Color(0.85, 0.85, 0.85, a))
			_outlined(fb, Vector2(sp.x - (nw + lw) * 0.5 + lw, y - 12), name, fs, Color(col.r, col.g, col.b, a))
		else:
			_outlined(fb, Vector2(sp.x - nw * 0.5, y), name, fs, Color(col.r, col.g, col.b, a))
			if u.sub_name != "" and not u.dead:
				var st := "<%s>" % u.sub_name
				var sw := f.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
				_outlined(f, Vector2(sp.x - sw * 0.5, y + 15), st, 12, Color(0.8, 0.95, 0.8, a))

func _outlined(f: Font, p: Vector2, t: String, s: int, c: Color) -> void:
	draw_string_outline(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, s, 5, Color(0, 0, 0, 0.85 * c.a))
	draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, s, c)
