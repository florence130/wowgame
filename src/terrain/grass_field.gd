class_name GrassField
extends Node3D
## 运行时草地：按地形涂刷层决定密度，以 24m 分块在玩家周围流式生成 MultiMesh（每帧最多建 1 块）
## 草地/花草地/深草最密，苔藓稀疏，道路/石板/沙地/岩石/农田不长；陡坡与水下不长

const CHUNK := 24.0
const RADIUS := 66.0
const SPACING := 0.40          # 1.82x near instances compared with the previous 0.54m grid.
const FAR_SPACING := 0.72      # 1.74x far coverage; purchased mesh has a reduced distant silhouette.
const NEAR_R := 26.0
const GRASS_H := 1.45          # 2026-10-10：草更高（用户要求；世界整体按 FF14 比例放大后草也要够高）
const SHADER := preload("res://src/terrain/grass.gdshader")
# 各图层长草权重：基础草地(0) + 8 个涂刷层
const LAYER_W := [1.0, 0.9, 0.0, 0.0, 0.0, 0.0, 0.1, 1.0, 0.55]

## 不长草的建筑占地：[节点, 本地包围盒]（室内、回廊庭院、门前台阶）
static var blockers: Array = []

static func add_blocker(n: Node3D, local: AABB) -> void:
	if local.size.x * local.size.z < 3.0:
		return   # 灯柱、树之类的小件不用挡
	remove_blocker(n)
	blockers.append([n, local])
	for g in n.get_tree().get_nodes_in_group("grass_fields"):
		g.invalidate_bounds(n.global_transform * local)

## 与该矩形相交的挡草件：[逆变换, 本地包围盒（向内收 0.15m，草能长到墙根）]
func _blockers_in(r: Rect2) -> Array:
	var out := []
	for b in blockers:
		var n: Node3D = b[0]
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		var la: AABB = b[1]
		var xf := n.global_transform
		var wr := Rect2()
		var first := true
		for cx in [la.position.x, la.end.x]:
			for cz in [la.position.z, la.end.z]:
				var p := xf * Vector3(cx, 0, cz)
				if first:
					wr = Rect2(p.x, p.z, 0, 0)
					first = false
				else:
					wr = wr.expand(Vector2(p.x, p.z))
		if wr.intersects(r):
			out.append([xf.affine_inverse(), la.grow(-0.15), n.global_position.y])
	return out

var terrain: BrushTerrain
var mat: ShaderMaterial
var mesh: ArrayMesh
var flower_mesh: ArrayMesh
var far_mesh: ArrayMesh
var flower_variants: Array[ArrayMesh] = []
var plant_variants: Array[ArrayMesh] = []
static var source_meshes := {}
var chunks := {}
var _t := 0.0
var _origin := Vector3.ZERO
var _patch_noise: FastNoiseLite

func setup(t: BrushTerrain) -> void:
	add_to_group("grass_fields")
	terrain = t
	_origin = t.global_position
	# 绘本草毯：少量宽叶组成清楚的簇状轮廓，远处两段叶保留覆盖率。
	mesh = _source_mesh("grass_near")
	far_mesh = _source_mesh("grass_far")
	# World-space patches remain continuous across chunk and zone boundaries.
	_patch_noise = FastNoiseLite.new()
	_patch_noise.seed = 731
	_patch_noise.frequency = 0.085
	_patch_noise.fractal_octaves = 2
	for key in ["flower_white", "flower_yellow", "flower_blue", "flower_pink"]:
		flower_variants.append(_source_mesh(key))
	for key in ["plant_broad", "plant_fern", "plant_leaf"]:
		plant_variants.append(_source_mesh(key))
	flower_mesh = flower_variants[0]
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("noise_tex", BrushTerrain.get_noise_texture())
	mat.set_shader_parameter("plant_atlas", preload("res://assets/textures/environment_packs/plant_atlas.png"))
	# Bind the terrain's actual texture/control/color values, including per-zone overrides.
	for key in ["control_a", "control_b", "tex0", "tex1", "tex7", "tex8", "col0", "col1", "col7", "col8", "meadow_color", "tile_m", "terrain_origin", "terrain_size"]:
		var value = terrain._mat.get_shader_parameter(key)
		if value != null:
			mat.set_shader_parameter(key, value)
	# 旧的圆锥草丛隐藏
	_hide_old(get_parent())

