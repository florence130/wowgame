class_name ZoneBuilder
extends RefCounted
## 区域生成工具：先塑造地形，再沿地形布置建筑/植被/怪物/NPC，最后输出可编辑的 .tscn

var data: TerrainData
var root: Node3D
var terrain: BrushTerrain
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var ridge_noise := FastNoiseLite.new()   # 脊状噪声：山脊线尖、谷底宽（山体结构用）
var groups := {}
var roads: Array = []   # [points, width]
var blocked: Array = [] # 不放植被的区域 [x,z,r]
var res := 384
var cs := 2.5
var org := Vector2.ZERO  # 地形左上角的世界坐标；所有放置函数都使用世界坐标
## 2026-10-10 世界比例（用户：玩家 1.7m 时门和门框高 3.0m，参考 FF14 的建筑 / 物件与人物的比例）：旧版门洞 2.3m → 全部人造物件 / 树木按 2.8/2.3 等比放大。
## 区域生成器令 b.obj_scale = ZoneBuilder.OBJ_SCALE 开启；prop() / building() / landmark() 的节点按它放大，forest() 的缩放系数同乘。
const OBJ_SCALE := 3.0 / 2.3
const NO_SCALE_KINDS := ["field", "rug"]                             # 贴地的田垄 / 地毯：尺寸本身就是占地，不放大
const LEN_KINDS := ["fence", "wall", "abbey_wall", "rail", "ruin_wall"]   # 沿长度平铺的构件：总长度保持，高度 / 厚度放大
var obj_scale := 1.0

func _init(zone_id: String, resolution: int, cell: float, seed_v: int, origin: Vector2 = Vector2.ZERO) -> void:
	res = resolution
	cs = cell
	org = origin
	rng.seed = seed_v
	noise.seed = seed_v
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.0035
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	ridge_noise.seed = seed_v + 7
	ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ridge_noise.frequency = 0.004
	ridge_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge_noise.fractal_octaves = 4
	ridge_noise.fractal_gain = 0.45
	data = TerrainData.new()
	data.setup(res, cs, 0.0)
	root = Node3D.new()
	root.name = "Zone"
	root.set_script(load("res://src/world/zone.gd"))
	root.set("zone_id", zone_id)
	terrain = BrushTerrain.new()
	terrain.name = "Terrain"
	root.add_child(terrain)
	for g in ["Buildings", "Props", "Vegetation", "Spawners", "NPCs", "POIs", "Gathers", "Portals", "SpawnPoints"]:
		var n := Node3D.new()
		n.name = g
		root.add_child(n)
		groups[g] = n

func size() -> float:
	return res * cs

# ================================================================ 地形
func set_heights(f: Callable) -> void:
	var r1 := res + 1
	for z in r1:
		for x in r1:
			data.heights[z * r1 + x] = f.call(x * cs + org.x, z * cs + org.y)

func h(x: float, z: float) -> float:
	return data.sample(x - org.x, z - org.y)

func n2(x: float, z: float) -> float:
	return noise.get_noise_2d(x, z)

func modify(cx: float, cz: float, radius: float, f: Callable) -> void:
	var x0 := maxi(0, int((cx - org.x - radius) / cs))
	var x1 := mini(res, int((cx - org.x + radius) / cs) + 1)
	var z0 := maxi(0, int((cz - org.y - radius) / cs))
	var z1 := mini(res, int((cz - org.y + radius) / cs) + 1)
	var r1 := res + 1
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var wx := x * cs + org.x
			var wz := z * cs + org.y
			var d := Vector2(wx - cx, wz - cz).length()
			if d > radius:
				continue
			var i := z * r1 + x
			data.heights[i] = f.call(data.heights[i], wx, wz, d)

## 圆形压平（带渐变边缘）
func flatten(cx: float, cz: float, r: float, target: float, falloff: float = 20.0) -> void:
	modify(cx, cz, r + falloff, func(hv, _x, _z, d):
		var t := 1.0 - smoothstep(r, r + falloff, d)
		return lerpf(hv, target, t))

