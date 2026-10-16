class_name CityHouses
extends Node3D
## 合批的街区住宅（晴岚港 v4）：上千栋联排房不再一栋一个 ModelProp 节点。
## 生成器（tools/gen_solenne.gd）把每栋房子写进 data，运行时：
##   · 按 CHUNK 米分块、同一模型合成一个 MultiMesh（近景，NEAR 米内）；
##   · 远景用"墙体盒 + 四坡屋顶"的简模 MultiMesh（NEAR 米外到 FAR 米）；
##   · 墙 / 屋顶 / 饰边颜色是调色板下标，写进实例自定义数据，由 building.gdshader 的 inst_slot 读取；
##   · 每栋一个碰撞盒（同一个 StaticBody3D）。
## 每栋 10 个 float：x, y, z, yaw(度), 宽, 高, 进深, 墙色下标, 屋顶色下标, 模型下标*8 + 饰边色下标

const STRIDE := 10
const CHUNK := 120.0
const NEAR := 280.0
const FAR := 2200.0
const DIR := "res://assets/models/"

## 住宅模型（assets/models/<名>.glb，原点在底面中心、正面朝 +Z）
@export var models: PackedStringArray = PackedStringArray(["manor_0", "manor_1", "manor_2", "manor_3", "manor_4", "manor_5", "corner_0"])
@export var palette: PackedColorArray = PackedColorArray()
@export var data: PackedFloat32Array = PackedFloat32Array()

static var _merged := {}     # 模型名 -> ArrayMesh（按材质名合并后的表面）
static var _surf_names := {} # 模型名 -> [材质名]
var _mats := {}

func count() -> int:
	return data.size() / STRIDE

func house(i: int) -> Array:
	return Array(data.slice(i * STRIDE, i * STRIDE + STRIDE))

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not has_meta("stream_deferred"):
		_build()

func _build() -> void:
	var n := count()
	if n == 0:
		return
	# 分块
	var chunks := {}
	for i in n:
		var k := Vector2i(int(floor(data[i * STRIDE] / CHUNK)), int(floor(data[i * STRIDE + 2] / CHUNK)))
		if not chunks.has(k):
			chunks[k] = []
		chunks[k].append(i)
	var far_mesh := _far_mesh()
	for k in chunks:
		var ids: Array = chunks[k]
		var center := Vector3((k.x + 0.5) * CHUNK, 0.0, (k.y + 0.5) * CHUNK)
		var by_model := {}
		for i in ids:
			var mi_idx := int(data[i * STRIDE + 9]) / 8
			if not by_model.has(mi_idx):
				by_model[mi_idx] = []
			by_model[mi_idx].append(i)
		for m in by_model if not has_meta("stream_proxy") else []:
			var mesh := _model_mesh(models[clampi(m, 0, models.size() - 1)])
			if mesh == null:
				continue
			_add_mmi(mesh, by_model[m], center, models[clampi(m, 0, models.size() - 1)], 0.0, NEAR, true)
		if not has_meta("stream_detail"):
			_add_mmi(far_mesh, ids, center, "", 0.0 if has_meta("stream_proxy") else NEAR - 20.0, FAR, false)
	if not has_meta("stream_proxy"):
		_add_collision()

func _xf(i: int, nom: Vector3, center: Vector3) -> Transform3D:
	var o := i * STRIDE
	var b := Basis(Vector3.UP, deg_to_rad(data[o + 3])).scaled_local(Vector3(data[o + 4] / nom.x, data[o + 5] / nom.y, data[o + 6] / nom.z))
	return Transform3D(b, Vector3(data[o], data[o + 1], data[o + 2]) - center)

