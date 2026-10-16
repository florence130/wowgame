class_name GenCityV7
extends RefCounted
## 晴岚港 v7：由 tools/city_plan_v6 规划并导出（node export_game.mjs）。
## 全城地面是铺平的人工地基（台地），网格与碰撞在 assets/models/city_v7/chunk_*.glb，布局数据 docs/city_v7/game.json。
## 地形在城内统一压到台面以下 0.6m（只作底衬，玩家站在地基碰撞上），水面区域压到海底。
## 与 GenSolenne 对 gen_tidewind 的契约相同：in_city / city_h / coast_x / south_coast_z / build。

const DATA := "res://docs/city_v7/game.json"
const MODELS := "res://assets/models/city_v7/"
const CIVIL := "res://assets/models/city_v5/civil/"
const SEA := 8.0             # 规划标高 0 = 海平面 = 游戏水位 8m
const X0 := -772.0           # v7.1：全城按 0.8 以东门 (300,430) 为基点缩放
const X1 := 298.0            # 城墙内侧（墙外是自然地形）
const Z0 := -392.0
const Z1 := 1108.0
const STEP := 2.5
## v7.2：台地栅格比城墙矩形大，覆盖西侧离岸岛、栈桥与北苑叠园（矩形外的台地只把地形压平，其余仍是自然地形 / 大海）
const GX0 := -1030.0
const GZ0 := -730.0
static var _d: Dictionary = {}
static var _grid := PackedFloat32Array()
static var _gw := 0
static var _gh := 0

static func data() -> Dictionary:
	if _d.is_empty():
		_d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_raster()
	return _d

## 台地标高栅格（2.5m）：-1 表示水面
static func _raster() -> void:
	_gw = int((X1 - GX0) / STEP) + 2
	_gh = int((Z1 - GZ0) / STEP) + 2
	_grid.resize(_gw * _gh)
	_grid.fill(-1.0)
	for t in _d.terraces:
		var pa := PackedVector2Array()
		var mn := Vector2(INF, INF)
		var mx := -mn
		for p in t.poly:
			var v := Vector2(p[0], p[1])
			pa.append(v)
			mn = mn.min(v)
			mx = mx.max(v)
		var lvl := float(t.level) + SEA
		for iz in range(maxi(0, int((mn.y - GZ0) / STEP)), mini(_gh, int((mx.y - GZ0) / STEP) + 2)):
			for ix in range(maxi(0, int((mn.x - GX0) / STEP)), mini(_gw, int((mx.x - GX0) / STEP) + 2)):
				var q := Vector2(GX0 + ix * STEP, GZ0 + iz * STEP)
				if Geometry2D.is_point_in_polygon(q, pa) or _on_edge(q, pa):
					_grid[iz * _gw + ix] = maxf(_grid[iz * _gw + ix], lvl)

static func _on_edge(q: Vector2, pa: PackedVector2Array) -> bool:
	for i in pa.size():
		if Geometry2D.get_closest_point_to_segment(q, pa[i], pa[(i + 1) % pa.size()]).distance_to(q) < 0.01:
			return true
	return false

static func _lv(x: float, z: float) -> float:
	var ix := int(round((x - GX0) / STEP))
	var iz := int(round((z - GZ0) / STEP))
	if ix < 0 or iz < 0 or ix >= _gw or iz >= _gh:
		return -1.0
	return _grid[iz * _gw + ix]

static func in_city(x: float, z: float) -> bool:
	return x >= X0 and x <= X1 and z >= Z0 and z <= Z1

## 区域局部坐标处的地面高度：台面 - 0.6（靠近台地边缘取低侧，使挡土墙脚下不露地形）
static func city_h(_noise: FastNoiseLite, x: float, z: float) -> float:
	data()
	var c := _lv(x, z)
	if c < 0.0:
		return 2.0
	var m := c
	for o in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3), Vector2(3, 3), Vector2(-3, -3), Vector2(3, -3), Vector2(-3, 3)]:
		var v := _lv(x + o.x, z + o.y)
		m = minf(m, 2.0 if v < 0.0 else v)
	return m - 0.6

