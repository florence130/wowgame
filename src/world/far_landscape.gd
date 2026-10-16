class_name FarLandscape
extends Node3D
## 远景地貌：在可玩地形四周生成连续的丘陵 → 林带 → 远山（雪顶），让区域看起来处在开阔的自然山谷里，
## 而不是被一圈围墙山包住。支持多块地形拼成的大世界（WorldLayout）：以所有地形矩形的并集为内边界。
## 近环（0-420m）10m 网格，远环（到 2.8km）60m 网格；内缘高度取最近地形的边缘高度无缝衔接。
## 另放一圈风格化远景树（与近景同模型），并在大世界外边界加隐形碰撞墙（两图接缝处不加）。
## 本节点放在世界原点，所有坐标为世界坐标。

const SHADER := preload("res://src/world/far_landscape.gdshader")
const NEAR := 420.0
const FAR := 2800.0
const TILE := 400.0        # 远景树分块边长
const LOD_SWITCH := 650.0  # 远景树：此距离内用风格化模型，外面用低模

## [Rect2(世界坐标 x/z), BrushTerrain, 临海方向数组]
var rects: Array = []
var bounds := Rect2()
var noise := FastNoiseLite.new()
var noise2 := FastNoiseLite.new()
var water := -1000.0
## 兼容单地形调用：临海方向（west/east/south/north）
var sea_sides: Array = []

func setup(t: BrushTerrain, seed_v: int = 7) -> void:
	setup_multi([[t, sea_sides]], seed_v)

## entries: [[BrushTerrain, 临海方向数组], ...]
func setup_multi(entries: Array, seed_v: int = 7) -> void:
	rects.clear()
	for e in entries:
		var t: BrushTerrain = e[0]
		var s := t.data.world_size()
		var r := Rect2(Vector2(t.global_position.x, t.global_position.z), Vector2(s, s))
		rects.append([r, t, e[1]])
		bounds = r if bounds.size == Vector2.ZERO else bounds.merge(r)
		water = maxf(water, t.data.water_level)
	noise.seed = seed_v
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.0011
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	noise2.seed = seed_v + 11
	noise2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise2.frequency = 0.004
	noise2.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise2.fractal_octaves = 3
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	if ResourceLoader.exists("res://assets/textures/terrain/t0_grass.png"):
		mat.set_shader_parameter("detail_tex", load("res://assets/textures/terrain/t0_grass.png"))
		mat.set_shader_parameter("use_detail", 1.0)
	var near := _grid(bounds.grow(NEAR), 10.0, 0.0, true)
	var far := _grid(bounds.grow(FAR), 60.0, NEAR - 40.0, false)
	for m in [near, far]:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 200.0
		add_child(mi)
	_trees()
	_walls()

static func _rect_dist(r: Rect2, x: float, z: float) -> Array:
	var q := Vector2(clampf(x, r.position.x, r.end.x), clampf(z, r.position.y, r.end.y))
	return [Vector2(x, z).distance_to(q), q]

## 到所有地形并集的距离、最近边缘点、最近矩形序号
func _outside(x: float, z: float) -> Array:
	var best := [INF, Vector2.ZERO, 0]
	for i in rects.size():
		var o := _rect_dist(rects[i][0], x, z)
		if o[0] < best[0]:
			best = [o[0], o[1], i]
	return best

func _inside_any(x: float, z: float, inset: float) -> bool:
	for e in rects:
		if (e[0] as Rect2).grow(-inset).has_point(Vector2(x, z)):
			return true
	return false

