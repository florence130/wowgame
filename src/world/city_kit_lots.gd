class_name CityKitLots
extends Node3D
## 模块化沿街楼（tools/blender/street_kit 构件 + tools/city_plan_v6/src/kitlots.js 摆放表）的 MultiMesh 合批。
## 数据：assets/models/street_kit/kit_lots.bin（Float32，每个构件实例 12 个数）+ kit_lots.json（构件表 / 调色板）。
##   每个实例：构件下标, x, y, z, yaw(弧度), sx, sy, sz, 墙色, 屋顶色, 石材色, 点缀色（调色板下标）
## 运行时：按 CELL 米分块，每块每种构件一个 MultiMesh（共用 building.gdshader，调色板下标走 INSTANCE_CUSTOM）；
## 只在 KIT_RANGE 米内可见，更远处是城市 chunk 里的白模代理（节点 lotfar，从 PROXY_BEGIN 米起可见）。
## 分块节点由 WorldStream 按距离流入 / 流出（rebuild / stream_unload），与 CityHouses 同一套约定。

const STRIDE := 12
const CELL := 120.0
const KIT_RANGE := 140.0
const DIR := "res://assets/models/street_kit/"
@export var data_path := DIR + "kit_lots.bin"
@export var meta_path := DIR + "kit_lots.json"

var pieces: PackedStringArray = PackedStringArray()
var palette: PackedColorArray = PackedColorArray()
var data: PackedFloat32Array = PackedFloat32Array()
## 封顶三角形（街角楼屋面中心）：每个 10 个数 x,y,z ×3 + 调色板下标（-1 = 锌板平顶，否则陶瓦锥顶取该色）
var caps: PackedFloat32Array = PackedFloat32Array()
var cell_center := Vector3.ZERO

static var _meshes := {}     # 构件名 -> ArrayMesh（按材质名合并的表面）
static var _mats := {}
static var _meta := {}

func count() -> int:
	return data.size() / STRIDE


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if has_meta("stream_detail"):
		if not has_meta("stream_deferred"):
			rebuild()
		return
	_load_all()

## 根节点：读取数据文件（WorldStream 随后把它按 CELL 拆成 stream_detail 子节点）
func _load_all() -> void:
	if not data.is_empty():
		return
	if not FileAccess.file_exists(data_path):
		push_warning("CityKitLots: missing " + data_path)
		return
	var meta = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
	pieces = PackedStringArray(meta.pieces)
	var pal := PackedColorArray()
	for h in meta.palette:
		pal.append(Color(h))
	palette = pal
	data = FileAccess.get_file_as_bytes(data_path).to_float32_array()
	var cp := data_path.get_base_dir() + "/kit_caps.bin"
	if FileAccess.file_exists(cp):
		caps = FileAccess.get_file_as_bytes(cp).to_float32_array()

func rebuild() -> void:
	stream_unload()
	var n := count()
	if n == 0:
		return
	var by_piece := {}
	for i in n:
		var p := int(data[i * STRIDE])
		if not by_piece.has(p):
			by_piece[p] = []
		by_piece[p].append(i)
	for p in by_piece:
		var mesh := _piece_mesh(pieces[p], palette)
		if mesh == null:
			continue
		var ids: Array = by_piece[p]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = ids.size()
		for j in ids.size():
			var o: int = int(ids[j]) * STRIDE
			var b := Basis(Vector3.UP, data[o + 4]) * Basis.from_scale(Vector3(data[o + 5], data[o + 6], data[o + 7]))
			mm.set_instance_transform(j, Transform3D(b, Vector3(data[o + 1], data[o + 2], data[o + 3]) - cell_center))
			mm.set_instance_custom_data(j, Color(data[o + 8], data[o + 9], data[o + 10], data[o + 11]))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = pieces[p]
		mmi.multimesh = mm
		mmi.position = cell_center
		mmi.visibility_range_end = KIT_RANGE
		mmi.visibility_range_end_margin = 12.0
		add_child(mmi)
	_build_caps()

