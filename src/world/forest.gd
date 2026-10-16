@tool
class_name Forest
extends Node3D
## 批量植被（MultiMesh 渲染）：树木/灌木/岩石/草丛。点坐标为局部坐标。

@export var points: PackedVector3Array = PackedVector3Array():
	set(v):
		points = v
		_queue()
@export var scales: PackedFloat32Array = PackedFloat32Array()
## 可选：逐棵的椭圆冠幅 (yaw 弧度, 沿 yaw 方向系数, 垂直方向系数)；用于行道树避让建筑立面。留空 = 圆冠 + 随机朝向。
@export var shapes: PackedVector3Array = PackedVector3Array()
@export_enum("oak", "pine", "palm", "birch", "bush", "rock", "grass", "flower", "deadtree") var kind: String = "oak":
	set(v):
		kind = v
		_queue()
@export var color: Color = Color("4f8f3a"):
	set(v):
		color = v
		_queue()
@export var collide: bool = true
@export var point_ids: PackedInt32Array = PackedInt32Array()

func _point_id(i: int) -> int:
	return point_ids[i] if i < point_ids.size() else i
var _gen: Node3D
var _pending := false

func _ready() -> void:
	if has_meta("stream_deferred") and not Engine.is_editor_hint():
		set_process(false)
		return
	rebuild()

func _queue() -> void:
	if is_inside_tree() and not _pending:
		_pending = true
		call_deferred("rebuild")

func _parts() -> Array:
	# [mesh, color, offset, scale]
	var trunk := Color("7a5a3a")
	match kind:
		"oak":
			return [[U.cyl_mesh(0.25, 0.4, 4.0, 7), trunk, Vector3(0, 2.0, 0), Vector3.ONE],
				[U.sphere_mesh(2.4, 4.8, false, 10), color, Vector3(0, 5.2, 0), Vector3(1, 0.85, 1)],
				[U.sphere_mesh(1.7, 3.4, false, 9), color.lightened(0.07), Vector3(1.3, 4.6, 0.5), Vector3.ONE],
				[U.sphere_mesh(1.6, 3.2, false, 9), color.darkened(0.06), Vector3(-1.2, 4.4, -0.6), Vector3.ONE],
				[U.sphere_mesh(1.4, 2.8, false, 9), color.lightened(0.12), Vector3(0, 6.6, 0), Vector3.ONE]]
		"pine":
			return [[U.cyl_mesh(0.2, 0.32, 3.0, 6), trunk.darkened(0.1), Vector3(0, 1.5, 0), Vector3.ONE],
				[U.cyl_mesh(0.0, 2.4, 3.2, 8), color.darkened(0.1), Vector3(0, 3.8, 0), Vector3.ONE],
				[U.cyl_mesh(0.0, 1.9, 2.8, 8), color.darkened(0.05), Vector3(0, 5.4, 0), Vector3.ONE],
				[U.cyl_mesh(0.0, 1.3, 2.4, 8), color, Vector3(0, 6.9, 0), Vector3.ONE]]
		"birch":
			return [[U.cyl_mesh(0.15, 0.22, 5.0, 6), Color("ece8e0"), Vector3(0, 2.5, 0), Vector3.ONE],
				[U.sphere_mesh(1.8, 3.6, false, 9), color.lightened(0.15), Vector3(0, 5.6, 0), Vector3(0.9, 1.3, 0.9)]]
		"palm":
			var arr := [[U.cyl_mesh(0.18, 0.26, 6.0, 6), trunk.lightened(0.1), Vector3(0, 3.0, 0), Vector3.ONE], [U.sphere_mesh(0.35), Color("6a5030"), Vector3(0, 6.0, 0), Vector3.ONE]]
			for i in 6:
				var a := i * TAU / 6.0
				arr.append([U.box_mesh(Vector3(0.6, 0.06, 3.0)), color.lightened(0.1), Vector3(sin(a) * 1.3, 5.7, cos(a) * 1.3), Vector3.ONE, Vector3(28, rad_to_deg(a), 0)])
			return arr
		"bush":
			return [[U.sphere_mesh(0.9, 1.8, false, 8), color, Vector3(0, 0.55, 0), Vector3(1, 0.75, 1)],
				[U.sphere_mesh(0.6, 1.2, false, 8), color.lightened(0.08), Vector3(0.55, 0.45, 0.1), Vector3.ONE]]
		"rock":
			return [[U.sphere_mesh(1.0, 2.0, false, 7), Color("9a968c"), Vector3(0, 0.3, 0), Vector3(1.2, 0.7, 1.0)],
				[U.sphere_mesh(0.6, 1.2, false, 6), Color("8a867c"), Vector3(0.7, 0.2, 0.3), Vector3.ONE]]
		"grass":
			return [[U.cyl_mesh(0.0, 0.18, 0.7, 4), color.lightened(0.05), Vector3(0, 0.3, 0), Vector3.ONE],
				[U.cyl_mesh(0.0, 0.15, 0.55, 4), color.darkened(0.05), Vector3(0.18, 0.25, 0.1), Vector3.ONE, Vector3(0, 0, -15)],
				[U.cyl_mesh(0.0, 0.15, 0.6, 4), color, Vector3(-0.15, 0.27, -0.08), Vector3.ONE, Vector3(10, 0, 12)]]
		"flower":
			return [[U.cyl_mesh(0.02, 0.02, 0.4, 4), Color("4a8a3a"), Vector3(0, 0.2, 0), Vector3.ONE],
				[U.sphere_mesh(0.12, 0.24, false, 6), color, Vector3(0, 0.42, 0), Vector3.ONE]]
		"deadtree":
			return [[U.cyl_mesh(0.15, 0.3, 4.5, 6), Color("5a4a3a"), Vector3(0, 2.2, 0), Vector3.ONE],
				[U.cyl_mesh(0.04, 0.12, 2.0, 5), Color("5a4a3a"), Vector3(0.6, 3.8, 0), Vector3.ONE, Vector3(0, 0, -45)],
				[U.cyl_mesh(0.04, 0.12, 1.8, 5), Color("5a4a3a"), Vector3(-0.5, 3.4, 0.2), Vector3.ONE, Vector3(10, 0, 40)]]
	return []

