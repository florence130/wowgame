@tool
class_name BrushTerrain
extends Node3D
## 可笔刷编辑的高度图地形。分块网格 + 高度场碰撞 + 水面。
## 编辑器中选中本节点后，使用右侧「地形笔刷」面板进行抬升/降低/平滑/压平/涂刷。

const TERRAIN_SHADER := preload("res://src/terrain/terrain.gdshader")
const WATER_SHADER := preload("res://src/terrain/water.gdshader")
## 9 个图层的贴图（与 TerrainData.LAYER_NAMES 顺序一致）。
## 使用工程原有地表贴图，颜色由 ArtStyle 色板统一。
const TERRAIN_TEX := [
	"res://assets/textures/terrain/t0_grass.png", # 草地
	"res://assets/textures/terrain/t1_grass_dark.png", # 深草/林地
	"res://assets/textures/terrain/t2_dirt.png", # 泥土路
	"res://assets/textures/terrain/t3_rock.png", # 岩石
	"res://assets/textures/terrain/t4_sand.png", # 沙地
	"res://assets/textures/terrain/t5_cobble.png", # 石板路
	"res://assets/textures/terrain/t6_farm.png", # 农田
	"res://assets/textures/terrain/t7_flowers.png", # 花草地
	"res://assets/textures/terrain/t8_moss.png", # 苔藓 / 暗土
]

@export var data: TerrainData:
	set(v):
		data = v
		if is_inside_tree():
			rebuild()
@export var chunk_cells: int = 32
@export var collision_enabled: bool = true
@export var water_extent: float = 2500.0
@export_tool_button("重建地形", "Reload") var _rebuild_btn := rebuild

var streamed := false
var _coarse := {}
var _tile_bodies := {}
var _wanted := {}
var _terrain_queue: Array[Vector2i] = []
const DETAIL_RADIUS := 240.0
const RETAIN_RADIUS := 340.0

var _gen: Node3D
var _chunks := {}
var _mat: ShaderMaterial
var _water_mat: ShaderMaterial
var _outer_water_mat: ShaderMaterial
var _tex_a: ImageTexture
var _tex_b: ImageTexture
var _tex_h: ImageTexture
var _body: StaticBody3D
var _shape: HeightMapShape3D
var _col_node: CollisionShape3D
var _index_cache := {}
static var _noise_tex: NoiseTexture2D

func _ready() -> void:
	add_to_group("terrain")
	rebuild()

static func get_noise_texture() -> NoiseTexture2D:
	if _noise_tex == null:
		var nt := NoiseTexture2D.new()
		var fn := FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.frequency = 0.02
		fn.fractal_octaves = 3
		nt.noise = fn
		nt.width = 256
		nt.height = 256
		nt.seamless = true
		nt.generate_mipmaps = true
		_noise_tex = nt
	return _noise_tex

func rebuild() -> void:
	if _gen != null and is_instance_valid(_gen):
		remove_child(_gen)
		_gen.free()
	_gen = null
	_chunks.clear()
	_coarse.clear()
	_tile_bodies.clear()
	_body = null
	if data == null or data.heights.size() != (data.resolution + 1) * (data.resolution + 1):
		return
	_gen = Node3D.new()
	_gen.name = "_generated"
	add_child(_gen)
	_tex_a = ImageTexture.create_from_image(data.control_a)
	_tex_b = ImageTexture.create_from_image(data.control_b)
	_mat = ShaderMaterial.new()
	_mat.shader = TERRAIN_SHADER
	_mat.set_shader_parameter("control_a", _tex_a)
	_mat.set_shader_parameter("control_b", _tex_b)
	_mat.set_shader_parameter("noise_tex", get_noise_texture())
	_mat.set_shader_parameter("terrain_size", data.world_size())
	_mat.set_shader_parameter("terrain_origin", Vector2(global_position.x, global_position.z))
	_mat.set_shader_parameter("water_level", (data.water_level + global_position.y) if data.water_level > -999.0 else -1000.0)
	for i in mini(9, data.layer_colors.size()):
		_mat.set_shader_parameter("col%d" % i, data.layer_colors[i])
	var ok := true
	for i in TERRAIN_TEX.size():
		var texture_path: String = data.texture_overrides.get(i, TERRAIN_TEX[i])
		var t: Texture2D = load(texture_path) if ResourceLoader.exists(texture_path) else null
		if t == null:
			ok = false
			break
		_mat.set_shader_parameter("tex%d" % i, t)
	_mat.set_shader_parameter("has_tex", 1.0 if ok else 0.0)
	var n := data.resolution / chunk_cells
	for cz in n:
		for cx in n:
			_build_chunk(cx, cz, 8 if streamed else 1)
	if collision_enabled and not streamed:
		_build_collision()
	_build_water()
	_refresh_ocean_masks()