## 城墙矩形之外的人工台地（岛 / 栈桥 / 北苑）：台面 - 0.6；没有台地返回 -1
static func extra_h(x: float, z: float) -> float:
	if in_city(x, z):
		return -1.0
	data()
	var lvl := _lv(x, z)
	return lvl - 0.6 if lvl >= 0.0 else -1.0

## 供 ZoneBuilder.block_fns：城内 + 矩形外台地上不撒自然植被 / 草
static func covered(x: float, z: float) -> bool:
	return in_city(x, z) or extra_h(x, z) >= 0.0

static func coast_x(_z: float) -> float:
	return -716.0

static func south_coast_z(x: float) -> float:
	# 城东墙南端（缩放后 z≈889）附近收到 894，往东 90m 内回到原野外海岸 1010
	return lerpf(894.0, 1010.0, smoothstep(330.0, 420.0, x))

## 北苑叠园的山坡剖面：沿王宫轴线穿过各层台中点的折线（游戏高度，含 SEA 与 -0.6 底衬），出了山顶台继续以 0.22 的坡度升向北岭
static func _hill_profile(z: float) -> float:
	var hill: Dictionary = data().get("hill", {})
	if hill.is_empty():
		return 0.0
	var zs: Array = hill.zs
	var lv: Array = hill.levels
	var pts: Array = [Vector2(float(zs[0]), float(lv[0]))]
	for k in range(1, 5):
		var z_n: float = float(zs[k]) if k < 4 else float(zs[3]) - 36.0
		pts.append(Vector2((float(zs[k - 1]) + z_n) * 0.5, float(lv[k])))
	pts.append(Vector2(float(zs[4]), float(lv[4])))
	var y := 0.0
	if z >= pts[0].x:
		y = pts[0].y
	elif z <= pts[pts.size() - 1].x:
		y = pts[pts.size() - 1].y + (pts[pts.size() - 1].x - z) * 0.22
	else:
		for i in pts.size() - 1:
			if z <= pts[i].x and z >= pts[i + 1].x:
				y = lerpf(pts[i].y, pts[i + 1].y, (pts[i].x - z) / (pts[i].x - pts[i + 1].x))
				break
	return y + SEA - 0.6

## 城外环境（gen_tidewind 在野外高度之后调用）：
## 东 / 南：城墙外 18m 平整环城路（与墙内地面同高）→ 52m 内升起岩壁接回原地形；
## 北（v7.2）：不再是 52m 直上的断崖，而是约 300m 的缓坡，王宫轴线上被削成北苑叠园的山谷（两侧升向自然山势）；北门外开一条上山的隘口路。
static func surround(b: ZoneBuilder, base: float, x: float, z: float) -> float:
	if in_city(x, z):
		return base
	data()
	# 北侧的缓坡绕过西北 / 东北角（到矩形最近点的距离），避免在 x = X0 处出现直立断崖；西侧（z >= Z0）是大海，保持原样
	var north := z < Z0
	var ox := maxf(maxf(x - X1, X0 - x), 0.0) if north else maxf(x - X1, 0.0)
	var oz := maxf(Z0 - z, 0.0)
	var d := Vector2(ox, oz).length()
	if d > (380.0 if north else 240.0) or (x < X0 and not north) or z > Z1:
		return base
	# 北岭：自然山势再抬一点（比原来的 +58..98 柔和得多）
	if north:
		var t := smoothstep(0.0, 330.0, Z0 - z)
		base += t * (26.0 + b.n2(x * 1.3 + 300.0, z * 1.3) * 12.0 + b.ridge(x * 2.2, z * 2.2) * 10.0)
	var px := clampf(x, X0 + 2.0, X1 - 2.0)
	var pz := clampf(z, Z0 + 2.0, Z1 - 2.0)
	var lv := level_at(px, pz)
	if lv < 0.0:
		return base
	var apron := lv - 0.3
	var blend := smoothstep(6.0, 300.0, d + b.n2(x * 3.0, z * 3.0) * 10.0) if north else smoothstep(18.0, 70.0, d + b.n2(x * 3.0, z * 3.0) * 6.0)
	var h := lerpf(apron, maxf(base, apron), blend)
	# 北苑山谷：王宫轴线两侧 130m 内取剖面，再在 130..260m 之间平滑回到自然山势；山顶台以北 300..366m 淡出
	if north and data().has("hill"):
		var hx := float(data().hill.x)
		var wax := (1.0 - smoothstep(130.0, 260.0, absf(x - hx))) * (1.0 - smoothstep(300.0, 366.0, d))
		if wax > 0.0:
			h = lerpf(h, _hill_profile(z) + b.n2(x * 2.0, z * 2.0) * 1.2, wax)
	# 北门隘口（门在 x=244）：路面以 12% 坡度上山，两侧 10m 过渡
	if z < Z0 + 4.0:
		var road := apron + maxf(0.0, Z0 - z - 18.0) * 0.12
		var w := 1.0 - smoothstep(9.0, 22.0, absf(x - 244.0))
		h = lerpf(h, minf(h, road), w)
	return h