func height(x: float, z: float) -> float:
	# 边缘高度：附近各地形边缘按距离加权（避免两块地形交界外侧出现折痕）
	var d := INF
	var edge := 0.0
	var wsum := 0.0
	var sea := 0.0
	for e in rects:
		var o := _rect_dist(e[0], x, z)
		var di: float = o[0]
		d = minf(d, di)
		var w := 1.0 / pow(di + 25.0, 3.0)
		var q: Vector2 = o[1]
		edge += (e[1] as BrushTerrain).get_height_global(q.x, q.y) * w
		var r: Rect2 = e[0]
		var s := 0.0
		for side in e[2]:
			match side:
				"west": s = maxf(s, smoothstep(r.position.x, r.position.x - 120.0, x))
				"east": s = maxf(s, smoothstep(r.end.x, r.end.x + 120.0, x))
				"south": s = maxf(s, smoothstep(r.end.y, r.end.y + 120.0, z))
				"north": s = maxf(s, smoothstep(r.position.y, r.position.y - 120.0, z))
		sea += s * w
		wsum += w
	edge /= wsum
	sea /= wsum
	# 丘陵（近处）+ 山脉（远处，脊状噪声）
	var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
	var hills := 26.0 + n * 70.0
	var ridge := noise2.get_noise_2d(x * 0.35, z * 0.35) * 0.5 + 0.5
	var mount := pow(ridge, 1.6) * 520.0 * smoothstep(500.0, 1700.0, d) + n * 120.0 * smoothstep(300.0, 1200.0, d)
	var h := lerpf(edge, hills, smoothstep(0.0, 260.0, d)) + mount
	# 临海方向压低成海面
	return lerpf(h, water - 6.0, sea)

func _color(h: float, slope: float, x: float, z: float) -> Color:
	var n := noise.get_noise_2d(x * 3.0, z * 3.0) * 0.5 + 0.5
	var grass := Color("5f8433").lerp(Color("8ead48"), n)   # 色板 grass_mid → grass_lit
	var forest := Color("24502c").lerp(Color("3f7a3a"), n)   # leaf_dark → leaf_mid
	var rock := Color("b3a894").lerp(Color("8a8072"), n)   # rock → rock_shadow
	var snow := Color(0.96, 0.97, 1.0)
	var c := grass.lerp(forest, smoothstep(0.45, 0.62, noise.get_noise_2d(x * 1.7 + 300.0, z * 1.7) * 0.5 + 0.5) * smoothstep(320.0, 60.0, h))
	c = c.lerp(rock, clampf(smoothstep(0.55, 0.85, slope) + smoothstep(180.0, 300.0, h), 0.0, 1.0))
	c = c.lerp(snow, smoothstep(430.0 + n * 60.0, 480.0 + n * 60.0, h) * (1.0 - smoothstep(0.8, 1.0, slope) * 0.6))
	if h < water + 1.5:
		c = Color(0.9, 0.84, 0.66)
	return c

func _grid(area: Rect2, cell: float, hole: float, near: bool) -> ArrayMesh:
	var nx := int(area.size.x / cell) + 1
	var nz := int(area.size.y / cell) + 1
	var ax := area.position.x
	var az := area.position.y
	var hs := PackedFloat32Array()
	hs.resize(nx * nz)
	var dist := PackedFloat32Array()
	dist.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			var x := ax + ix * cell
			var z := az + iz * cell
			var h := height(x, z)
			var o := _outside(x, z)
			dist[iz * nx + ix] = o[0]
			if near and o[0] < 6.0:
				h -= 0.6   # 藏到可玩地形下面
			if not near:
				h -= 2.0   # 远环略低，交界处由近环覆盖
			hs[iz * nx + ix] = h
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	verts.resize(nx * nz)
	cols.resize(nx * nz)
	norms.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			var x := ax + ix * cell
			var z := az + iz * cell
			var h := hs[iz * nx + ix]
			var hl := hs[iz * nx + maxi(ix - 1, 0)]
			var hr := hs[iz * nx + mini(ix + 1, nx - 1)]
			var hu := hs[maxi(iz - 1, 0) * nx + ix]
			var hd := hs[mini(iz + 1, nz - 1) * nx + ix]
			var nr := Vector3(hl - hr, 2.0 * cell, hu - hd).normalized()
			verts[iz * nx + ix] = Vector3(x, h, z)
			norms[iz * nx + ix] = nr
			cols[iz * nx + ix] = _color(h, 1.0 - nr.y, x, z)
	var idx := PackedInt32Array()
	for iz in nz - 1:
		for ix in nx - 1:
			var x0 := ax + ix * cell
			var z0 := az + iz * cell
			if near:
				# 整格都在某块可玩地形内（留 6m 重叠）就跳过
				if _inside_any(x0, z0, 6.0) and _inside_any(x0 + cell, z0 + cell, 6.0) and _inside_any(x0 + cell, z0, 6.0) and _inside_any(x0, z0 + cell, 6.0):
					continue
			else:
				var i00 := iz * nx + ix
				if minf(minf(dist[i00], dist[i00 + 1]), minf(dist[i00 + nx], dist[i00 + nx + 1])) < hole:
					continue
			var i0 := iz * nx + ix
			idx.append_array([i0, i0 + 1, i0 + nx, i0 + 1, i0 + nx + 1, i0 + nx])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