func flatten_rect(cx: float, cz: float, w: float, d: float, target: float, falloff: float = 12.0, yaw: float = 0.0) -> void:
	var rr := Vector2(w, d).length() * 0.5 + falloff
	var c := cos(-yaw)
	var s := sin(-yaw)
	modify(cx, cz, rr, func(hv, x, z, _dd):
		var lx = (x - cx) * c - (z - cz) * s
		var lz = (x - cx) * s + (z - cz) * c
		var ex := maxf(0.0, absf(lx) - w * 0.5)
		var ez := maxf(0.0, absf(lz) - d * 0.5)
		var e := Vector2(ex, ez).length()
		var t := 1.0 - smoothstep(0.0, falloff, e)
		return lerpf(hv, target, t))

func raise(cx: float, cz: float, r: float, amount: float, power: float = 1.5) -> void:
	modify(cx, cz, r, func(hv, _x, _z, d):
		var t = 1.0 - d / r
		return hv + amount * pow(clampf(t, 0.0, 1.0), power) * (3.0 - 2.0 * clampf(t, 0.0, 1.0)))

# ---------------------------------------------------------------- 自然地貌（取代圆形 raise / flatten）
## 脊状噪声 0..1，带域扭曲：山脊蜿蜒、不成规则网格
func ridge(x: float, z: float) -> float:
	var wx := x + noise.get_noise_2d(x * 0.7 + 311.0, z * 0.7) * 60.0
	var wz := z + noise.get_noise_2d(x * 0.7, z * 0.7 - 517.0) * 60.0
	return clampf(ridge_noise.get_noise_2d(wx, wz) * 0.5 + 0.5, 0.0, 1.0)

## 方位噪声：同一圆心不同方向返回平滑变化的 -1..1（让平台 / 湖岸边界不是正圆）
func _ang_noise(cx: float, cz: float, ang: float, lobes: float = 150.0) -> float:
	return noise.get_noise_2d(cx * 0.37 + cos(ang) * lobes, cz * 0.37 + sin(ang) * lobes)

## 不规则平台：边界半径随方向起伏（wobble）、过渡宽度也随位置变化，台面保留轻微起伏；
## 用于据点 / 村镇占地，替代会在地图上留下规整圆盘的 flatten()
func platform(cx: float, cz: float, r: float, target: float, falloff: float = 26.0, wobble: float = 0.3, relief: float = 0.6) -> void:
	modify(cx, cz, r * (1.0 + wobble) + falloff * 1.3, func(hv, x, z, d):
		var ang := atan2(z - cz, x - cx)
		var rr := r * (1.0 + wobble * _ang_noise(cx, cz, ang))
		var fo := falloff * (0.7 + 0.6 * (noise.get_noise_2d(x * 2.1, z * 2.1) * 0.5 + 0.5))
		var t := 1.0 - smoothstep(rr, rr + fo, d)
		return lerpf(hv, target + noise.get_noise_2d(x * 4.0, z * 4.0) * relief, t))

## 沿折线隆起一道山脊：截面是带噪声的山形，脊顶高低起伏（不是圆锥）。sharp 越大山脊越尖
func ridge_line(pts: Array, width: float, height: float, sharp: float = 1.6) -> void:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in pts:
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
	var c := (mn + mx) * 0.5
	modify(c.x, c.y, (mx - mn).length() * 0.5 + width * 1.3, func(hv, x, z, _d):
		var p := Vector2(x, z)
		var dd := INF
		var along := 0.0
		var acc := 0.0
		var total := 0.0
		for i in pts.size() - 1:
			total += (pts[i + 1] as Vector2).distance_to(pts[i])
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b2: Vector2 = pts[i + 1]
			var sd := _seg_dist(p, a, b2)
			if sd < dd:
				dd = sd
				var ab := b2 - a
				along = (acc + clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0) * ab.length()) / maxf(total, 0.001)
			acc += a.distance_to(b2)
		var w := width * (0.8 + 0.4 * (noise.get_noise_2d(x * 1.7, z * 1.7) * 0.5 + 0.5))
		if dd > w:
			return hv
		var t := 1.0 - dd / w
		# 两端收尾、脊顶按脊状噪声起伏（出现鞍部与小峰）
		var ends := smoothstep(0.0, 0.18, along) * smoothstep(1.0, 0.82, along)
		var crest := 0.65 + 0.55 * ridge(x * 1.6, z * 1.6)
		# 截面 t^sharp：山脚平缓、近脊处变陡；两端降到 25%
		return hv + height * pow(t, sharp) * crest * lerpf(0.25, 1.0, ends))