static func _source_mesh(key: String) -> ArrayMesh:
	if source_meshes.has(key):
		return source_meshes[key]
	var scene := load("res://assets/models/cartoon_plants/%s.glb" % key) as PackedScene
	var root := scene.instantiate()
	var found: ArrayMesh
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if node.mesh is ArrayMesh:
			found = node.mesh
			break
	if root is MeshInstance3D:
		found = root.mesh
	root.free()
	assert(found != null, "Purchased plant mesh is missing: " + key)
	source_meshes[key] = found
	return found

func _hide_old(n: Node) -> void:
	for c in n.get_children():
		if c is Forest and (c.kind == "grass" or c.kind == "flower"):
			c.visible = false
		elif c.get_child_count() > 0 and not (c is Prop):
			_hide_old(c)

## 一丛 n 片弯曲宽叶，保留叶腹、末端收尖。UV.y = 高度系数，UV.x = 0（花头为 1）
func _clump_mesh(n: int, h0: float, h1: float, spread: float, seed_v: int, w0: float = 0.018, w1: float = 0.032, segs: int = 3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for b in n:
		var ang := b * TAU / n + rng.randf_range(-0.6, 0.6)
		var r := sqrt(rng.randf()) * spread
		var off := Vector3(cos(ang), 0, sin(ang)) * r
		# 外圈的叶片外倾多一点，中心几乎直立
		var lean := Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(0.07, 0.15) * (0.5 + r / maxf(spread, 0.01))
		var side := Vector3(-sin(ang), 0, cos(ang)).rotated(Vector3.UP, rng.randf_range(-1.2, 1.2))
		var h := rng.randf_range(h0, h1)
		var w := rng.randf_range(w0, w1)
		_blade(st, off, lean, side, h, w, segs, Vector3(cos(ang), 0.8, sin(ang)).normalized(), 0.0)
	st.index()
	return st.commit()

func _blade(st: SurfaceTool, off: Vector3, lean: Vector3, side: Vector3, h: float, w: float, segs: int, nrm: Vector3, ux: float, uv_top: float = 1.0) -> void:
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for s in segs + 1:
		var f := float(s) / segs
		var c := off + lean * f * f + Vector3(0, h * f, 0)
		var ww := w * (1.0 - pow(f, 1.5) * 0.98)
		var l := c - side * ww
		var rr := c + side * ww
		if s > 0:
			var f0 := float(s - 1) / segs
			for v in [[prev_l, f0], [prev_r, f0], [l, f], [prev_r, f0], [rr, f], [l, f]]:
				st.set_uv(Vector2(ux, v[1] * uv_top))
				st.set_normal(nrm)
				st.add_vertex(v[0])
		prev_l = l
		prev_r = rr

## 野花：每丛 3 朵，细茎 + 5 瓣小花头（UV.x = 1 标记花瓣，由着色器按实例花色上色）+ 根部两片叶
func _flower_mesh(seed_v: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for k in 3:
		var a := k * TAU / 3 + rng.randf_range(-0.4, 0.4)
		var off := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.03, 0.12)
		var h := rng.randf_range(0.4, 0.6)
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.02, 0.07)
		var side := Vector3(-sin(a), 0, cos(a))
		_blade(st, off, lean, side, h, 0.009, 3, Vector3(cos(a), 0.8, sin(a)).normalized(), 0.0)
		_blade(st, off, lean * 2.0 + Vector3(cos(a), 0, sin(a)) * 0.06, side.rotated(Vector3.UP, 1.2), h * 0.4, 0.03, 2, Vector3.UP, 0.0, 0.4)
		# 花头：5 瓣扇形，略向上翻
		var top := off + lean + Vector3(0, h, 0)
		var pr := rng.randf_range(0.055, 0.075)
		var tilt := Vector3(rng.randf_range(-0.25, 0.25), 1.0, rng.randf_range(-0.25, 0.25)).normalized()
		var bx := tilt.cross(Vector3.FORWARD).normalized()
		var bz := tilt.cross(bx).normalized()
		for i in 5:
			var a0 := i * TAU / 5
			var a1 := a0 + TAU / 10
			var a2 := a0 + TAU / 5
			var p0 := top + (bx * cos(a0) + bz * sin(a0)) * pr * 0.35 + tilt * 0.012
			var p1 := top + (bx * cos(a1) + bz * sin(a1)) * pr + tilt * 0.02
			var p2 := top + (bx * cos(a2) + bz * sin(a2)) * pr * 0.35 + tilt * 0.012
			for v in [[top + tilt * 0.018, 0.5], [p0, 1.0], [p1, 1.0], [top + tilt * 0.018, 0.5], [p1, 1.0], [p2, 1.0]]:
				st.set_uv(Vector2(v[1], 1.0))
				st.set_normal(tilt)
				st.add_vertex(v[0])
	st.index()
	return st.commit()