## 外海只覆盖可玩地形以外；湖河在自己的高度图下裁切，不能有第二张
## 无高度图大水面穿过本区/相邻区的粗网格，导致房屋附近显示为淹水。
func _refresh_ocean_masks() -> void:
	if not is_inside_tree():
		return
	var rects := PackedVector4Array()
	for t in get_tree().get_nodes_in_group("terrain"):
		if not (t is BrushTerrain) or t.data == null:
			continue
		var p: Vector3 = t.global_position
		var width: float = t.data.world_size()
		rects.append(Vector4(p.x, p.z, p.x + width, p.z + width))
		if rects.size() == 8:
			break
	var count := rects.size()
	while rects.size() < 8:
		rects.append(Vector4.ZERO)
	for t in get_tree().get_nodes_in_group("terrain"):
		if t is BrushTerrain and t._outer_water_mat:
			t._outer_water_mat.set_shader_parameter("land_rect_count", count)
			t._outer_water_mat.set_shader_parameter("land_rects", rects)

func _chunk_indices(cells: int) -> PackedInt32Array:
	if _index_cache.has(cells):
		return _index_cache[cells]
	var idx := PackedInt32Array()
	var w := cells + 1
	for z in cells:
		for x in cells:
			var a := z * w + x
			var b := a + 1
			var c := a + w
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])
	_index_cache[cells] = idx
	return idx

func _build_chunk(cx: int, cz: int, step: int = 1) -> void:
	var cells := chunk_cells / step
	var cs := data.cell_size
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	verts.resize((cells + 1) * (cells + 1))
	norms.resize(verts.size())
	var x0 := cx * chunk_cells
	var z0 := cz * chunk_cells
	var i := 0
	for z in range(z0, z0 + chunk_cells + 1, step):
		for x in range(x0, x0 + chunk_cells + 1, step):
			var h := data.get_h(x, z)
			verts[i] = Vector3(x * cs, h, z * cs)
			var hl := data.get_h(x - 1, z)
			var hr := data.get_h(x + 1, z)
			var hu := data.get_h(x, z - 1)
			var hd := data.get_h(x, z + 1)
			norms[i] = Vector3(hl - hr, 2.0 * cs, hu - hd).normalized()
			i += 1
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	var indices := _chunk_indices(cells).duplicate()
	if streamed:
		_add_skirts(verts, norms, indices, cells)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var key := Vector2i(cx, cz)
	var dst: Dictionary = _coarse if step > 1 else _chunks
	var mi: MeshInstance3D = dst.get(key)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "chunk_%d_%d" % [cx, cz]
		mi.material_override = _mat
		_gen.add_child(mi)
		dst[key] = mi
	mi.mesh = mesh
	if step == 1 and _coarse.has(key):
		_coarse[key].visible = false