## 阶梯式露天矿：不规则椭圆坑，按台阶量化深度，一侧（局部 +x）留斜坡道通到坑底。
## 只往下挖（不会在平地上堆出东西）；yaw 为坑的长轴方向（度）
func quarry(cx: float, cz: float, rx: float, rz: float, yaw_deg: float, floor_h: float, steps: int = 4, rim_h: float = INF) -> void:
	var yaw := deg_to_rad(yaw_deg)
	var c := cos(yaw)
	var s := sin(yaw)
	var rim := rim_h if rim_h < INF else h(cx, cz)
	modify(cx, cz, maxf(rx, rz) * 1.5, func(hv, x, z, _d):
		var lx: float = (x - cx) * c + (z - cz) * s
		var lz: float = -(x - cx) * s + (z - cz) * c
		var ang := atan2(lz, lx)
		# 不规则轮廓：大瓣（半径 ±28%）+ 中瓣（±10%）+ 台阶线位置扰动（每阶宽窄不一、斜着错开），不再是同心圆环 / 陨石坑
		var e := Vector2(lx / rx, lz / rz).length() * (1.0 + 0.28 * _ang_noise(cx, cz, ang, 60.0) + 0.1 * _ang_noise(cx + 31.0, cz, ang * 2.0, 170.0))
		if e > 1.25:
			return hv
		var top := minf(hv, rim)
		# 台阶：每阶外缘是陡坎（0.82–1.0 段）、内侧是平台
		var q := e * steps + 0.7 * noise.get_noise_2d(x * 0.045 + 17.0, z * 0.045) + 0.18 * (lx / rx)
		var k := floorf(q)
		var f := q - k
		var lvl := (k + smoothstep(0.78, 1.0, f)) / steps
		var tgt := lerpf(floor_h, top, clampf(lvl, 0.0, 1.0))
		# 坡道：沿局部 +x 方向的带状斜坡，从坑底平滑升到坑口
		var ramp := (1.0 - smoothstep(3.5, 7.0, absf(lz + lx * 0.12))) * smoothstep(-0.2, 0.15, lx / rx)
		tgt = lerpf(tgt, lerpf(floor_h, top, clampf(e, 0.0, 1.0)), ramp)
		var edge := 1.0 - smoothstep(0.95, 1.25, e)
		# 坑底散落碎石坡的起伏，台面不是一块平板
		tgt += noise.get_noise_2d(x * 0.22, z * 0.22) * 0.5 * (1.0 - clampf(lvl, 0.0, 1.0))
		return lerpf(hv, minf(hv, tgt), edge))

## 多瓣湖：若干圆（x, z, r）平滑并集 + 噪声岸线；岸边是缓坡滩地，湖心最深 bottom。
## shore 为湖岸处高度（略高于水位，形成滩），返回到岸线的有向距离函数供涂刷使用
func lake(lobes: Array, bottom: float, shore: float, beach: float = 26.0) -> Callable:
	var sdf := func(x: float, z: float) -> float:
		var dmin := INF
		var k := 12.0
		var acc := 0.0
		for l in lobes:
			var dl: float = Vector2(x - l.x, z - l.y).length() - l.z
			acc += exp(-dl / k)
		dmin = -k * log(maxf(acc, 1e-6))   # 平滑并集
		return dmin + noise.get_noise_2d(x * 3.0, z * 3.0) * 6.0
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for l in lobes:
		mn = Vector2(minf(mn.x, l.x - l.z), minf(mn.y, l.y - l.z))
		mx = Vector2(maxf(mx.x, l.x + l.z), maxf(mx.y, l.y + l.z))
	var c := (mn + mx) * 0.5
	modify(c.x, c.y, (mx - mn).length() * 0.5 + beach + 20.0, func(hv, x, z, _d):
		var sd: float = sdf.call(x, z)
		if sd > beach:
			return hv
		if sd > 0.0:
			# 岸外：向湖岸高度缓降
			var t := 1.0 - smoothstep(0.0, beach, sd)
			return lerpf(hv, minf(hv, shore + sd * 0.12), t * t)
		# 湖内：离岸越远越深
		return minf(hv, lerpf(shore - 1.2, bottom, smoothstep(0.0, 40.0, -sd))))
	return sdf