## Blender 模型（tools/blender/build_models.py / build_props.py）；材质 B = 叶片（按 color 着色），其余保持模型颜色
const MODEL := {"oak": "tree_0", "pine": "tree_1", "palm": "tree_2", "birch": "tree_3", "deadtree": "tree_4",
	"bush": "bush_0", "rock": "rock_0", "flower": "flower_0"}
static var _mesh_cache := {}

## 返回按 kind+color 着色后的模型网格（缓存），没有模型则返回 null
func _model_mesh() -> Mesh:
	if not MODEL.has(kind):
		return null
	var key := "%s_%s" % [kind, color.to_html()]
	if _mesh_cache.has(key):
		return _mesh_cache[key][0]
	var path := "res://assets/models/%s.glb" % MODEL[kind]
	if not ResourceLoader.exists(path):
		return null
	var root: Node = (load(path) as PackedScene).instantiate()
	var src: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0] if root.find_children("*", "MeshInstance3D", true, false).size() > 0 else null
	if src == null:
		root.free()
		return null
	var m: ArrayMesh = src.mesh.duplicate()
	var xf := src.transform
	for s in m.get_surface_count():
		var sm := m.surface_get_material(s)
		var nm := sm.resource_name if sm else ""
		var c: Color = (sm as BaseMaterial3D).albedo_color if sm is BaseMaterial3D else Color.WHITE
		if nm == "B":
			c = color
		m.surface_set_material(s, U.mat(c))
	root.free()
	_mesh_cache[key] = [m, xf]
	return m