func _build_collision() -> void:
	if _body == null or not is_instance_valid(_body):
		_body = StaticBody3D.new()
		_body.name = "TerrainBody"
		_body.collision_layer = 1
		_gen.add_child(_body)
		_col_node = CollisionShape3D.new()
		_body.add_child(_col_node)
	_shape = HeightMapShape3D.new()
	var r1 := data.resolution + 1
	_shape.map_width = r1
	_shape.map_depth = r1
	var scaled := PackedFloat32Array()
	scaled.resize(data.heights.size())
	var inv := 1.0 / data.cell_size
	for k in data.heights.size():
		scaled[k] = data.heights[k] * inv
	_shape.map_data = scaled
	_col_node.shape = _shape
	_col_node.scale = Vector3.ONE * data.cell_size
	var half := data.world_size() * 0.5
	_col_node.position = Vector3(half, 0.0, half)

## Skirts close visual T-junctions; collision always uses the original full-resolution samples.
func _add_skirts(v: PackedVector3Array, n: PackedVector3Array, ix: PackedInt32Array, cells: int) -> void:
	var w := cells + 1
	var edges := []
	for i in cells:
		edges.append_array([[i + 1, i], [cells * w + i, cells * w + i + 1], [i * w, (i + 1) * w], [(i + 1) * w + cells, i * w + cells]])
	for e in edges:
		var a: int = e[0]
		var b: int = e[1]
		var k := v.size()
		v.append(v[a] - Vector3(0, 50, 0))
		v.append(v[b] - Vector3(0, 50, 0))
		n.append(n[a])
		n.append(n[b])
		ix.append_array([a, b, k, b, k + 1, k])

func tile_distance(key: Vector2i, p: Vector3) -> float:
	var width := chunk_cells * data.cell_size
	var a := Vector2(key.x, key.y) * width + Vector2(global_position.x, global_position.z)
	var q := Vector2(p.x, p.z)
	return q.distance_to(q.clamp(a, a + Vector2.ONE * width))

func stream_request(focus: Vector3, supports: Array = []) -> void:
	if not streamed:
		return
	_wanted.clear()
	var anchors := [focus]
	anchors.append_array(supports)
	var width := chunk_cells * data.cell_size
	var limit := data.resolution / chunk_cells
	for j in anchors.size():
		var p: Vector3 = anchors[j]
		var rad := DETAIL_RADIUS if j == 0 else 96.0
		var local := p - global_position
		var a := Vector2i(floori((local.x - rad) / width), floori((local.z - rad) / width))
		var b := Vector2i(floori((local.x + rad) / width), floori((local.z + rad) / width))
		for z in range(maxi(0, a.y), mini(limit - 1, b.y) + 1):
			for x in range(maxi(0, a.x), mini(limit - 1, b.x) + 1):
				var k := Vector2i(x, z)
				if tile_distance(k, p) <= rad:
					_wanted[k] = true
	for k in _chunks.keys():
		if not _wanted.has(k) and tile_distance(k, focus) > RETAIN_RADIUS:
			_chunks[k].queue_free()
			_chunks.erase(k)
			_coarse[k].visible = true
			if _tile_bodies.has(k):
				_tile_bodies[k].queue_free()
				_tile_bodies.erase(k)
	_terrain_queue.clear()
	for k in _wanted:
		if not _chunks.has(k):
			_terrain_queue.append(k)
	_terrain_queue.sort_custom(func(a, b): return tile_distance(a, focus) < tile_distance(b, focus))

func stream_step() -> bool:
	if _terrain_queue.is_empty():
		return false
	var k: Vector2i = _terrain_queue.pop_front()
	_build_chunk(k.x, k.y)
	if collision_enabled:
		_build_tile_collision(k)
	return true

func collision_ready(p: Vector3, margin: float = 6.0) -> bool:
	if not streamed or not is_inside(p.x, p.z):
		return true
	var width := chunk_cells * data.cell_size
	var local := p - global_position
	var limit := data.resolution / chunk_cells
	for z in range(maxi(0, floori((local.z - margin) / width)), mini(limit - 1, floori((local.z + margin) / width)) + 1):
		for x in range(maxi(0, floori((local.x - margin) / width)), mini(limit - 1, floori((local.x + margin) / width)) + 1):
			if not _tile_bodies.has(Vector2i(x, z)):
				return false
	return true