## 2026-10-10 地形抛光：① 热侵蚀——比 talus（坡度 = 高差 / 格距）更陡的地方，把土往低处滑一点，消掉锯齿 / 针状尖刺 / 台阶（整体坡度上限约 talus）；
## ② 水岸平滑——水位 ± band 内做高斯平滑（离水线越近越强），岸线圆润、没有一格一格的台阶。protect(x, z) -> bool 为 true 的地方（设计好的断崖）不侵蚀。
func polish(water: float, talus: float = 1.0, iters: int = 6, band: float = 3.0, protect: Callable = Callable()) -> void:
	var r1 := res + 1
	var hs := data.heights
	var lim := talus * cs
	for it in iters:
		var delta := PackedFloat32Array()
		delta.resize(hs.size())
		delta.fill(0.0)
		for z in range(1, res):
			for x in range(1, res):
				var i := z * r1 + x
				if protect.is_valid() and protect.call(x * cs + org.x, z * cs + org.y):
					continue
				var h0 := hs[i]
				for k in [i + 1, i - 1, i + r1, i - r1]:
					var d := h0 - hs[k]
					if d > lim:
						var mv := (d - lim) * 0.25
						delta[i] -= mv
						delta[k] += mv
		for i in hs.size():
			hs[i] += delta[i]
	data.heights = hs
	smooth_banks(water, band, 3, protect)

## 缓岸：水位附近的高度重映射——dh = h - water，|dh| < band 时乘 factor（离水越远越接近 1），水线两侧的坡度变缓，
## 沙滩 / 浅滩 / 河滩变宽（湖岸、河岸、海岸统一处理），而不是草坡直接扎进水里
func soften_shore(water: float, band: float = 3.5, factor: float = 0.45) -> void:
	var hs := data.heights
	for i in hs.size():
		var dh := hs[i] - water
		var a := absf(dh)
		if a < band:
			var k := lerpf(factor, 1.0, smoothstep(0.0, band, a))
			hs[i] = water + dh * k
	data.heights = hs

## 水岸平滑（见 polish）：只动水位 ± band 之内的格子，3×3 高斯权重，离水线越近混合越多
func smooth_banks(water: float, band: float = 3.0, iters: int = 3, protect: Callable = Callable()) -> void:
	var r1 := res + 1
	for it in iters:
		var hs := data.heights
		var out := hs.duplicate()
		for z in range(1, res):
			for x in range(1, res):
				var i := z * r1 + x
				var dh := absf(hs[i] - water)
				if dh > band:
					continue
				if protect.is_valid() and protect.call(x * cs + org.x, z * cs + org.y):
					continue
				var w := 1.0 - smoothstep(band * 0.5, band, dh)
				var avg := (hs[i] * 4.0 + (hs[i - 1] + hs[i + 1] + hs[i - r1] + hs[i + r1]) * 2.0 + hs[i - 1 - r1] + hs[i + 1 - r1] + hs[i - 1 + r1] + hs[i + 1 + r1]) / 16.0
				out[i] = lerpf(hs[i], avg, w * 0.85)
		data.heights = out

## 坡道：在 a→b 之间把地形换成匀速斜坡（高度取两端原地形），用于翻越断崖的山口路
func ramp(a: Vector2, b2: Vector2, width: float, falloff: float = 14.0) -> void:
	var ha := h(a.x, a.y)
	var hb := h(b2.x, b2.y)
	var mid := (a + b2) * 0.5
	modify(mid.x, mid.y, a.distance_to(b2) * 0.5 + width + falloff, func(hv, x, z, _d):
		var p := Vector2(x, z)
		var ab := b2 - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var dd := p.distance_to(a + ab * t)
		if dd > width + falloff:
			return hv
		var k := (1.0 - smoothstep(width, width + falloff, dd)) * smoothstep(0.0, 0.08, t) * smoothstep(1.0, 0.92, t)
		return lerpf(hv, lerpf(ha, hb, smoothstep(0.0, 1.0, t)), k))