func _process(delta: float) -> void:
	var p = Game.player
	if p == null or not is_instance_valid(p) or not p.is_inside_tree() or terrain == null:
		return
	if Game.world and Game.world.loading:
		return
	mat.set_shader_parameter("player_pos", p.global_position)
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.06
	var pp: Vector3 = p.global_position
	var pv := Vector2(pp.x, pp.z)
	# Other zones must not scan/build empty chunks around this zone's player.
	var terrain_rect := Rect2(Vector2(_origin.x, _origin.z), Vector2.ONE * terrain.data.world_size())
	if not terrain_rect.grow(RADIUS + CHUNK * 1.6).has_point(pv):
		for chunk in chunks.values():
			if is_instance_valid(chunk[0]): chunk[0].queue_free()
		chunks.clear()
		return
	var cx := int(floor(pp.x / CHUNK))
	var cz := int(floor(pp.z / CHUNK))
	var rc := int(ceil(RADIUS / CHUNK))
	# 最近的未建块（或需要从稀疏升级到密集的块）优先，每次只建一块，避免卡顿
	var best := Vector2i(999999, 0)
	var bd := INF
	for dz in range(-rc, rc + 1):
		for dx in range(-rc, rc + 1):
			var k := Vector2i(cx + dx, cz + dz)
			var center := Vector2((k.x + 0.5) * CHUNK, (k.y + 0.5) * CHUNK)
			var d := center.distance_to(pv)
			var want_near := d < NEAR_R + CHUNK * 0.5
			if chunks.has(k) and (not want_near or chunks[k][1]):
				continue
			if d < RADIUS + CHUNK * 0.7 and d < bd:
				bd = d
				best = k
	if best.x != 999999:
		if chunks.has(best) and chunks[best][0]:
			chunks[best][0].queue_free()
		var c2 := Vector2((best.x + 0.5) * CHUNK, (best.y + 0.5) * CHUNK)
		chunks[best] = [_build(best), c2.distance_to(pv) < NEAR_R + CHUNK * 0.5]
	# 回收远处
	for k in chunks.keys():
		var center2 := Vector2((k.x + 0.5) * CHUNK, (k.y + 0.5) * CHUNK)
		if center2.distance_to(pv) > RADIUS + CHUNK * 1.6:
			if chunks[k][0]:
				chunks[k][0].queue_free()
			chunks.erase(k)

func _density(wx: float, wz: float) -> float:
	var d := terrain.data
	var lx := wx - _origin.x
	var lz := wz - _origin.z
	var px := int(lx / d.cell_size)
	var pz := int(lz / d.cell_size)
	if px < 0 or pz < 0 or px >= d.resolution or pz >= d.resolution:
		return 0.0
	var w := d.get_layer(px, pz)
	var base := 1.0
	var acc := 0.0
	for i in 8:
		acc += w[i] * LAYER_W[i + 1]
		base -= w[i]
	# 路面类图层（泥土路/岩石/沙地/石板路）占比稍高就完全不长，避免草从广场石板里冒出来
	var paved := w[1] + w[2] + w[3] + w[4]
	return clampf(acc + maxf(base, 0.0) * LAYER_W[0], 0.0, 1.0) * (1.0 - smoothstep(0.15, 0.35, paved))

