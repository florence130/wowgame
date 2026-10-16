class_name CityKit
extends RefCounted
## 晴岚港城市建筑构件库（tools/blender/city_kit 生成，assets/models/city_kit/*.glb，清单 manifest.json）的运行时拼装器。
## 模数：开间 BAY 4.4m，底层 GF 5.6m，标准层 FH 4.4m。构件沿 +X 展开 0..BAY、外立面朝 +Z、原点在左下角墙中心线。
## 用法：
##   var b := CityKit.building({"nx": 5, "nz": 3, "floors": 3, "gf": "SASDSAS"..., "uf": ["balc", "pedi", "seg"],
##       "wall": "brick", "roof": "slate", "dormer": "pedi", "turret": true})
##   parent.add_child(b)   # 建筑占地 x∈[0, nx·BAY]，z∈[-nz·BAY, 0]，正面在 z=0 朝 +Z
## 底层编码（gf 字符串，按 front→right→back→left 逐开间循环取用）：
##   A 拱窗  D 拱门  O 过街拱  S 商铺（带雨篷）  s 商铺（无雨篷）  W 实墙
const DIR := "res://assets/models/city_kit/"
const BAY := 4.4
const GF := 5.6
const FH := 4.4
const GF_CODES := {"A": "ck_gf_arch_window", "D": "ck_gf_arch_door", "O": "ck_gf_arch_open", "S": "ck_gf_shop", "s": "ck_gf_shop_plain", "W": "ck_gf_solid"}
static var _scenes := {}

static func scene(id: String) -> PackedScene:
	if not _scenes.has(id):
		_scenes[id] = load(DIR + id + ".glb") as PackedScene
	return _scenes[id]

## 加载任意 GLB（飞艇等整件资产）：只替换 K| 构件材质，不生成碰撞
static func load_glb(path: String) -> Node3D:
	var ps := load(path) as PackedScene
	if ps == null:
		push_error("CityKit: cannot load " + path)
		return null
	var inst := ps.instantiate() as Node3D
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count():
			var sm := m3.mesh.surface_get_material(i)
			if sm != null:
				var km := U.kit_mat(sm.resource_name)
				if km != null:
					m3.set_surface_override_material(i, km)
		m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst

## 实例化一个构件：替换 K| 构件材质；collide 时为非 *_nocol 网格生成静态碰撞
static func piece(id: String, xf: Transform3D, collide := true) -> Node3D:
	var ps := scene(id)
	if ps == null:
		push_error("CityKit: missing piece " + id)
		return Node3D.new()
	var inst := ps.instantiate() as Node3D
	inst.name = id
	inst.transform = xf
	var body: StaticBody3D = null
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count():
			var sm := m3.mesh.surface_get_material(i)
			if sm != null:
				var km := U.kit_mat(sm.resource_name)
				if km != null:
					m3.set_surface_override_material(i, km)
		if collide and not String(m3.name).to_lower().contains("nocol"):
			if body == null:
				body = StaticBody3D.new()
				body.name = "col"
				inst.add_child(body)
			var cs := CollisionShape3D.new()
			cs.shape = m3.mesh.create_trimesh_shape()
			body.add_child(cs)
			cs.transform = m3.transform
	return inst

## 四个立面上第 i 个开间的变换（与 tools/blender/city_kit/build.py facade_xf 对应；Blender Z 轴旋转 = Godot Y 轴旋转）
static func facade_xf(side: String, i: int, w: float, d: float, y: float) -> Transform3D:
	match side:
		"front":
			return Transform3D(Basis.IDENTITY, Vector3(i * BAY, y, 0))
		"back":
			return Transform3D(Basis(Vector3.UP, PI), Vector3((i + 1) * BAY, y, -d))
		"left":
			return Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(0, y, -(i + 1) * BAY))
		_:
			return Transform3D(Basis(Vector3.UP, PI / 2), Vector3(w, y, -i * BAY))

## 整栋街区楼：底层编码 + 各层窗式 + 檐口 / 腰线 / 芒萨尔老虎窗 / 转角隅石 / 可选圆角楼
static func building(spec: Dictionary) -> Node3D:
	var nx: int = spec.get("nx", 4)
	var nz: int = spec.get("nz", 3)
	var floors: int = spec.get("floors", 3)
	var gf: String = spec.get("gf", "A")
	var uf: Array = spec.get("uf", ["plain"])
	var wall: String = spec.get("wall", "brick")
	var roof: String = spec.get("roof", "slate")
	var dormer: String = spec.get("dormer", "pedi")
	var collide: bool = spec.get("collide", true)
	var w := nx * BAY
	var d := nz * BAY
	var root := Node3D.new()
	root.name = spec.get("name", "kit_building")
	var k := 0
	var top := GF + floors * FH
	for side in ["front", "right", "back", "left"]:
		var n := nx if side in ["front", "back"] else nz
		for i in n:
			var code := gf[k % gf.length()]
			k += 1
			root.add_child(piece(GF_CODES.get(code, "ck_gf_solid"), facade_xf(side, i, w, d, 0.0), collide))
			for f in floors:
				var y := GF + f * FH
				var st: String = uf[f % uf.size()]
				root.add_child(piece("ck_uf_%s_%s" % [st, wall], facade_xf(side, i, w, d, y), collide))
				root.add_child(piece("ck_band", facade_xf(side, i, w, d, y - 0.16), false))
			root.add_child(piece("ck_cornice", facade_xf(side, i, w, d, top - 0.86), false))
			if roof != "flat":
				var dm := dormer != "" and (i % 2 == 1 or n <= 2)
				var rid := "ck_mansard_copper" if roof == "copper" else ("ck_mansard_" + dormer if dm else "ck_mansard")
				root.add_child(piece(rid, facade_xf(side, i, w, d, top), collide))
	for c in [Vector3(0, 0, 0), Vector3(w, 0, 0), Vector3(0, 0, -d), Vector3(w, 0, -d)]:
		for f in floors:
			root.add_child(piece("ck_quoins", Transform3D(Basis.IDENTITY, c + Vector3(0, GF + f * FH, 0)), false))
	if spec.get("turret", false):
		for f in floors:
			root.add_child(piece("ck_turret_body", Transform3D(Basis.IDENTITY, Vector3(0, GF + f * FH, 0)), collide))
		root.add_child(piece("ck_turret_cone", Transform3D(Basis.IDENTITY, Vector3(0, top, 0)), collide))
	# 平屋顶（锌皮）盖住芒萨尔顶面之间的空隙
	var cap := MeshInstance3D.new()
	cap.name = "roof_cap"
	var bm := BoxMesh.new()
	bm.size = Vector3(w - 2.2, 0.2, d - 2.2)
	cap.mesh = bm
	cap.material_override = U.kit_mat("K|9|7f8b97||0")
	cap.position = Vector3(w / 2, top + (4.4 if roof != "flat" else 0.0) + 0.1, -d / 2)
	root.add_child(cap)
	root.set_meta("footprint", Vector2(w, d))
	root.set_meta("height", top + (4.4 if roof != "flat" else 0.0))
	return root