func carve_path(pts: Array, width: float, depth_to: float, falloff: float = 8.0) -> void:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var mid := (a + b) * 0.5
		var rr := a.distance_to(b) * 0.5 + width + falloff
		modify(mid.x, mid.y, rr, func(hv, x, z, _d):
			var p := Vector2(x, z)
			var dd := _seg_dist(p, a, b)
			# 蜿蜒：河岸线随噪声左右摆，宽窄也随位置变化；河心比两侧更深（抛物线剖面），不是平底沟
			dd += noise.get_noise_2d(x * 0.9, z * 0.9) * width * 0.55
			var wv := width * (0.85 + 0.3 * (noise.get_noise_2d(x * 0.5 + 9.0, z * 0.5) * 0.5 + 0.5))
			if dd > wv + falloff:
				return hv
			var t := 1.0 - smoothstep(wv, wv + falloff, dd)
			var bed := depth_to - (1.0 - smoothstep(0.0, wv, maxf(dd, 0.0))) * 0.7
			return lerpf(hv, minf(hv, bed), t))

static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

## 道路：平滑高度 + 涂泥土
func road(pts: Array, width: float = 6.0, layer: int = 2) -> void:
	roads.append([pts, width])
	# 1. 沿线采样目标高度（模糊）
	var samples := []
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := int(a.distance_to(b) / 3.0) + 1
		for k in n:
			var p := a.lerp(b, float(k) / n)
			var acc := 0.0
			var cnt := 0
			for ox in [-8.0, 0.0, 8.0]:
				for oz in [-8.0, 0.0, 8.0]:
					acc += h(p.x + ox, p.y + oz)
					cnt += 1
			samples.append([p, acc / cnt])
	samples.append([pts[-1], h(pts[-1].x, pts[-1].y)])
	# 2. 平滑采样序列
	for it in 3:
		for i in range(1, samples.size() - 1):
			samples[i][1] = (samples[i - 1][1] + samples[i][1] * 2.0 + samples[i + 1][1]) * 0.25
	# 3. 应用到网格
	for s in samples:
		var p2: Vector2 = s[0]
		var th: float = s[1]
		modify(p2.x, p2.y, width + 6.0, func(hv, _x, _z, d):
			var t := 1.0 - smoothstep(width * 0.6, width + 6.0, d)
			return lerpf(hv, th, t * 0.85))
	# 4. 涂刷
	for s in samples:
		var p3: Vector2 = s[0]
		paint_circle(p3.x, p3.y, width * 0.66, layer, 1.0, 0.3)

func paint_circle(cx: float, cz: float, r: float, layer: int, strength: float = 1.0, soft: float = 0.5) -> void:
	cx -= org.x
	cz -= org.y
	var px0 := int((cx - r) / cs)
	var px1 := int((cx + r) / cs) + 1
	var pz0 := int((cz - r) / cs)
	var pz1 := int((cz + r) / cs) + 1
	for pz in range(pz0, pz1 + 1):
		for px in range(px0, px1 + 1):
			var d := Vector2((px + 0.5) * cs - cx, (pz + 0.5) * cs - cz).length()
			if d > r:
				continue
			var f := 1.0 - smoothstep(r * (1.0 - soft), r, d)
			data.paint_pixel(px, pz, layer, strength * f)

func paint_rect(cx: float, cz: float, w: float, d: float, layer: int, yaw: float = 0.0) -> void:
	cx -= org.x
	cz -= org.y
	var rr := Vector2(w, d).length() * 0.5
	var c := cos(-yaw)
	var s := sin(-yaw)
	for pz in range(int((cz - rr) / cs), int((cz + rr) / cs) + 1):
		for px in range(int((cx - rr) / cs), int((cx + rr) / cs) + 1):
			var x := (px + 0.5) * cs - cx
			var z := (pz + 0.5) * cs - cz
			var lx := x * c - z * s
			var lz := x * s + z * c
			if absf(lx) <= w * 0.5 and absf(lz) <= d * 0.5:
				data.paint_pixel(px, pz, layer, 1.0)