func _add_mmi(mesh: Mesh, ids: Array, center: Vector3, model: String, vis_begin: float, vis_end: float, shadows: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = ids.size()
	var nom := ModelProp.nominal(model) if model != "" else Vector3.ONE
	for j in ids.size():
		var i: int = ids[j]
		var o := i * STRIDE
		mm.set_instance_transform(j, _xf(i, nom, center))
		var mt := int(data[o + 9])
		mm.set_instance_custom_data(j, Color(data[o + 7], data[o + 8], float(mt % 8) + 40.0, 0.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.position = center
	mmi.visibility_range_begin = vis_begin
	mmi.visibility_range_end = 0.0 if has_meta("stream_detail") else vis_end
	mmi.visibility_range_end_margin = 30.0
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

## 按材质名合并模型里所有网格；材质：A 墙（实例色槽 0）、B 屋顶（槽 1）、C 饰边（槽 2），玻璃用夜间发光窗，其余按材质名固定
func _model_mesh(name: String) -> ArrayMesh:
	if _merged.has(name):
		return _merged[name]
	var ps: PackedScene = load(DIR + name + ".glb") if ResourceLoader.exists(DIR + name + ".glb") else null
	if ps == null:
		_merged[name] = null
		return null
	var inst := ps.instantiate()
	var groups := {}
	var cols := {}
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var nd: Node = mi
		while nd != null and nd != inst:
			if nd is Node3D:
				xf = (nd as Node3D).transform * xf
			nd = nd.get_parent()
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			var nm := mat.resource_name if mat else ""
			if not groups.has(nm):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[nm] = st
				cols[nm] = (mat as BaseMaterial3D).albedo_color if mat is BaseMaterial3D else Color.WHITE
			groups[nm].append_from(mesh, s, xf)
	inst.free()
	var out := ArrayMesh.new()
	var names := []
	for nm in groups:
		var st: SurfaceTool = groups[nm]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
		out.surface_set_material(out.get_surface_count() - 1, _material(nm, cols[nm]))
		names.append(nm)
	_merged[name] = out
	_surf_names[name] = names
	return out

func _slot_mat(type: int, slot: int, tex := "", tex_m := 0.0) -> Material:
	var key := "%d_%d" % [type, slot]
	if _mats.has(key):
		return _mats[key]
	var m: ShaderMaterial = (U.bmat(type, Color.WHITE, tex, tex_m) as ShaderMaterial).duplicate()
	m.set_shader_parameter("inst_slot", slot)
	var pal := PackedVector3Array()
	for c in palette:
		pal.append(Vector3(c.r, c.g, c.b))
	while pal.size() < 64:
		pal.append(Vector3.ONE)
	m.set_shader_parameter("inst_pal", pal)
	_mats[key] = m
	return m

func _material(nm: String, col: Color) -> Material:
	match nm:
		"A":
			return _slot_mat(0, 0)
		"B":
			return _slot_mat(3, 1)
		"C":
			return _slot_mat(9, 2)
		"glass":
			return Prop.get_window_mat()
		"stone", "stone_dark":
			return U.bmat(2, col)
		"brick":
			return U.bmat(1, col)
		"terracotta":
			return U.bmat(4, col)
		"copper":
			return U.bmat(5, Color("5a9886"))
		"door", "wood", "wood_dark":
			return U.bmat(6, col)
		"gold", "iron", "metal", "bronze":
			return U.bmat(7, col)
		"white", "beige", "sandstone":
			return U.bmat(9, col)
	return U.bmat(0, col)

## 远景简模：单位尺寸，墙体 0–0.78、四坡屋顶 0.78–1.0；表面 0 = 墙（槽 0），表面 1 = 屋顶（槽 1）
static var _far: ArrayMesh
func _far_mesh() -> ArrayMesh:
	if _far:
		return _far
	var m := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := 0.5
	var top := 0.78
	var quads := [
		[Vector3(-hw, 0, hw), Vector3(hw, 0, hw), Vector3(hw, top, hw), Vector3(-hw, top, hw), Vector3(0, 0, 1)],
		[Vector3(hw, 0, -hw), Vector3(-hw, 0, -hw), Vector3(-hw, top, -hw), Vector3(hw, top, -hw), Vector3(0, 0, -1)],
		[Vector3(hw, 0, hw), Vector3(hw, 0, -hw), Vector3(hw, top, -hw), Vector3(hw, top, hw), Vector3(1, 0, 0)],
		[Vector3(-hw, 0, -hw), Vector3(-hw, 0, hw), Vector3(-hw, top, hw), Vector3(-hw, top, -hw), Vector3(-1, 0, 0)]]
	for q in quads:
		st.set_normal(q[4])
		for v in [q[0], q[1], q[2], q[0], q[2], q[3]]:
			st.add_vertex(v)
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	m.surface_set_material(0, _slot_mat(0, 0))
	var rt := SurfaceTool.new()
	rt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ridge := Vector3(0, 1.0, 0)
	var e := 0.52
	var c4 := [Vector3(-e, top, e), Vector3(e, top, e), Vector3(e, top, -e), Vector3(-e, top, -e)]
	var r0 := Vector3(-0.22, 1.0, 0)
	var r1 := Vector3(0.22, 1.0, 0)
	for tri in [[c4[0], c4[1], r1], [c4[0], r1, r0], [c4[2], c4[3], r0], [c4[2], r0, r1], [c4[1], c4[2], r1], [c4[3], c4[0], r0]]:
		var nrm: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
		st = rt
		st.set_normal(nrm)
		for v in tri:
			st.add_vertex(v)
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rt.commit_to_arrays())
	m.surface_set_material(1, _slot_mat(3, 1))
	_far = m
	return m

func _add_collision() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for i in count():
		var o := i * STRIDE
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(data[o + 4], data[o + 5], data[o + 6])
		cs.shape = bs
		cs.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(data[o + 3])), Vector3(data[o], data[o + 1] + data[o + 5] * 0.5, data[o + 2]))
		body.add_child(cs)

## 地图：屋顶色块
func draw_map(img: Image, cs: float, origin: Vector3) -> void:
	for i in count():
		var o := i * STRIDE
		var roof: Color = palette[int(data[o + 8])] if int(data[o + 8]) < palette.size() else Color("4a6a96")
		roof = roof.darkened(0.12)
		var p := global_transform * Vector3(data[o], data[o + 1], data[o + 2]) - origin
		var yaw := deg_to_rad(data[o + 3])
		var ex := Vector3(cos(yaw), 0, -sin(yaw)) * data[o + 4] * 0.5
		var ez := Vector3(sin(yaw), 0, cos(yaw)) * data[o + 6] * 0.5
		var steps := int(maxf(data[o + 4], data[o + 6]) / cs * 2.0) + 2
		for a in steps + 1:
			for b in steps + 1:
				var q := p + ex * (a * 2.0 / steps - 1.0) + ez * (b * 2.0 / steps - 1.0)
				var px := int(q.x / cs)
				var pz := int(q.z / cs)
				if px >= 0 and pz >= 0 and px < img.get_width() and pz < img.get_height():
					var edge := a == 0 or b == 0 or a == steps or b == steps
					img.set_pixel(px, pz, roof.darkened(0.3) if edge else roof)

func rebuild() -> void:
	_build()

func stream_unload() -> void:
	for c in get_children():
		c.free()