## 室内大厅地面（区域坐标，含水位 SEA）：点落在某个大厅的包围范围内时返回其地面高度，否则 INF
static func hall_floor_at(x: float, z: float) -> float:
	var best := INF
	var bd := INF
	for h in data().get("halls", []):
		var dd := Vector2(x - float(h.x), z - float(h.z)).length()
		if dd < float(h.span) * 0.5 and dd < bd:
			bd = dd
			best = float(h.floor) + SEA
	return best

## 城市标高（台面，不含 0.6 的底衬），水面返回 -1
static func level_at(x: float, z: float) -> float:
	data()
	return _lv(x, z)

static func build(b: ZoneBuilder) -> void:
	var d := data()
	b.block_fns.append(func(x, z): return covered(x, z))
	b.paint_rect((X0 + X1) * 0.5, (Z0 + Z1) * 0.5, X1 - X0, Z1 - Z0, 5)
	for c in d.chunks:
		var p := ModelProp.new()
		p.name = "city7_" + String(c.file).get_basename()
		p.asset_scene = MODELS + c.file
		p.kind = "city7"
		p.size = Vector3(c.size[0], c.size[1], c.size[2])
		p.position = Vector3(c.x, SEA, c.z)
		p.collide = true
		p.set_meta("city_layout_version", 7)
		b.groups.Buildings.add_child(p)
	_map(b, d)
	_ward(b)
	for n in d.npcs:
		var outside: bool = float(n.x) > X1
		b.npc(n.id, n.x, n.z, n.yaw, 0, INF if outside else float(n.y) + SEA)
	for p in d.pois:
		b.poi(p.id, p.title, p.x, p.z, p.radius, int(p.priority), true, p.xp)
	for s in d.spawns:
		var m := b.spawn_point(s.id, s.x, s.z, s.yaw)
		if float(s.x) <= X1:
			m.position.y = float(s.y) + SEA + 0.2
	_trees(b, d)
	_kit_lots(b)
	_lamps(b, d)
	_kit_landmarks(b, d)
	_waystones(b, d)
	_hall_lights(b, d)
	_harbor(b)
	_west_ships(b, d)
	_airships(b, d)
	print("CITY V7 GENERATED: ", d.chunks.size(), " chunks, ", d.npcs.size(), " npcs, ", d.pois.size(), " pois")

static func _map(b: ZoneBuilder, d: Dictionary) -> void:
	var m := CityV7Map.new()
	m.name = "CityV7Map"
	var cols: Dictionary = d.map.districts
	for blk in d.map.blocks:
		m.blocks.append([cols.get(blk.d, "#cccccc"), blk.use, _pv(blk.poly)])
	for l in d.map.lots:
		m.lots.append(_pv(l))
	for l in d.map.landmarks:
		m.landmarks.append(_pv(l.poly))
	b.groups.Buildings.add_child(m)

static func _pv(poly: Array) -> PackedVector2Array:
	var pa := PackedVector2Array()
	for p in poly:
		pa.append(Vector2(p[0], p[1]))
	return pa

## 城市准入边界（未获 city_access 时阻挡）：北墙、东墙、南岸、港外海面、西侧海面
static func _ward(b: ZoneBuilder) -> void:
	var ward := CityWard.new()
	ward.name = "CityAccessBoundary"
	# v7.2：西侧含离岸岛（x -1010），北侧在北苑叠园一段向北凸出到 z -730
	ward.points = PackedVector2Array([Vector2(-1010, -397), Vector2(-200, -397), Vector2(-200, -730), Vector2(130, -730), Vector2(130, -397), Vector2(301, -397), Vector2(301, 889), Vector2(156, 915), Vector2(-97, 896),
		Vector2(-260, 958), Vector2(-500, 958), Vector2(-1010, 958)])
	b.groups.Buildings.add_child(ward)

