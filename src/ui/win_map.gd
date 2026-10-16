class_name WorldMapWindow
extends UIWindow
## 世界地图（M）

var map_rect: Control
var tex: ImageTexture
var world_size := Vector2(1000, 1000)
var origin := Vector3.ZERO
var legend: Label

func _init() -> void:
	_init_window("世界地图", Vector2(860, 900), "map")
	map_rect = Control.new()
	map_rect.custom_minimum_size = Vector2(820, 820)
	map_rect.draw.connect(_draw_map)
	body.add_child(map_rect)
	legend = UITheme.label("黄色箭头：你   ！：可接任务   ？：可交任务   ✈：飞行点", 14, UITheme.TEXT_DIM)
	body.add_child(legend)

func build_from_zone(z: Node) -> void:
	var m := MapGen.for_current(z)
	tex = m[0]
	origin = m[1]
	world_size = m[2]
	title_label.text = "世界地图 — %s" % DB.zones.get(Game.pd.get("zone", ""), {}).get("name", "")

func _process(_d: float) -> void:
	if visible:
		map_rect.queue_redraw()

## 地图在控件里的显示区域（保持长宽比居中）
func _map_area() -> Rect2:
	var s := map_rect.size
	var k := minf(s.x / world_size.x, s.y / world_size.y)
	var sz := world_size * k
	return Rect2((s - sz) * 0.5, sz)

func _w2m(p: Vector3) -> Vector2:
	var a := _map_area()
	return a.position + Vector2(p.x - origin.x, p.z - origin.z) / world_size * a.size

func _draw_map() -> void:
	var s := map_rect.size
	map_rect.draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.07, 0.12))
	if tex == null:
		return
	map_rect.draw_texture_rect(tex, _map_area(), false, Color(1, 1, 1))
	var f := UITheme.get_font(true)
	var zl: Array = Game.world.zones.values() if Game.world and Game.world.zones.size() > 1 else ([Game.zone] if Game.zone else [])
	for zz in zl:
		for poi in zz.pois:
			var mp := _w2m(poi.global_position)
			var discovered: bool = Game.pd["explored"].has(poi.poi_id) or poi.poi_id == ""
			# 未探索的小地点不标注；大区域显示「？？？」
			if not discovered and poi.radius < 60.0:
				continue
			var t: String = poi.title if discovered else "？？？"
			var fs := 18 if poi.radius > 50 else 14
			var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			map_rect.draw_string_outline(f, mp - Vector2(w * 0.5, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0.15, 0.1, 0.0, 0.9))
			map_rect.draw_string(f, mp - Vector2(w * 0.5, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fff0c0"))
	for u in get_tree().get_nodes_in_group("npcs"):
		var m := Game.npc_marker(u.npc_id)
		var mp2 := _w2m(u.global_position)
		if m == "!" or m == "?":
			map_rect.draw_string_outline(f, mp2 + Vector2(-4, 6), m, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Color(0, 0, 0))
			map_rect.draw_string(f, mp2 + Vector2(-4, 6), m, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ffd800"))
		elif u.nd.has("flight"):
			map_rect.draw_string(f, mp2 + Vector2(-8, 6), "✈", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("a0e0ff"))
	var p: Player = Game.player
	if p:
		var c := _w2m(p.global_position)
		var yaw := p.rotation.y
		var fwd := Vector2(-sin(yaw), -cos(yaw))
		var right := Vector2(-fwd.y, fwd.x)
		map_rect.draw_colored_polygon(PackedVector2Array([c + fwd * 14, c - fwd * 8 + right * 9, c - fwd * 4, c - fwd * 8 - right * 9]), Color("ffe860"))
