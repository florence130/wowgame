@tool
class_name U
extends RefCounted
## 通用工具：材质缓存、网格缓存、几何体快捷构建、格式化

static var _mat_cache := {}
static var _mesh_cache := {}

const QUALITY_COLORS := [
	Color("9d9d9d"), # 0 粗糙
	Color("ffffff"), # 1 普通
	Color("1eff00"), # 2 优秀
	Color("0070dd"), # 3 精良
	Color("a335ee"), # 4 史诗
	Color("ff8000"), # 5 传说
]
const QUALITY_NAMES := ["粗糙", "普通", "优秀", "精良", "史诗", "传说"]

# ---------------------------------------------------------------- 材质
## 场景用卡通材质（Toon 漫反射，无高光）。不带描边外壳（2026-10-08 按用户要求移除卡通描边）。
static func mat(c: Color, emissive: float = 0.0, transparent: bool = false) -> StandardMaterial3D:
	var key := "m_%s_%.2f_%s" % [c.to_html(true), emissive, transparent]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 0.85
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissive
	if transparent or c.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	elif emissive <= 0.0:
		m.set_meta("vc_kind", "toon")
		m.set_meta("vc_color", c)
	_mat_cache[key] = m
	return m

## 建筑风格化材质（src/render/building.gdshader）：type 0 灰泥 1 红砖 2 石块 3 石板瓦 4 陶瓦 5 铜绿 6 木板 7 金属 8 植物 9 光面石饰
static var _bshader: Shader
static func bmat(type: int, c: Color, tex := "", tex_m := 0.0) -> Material:
	var key := "b_%d_%s_%s_%.2f" % [type, c.to_html(false), tex, tex_m]
	if _mat_cache.has(key):
		return _mat_cache[key]
	if _bshader == null:
		_bshader = load("res://src/render/building.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _bshader
	m.set_shader_parameter("base_color", c)
	m.set_shader_parameter("mtype", type)
	if tex != "":
		tex = TEX_ALIAS.get(tex, tex)
		var tp2 := "res://assets/textures/building/%s.png" % tex
		if ResourceLoader.exists(tp2):
			m.set_shader_parameter("tex_detail", load(tp2))
			m.set_shader_parameter("use_tex", 1.0)
			m.set_shader_parameter("tex_m", tex_m if tex_m > 0.0 else 3.0)
			m.set_shader_parameter("pbr", _pbr_for(tex, type))
			_pbr_maps(m, tex)
	elif BTEX.has(type):
		var tp: String = "res://assets/textures/building/%s.png" % BTEX[type][0]
		if ResourceLoader.exists(tp):
			m.set_shader_parameter("tex_detail", load(tp))
			m.set_shader_parameter("use_tex", 1.0)
			m.set_shader_parameter("tex_m", BTEX[type][1])
			m.set_shader_parameter("pbr", _pbr_for(BTEX[type][0], type))
			_pbr_maps(m, BTEX[type][0])
	_mat_cache[key] = m
	return m

## 2026-10-10 PBR：按贴图（材质）给 [粗糙度, 金属度, 介电反射量(0.5=F0 0.04)]。木 / 灰泥 / 砖 / 石是粗糙介电体；钢 / 铁 / 铜是金属；瓦带一点釉光；木瓦、树皮、皮革各自不同。
## 没有贴图的材质按 building.gdshader 里 mtype 的默认值。
const TEX_PBR := {
	"pt_plaster": [0.95, 0.0, 0.25], "pt_brick": [0.88, 0.0, 0.3], "pt_ashlar": [0.82, 0.0, 0.4], "pt_rubble": [0.86, 0.0, 0.35], "pt_limestone": [0.8, 0.0, 0.45],
	"pt_roof_slate": [0.7, 0.0, 0.35], "pt_roof_tile": [0.65, 0.0, 0.4], "pt_shake": [0.82, 0.0, 0.3], "pt_wood": [0.78, 0.0, 0.3], "pt_bark": [0.92, 0.0, 0.2],
	"pt_leather": [0.62, 0.0, 0.4], "pt_metal": [0.55, 0.55, 0.5], "pt_steel": [0.45, 0.7, 0.5], "pt_copper": [0.46, 0.6, 0.5], "pt_foliage": [0.72, 0.0, 0.4],
	"pt_awning": [0.9, 0.0, 0.2], "pt_thatch": [0.95, 0.0, 0.15],
}
## 高清 PBR 贴图（tools/texgen/pbr_maps.py 生成的 <贴图>_n.png 法线 / _r.png 粗糙度+AO）；有就挂上，没有保持原样
static func _pbr_maps(m: ShaderMaterial, tex: String) -> void:
	var np := "res://assets/textures/building/%s_n.png" % tex
	var rp := "res://assets/textures/building/%s_r.png" % tex
	if ResourceLoader.exists(np):
		m.set_shader_parameter("tex_nrm", load(np))
		m.set_shader_parameter("use_nrm", 1.0)
		if ResourceLoader.exists(rp):
			m.set_shader_parameter("tex_rgh", load(rp))
static func _pbr_for(tex: String, type: int) -> Vector3:
	var r: Array = TEX_PBR.get(tex, [])
	if r.is_empty():
		return Vector3(-1.0, 0.0, 0.5)
	return Vector3(float(r[0]), float(r[1]), float(r[2]))
## 建筑手绘贴图：类型 -> [文件名, 每张覆盖米数]（tools/texgen 生成，tools/texgen/prep_tex.py 处理成无缝灰度）
## 贴图替换：构件库 GLB 里写死的贴图名 → 现用贴图（不必重新导出模型）。
## SUNTAIL 的规则砖格换成洛奇M 式手绘不规则石块（tools/texgen/paint_building.py）
## 2026-10-09：全部改为手绘 RGB 乘数贴图（tools/texgen/paint_building_v2.py → assets/textures/building/pt_*.png），旧灰度贴图不再引用。
const TEX_ALIAS := {"st_masonry": "pt_ashlar", "st_cobble": "pt_rubble", "st_plaster": "pt_plaster", "st_wood": "pt_wood", "st_boards": "pt_wood", "st_planks": "pt_wood",
	"st_stone": "pt_ashlar", "st_roof_scale": "pt_roof_slate", "st_roof_barrel": "pt_roof_tile", "brick": "pt_brick", "plaster": "pt_plaster", "stone": "pt_ashlar",
	"roof_slate": "pt_roof_slate", "roof_terracotta": "pt_roof_tile", "copper": "pt_copper", "wood": "pt_wood"}
const BTEX := {0: ["pt_plaster", 4.0], 1: ["pt_brick", 2.6], 2: ["pt_ashlar", 3.2], 3: ["pt_roof_slate", 2.6], 4: ["pt_roof_tile", 2.4], 5: ["pt_copper", 3.0], 6: ["pt_wood", 2.2],
	7: ["pt_metal", 2.0], 8: ["pt_foliage", 3.0], 9: ["pt_limestone", 4.8]}

## 构件库材质约定（tools/blender/modkit）：材质名 "K|<mtype>|<RRGGBB>|<贴图名或空>|<每张米数>" → bmat
## 玻璃用 "K|glass|RRGGBB||0"，发光用 "K|glow|RRGGBB||0"。返回 null 表示不是构件库材质。
## 洛奇M（Mabinogi Mobile）解包模型的图集材质：building.gdshader 的 use_uv 模式（直接用模型 UV 取 albedo，保留项目的卡通明暗）
static func mabi_mat(tex: String) -> Material:
	var key := "mabi_" + tex
	if _mat_cache.has(key):
		return _mat_cache[key]
	if _bshader == null:
		_bshader = load("res://src/render/building.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _bshader
	m.set_shader_parameter("base_color", Color.WHITE)
	m.set_shader_parameter("mtype", 0)
	var tp := "res://assets/textures/mabi/%s.png" % tex
	if ResourceLoader.exists(tp):
		m.set_shader_parameter("tex_detail", load(tp))
	m.set_shader_parameter("use_uv", 1.0)
	m.set_shader_parameter("ground_ao", 0.0)
	_mat_cache[key] = m
	return m

static func kit_mat(name: String) -> Material:
	if name.begins_with("V|"):
		var fields := name.split("|")
		var key := "village_batch_" + name
		if not _mat_cache.has(key):
			var material: ShaderMaterial = bmat(int(fields[1]), Color.WHITE, fields[2], float(fields[3])).duplicate()
			material.set_shader_parameter("use_vertex_base", true)
			_mat_cache[key] = material
		return _mat_cache[key]
	if name.begins_with("N|"):
		return CityMat.night_window(Color(name.substr(2)))      # 窗格：白天深色玻璃，夜间发暖光
	if name.begins_with("M|"):
		return mabi_mat(name.substr(2))                          # 洛奇M 图集模型：按自带 UV 贴 assets/textures/mabi/<name>.png
	if not name.begins_with("K|"):
		return null
	var f := name.split("|")
	if f.size() < 5:
		return null
	var c := Color(f[2])
	if f[1] == "glass":
		return mat(Color(c, 0.55))
	if f[1] == "glow":
		return mat(c, 1.6)
	return bmat(int(f[1]), c, f[3], float(f[4]))

## 角色用卡通材质：Toon + 轮廓光。不带描边外壳（2026-10-08 按用户要求移除卡通描边）。
## outline 形参保留：合并网格时作为分组标记（"char" / "char_no"），旧调用点不必逐个改写。
static func char_mat(c: Color, outline: bool = true, emissive: float = 0.0) -> StandardMaterial3D:
	var key := "c_%s_%s_%.2f" % [c.to_html(true), outline, emissive]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 0.6
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.6
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissive
	if emissive <= 0.0 and c.a >= 0.999:
		m.set_meta("vc_kind", "char" if outline else "char_no")
		m.set_meta("vc_color", c)
	_mat_cache[key] = m
	return m

static func unshaded(c: Color, additive: bool = false, nodepth: bool = false) -> StandardMaterial3D:
	var key := "u_%s_%s_%s" % [c.to_html(true), additive, nodepth]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if c.a < 0.999 or additive:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if nodepth:
		m.no_depth_test = true
		m.render_priority = 10
	if not nodepth:
		m.set_meta("vc_kind", "unshaded_add" if additive else ("unshaded_a" if c.a < 0.999 else "unshaded"))
		m.set_meta("vc_color", c)
	_mat_cache[key] = m
	return m

# ---------------------------------------------------------------- 网格
static func box_mesh(size: Vector3) -> BoxMesh:
	var key := "box%s" % size
	if not _mesh_cache.has(key):
		var m := BoxMesh.new()
		m.size = size
		_mesh_cache[key] = m
	return _mesh_cache[key]

static func sphere_mesh(r: float, h: float = -1.0, hemi: bool = false, seg: int = 16) -> SphereMesh:
	if h < 0.0:
		h = r * 2.0
	var key := "sph%.3f_%.3f_%s_%d" % [r, h, hemi, seg]
	if not _mesh_cache.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = h if not hemi else h * 0.5
		m.is_hemisphere = hemi
		m.radial_segments = seg
		m.rings = maxi(4, seg / 2)
		_mesh_cache[key] = m
	return _mesh_cache[key]

static func cyl_mesh(top: float, bottom: float, h: float, sides: int = 12) -> CylinderMesh:
	var key := "cyl%.3f_%.3f_%.3f_%d" % [top, bottom, h, sides]
	if not _mesh_cache.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = h
		m.radial_segments = sides
		m.rings = 1
		_mesh_cache[key] = m
	return _mesh_cache[key]

static func capsule_mesh(r: float, h: float) -> CapsuleMesh:
	var key := "cap%.3f_%.3f" % [r, h]
	if not _mesh_cache.has(key):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = maxf(h, r * 2.0)
		m.radial_segments = 12
		m.rings = 4
		_mesh_cache[key] = m
	return _mesh_cache[key]

static func prism_mesh(size: Vector3, left: float = 0.5) -> PrismMesh:
	var key := "pri%s_%.2f" % [size, left]
	if not _mesh_cache.has(key):
		var m := PrismMesh.new()
		m.size = size
		m.left_to_right = left
		_mesh_cache[key] = m
	return _mesh_cache[key]

static func torus_mesh(inner: float, outer: float, rings: int = 24) -> TorusMesh:
	var key := "tor%.3f_%.3f_%d" % [inner, outer, rings]
	if not _mesh_cache.has(key):
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = rings
		m.ring_segments = 10
		_mesh_cache[key] = m
	return _mesh_cache[key]

static func quad_mesh(size: Vector2) -> QuadMesh:
	var key := "quad%s" % size
	if not _mesh_cache.has(key):
		var m := QuadMesh.new()
		m.size = size
		_mesh_cache[key] = m
	return _mesh_cache[key]

## 在 parent 下添加网格实例
static func add_mesh(parent: Node, mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func box(parent: Node, size: Vector3, pos: Vector3, c: Color, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return add_mesh(parent, box_mesh(size), mat(c), pos, rot_deg)

## 静态碰撞盒
static func add_box_shape(body: CollisionObject3D, size: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.position = pos
	cs.rotation_degrees = rot_deg
	body.add_child(cs)
	return cs

static func add_cyl_shape(body: CollisionObject3D, r: float, h: float, pos: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = h
	cs.shape = s
	cs.position = pos
	body.add_child(cs)
	return cs

# ---------------------------------------------------------------- 格式化
static func money_text(copper: int) -> String:
	var neg := copper < 0
	copper = absi(copper)
	var g := copper / 10000
	var s := (copper / 100) % 100
	var c := copper % 100
	var parts := []
	if g > 0:
		parts.append("%d金" % g)
	if s > 0 or g > 0:
		parts.append("%d银" % s)
	parts.append("%d铜" % c)
	return ("-" if neg else "") + " ".join(parts)

static func money_bb(copper: int) -> String:
	var g := copper / 10000
	var s := (copper / 100) % 100
	var c := copper % 100
	var t := ""
	if g > 0:
		t += "[color=#ffd75e]%d[/color][color=#e8c27a]金[/color] " % g
	if s > 0 or g > 0:
		t += "[color=#e6e6e6]%d[/color][color=#c0c0c0]银[/color] " % s
	t += "[color=#f0a46a]%d[/color][color=#c87a40]铜[/color]" % c
	return t

static func time_text(sec: float) -> String:
	if sec >= 3600.0:
		return "%d小时" % ceili(sec / 3600.0)
	if sec >= 60.0:
		return "%d分" % ceili(sec / 60.0)
	if sec >= 10.0:
		return "%d" % ceili(sec)
	return "%.1f" % sec

static func quality_color(q: int) -> Color:
	return QUALITY_COLORS[clampi(q, 0, 5)]

static func hash01(n: int) -> float:
	var x := (n * 374761393 + 668265263) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	return float(x % 100000) / 100000.0

static func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

static func yaw_to(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(-d.x, -d.z)

static func color_hex(c: Color) -> String:
	return "#" + c.to_html(false).to_upper()

static func find_terrain(tree: SceneTree) -> Node:
	if tree == null:
		return null
	return tree.get_first_node_in_group("terrain")

## 包含该点的地形（无缝大世界里有多块地形）；都不包含时取最近的一块
static func terrain_at(tree: SceneTree, x: float, z: float) -> Node:
	if tree == null:
		return null
	var best: Node = null
	var bd := INF
	for t in tree.get_nodes_in_group("terrain"):
		if not t.is_inside_tree() or t.data == null:
			continue
		var s: float = t.data.world_size()
		var o: Vector3 = t.global_position
		var dx := maxf(maxf(o.x - x, x - (o.x + s)), 0.0)
		var dz := maxf(maxf(o.z - z, z - (o.z + s)), 0.0)
		var d := dx * dx + dz * dz
		if d < bd:
			bd = d
			best = t
			if d == 0.0:
				break
	return best

## 查询地面高度（优先地形，其次物理射线）
static func ground_height(tree: SceneTree, x: float, z: float, fallback: float = 0.0) -> float:
	var t := terrain_at(tree, x, z)
	if t != null:
		return t.get_height_global(x, z)
	return fallback

# ---------------------------------------------------------------- 网格合并（顶点色）
static var _vc_mats := {}
static var _colored := {}

static func vc_mat(kind: String) -> Material:
	if _vc_mats.has(kind):
		return _vc_mats[kind]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	match kind:
		"toon":
			m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			m.roughness = 0.85
		"char", "char_no":
			# 角色保留一层很薄的轮廓光代替描边：不加外壳，靠边缘亮起把角色从背景里分出来
			m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			m.roughness = 0.6
			m.rim_enabled = true
			m.rim = 0.35
			m.rim_tint = 0.6
		"unshaded", "unshaded_a", "unshaded_add":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			if kind != "unshaded":
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			if kind == "unshaded_add":
				m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_vc_mats[kind] = m
	return m

## 为网格附加顶点色（缓存），统一格式：顶点/法线/颜色/索引
static func colored_mesh(mesh: Mesh, c: Color) -> ArrayMesh:
	var key := "%d_%s" % [mesh.get_instance_id(), c.to_html(true)]
	if _colored.has(key):
		return _colored[key]
	var src := mesh.surface_get_arrays(0)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = src[Mesh.ARRAY_VERTEX]
	arr[Mesh.ARRAY_NORMAL] = src[Mesh.ARRAY_NORMAL]
	var cols := PackedColorArray()
	cols.resize(src[Mesh.ARRAY_VERTEX].size())
	cols.fill(c)
	arr[Mesh.ARRAY_COLOR] = cols
	if src[Mesh.ARRAY_INDEX] != null:
		arr[Mesh.ARRAY_INDEX] = src[Mesh.ARRAY_INDEX]
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_colored[key] = am
	return am

static func _mergeable(mi: MeshInstance3D) -> bool:
	if mi.mesh == null or mi.mesh.get_surface_count() != 1:
		return false
	var m := mi.material_override
	return m != null and m.has_meta("vc_kind") and not mi.has_meta("no_merge")

## 合并 node 的直接子网格（递归=true 时合并整棵静态子树，keep 中的节点保持独立）
static func merge_meshes(node: Node3D, recursive: bool = false, keep: Array = []) -> void:
	var groups := {}
	var to_free: Array = []
	_collect_merge(node, Transform3D.IDENTITY, groups, to_free, recursive, keep)
	for mi in to_free:
		mi.get_parent().remove_child(mi)
		mi.free()
	for k in groups:
		var g: Dictionary = groups[k]
		var st: SurfaceTool = g["st"]
		var mesh := st.commit()
		var out := MeshInstance3D.new()
		out.mesh = mesh
		out.material_override = vc_mat(g["kind"])
		out.cast_shadow = g["shadow"]
		out.name = "merged_" + String(k)
		node.add_child(out)
		if not recursive:
			pass

static func _collect_merge(n: Node, xf: Transform3D, groups: Dictionary, to_free: Array, recursive: bool, keep: Array) -> void:
	for c in n.get_children():
		if c in keep:
			continue
		if c is MeshInstance3D and _mergeable(c):
			var mi: MeshInstance3D = c
			var m: Material = mi.material_override
			var kind: String = m.get_meta("vc_kind")
			var key := "%s_%d" % [kind, mi.cast_shadow]
			if not groups.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"st": st, "kind": kind, "shadow": mi.cast_shadow}
			groups[key]["st"].append_from(colored_mesh(mi.mesh, m.get_meta("vc_color")), 0, xf * mi.transform)
			to_free.append(mi)
		elif recursive and c.get_class() == "Node3D" and c.get_script() == null:
			_collect_merge(c, xf * (c as Node3D).transform, groups, to_free, recursive, keep)

## 对每一层节点分别合并直接子网格（用于有骨骼动画的角色）
static func merge_levels(root: Node3D) -> void:
	var nodes: Array = [root]
	var i := 0
	while i < nodes.size():
		for c in nodes[i].get_children():
			if c.get_class() == "Node3D":
				nodes.append(c)
		i += 1
	for n in nodes:
		merge_meshes(n, false)