static func _trees(b: ZoneBuilder, d: Dictionary) -> void:
	var kinds := {"round": ["oak", Color("62834c")], "cypress": ["pine", Color("3f6a42")], "palm": ["oak", Color("6a8f4a")]}
	var groups := {}
	for t in d.trees:
		var k: String = t[4]
		if not groups.has(k):
			groups[k] = []
		groups[k].append(t)
	for k in groups:
		var f := Forest.new()
		f.name = "city7_trees_" + k
		f.kind = kinds[k][0]
		f.color = kinds[k][1]
		f.collide = true
		var pa := PackedVector3Array()
		var sc := PackedFloat32Array()
		var sh := PackedVector3Array()
		for t in groups[k]:
			pa.append(Vector3(t[0], float(t[2]) + SEA - 0.1, t[1]))
			sc.append(float(t[3]) * (0.75 if k == "cypress" else 0.9))
			sh.append(Vector3(float(t[5]), float(t[6]), float(t[7])))
		f.points = pa
		f.scales = sc
		f.shapes = sh
		b.groups.Vegetation.add_child(f)

## 夜间灯光：每三盏路灯挂一个灯光（由 World._update_lamps 按距离点亮最近的若干盏）
static func _lamps(b: ZoneBuilder, d: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "CityLampLights"
	b.groups.Buildings.add_child(holder)
	var i := 0
	for l in d.lamps:
		i += 1
		if i % 3 != 0:
			continue
		var yaw: float = l[3]
		var light := OmniLight3D.new()
		light.position = Vector3(float(l[0]) + sin(yaw) * 0.95, float(l[2]) + SEA + 4.0, float(l[1]) + cos(yaw) * 0.95)
		light.light_color = Color("ffcf80")
		light.omni_range = 11.0
		light.light_energy = 1.5
		light.shadow_enabled = false
		light.visible = false
		light.add_to_group("lamp_lights", true)
		holder.add_child(light)

## 模块化拼装的功能建筑外观（tools/blender/city_kit/landmarks_build.py → assets/models/city_lm/<id>.glb）。
## 城市分块只含这些建筑的室内 / 门外平台 / 碰撞；外观在这里按规划位置、标高、朝向摆放（原点 = 地标中心，正面朝 +Z）。
const LM_DIR := "res://assets/models/city_lm/"
static func _kit_landmarks(b: ZoneBuilder, d: Dictionary) -> void:
	var n := 0
	for l in d.landmarks:
		if not l.get("kit", false):
			continue
		var path: String = LM_DIR + String(l.id) + ".glb"
		if not ResourceLoader.exists(path):
			push_warning("city_lm missing: " + path)
			continue
		var p := ModelProp.new()
		p.name = "lm_" + String(l.id)
		p.asset_scene = path
		p.kind = "city_lm"
		p.size = Vector3(float(l.w), float(l.h), float(l.d))
		p.position = Vector3(float(l.x), float(l.level) + SEA, float(l.z))
		p.rotation_degrees.y = float(l.yaw)
		p.collide = false
		b.groups.Buildings.add_child(p)
		n += 1
	print("CITY V7 kit landmarks: ", n)

## 模块化沿街楼（tools/blender/street_kit 构件，摆放表由 export_game.mjs 导出）；近处 MultiMesh，远处是 chunk 里的白模代理
static func _kit_lots(b: ZoneBuilder) -> void:
	if not FileAccess.file_exists(CityKitLots.DIR + "kit_lots.bin"):
		push_warning("street_kit: kit_lots.bin missing")
		return
	var k := CityKitLots.new()
	k.name = "CityKitLots"
	k.position = Vector3(0, SEA, 0)
	b.groups.Buildings.add_child(k)

## 城内传送石（Waystone 节点自建模型与交互）
static func _waystones(b: ZoneBuilder, d: Dictionary) -> void:
	for w in d.get("waystones", []):
		var s := Waystone.new()
		s.name = String(w.id)
		s.ws_id = w.id
		s.title = w.name
		s.zone_id = "tidewind"
		s.position = Vector3(w.x, float(w.y) + SEA, w.z)
		s.land_rel = Vector3(float(w.land[0]) - float(w.x), 0.3, float(w.land[1]) - float(w.z))
		s.land_yaw = float(w.land[2])
		b.groups.Buildings.add_child(s)

## 白盒室内补光：每个大厅按导出的网格（约 14m 一盏，最多 6 盏）挂在天花下 1.6m，不投影的暖光（白天也开，室内没有窗光）
static func _hall_lights(b: ZoneBuilder, d: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "CityHallLights"
	b.groups.Buildings.add_child(holder)
	for h in d.get("halls", []):
		var hgt: float = float(h.ceil) - float(h.floor)
		var pts: Array = h.get("lights", [[h.x, h.z]])
		var k := 0
		for q in pts:
			var light := OmniLight3D.new()
			light.name = "hall_%s_%d" % [String(h.id), k]
			k += 1
			light.position = Vector3(q[0], float(h.ceil) + SEA - minf(1.6, hgt * 0.3), q[1])
			light.light_color = Color("ffd9a0")
			light.omni_range = clampf(hgt + 9.0, 8.0, 22.0)
			light.omni_attenuation = 0.7
			light.light_energy = 1.4 if hgt < 7.0 else 2.0
			light.light_specular = 0.2
			light.shadow_enabled = false
			light.distance_fade_enabled = true
			light.distance_fade_begin = 50.0
			light.distance_fade_length = 15.0
			holder.add_child(light)

## v7.2 飞艇：停在泊台上的 + 在城市 / 海面 / 山前上空巡航的（game.json airships；高度是规划标高，+SEA 才是游戏高度）
static func _airships(b: ZoneBuilder, d: Dictionary) -> void:
	var i := 0
	for a in d.get("airships", []):
		var s := Airship.new()
		s.name = "airship_%d" % i
		s.length = float(a.len)
		s.moored = bool(a.moored)
		s.radius = float(a.r)
		s.speed = float(a.speed) if float(a.speed) > 0.0 else 5.0
		s.phase = float(i) * 1.7
		s.center = Vector3(float(a.x), float(a.y) + SEA, float(a.z))
		b.groups.Buildings.add_child(s)
		i += 1

## v7.2 西侧海堤 / 栈桥 / 码头岛的船只（game.json ships 里 index >= 8 的是新增的）
static func _west_ships(b: ZoneBuilder, d: Dictionary) -> void:
	var ships: Array = d.get("ships", [])
	for i in range(8, ships.size()):
		var s: Dictionary = ships[i]
		var len := float(s.len)
		if String(s.kind) == "steamer":
			_ship(b, CIVIL + "harbor_passenger_65.glb", "west_ship_%d" % i, Vector3(s.x, SEA, s.z), Vector3(13, 24, 65) * (len / 65.0), rad_to_deg(float(s.yaw)))
		else:
			_ship(b, CIVIL + "harbor_sailing_52.glb", "west_ship_%d" % i, Vector3(s.x, SEA, s.z), Vector3(12, 42, 52) * (len / 52.0), rad_to_deg(float(s.yaw)))

static func _harbor(b: ZoneBuilder) -> void:
	_ship(b, CIVIL + "harbor_passenger_65.glb", "passenger_ship", Vector3(-276, SEA, 638), Vector3(13, 24, 65), 0)
	_ship(b, CIVIL + "harbor_sailing_52.glb", "merchant_ship", Vector3(-340, SEA, 646), Vector3(12, 42, 52), 0)
	_ship(b, CIVIL + "harbor_sailing_52.glb", "outer_ship", Vector3(-204, SEA, 854), Vector3(12, 42, 52), 30)
	for z in [646.0, 726.0, 806.0]:
		_ship(b, CIVIL + "harbor_crane.glb", "crane_%d" % int(z), Vector3(-410.4, SEA + 3.0, z), Vector3(12, 23, 14), 270)

static func _ship(b: ZoneBuilder, path: String, id: String, pos: Vector3, sz: Vector3, yaw: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := ModelProp.new()
	p.name = id
	p.asset_scene = path
	p.kind = "ship"
	p.size = sz
	p.position = pos
	p.rotation_degrees.y = yaw
	b.groups.Buildings.add_child(p)