func _build_tile_collision(k: Vector2i) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := HeightMapShape3D.new()
	var w := chunk_cells + 1
	shape.map_width = w
	shape.map_depth = w
	var heights := PackedFloat32Array()
	heights.resize(w * w)
	for z in w:
		for x in w:
			heights[z * w + x] = data.get_h(k.x * chunk_cells + x, k.y * chunk_cells + z) / data.cell_size
	shape.map_data = heights
	var col := CollisionShape3D.new()
	col.shape = shape
	col.scale = Vector3.ONE * data.cell_size
	col.position = Vector3((k.x + 0.5) * chunk_cells * data.cell_size, 0, (k.y + 0.5) * chunk_cells * data.cell_size)
	body.add_child(col)
	_gen.add_child(body)
	_tile_bodies[k] = body

func _build_water() -> void:
	if data.water_level < -999.0:
		return
	var img := Image.create_from_data(data.resolution + 1, data.resolution + 1, false, Image.FORMAT_RF, data.heights.to_byte_array())
	_tex_h = ImageTexture.create_from_image(img)
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = WATER_SHADER
	WaterStyle.configure(_water_mat)
	if ResourceLoader.exists("res://assets/textures/env/water_normal.png"):
		_water_mat.set_shader_parameter("detail_normal", load("res://assets/textures/env/water_normal.png"))
	_water_mat.set_shader_parameter("noise_tex", get_noise_texture())
	_water_mat.set_shader_parameter("height_tex", _tex_h)
	_water_mat.set_shader_parameter("has_height", 1.0)
	_water_mat.set_shader_parameter("terrain_origin", Vector2(global_position.x, global_position.z))
	_water_mat.set_shader_parameter("terrain_size", data.world_size())
	_water_mat.set_shader_parameter("water_level", water_level_global())
	var pm := PlaneMesh.new()
	var size := data.world_size()
	# 中心细分网格 + 外围大平面
	pm.size = Vector2(size, size)
	pm.subdivide_width = 96
	pm.subdivide_depth = 96
	var w := MeshInstance3D.new()
	w.name = "Water"
	w.mesh = pm
	w.material_override = _water_mat
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.position = Vector3(size * 0.5, data.water_level, size * 0.5)
	_gen.add_child(w)
	var outer := PlaneMesh.new()
	outer.size = Vector2(water_extent * 2.0, water_extent * 2.0)
	var o := MeshInstance3D.new()
	o.name = "WaterOuter"
	o.mesh = outer
	var om := _water_mat.duplicate() as ShaderMaterial
	_outer_water_mat = om
	om.set_shader_parameter("has_height", 0.0)
	om.set_shader_parameter("wave_geometry", 0.0)
	o.material_override = om
	o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	o.position = Vector3(size * 0.5, data.water_level - 0.08, size * 0.5)
	_gen.add_child(o)

# ---------------------------------------------------------------- 查询
func get_height_global(wx: float, wz: float) -> float:
	if data == null:
		return 0.0
	return data.sample(wx - global_position.x, wz - global_position.z) + global_position.y

func get_normal_global(wx: float, wz: float) -> Vector3:
	if data == null:
		return Vector3.UP
	return data.normal_at(wx - global_position.x, wz - global_position.z)

func is_inside(wx: float, wz: float) -> bool:
	if data == null:
		return false
	var lx := wx - global_position.x
	var lz := wz - global_position.z
	var s := data.world_size()
	return lx >= 0 and lz >= 0 and lx <= s and lz <= s

func water_level_global() -> float:
	if data == null or data.water_level < -999.0:
		return -10000.0
	return data.water_level + global_position.y