## 按条件全图涂刷
func paint_where(layer: int, f: Callable) -> void:
	for pz in res:
		for px in res:
			var x := (px + 0.5) * cs + org.x
			var z := (pz + 0.5) * cs + org.y
			var amt: float = f.call(x, z, h(x, z))
			if amt > 0.0:
				data.paint_pixel(px, pz, layer, clampf(amt, 0.0, 1.0))

func slope(x: float, z: float) -> float:
	return 1.0 - data.normal_at(x - org.x, z - org.y).y

func near_road(x: float, z: float, margin: float = 4.0) -> bool:
	var p := Vector2(x, z)
	for r in roads:
		var pts: Array = r[0]
		for i in pts.size() - 1:
			if _seg_dist(p, pts[i], pts[i + 1]) < r[1] + margin:
				return true
	return false

var block_fns: Array = []   # 额外的不放植被区域判定 Callable(x, z) -> bool（如整片城区）

func is_blocked(x: float, z: float, margin: float = 0.0) -> bool:
	for f in block_fns:
		if f.call(x, z):
			return true
	for b in blocked:
		if Vector2(x - b[0], z - b[1]).length() < b[2] + margin:
			return true
	return false

func block(x: float, z: float, r: float) -> void:
	blocked.append([x, z, r])

# ================================================================ 放置
func _own(n: Node) -> void:
	n.owner = root
	for c in n.get_children():
		_own(c)

## 有 Blender 模型的 kind 输出 ModelProp，否则输出程序化 Prop（两者参数语义相同）
var use_models := true

func prop(kind: String, x: float, z: float, yaw_deg: float = 0.0, sz: Vector3 = Vector3(8, 6, 8), ca: Color = Color("e8dcc0"), cb: Color = Color("b05a3a"), cc: Color = Color("6a4a30"), variant: int = 0, lbl: String = "", y_off: float = 0.0, group: String = "Buildings", y_abs: float = INF) -> Node3D:
	var p
	if use_models and ModelProp.has_model(kind):
		p = ModelProp.new()
	else:
		p = Prop.new()
	p.kind = kind
	p.size = sz
	if obj_scale != 1.0 and kind not in NO_SCALE_KINDS:
		p.scale = Vector3.ONE * obj_scale
		if kind in LEN_KINDS:
			p.size = Vector3(sz.x / obj_scale, sz.y, sz.z)
	p.color_a = ca
	p.color_b = cb
	p.color_c = cc
	p.variant = variant
	p.label = lbl
	p.seed_v = rng.randi() % 10000
	var y := h(x, z) + y_off if y_abs == INF else y_abs
	if kind == "tent" and y_abs == INF:
		# A tent is authored at its centre. Use the lowest footprint sample so
		# tents on a slope sit on the ground instead of leaving a low corner
		# visibly suspended above it.
		var footprint := sz * (obj_scale if kind not in NO_SCALE_KINDS else 1.0)
		var yr := deg_to_rad(yaw_deg)
		var ex := Vector2(cos(yr), -sin(yr)) * footprint.x * 0.5
		var ez := Vector2(sin(yr), cos(yr)) * footprint.z * 0.5
		for sx in [-1, 1]:
			for sz2 in [-1, 1]:
				y = minf(y, h(x + ex.x * sx + ez.x * sz2, z + ex.y * sx + ez.y * sz2) + y_off)
	p.position = Vector3(x, y, z)
	p.rotation_degrees.y = yaw_deg
	p.name = "%s_%d" % [kind, groups[group].get_child_count()]
	groups[group].add_child(p)
	return p