## 成熟乔木派生资产：kind -> [模型名, 变体数, 缩放]；旧模型保留作缺失资源回退。
const VEG := {"oak": ["oak", 3, 1.0], "pine": ["pine", 3, 1.0], "birch": ["birch", 2, 1.0], "bush": ["bush", 2, 0.85]}
const VEG_DIR := "res://assets/models/veg/"
const DETAIL_RANGE := 120.0
const DETAIL_MARGIN := 12.0
const STORYBOOK_DIR := "res://assets/models/nature_storybook/"
const FOLIAGE := preload("res://src/render/foliage.gdshader")
const CANOPY := preload("res://src/render/canopy.gdshader")
static var _veg_cache := {}
static var _veg_mats := {}

## Let the existing bounded background loader warm models before building a forest cell.
func stream_asset_paths() -> Array[String]:
	var paths: Array[String] = []
	if VEG.has(kind):
		var entry: Array = VEG[kind]
		for v in int(entry[1]):
			var name := "%s_%d" % [entry[0], v]
			var candidate := STORYBOOK_DIR + ("bush_0" if name == "bush_1" else name) + ".scn"
			if ResourceLoader.exists(candidate) and not paths.has(candidate):
				paths.append(candidate)
			var proxy := STORYBOOK_DIR + "proxy/" + ("bush_0" if name == "bush_1" else name) + ".scn"
			if ResourceLoader.exists(proxy):
				if not paths.has(proxy): paths.append(proxy)
				continue
			var original := VEG_DIR + name + ".glb"
			if ResourceLoader.exists(original):
				paths.append(original)
	elif MODEL.has(kind):
		var original := "res://assets/models/%s.glb" % MODEL[kind]
		if ResourceLoader.exists(original):
			paths.append(original)
	return paths

## 模型拆成 [网格, 是否树冠, 相对变换]
static func _veg_parts(name: String, storybook: bool = false) -> Array:
	var key := name + ("_storybook" if storybook else "")
	if _veg_cache.has(key):
		return _veg_cache[key]
	var out := []
	var path := VEG_DIR + name + ".glb"
	var proxy := STORYBOOK_DIR + "proxy/" + ("bush_0" if name == "bush_1" else name) + ".scn"
	if not storybook and ResourceLoader.exists(proxy):
		path = proxy
	if storybook:
		# Detailed crowns use their fitted proxy at distance; legacy originals remain a fallback.
		var candidate := STORYBOOK_DIR + ("bush_0" if name == "bush_1" else name) + ".scn"
		if ResourceLoader.exists(candidate):
			path = candidate
	if ResourceLoader.exists(path):
		var ps: PackedScene = load(path)
		if ps:
			var root := ps.instantiate()
			var stack := [[root, Transform3D.IDENTITY]]
			while not stack.is_empty():
				var e: Array = stack.pop_back()
				var n: Node = e[0]
				var xf: Transform3D = e[1]
				if n is Node3D and n != root:
					xf = xf * (n as Node3D).transform
				if n is MeshInstance3D and (n as MeshInstance3D).mesh:
					var mesh := (n as MeshInstance3D).mesh
					var leaf := String(n.name).to_lower().contains("leaf")
					var material := mesh.surface_get_material(0) as BaseMaterial3D
					var mask: Texture2D = material.albedo_texture if leaf and path.ends_with(".scn") and material else null
					out.append([mesh, leaf, xf, mask])
				for c in n.get_children():
					stack.append([c, xf])
			root.free()
	_veg_cache[key] = out
	return out