## 射线与地形求交（编辑器笔刷用）
func ray_hit(from: Vector3, dir: Vector3, max_dist: float = 4000.0) -> Variant:
	if data == null:
		return null
	dir = dir.normalized()
	var step := data.cell_size * 0.5
	var t := 0.0
	var prev_above := true
	var prev_t := 0.0
	while t < max_dist:
		var p := from + dir * t
		var above := p.y > get_height_global(p.x, p.z)
		if not above and is_inside(p.x, p.z):
			if t == 0.0:
				return p
			var lo := prev_t
			var hi := t
			for k in 12:
				var mid := (lo + hi) * 0.5
				var q := from + dir * mid
				if q.y > get_height_global(q.x, q.z):
					lo = mid
				else:
					hi = mid
			return from + dir * hi
		prev_above = above
		prev_t = t
		t += step
	return null

# ---------------------------------------------------------------- 编辑
## mode: 0 抬升 1 降低 2 平滑 3 压平 4 涂刷
func apply_brush(mode: int, center_g: Vector3, radius: float, strength: float, flatten_h: float = 0.0, layer: int = 0) -> void:
	if data == null:
		return
	var c := center_g - global_position
	var cs := data.cell_size
	if mode == 4:
		var px0 := int(floor((c.x - radius) / cs))
		var px1 := int(ceil((c.x + radius) / cs))
		var pz0 := int(floor((c.z - radius) / cs))
		var pz1 := int(ceil((c.z + radius) / cs))
		for pz in range(pz0, pz1 + 1):
			for px in range(px0, px1 + 1):
				var d := Vector2((px + 0.5) * cs - c.x, (pz + 0.5) * cs - c.z).length()
				if d > radius:
					continue
				var f := 1.0 - smoothstep(radius * 0.5, radius, d)
				data.paint_pixel(px, pz, layer, strength * f)
		if _tex_a:
			_tex_a.update(data.control_a)
			_tex_b.update(data.control_b)
		return
	var x0 := maxi(0, int(floor((c.x - radius) / cs)))
	var x1 := mini(data.resolution, int(ceil((c.x + radius) / cs)))
	var z0 := maxi(0, int(floor((c.z - radius) / cs)))
	var z1 := mini(data.resolution, int(ceil((c.z + radius) / cs)))
	var orig := {}
	if mode == 2:
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				orig[Vector2i(x, z)] = (data.get_h(x - 1, z) + data.get_h(x + 1, z) + data.get_h(x, z - 1) + data.get_h(x, z + 1) + data.get_h(x, z) * 2.0) / 6.0
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(x * cs - c.x, z * cs - c.z).length()
			if d > radius:
				continue
			var f := 1.0 - smoothstep(0.0, radius, d)
			var h := data.get_h(x, z)
			match mode:
				0: h += strength * f
				1: h -= strength * f
				2: h = lerpf(h, orig[Vector2i(x, z)], clampf(strength * f * 0.5, 0.0, 1.0))
				3: h = lerpf(h, flatten_h - global_position.y, clampf(strength * f * 0.3, 0.0, 1.0))
			data.set_h(x, z, h)
	_rebuild_rect(x0 - 1, z0 - 1, x1 + 1, z1 + 1)

func _rebuild_rect(x0: int, z0: int, x1: int, z1: int) -> void:
	var n := data.resolution / chunk_cells
	var cx0 := clampi(x0 / chunk_cells, 0, n - 1)
	var cx1 := clampi(x1 / chunk_cells, 0, n - 1)
	var cz0 := clampi(z0 / chunk_cells, 0, n - 1)
	var cz1 := clampi(z1 / chunk_cells, 0, n - 1)
	for cz in range(cz0, cz1 + 1):
		for cx in range(cx0, cx1 + 1):
			_build_chunk(cx, cz)

func commit_collision() -> void:
	if collision_enabled and data != null and _gen != null:
		_build_collision()
	if _tex_h != null and data != null:
		var img := Image.create_from_data(data.resolution + 1, data.resolution + 1, false, Image.FORMAT_RF, data.heights.to_byte_array())
		_tex_h.update(img)

func set_brush_preview(pos: Vector3, radius: float) -> void:
	if _mat:
		_mat.set_shader_parameter("brush_pos", pos)
		_mat.set_shader_parameter("brush_radius", radius)