## 建筑底部取四角最低点，避免悬空
func building(kind: String, x: float, z: float, yaw_deg: float, sz: Vector3, ca: Color, cb: Color, cc: Color = Color("6a4a30"), variant: int = 0, lbl: String = "", fit: float = -1.0) -> Node3D:
	## fit：占地按多大系数估算（默认 obj_scale）；构件库房屋在 Blender 里已按真实比例放大到位（节点缩放 1），调用方传 fit = 1 并把节点缩放复位
	var fs := obj_scale if fit < 0.0 else fit
	sz = sz * fs
	var yr := deg_to_rad(yaw_deg)
	var ex := Vector2(cos(yr), -sin(yr)) * sz.x * 0.5
	var ez := Vector2(sin(yr), cos(yr)) * sz.z * 0.5
	var lo := INF
	for sx in [-1, 1]:
		for sz2 in [-1, 1]:
			var p = Vector2(x, z) + ex * sx + ez * sz2
			lo = minf(lo, h(p.x, p.y))
	lo = minf(lo, h(x, z))
	block(x, z, maxf(sz.x, sz.z) * 0.6 + 2.0)
	var bn := prop(kind, x, z, yaw_deg, sz / fs, ca, cb, cc, variant, lbl, 0.0, "Buildings", lo + 0.05)
	if fit >= 0.0 and obj_scale != 1.0:
		bn.scale = Vector3.ONE * fit
	return bn

## 大型地标（Landmark）：与 building() 一样取四角最低点落地，并阻挡植被
func landmark(kind: String, x: float, z: float, yaw_deg: float, sz: Vector3, ca: Color, cb: Color, cc: Color, variant: int = 0, lbl: String = "", y_abs: float = INF) -> Node3D:
	var p
	# 锻铁匠（冒烟烟囱）/精工（旋转齿轮）两种行会会馆带动画部件，仍用程序化 Landmark
	if use_models and ModelProp.has_model(kind):
		p = ModelProp.new()
	else:
		p = Landmark.new()
	p.kind = kind
	p.size = sz
	if obj_scale != 1.0:
		p.scale = Vector3.ONE * obj_scale
		sz = sz * obj_scale
	p.color_a = ca
	p.color_b = cb
	p.color_c = cc
	p.variant = variant
	p.label = lbl
	p.seed_v = rng.randi() % 10000
	if y_abs == INF:
		var yr := deg_to_rad(yaw_deg)
		var ex := Vector2(cos(yr), -sin(yr)) * sz.x * 0.5
		var ez := Vector2(sin(yr), cos(yr)) * sz.z * 0.5
		y_abs = h(x, z)
		for sx in [-1, 1]:
			for sz2 in [-1, 1]:
				var q = Vector2(x, z) + ex * sx + ez * sz2
				y_abs = minf(y_abs, h(q.x, q.y))
		y_abs += 0.05
	p.position = Vector3(x, y_abs, z)
	p.rotation_degrees.y = yaw_deg
	p.name = "%s_%d" % [kind, groups["Buildings"].get_child_count()]
	groups["Buildings"].add_child(p)
	block(x, z, maxf(sz.x, sz.z) * 0.6 + 2.0)
	return p

func forest(kind: String, pts: Array, color: Color, scale_min: float = 0.8, scale_max: float = 1.25, collide: bool = true) -> Forest:
	var f := Forest.new()
	f.name = "%s_%d" % [kind, groups["Vegetation"].get_child_count()]
	var pa := PackedVector3Array()
	var sc := PackedFloat32Array()
	for p in pts:
		pa.append(Vector3(p.x, h(p.x, p.y) - 0.15, p.y))
		sc.append(rng.randf_range(scale_min, scale_max) * (1.0 if kind in ["grass", "flower"] else obj_scale))
	f.kind = kind
	f.color = color
	f.collide = collide
	f.scales = sc
	f.points = pa
	groups["Vegetation"].add_child(f)
	return f