static func _veg_mat(c: Color, leaf: bool, mask: Texture2D = null) -> ShaderMaterial:
	var key := "%s_%s_%s" % [c.to_html(false), leaf, mask.resource_path if mask else "solid"]
	if _veg_mats.has(key):
		return _veg_mats[key]
	var m := ShaderMaterial.new()
	m.shader = CANOPY if mask else FOLIAGE
	if mask:
		m.set_shader_parameter("leaf_mask", mask)
		m.set_shader_parameter("use_leaf_mask", true)
		m.set_shader_parameter("painted_mask", mask.resource_path.contains("/masks/"))
	if leaf:
		# 保留区域植被差异，减少荧光黄顶，统一到灰绿/玉绿的绘本色板。
		var leaf_color := c.lerp(Color("628a60"), 0.34)
		m.set_shader_parameter("base_color", leaf_color)
		m.set_shader_parameter("dark_color", leaf_color.lerp(Color("345e55"), 0.36))
		m.set_shader_parameter("hi_color", leaf_color.lightened(0.16).lerp(Color("b5c588"), 0.22))
	else:
		m.set_shader_parameter("base_color", c)
		m.set_shader_parameter("is_leaf", 0.0)
		m.set_shader_parameter("birch_bark", c.r > 0.7 and c.g > 0.7)
	_veg_mats[key] = m
	return m

func _build_veg() -> bool:
	if not VEG.has(kind):
		return false
	var e: Array = VEG[kind]
	var nv: int = e[1]
	var variants := []
	for v in nv:
		var parts := _veg_parts("%s_%d" % [e[0], v], true)
		if parts.is_empty():
			return false
		variants.append(parts)
	var bark := Color("e6e1d6") if kind == "birch" else Color("5a3f2a")
	var base_s: float = e[2]
	for v in nv:
		var idx := []
		for i in points.size():
			if hash(_point_id(i) * 31 + 7) % nv == v:
				idx.append(i)
		if idx.is_empty():
			continue
		var has_detail: bool = variants[v].any(func(p): return p[3] != null)
		# Both representations share exactly the same bounds and switch distance.
		# Far forests stay opaque: thousands of alpha leaves must not fill the horizon.
		var parts: Array = variants[v].duplicate()
		if has_detail:
			parts.append_array(_veg_parts("%s_%d" % [e[0], v]))
		# Fit both representations to their actual mature-tree bounds, including wind.
		var local_bounds := AABB()
		for part in parts:
			local_bounds = local_bounds.merge(part[2] * part[0].get_aabb())
		local_bounds = local_bounds.grow(1.5)
		var shared_bounds: AABB = _tree_transform(idx[0], base_s) * local_bounds
		for i in idx:
			shared_bounds = shared_bounds.merge(_tree_transform(i, base_s) * local_bounds)
		for pi in parts.size():
			var part: Array = parts[pi]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part[0]
			mm.instance_count = idx.size()
			for k in idx.size():
				var i: int = idx[k]
				var t := _tree_transform(i, base_s)
				mm.set_instance_transform(k, t * part[2])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = _veg_mat(color if part[1] else bark, part[1], part[3])
			if has_detail:
				mmi.custom_aabb = shared_bounds
				if pi < variants[v].size():
					mmi.visibility_range_end = DETAIL_RANGE
					mmi.visibility_range_end_margin = DETAIL_MARGIN
				else:
					mmi.visibility_range_begin = DETAIL_RANGE
					mmi.visibility_range_begin_margin = DETAIL_MARGIN
			if kind == "bush":
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			elif has_detail and pi < variants[v].size() and part[1]:
				# Alpha-tested leaves are costly in every shadow cascade. A soft, opaque
				# crown proxy below supplies the tree shadow while keeping the visible leaves.
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_gen.add_child(mmi)
			if has_detail and pi >= variants[v].size() and part[1] and kind != "bush":
				var caster := MultiMeshInstance3D.new()
				caster.name = "CanopyShadowProxy"
				caster.multimesh = mm
				caster.material_override = mmi.material_override
				caster.custom_aabb = shared_bounds
				caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
				caster.visibility_range_end = DETAIL_RANGE
				caster.visibility_range_end_margin = DETAIL_MARGIN
				_gen.add_child(caster)
	return true