func _build(k: Vector2i) -> Node3D:
	var terrain_rect := Rect2(Vector2(_origin.x, _origin.z), Vector2.ONE * terrain.data.world_size())
	if not terrain_rect.intersects(Rect2(Vector2(k) * CHUNK, Vector2.ONE * CHUNK)):
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(k)
	var xs := []
	var fl := []
	var decoration := [[], [], [], [], [], [], []]
	var wl := terrain.water_level_global()
	var pp: Vector3 = Game.player.global_position if Game.player else Vector3.ZERO
	var center := Vector2((k.x + 0.5) * CHUNK, (k.y + 0.5) * CHUNK)
	var sp := SPACING if center.distance_to(Vector2(pp.x, pp.z)) < NEAR_R + CHUNK * 0.5 else FAR_SPACING
	var n := int(CHUNK / sp)
	blockers = blockers.filter(func(b): return is_instance_valid(b[0]))
	var blk := _blockers_in(Rect2(k.x * CHUNK, k.y * CHUNK, CHUNK, CHUNK))
	for iz in n:
		for ix in n:
			var x := (k.x * CHUNK) + (ix + rng.randf()) * sp
			var z := (k.y * CHUNK) + (iz + rng.randf()) * sp
			var dens := _density(x, z)
			var patch := smoothstep(0.25, 0.75, _patch_noise.get_noise_2d(x, z) * 0.5 + 0.5)
			if dens <= 0.02 or rng.randf() > dens * lerpf(0.58, 1.0, patch):
				continue
			var inside := false
			for b in blk:
				var lp: Vector3 = b[0] * Vector3(x, b[2], z)
				var la: AABB = b[1]
				if lp.x > la.position.x and lp.x < la.end.x and lp.z > la.position.z and lp.z < la.end.z:
					inside = true
					break
			if inside:
				continue
			var nrm := terrain.get_normal_global(x, z)
			if nrm.y < 0.78:
				continue
			var y := terrain.get_height_global(x, z)
			if y < wl + 1.1:         # 新的缓坡沙滩带（terrain.gdshader 水线 +1.1m 内是沙）不长草
				continue
			var s := rng.randf_range(0.8, 1.15) * lerpf(0.75, 1.0, dens)
			var sxz := s * (sp / SPACING if sp > SPACING else 1.0)
			var height := s * lerpf(0.52, 1.18, patch) * rng.randf_range(0.88, 1.08) * GRASS_H
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sxz, height, sxz))
			var value := rng.randf_range(0.96, 1.04)
			var tint := Color(value, value, value, 0.0)
			xs.append([Transform3D(b, Vector3(x, y - 0.04, z)), tint])
			# 野花：花草地层很多，普通草地零星
			var fw := _flower_w(x, z)
			if rng.randf() < 0.010 + fw * 0.11:
				var fb := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.15))
				decoration[rng.randi() % 4].append([Transform3D(fb, Vector3(x, y - 0.03, z)), Color(1, 1, 1, 1)])
			if sp <= SPACING and patch > 0.55 and rng.randf() < 0.004:
				var pb := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.60, 0.90))
				decoration[4 + rng.randi() % 3].append([Transform3D(pb, Vector3(x, y - 0.035, z)), Color(1, 1, 1, 1)])
	if xs.is_empty():
		return null
	var root := Node3D.new()
	# Instances are authored in world space; zone translation must not apply twice.
	root.top_level = true
	add_child(root)
	var pairs := [[mesh if sp <= SPACING else far_mesh, xs]]
	for i in 7:
		pairs.append([flower_variants[i] if i < 4 else plant_variants[i - 4], decoration[i]])
	for pair in pairs:
		var arr: Array = pair[1]
		if arr.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = pair[0]
		mm.instance_count = arr.size()
		for i in arr.size():
			mm.set_instance_transform(i, arr[i][0])
			mm.set_instance_custom_data(i, arr[i][1])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat
		mi.extra_cull_margin = 1.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return root

func _flower_w(wx: float, wz: float) -> float:
	var d := terrain.data
	var px := int((wx - _origin.x) / d.cell_size)
	var pz := int((wz - _origin.z) / d.cell_size)
	if px < 0 or pz < 0 or px >= d.resolution or pz >= d.resolution:
		return 0.0
	return d.get_layer(px, pz)[6]

static func remove_blocker(n: Node3D) -> void:
	blockers = blockers.filter(func(b): return is_instance_valid(b[0]) and b[0] != n)

func invalidate_bounds(box: AABB) -> void:
	var r := Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
	for k in chunks.keys():
		if r.intersects(Rect2(Vector2(k.x, k.y) * CHUNK, Vector2.ONE * CHUNK)):
			if is_instance_valid(chunks[k][0]):
				chunks[k][0].queue_free()
			chunks.erase(k)