## 远景树林：近环里的缓坡上撒低模树（松树 + 圆冠树），成片分布
func _trees() -> void:
	var tree := _tree_mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var xs := []
	var tries := 0
	var area := bounds.grow(NEAR)
	var want := int(3600.0 * area.get_area() / (1800.0 * 1800.0))
	while xs.size() < want and tries < want * 12:
		tries += 1
		var x := rng.randf_range(area.position.x, area.end.x)
		var z := rng.randf_range(area.position.y, area.end.y)
		var d: float = _outside(x, z)[0]
		if d < 4.0 or d > NEAR - 20.0:
			continue
		var clump := noise.get_noise_2d(x * 2.4 + 90.0, z * 2.4) * 0.5 + 0.5
		if rng.randf() > smoothstep(0.38, 0.6, clump) * 0.95 + 0.05:
			continue
		var h := height(x, z)
		if h < water + 1.0 or h > 240.0:
			continue
		var sl := absf(height(x + 6.0, z) - height(x - 6.0, z)) + absf(height(x, z + 6.0) - height(x, z - 6.0))
		if sl > 11.0:
			continue
		var s := rng.randf_range(0.8, 1.6) * lerpf(1.0, 1.8, smoothstep(40.0, NEAR, d))
		var tint := Color(rng.randf_range(0.8, 1.1), rng.randf_range(0.85, 1.1), rng.randf_range(0.8, 1.0))
		xs.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, h - 0.4, z)), tint])
	# 远景树林按 400m 分块（每块一个 MultiMesh，才能逐块按距离切换）：
	# 650m 内用低面数的风格化树（pine_0 544 面 / round_0 598 面），650m 外换 52 面的低模树。
	# 2026-10-09 性能：原先整环用 oak_0（3251 面）且不做距离切换，城里每帧要画约 1500 万面。
	var groups := [["pine_0", Color("2f5e3e")], ["round_0", Color("3f7a3a")]]
	var have := not Forest._veg_parts("pine_0").is_empty() and not Forest._veg_parts("round_0").is_empty()
	var tiles := {}
	for i in xs.size():
		var t: Transform3D = xs[i][0]
		var key := Vector2i(floori(t.origin.x / TILE), floori(t.origin.z / TILE))
		if not tiles.has(key):
			tiles[key] = [[], []]
		tiles[key][0 if i % 3 != 0 else 1].append(xs[i])
	for key in tiles:
		var center := Vector3((key.x + 0.5) * TILE, 0.0, (key.y + 0.5) * TILE)
		var all: Array = tiles[key][0] + tiles[key][1]
		_tree_cones(tree, all, center, LOD_SWITCH)
		if not have:
			continue
		for gi in groups.size():
			var sel: Array = tiles[key][gi]
			if sel.is_empty():
				continue
			for part in Forest._veg_parts(groups[gi][0]):
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = part[0]
				mm.instance_count = sel.size()
				for k in sel.size():
					var tr: Transform3D = sel[k][0]
					tr.origin -= center
					mm.set_instance_transform(k, tr.scaled_local(Vector3.ONE * 0.85) * part[2])
				var mi := MultiMeshInstance3D.new()
				mi.multimesh = mm
				mi.position = center
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.visibility_range_end = LOD_SWITCH
				mi.visibility_range_end_margin = 60.0
				mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				mi.material_override = Forest._veg_mat(groups[gi][1] if part[1] else Color("5a3f2a"), part[1])
				add_child(mi)