func _tree_transform(i: int, base_scale: float) -> Transform3D:
	var s: float = (scales[i] if i < scales.size() else 1.0) * base_scale
	if i < shapes.size() and (shapes[i].y < 0.999 or shapes[i].z < 0.999):
		# 局部坐标下 X 沿街、Z 垂直街：先转朝向，再按椭圆压窄冠幅（树干同比变细，高度不变）
		return Transform3D(Basis(Vector3.UP, shapes[i].x) * Basis.from_scale(Vector3(shapes[i].y, 1.0, shapes[i].z)) * Basis.from_scale(Vector3.ONE * s), points[i])
	var rot := float(hash(_point_id(i) * 7919) % 628) / 100.0
	return Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * s), points[i])

func _trunk_radius(i: int) -> float:
	if not VEG.has(kind): return 0.4
	var entry: Array = VEG[kind]
	var variant := hash(_point_id(i) * 31 + 7) % int(entry[1])
	for part in _veg_parts("%s_%d" % [entry[0], variant], true):
		if not part[1]: return float(part[0].get_meta("trunk_radius", 0.4)) * float(entry[2])
	return 0.4

func rebuild() -> void:
	_pending = false
	if _gen and is_instance_valid(_gen):
		remove_child(_gen)
		_gen.free()
	_gen = Node3D.new()
	_gen.name = "_gen"
	add_child(_gen)
	if points.is_empty():
		return
	if _build_veg():
		_add_collision()
		return
	var mm_mesh := _model_mesh()
	if mm_mesh != null:
		var xf0: Transform3D = _mesh_cache["%s_%s" % [kind, color.to_html()]][1]
		var mm0 := MultiMesh.new()
		mm0.transform_format = MultiMesh.TRANSFORM_3D
		mm0.mesh = mm_mesh
		mm0.instance_count = points.size()
		for i in points.size():
			var s0: float = scales[i] if i < scales.size() else 1.0
			var rot0 := float(hash(_point_id(i) * 7919) % 628) / 100.0
			mm0.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rot0).scaled(Vector3.ONE * s0), points[i]) * xf0)
		var mmi0 := MultiMeshInstance3D.new()
		mmi0.multimesh = mm0
		if kind in ["flower", "bush"]:
			mmi0.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if kind == "flower":
			mmi0.visibility_range_end = 90.0
		_gen.add_child(mmi0)
		_add_collision()
		return
	for part in _parts():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part[0]
		mm.instance_count = points.size()
		var local := Transform3D(Basis.from_euler((part[4] if part.size() > 4 else Vector3.ZERO) * (PI / 180.0)).scaled(part[3]), part[2])
		for i in points.size():
			var s: float = scales[i] if i < scales.size() else 1.0
			var rot := float(hash(_point_id(i) * 7919) % 628) / 100.0
			var t := Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * s), points[i])
			mm.set_instance_transform(i, t * local)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = U.mat(part[1])
		if kind in ["grass", "flower"]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 90.0
		_gen.add_child(mmi)
	_add_collision()

func _add_collision() -> void:
	if collide and kind in ["oak", "pine", "birch", "palm", "rock", "deadtree"] and not Engine.is_editor_hint():
		var body := StaticBody3D.new()
		body.collision_layer = 1
		_gen.add_child(body)
		for i in points.size():
			var s2: float = scales[i] if i < scales.size() else 1.0
			if kind == "rock":
				U.add_box_shape(body, Vector3(2.0, 1.2, 1.8) * s2, points[i] + Vector3(0, 0.4 * s2, 0))
			else:
				U.add_cyl_shape(body, _trunk_radius(i) * s2, 4.0 * s2, points[i] + Vector3(0, 2.0 * s2, 0))

## Release generated render/physics content; retain the authored descriptor.
func stream_unload() -> void:
	set_process(false)
	if is_instance_valid(_gen):
		_gen.free()
	_gen = null