## 街角楼屋面封顶：按（锌板 / 各陶瓦色）合成网格，每种一个 MeshInstance
func _build_caps() -> void:
	var by_col := {}
	for t in caps.size() / 10:
		var o := t * 10
		var ci := int(caps[o + 9])
		if not by_col.has(ci):
			by_col[ci] = SurfaceTool.new()
			(by_col[ci] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
		var st: SurfaceTool = by_col[ci]
		var v0 := Vector3(caps[o], caps[o + 1], caps[o + 2]) - cell_center
		var v1 := Vector3(caps[o + 3], caps[o + 4], caps[o + 5]) - cell_center
		var v2 := Vector3(caps[o + 6], caps[o + 7], caps[o + 8]) - cell_center
		var nrm := (v1 - v0).cross(v2 - v0)
		if nrm.y < 0.0:                       # 保证朝上的一面是正面
			var tmp := v1
			v1 = v2
			v2 = tmp
		for v in [v0, v1, v2]:
			st.add_vertex(v)
	for ci in by_col:
		var st: SurfaceTool = by_col[ci]
		st.generate_normals()
		var mesh: ArrayMesh = st.commit()
		var mi := MeshInstance3D.new()
		mi.name = "caps_%d" % ci
		mi.mesh = mesh
		mi.position = cell_center
		mi.material_override = _cap_material(int(ci), palette)
		mi.visibility_range_end = KIT_RANGE
		mi.visibility_range_end_margin = 12.0
		add_child(mi)

static func _cap_material(ci: int, pal: PackedColorArray) -> Material:
	var key := "cap_%d" % ci
	if _mats.has(key):
		return _mats[key]
	var m: Material
	if ci < 0:
		m = U.kit_mat("K|7|59616b|pt_metal|2.0")
	else:
		m = U.bmat(4, pal[ci], "pt_roof_tile", 2.4)
	_mats[key] = m
	return m

func stream_unload() -> void:
	for c in get_children():
		c.free()

static func _piece_mesh(id: String, pal: PackedColorArray) -> ArrayMesh:
	if _meshes.has(id):
		return _meshes[id]
	var path := DIR + id + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("CityKitLots: missing piece " + id)
		_meshes[id] = null
		return null
	var inst := (load(path) as PackedScene).instantiate()
	var groups := {}
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var nd: Node = m3
		while nd != null and nd != inst:
			if nd is Node3D:
				xf = (nd as Node3D).transform * xf
			nd = nd.get_parent()
		for s in m3.mesh.get_surface_count():
			var sm := m3.mesh.surface_get_material(s)
			var nm := sm.resource_name if sm else ""
			if not groups.has(nm):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[nm] = st
			groups[nm].append_from(m3.mesh, s, xf)
	inst.free()
	var out := ArrayMesh.new()
	var ground := id.begins_with("sk_gf")
	for nm in groups:
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, (groups[nm] as SurfaceTool).commit_to_arrays())
		out.surface_set_material(out.get_surface_count() - 1, _material(String(nm), pal, ground))
	_meshes[id] = out
	return out

## 材质名：S|槽|类型|贴图|米 = 实例着色槽；N|RRGGBB = 夜间发光窗格；K|… 固定色（U.kit_mat）
static func _material(nm: String, pal: PackedColorArray, ground: bool) -> Material:
	var key := "%s_%s" % [nm, ground]
	if _mats.has(key):
		return _mats[key]
	var m: Material = null
	var f := nm.split("|")
	if f[0] == "S" and f.size() >= 5:
		var sm: ShaderMaterial = (U.bmat(int(f[2]), Color.WHITE, f[3], float(f[4])) as ShaderMaterial).duplicate()
		sm.set_shader_parameter("inst_slot", int(f[1]))
		var p := PackedVector3Array()
		for c in pal:
			p.append(Vector3(c.r, c.g, c.b))
		while p.size() < 64:
			p.append(Vector3.ONE)
		sm.set_shader_parameter("inst_pal", p)
		sm.set_shader_parameter("ground_ao", 1.0 if ground else 0.0)
		m = sm
	elif f[0] == "N":
		m = CityMat.night_window(Color(f[1]))
	else:
		m = U.kit_mat(nm)
		if m is ShaderMaterial and not ground:
			m = (m as ShaderMaterial).duplicate()
			(m as ShaderMaterial).set_shader_parameter("ground_ao", 0.0)
	_mats[key] = m
	return m