func _tree_cones(tree: Mesh, xs: Array, center := Vector3.ZERO, begin := 0.0) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = tree
	mm.instance_count = xs.size()
	for i in xs.size():
		var tr: Transform3D = xs[i][0]
		tr.origin -= center
		mm.set_instance_transform(i, tr)
		mm.set_instance_color(i, xs[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.position = center
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if begin > 0.0:
		mi.visibility_range_begin = begin
		mi.visibility_range_begin_margin = 60.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	var tm := ShaderMaterial.new()
	tm.shader = SHADER
	tm.set_shader_parameter("instance_tint", true)
	mi.material_override = tm
	add_child(mi)

func _tree_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := Color(0.42, 0.3, 0.2)
	var leaf := Color(0.22, 0.44, 0.24)
	var leaf2 := Color(0.3, 0.54, 0.28)
	_cone(st, Vector3(0, 0, 0), 0.5, 0.35, 3.0, trunk, 5)
	_cone(st, Vector3(0, 2.0, 0), 3.4, 0.0, 6.0, leaf, 7)
	_cone(st, Vector3(0, 5.0, 0), 2.6, 0.0, 5.0, leaf2, 7)
	_cone(st, Vector3(0, 7.6, 0), 1.7, 0.0, 3.6, leaf2.lightened(0.08), 7)
	st.generate_normals()
	return st.commit()

func _cone(st: SurfaceTool, base: Vector3, r0: float, r1: float, h: float, c: Color, seg: int) -> void:
	for i in seg:
		var a0 := i * TAU / seg
		var a1 := (i + 1) * TAU / seg
		var p0 := base + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p1 := base + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var q0 := base + Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var q1 := base + Vector3(cos(a1) * r1, h, sin(a1) * r1)
		for v in [p0, q0, p1, p1, q0, q1]:
			st.set_color(c)
			st.add_vertex(v)

## 隐形边界：沿大世界外边界的高墙；某段外侧紧挨着另一块地形（两图接缝）时不加
func _walls() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	const SEG := 40.0
	const IN := 2.0
	for e in rects:
		var r: Rect2 = e[0]
		# [起点, 方向, 长度, 外法线]
		var edges := [[r.position, Vector2.RIGHT, r.size.x, Vector2.UP], [Vector2(r.position.x, r.end.y), Vector2.RIGHT, r.size.x, Vector2.DOWN],
			[r.position, Vector2.DOWN, r.size.y, Vector2.LEFT], [Vector2(r.end.x, r.position.y), Vector2.DOWN, r.size.y, Vector2.RIGHT]]
		for ed in edges:
			var n := int(ceil(ed[2] / SEG))
			var L: float = ed[2] / n
			for k in n:
				var mid: Vector2 = ed[0] + ed[1] * (k + 0.5) * L
				var probe: Vector2 = mid + ed[3] * 8.0
				var shared := false
				for o in rects:
					if o[0] != r and (o[0] as Rect2).has_point(probe):
						shared = true
						break
				if shared:
					continue
				var c: Vector2 = mid - ed[3] * IN
				var cs := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				var horiz: bool = absf(ed[1].x) > 0.5
				bs.size = Vector3(L + 4.0 if horiz else 4.0, 600.0, 4.0 if horiz else L + 4.0)
				cs.shape = bs
				cs.position = Vector3(c.x, 150.0, c.y)
				body.add_child(cs)
