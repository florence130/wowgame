class_name Minimap
extends Control
## 正方形小地图：地形图 + 玩家箭头 + 任务NPC + 敌人 + 采集物

var tex: ImageTexture
var world_size := Vector2(1000, 1000)
var origin := Vector3.ZERO
var zoom := 140.0  # 半径（米）
var _t := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "滚轮缩放小地图，点击打开世界地图"

func build_from_zone(z: Node) -> void:
	var m := MapGen.for_current(z)
	tex = m[0]
	origin = m[1]
	world_size = m[2]
	queue_redraw()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = maxf(50.0, zoom * 0.85)
			accept_event()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = minf(400.0, zoom * 1.15)
			accept_event()
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			Game.hud.toggle_window("map")

func _process(d: float) -> void:
	_t += d
	if _t > 0.05:
		_t = 0.0
		queue_redraw()

func _w2m(p: Vector3, c: Vector2, r: float, pp: Vector3) -> Vector2:
	return c + Vector2(p.x - pp.x, p.z - pp.z) / zoom * r

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 4
	draw_rect(Rect2(c - Vector2.ONE * (r + 4), Vector2.ONE * (r + 4) * 2.0), Color(UITheme.GOLD, 0.7))
	draw_rect(Rect2(c - Vector2.ONE * (r + 2), Vector2.ONE * (r + 2) * 2.0), Color(0.08, 0.075, 0.065))
	var p: Player = Game.player
	# 切换区域时玩家会短暂离开场景树
	if p == null or not is_instance_valid(p) or not p.is_inside_tree() or tex == null:
		return
	var pp := p.global_position - origin
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	for v in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		pts.append(c + v * r)
		var wpos: Vector2 = Vector2(pp.x, pp.z) + v * zoom
		uvs.append(wpos / world_size)
		cols.append(Color.WHITE)
	draw_polygon(pts, cols, uvs, tex)
	var ppw := p.global_position
	# 采集物
	for g in get_tree().get_nodes_in_group("interactable"):
		if g is GatherNode and g.can_interact():
			var mp := _w2m(g.global_position, c, r, ppw)
			if _inside_map(mp, c, r - 5):
				draw_circle(mp, 3.5, Color("ffe060"))
	# 单位
	for u in get_tree().get_nodes_in_group("units"):
		if u == p or not is_instance_valid(u):
			continue
		var mp2 := _w2m(u.global_position, c, r, ppw)
		if not _inside_map(mp2, c, r - 8):
			continue
		if u is NPC:
			var m := Game.npc_marker(u.npc_id)
			if m == "!" or m == "?":
				_text(mp2, m, Color("ffd800"), 16)
			elif u.nd.has("vendor") or u.nd.has("trainer") or u.nd.get("innkeeper", false) or u.nd.has("flight"):
				draw_circle(mp2, 3.0, Color("e0e0e0"))
		elif u is Mob and not u.dead and not u.is_critter:
			draw_circle(mp2, 2.5, Color("ff5040") if u.faction == "hostile" else Color("f0e040"))
		elif u is Ally:
			draw_circle(mp2, 3.0, Color("60ff60"))
	# 玩家箭头
	var yaw := p.rotation.y
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(-fwd.y, fwd.x)
	var tip := c + fwd * 10
	draw_colored_polygon(PackedVector2Array([tip, c - fwd * 6 + right * 6, c - fwd * 3, c - fwd * 6 - right * 6]), Color("ffe860"))
	draw_polyline(PackedVector2Array([tip, c - fwd * 6 + right * 6, c - fwd * 3, c - fwd * 6 - right * 6, tip]), Color(0, 0, 0, 0.8), 1.5, true)
	_text(c + Vector2(0, -r + 14), "北", Color("ffe7a8"), 13)

func _inside_map(point: Vector2, center: Vector2, radius: float) -> bool:
	var delta := (point - center).abs()
	return delta.x < radius and delta.y < radius

func _text(p: Vector2, t: String, col: Color, s: int) -> void:
	var f := UITheme.get_font(true)
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
	draw_string_outline(f, p + Vector2(-w * 0.5, s * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, s, 4, Color(0, 0, 0, 0.9))
	draw_string(f, p + Vector2(-w * 0.5, s * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, s, col)