## 在区域内撒点（避开道路/建筑/水/陡坡）
func scatter(cx: float, cz: float, r: float, count: int, min_dist: float = 4.0, max_slope: float = 0.35, avoid_road: bool = true, water_margin: float = 1.0) -> Array:
	var pts := []
	var tries := count * 12
	while pts.size() < count and tries > 0:
		tries -= 1
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r
		var x := cx + cos(a) * d
		var z := cz + sin(a) * d
		if x < org.x + 4 or z < org.y + 4 or x > org.x + size() - 4 or z > org.y + size() - 4:
			continue
		if data.water_level > -999 and h(x, z) < data.water_level + water_margin:
			continue
		if slope(x, z) > max_slope:
			continue
		if avoid_road and near_road(x, z):
			continue
		if is_blocked(x, z):
			continue
		var ok := true
		for p in pts:
			if p.distance_to(Vector2(x, z)) < min_dist:
				ok = false
				break
		if ok:
			pts.append(Vector2(x, z))
	return pts

func spawner(mob: String, x: float, z: float, count: int, radius: float = 15.0, wander: float = 6.0, respawn: float = 60.0) -> MobSpawner:
	var s := MobSpawner.new()
	s.mob_id = mob
	s.count = count
	s.radius = radius
	s.wander = wander
	s.respawn = respawn
	s.position = Vector3(x, h(x, z), z)
	s.name = "%s_%d" % [mob, groups["Spawners"].get_child_count()]
	groups["Spawners"].add_child(s)
	return s

func npc(id: String, x: float, z: float, yaw_deg: float = 0.0, wander: float = -1.0, y_abs: float = INF, seed_v: int = 0) -> NpcSpot:
	var s := NpcSpot.new()
	s.npc_id = id
	s.wander = wander
	s.seed_v = seed_v
	s.position = Vector3(x, h(x, z) if y_abs == INF else y_abs, z)
	s.rotation_degrees.y = yaw_deg
	s.name = "%s_%d" % [id, groups["NPCs"].get_child_count()]
	groups["NPCs"].add_child(s)
	return s

func poi(id: String, title: String, x: float, z: float, r: float, priority: int = 0, rest: bool = false, xp: bool = true) -> POI:
	var p := POI.new()
	p.poi_id = id
	p.title = title
	p.radius = r
	p.priority = priority
	p.rest_area = rest
	p.explore_xp = xp
	p.position = Vector3(x, h(x, z), z)
	p.name = id if id != "" else "poi_%d" % groups["POIs"].get_child_count()
	groups["POIs"].add_child(p)
	return p

func gather(type: String, x: float, z: float, count: int, r: float, respawn: float = 30.0) -> GatherSpot:
	var g := GatherSpot.new()
	g.node_type = type
	g.count = count
	g.radius = r
	g.respawn = respawn
	g.position = Vector3(x, h(x, z), z)
	g.name = "%s_%d" % [type, groups["Gathers"].get_child_count()]
	groups["Gathers"].add_child(g)
	return g

func spawn_point(name: String, x: float, z: float, yaw_deg: float = 0.0) -> Marker3D:
	var m := Marker3D.new()
	m.name = name
	m.position = Vector3(x, h(x, z) + 0.2, z)
	m.rotation_degrees.y = yaw_deg
	groups["SpawnPoints"].add_child(m)
	return m

func portal(target_zone: String, target_spawn: String, title: String, x: float, z: float, r: float = 8.0, lvl: int = 0) -> ZonePortal:
	var p := ZonePortal.new()
	p.target_zone = target_zone
	p.target_spawn = target_spawn
	p.title = title
	p.radius = r
	p.requires_level = lvl
	p.position = Vector3(x, h(x, z), z)
	p.name = "portal_" + target_zone
	groups["Portals"].add_child(p)
	return p

# ================================================================ 输出
func save(terrain_path: String, scene_path: String) -> void:
	terrain.data = null
	ResourceSaver.save(data, terrain_path)
	var loaded: TerrainData = load(terrain_path)
	terrain.position = Vector3(org.x, 0.0, org.y)
	terrain.data = loaded
	_own_children(root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack failed %d" % err)
	err = ResourceSaver.save(ps, scene_path)
	print("saved ", scene_path, " err=", err)

func _own_children(n: Node) -> void:
	for c in n.get_children():
		c.owner = root
		if not (c is Prop or c is ModelProp or c is Forest or c is BrushTerrain or c is EditorMarker):
			_own_children(c)





