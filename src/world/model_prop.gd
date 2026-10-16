@tool
class_name ModelProp
extends Node3D
## Blender 模型道具（assets/models/*.glb，由 tools/blender/build_models.py 生成）。
## 与 Prop 同样的参数语义：size = (宽, 墙高, 进深)，color_a/b/c 对应模型中名为 A/B/C 的材质（墙/屋顶/木筋或饰边），
## glass 材质换成游戏的窗户材质（夜晚发光）。墙、栅栏按模块沿长度平铺而不是拉伸。

const DIR := "res://assets/models/"
## kind -> [模型名前缀, 变体数, 缩放模式]；缩放模式：full 按 size 三轴缩放 / x 按宽度等比 / fixed 不缩放 / tile 沿 X 平铺
const LIB := {
	"house": ["house", 3, "full"], "cottage": ["house", 3, "full"], "townhouse": ["manor", 6, "full"], "rowhouse": ["manor", 6, "full"],
	"tower": ["tower", 1, "full"], "wall": ["wall", 1, "tile"], "fence": ["fence", 1, "tile"], "crate": ["crate", 3, "x"],
	"barrel": ["barrel", 2, "full"], "cart": ["cart", 1, "fixed"], "bench": ["bench", 1, "x"], "well": ["well", 1, "full"],
	"stall": ["stall", 1, "full"], "tent": ["tent", 1, "full"], "lamp": ["lamp", 1, "full"], "lantern_post": ["lamp", 1, "full"],
	"haystack": ["haystack", 1, "x"], "banner": ["banner", 1, "full"], "tree": ["tree", 5, "full"], "guildhouse": ["guildhouse", 4, "full"],
	"hall": ["hall", 3, "full"], "church": ["church", 1, "full"], "pier": ["pier", 1, "full"], "bridge": ["bridge", 1, "full"],
	# 第 4 批：场景道具（tools/blender/build_props.py）
	"ruin_wall": ["ruin_wall", 2, "full"], "column": ["column", 1, "full"], "pillar": ["pillar", 2, "full"], "pillar_row": ["pillar_row", 1, "full"],
	"arch": ["arch", 1, "full"], "obelisk": ["obelisk", 1, "full"], "grave": ["grave", 1, "fixed"], "block": ["block", 2, "full"],
	"platform": ["platform", 1, "full"], "campfire": ["campfire", 1, "fixed"], "brazier": ["brazier", 1, "fixed"],
	"signal_lamp": ["signal_lamp", 1, "fixed"], "crystal": ["crystal", 1, "full"], "flowerbed": ["flowerbed", 1, "full"],
	"hedge": ["hedge", 1, "full"], "sign": ["sign", 1, "fixed"], "gazebo": ["gazebo", 1, "full"], "fountain": ["fountain", 1, "full"],
	"rug": ["rug", 1, "full"], "altar": ["altar", 1, "full"], "throne": ["throne", 1, "fixed"], "bell": ["bell", 1, "full"],
	"statue": ["statue", 1, "y"], "web": ["web", 1, "full"], "field": ["field", 3, "tile2"], "anvil": ["anvil", 1, "fixed"],
	"rail": ["rail", 1, "tile"], "mine_entrance": ["mine_entrance", 1, "fixed"], "crane": ["crane", 1, "full"], "pipe": ["pipe", 1, "full"],
	"train": ["train", 2, "fixed"], "boat": ["boat", 1, "full"], "buoy": ["buoy", 1, "fixed"], "ramp": ["ramp", 1, "full"],
	"windmill": ["windmill", 1, "full"], "clocktower": ["clocktower", 1, "full"], "dome": ["dome", 1, "full"],
	"portal_ring": ["portal_ring", 1, "full"],
	# 晨钟修道院重制（tools/blender/build_abbey.py）
	"abbey_chapel": ["abbey_chapel", 1, "full"], "abbey_campanile": ["abbey_campanile", 1, "full"], "abbey_house": ["abbey_house", 2, "full"],
	"abbey_cottage": ["abbey_cottage", 1, "full"], "abbey_wall": ["abbey_wall", 1, "tile"], "abbey_gate": ["abbey_gate", 1, "full"],
	"abbey_lamp": ["lantern_post", 1, "fixed"], "cypress": ["cypress", 1, "y"], "training_dummy": ["training_dummy", 1, "fixed"],
	"weapon_rack": ["weapon_rack", 1, "fixed"], "birdbath": ["birdbath", 1, "fixed"], "grave_cross": ["grave_cross", 1, "fixed"],
	"flower_pot": ["flower_pot", 1, "x"],
	# 第 5 批：地标与特殊建筑（tools/blender/build_landmarks.py）
	"goddess": ["goddess", 1, "y"], "beacon": ["beacon", 1, "full"], "clock_spire": ["clock_spire", 1, "full"],
	"cathedral": ["cathedral", 1, "full"], "civic_hall": ["civic_hall", 1, "full"], "opera": ["opera", 1, "full"],
	"mage_tower": ["mage_tower", 1, "full"], "rotunda": ["rotunda", 1, "full"], "bathhouse": ["bathhouse", 1, "full"],
	"hospital": ["hospital", 1, "full"], "warehouse": ["warehouse", 1, "full"], "terminal": ["terminal", 1, "full"],
	"market_hall": ["market_hall", 1, "full"], "culvert": ["culvert", 1, "full"], "galleon": ["galleon", 1, "full"],
	"steamship": ["steamship", 1, "full"], "gate": ["gate", 1, "full"], "station": ["station", 1, "full"], "airship": ["airship", 1, "full"],
	# 第 6 批：晴岚港 v3 参考图资产（tools/blender/build_city2.py）
	"grand_station": ["grand_station", 1, "full"], "cathedral2": ["cathedral2", 1, "full"], "tholos": ["tholos", 1, "full"],
	"manor": ["manor", 6, "full"], "corner": ["corner", 1, "full"], "viaduct": ["viaduct", 1, "full"], "hero_statue": ["hero_statue", 1, "y"],
	"lamp2": ["lamp2", 1, "full"], "palm": ["palm", 1, "full"],
	# 第 8 批：晴岚港 v4 新增设施（tools/blender/build_city4.py）
	"crystal_palace": ["crystal_palace", 1, "full"], "mansion": ["mansion", 2, "full"],
	# 第 7 批：洛奇M 风村庄小物件（tools/blender/build_props2.py）
	"chair": ["chair", 1, "fixed"], "stool": ["stool", 1, "fixed"], "table": ["table", 1, "fixed"], "bucket": ["bucket", 1, "fixed"],
	"sack": ["sack", 1, "x"], "basket": ["basket", 1, "x"], "wood_pile": ["wood_pile", 1, "x"], "trough": ["trough", 1, "x"],
	"wheelbarrow": ["wheelbarrow", 1, "fixed"],
}
@export var flag := ""   # 城门屏障：未获得该标记时挡路（同 Prop.gate）
var _anim: Array = []    # [节点, 类型, 速度]
var _bob := false
var _t := 0.0
const WATER_SHADER := preload("res://src/terrain/water.gdshader")
var _spin: Node3D
var _auto_door_pivot: Node3D
var _auto_door_collision: CollisionShape3D
var _auto_door_angle := 0.0
var _auto_door_target := 0.0
static var _village_door_meta: Dictionary = {}
const VILLAGE_DOOR_RANGE := 3.2
## Blender front faces -Y (Godot +Z); positive Godot Y rotates the leaf toward
## Godot -Z, which is the room side.  The previous negative sign swung outside.
const VILLAGE_DOOR_OPEN := 1.36
const VILLAGE_DOOR_ASSET := "res://assets/models/village_kit/door_leaf_hinged.glb"

@export var kind := "house"
@export var variant := 0
@export var size := Vector3(8, 6, 8)
@export var color_a := Color("e8dcc0")
@export var color_b := Color("b05a3a")
@export var color_c := Color("6a4a30")
@export var label := ""
@export var collide := true
@export var seed_v := 0
## Explicit modular assembly; assigned only to selected valley instances.
## Native metre scale, authored materials and open-door collision are preserved.
@export_file("*.scn", "*.tscn") var asset_scene := ""

static var _nominal := {}
var _gen: Node3D

## 该 kind 是否有可用模型
static func has_model(k: String) -> bool:
	if not LIB.has(k):
		return false
	return ResourceLoader.exists(DIR + LIB[k][0] + "_0.glb")

static func nominal(name: String) -> Vector3:
	if _nominal.is_empty():
		var f := FileAccess.open(DIR + "models.json", FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_nominal = d
	var a: Array = _nominal.get(name, [1, 1, 1])
	return Vector3(a[0], a[1], a[2])

func model_name() -> String:
	var e: Array = LIB[kind]
	var v := variant % int(e[1])
	if kind == "cottage":
		v = 1
	return "%s_%d" % [e[0], v]

func _ready() -> void:
	if has_meta("stream_deferred") and not Engine.is_editor_hint():
		set_process(false)
		return
	set_process(false)
	rebuild()

## Same priority as rebuild; no speculative alternative resource loads in the streamer.
func stream_asset_paths() -> Array[String]:
	if asset_scene != "":
		return [_runtime_asset_path()]
	# 普通路灯只有一个正式铁艺资产；声明它才能让 WorldStream 预取同一模型。
	if kind in ["lamp", "lantern_post", "lamp2", "abbey_lamp"] and ResourceLoader.exists("res://assets/models/modkit/lamp_post_iron.glb"):
		return ["res://assets/models/modkit/lamp_post_iron.glb"]
	var kit := preload("res://src/world/goldshire_kit.gd")
	var id := kit.choice(self)
	if id != "":
		var baked := kit.baked_path(id)
		if baked != "":
			return [baked]
		# Missing/outdated derived cache uses the original builder, preserving content.
		if FileAccess.file_exists(kit.DIR + "assemblies/" + id + ".glb"):
			return []
	var tripo := _tripo_id()
	if tripo != "":
		return [TRIPO_DIR + tripo + ".glb"]
	return [_library_path()] if LIB.has(kind) else []

func _library_path() -> String:
	var path := DIR + model_name() + ".glb"
	return path if ResourceLoader.exists(path) else DIR + LIB[kind][0] + "_0.glb"

func rebuild() -> void:
	_spin = null
	_anim.clear()
	_bob = false
	set_process(false)
	_snap_tent_to_terrain()
	if _gen and is_instance_valid(_gen):
		_gen.free()
	_gen = Node3D.new()
	_gen.name = "_gen"
	add_child(_gen)
	if _try_asset_scene():
		return
	# 农田只生成内缩的独立田垄；外围泥地由地形实例的控制图提供。
	if kind == "field":
		_build_field_rows()
		return
	# 所有普通街灯复用正式铁艺灯柱；修道院的显式 asset_scene 保持原样。
	if kind in ["lamp", "lantern_post", "lamp2", "abbey_lamp"] and _try_formal_lamp():
		return
	if preload("res://src/world/goldshire_kit.gd").try_build(self, _gen):
		return
	if _try_tripo():
		return
	if not LIB.has(kind):
		return
	var mn := model_name()
	var path := _library_path()
	var ps: PackedScene = load(path)
	if ps == null:
		return
	var nom := nominal(mn)
	var mode: String = LIB[kind][2]
	var sc := Vector3.ONE
	match mode:
		"full": sc = size / nom
		"x": sc = Vector3.ONE * (size.x / nom.x)
		"y": sc = Vector3.ONE * (size.y / nom.y)
		"fixed": sc = Vector3.ONE
	if mode == "tile2":
		var nx := maxi(1, int(round(size.x / nom.x)))
		var nz := maxi(1, int(round(size.z / nom.z)))
		for ix in nx:
			for iz in nz:
				var t := ps.instantiate()
				_gen.add_child(t)
				t.position = Vector3(-size.x * 0.5 + (ix + 0.5) * size.x / nx, 0, -size.z * 0.5 + (iz + 0.5) * size.z / nz)
				t.scale = Vector3(size.x / nx / nom.x, 1.0, size.z / nz / nom.z)
	elif mode == "tile":
		var n := maxi(1, int(round(size.x / nom.x)))
		var mw := size.x / n
		var sz := size.z / nom.z if kind == "wall" else 1.0
		for i in n:
			var inst := ps.instantiate()
			_gen.add_child(inst)
			inst.position = Vector3(-size.x * 0.5 + (i + 0.5) * mw, 0, 0)
			inst.scale = Vector3(mw / nom.x, size.y / nom.y, sz)
	else:
		var inst2 := ps.instantiate()
		_gen.add_child(inst2)
		inst2.scale = sc
	_recolor(_gen)
	if collide and not Engine.is_editor_hint():
		_add_collision(mode, nom, sc)
	if label != "" or kind == "sign":
		_signboard()
	if not Engine.is_editor_hint():
		_extras(sc)
		if flag != "" and kind != "gate":
			add_to_group("gates")
			refresh_gate()
	if kind in ["lamp", "lantern_post", "lamp2", "abbey_lamp"] and not Engine.is_editor_hint():
		# 与程序化街灯一致：夜间由 World._update_lamps 打开最近的 14 盏
		var l := OmniLight3D.new()
		l.position = Vector3(0, 3.1, -0.75) if kind == "abbey_lamp" else Vector3(0.55 * sc.x, 3.85 * sc.y, 0)
		l.light_color = Color("ffcf80")
		l.omni_range = 9.0
		l.light_energy = 1.4
		l.shadow_enabled = false
		l.visible = false
		l.add_to_group("lamp_lights")
		_gen.add_child(l)

func _build_field_rows() -> void:
	var outer_w := maxf(size.x, 1.5)
	var outer_d := maxf(size.z, 1.5)
	var inset := minf(1.6, minf(outer_w, outer_d) * 0.16)
	var inner_w := maxf(outer_w - inset * 2.0, 1.0)
	var inner_d := maxf(outer_d - inset * 2.0, 1.0)
	var field_nom := nominal(model_name())
	var nx := maxi(1, roundi(inner_w / maxf(field_nom.x, 0.01)))
	var nz := maxi(1, roundi(inner_d / maxf(field_nom.z, 0.01)))
	var tile_w := inner_w / nx
	var tile_d := inner_d / nz
	var terrain = U.terrain_at(get_tree(), global_position.x, global_position.z) if is_inside_tree() else null
	var soil := _field_material("t6_farm.png", Color("aa9274"), 1.0)
	# 泥地已在地形控制图中涂好，不铺整块有厚度的浮空底板。
	# 原作物资产每块5行，泥垄与原模型的行距严格一致，条带之间露出泥地。
	for i in nz * 5:
		var z := -inner_d * 0.5 + (i + 0.5) * tile_d / 5.0
		var strip_d := minf(0.52, tile_d / 5.0 * 0.42)
		U.add_mesh(_gen, _field_strip(inner_w, z, strip_d, terrain), soil)
	var parts := _field_crop_parts()
	for part in parts:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part
		mm.instance_count = nx * nz
		for ix in nx:
			for iz in nz:
				var p := Vector3(-inner_w * 0.5 + (ix + 0.5) * tile_w, 0, -inner_d * 0.5 + (iz + 0.5) * tile_d)
				p.y = _field_ground(p, terrain) + 0.045
				mm.set_instance_transform(ix * nz + iz, Transform3D(Basis.from_scale(Vector3(tile_w / field_nom.x, 1.0, tile_d / field_nom.z)), p))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		_gen.add_child(mi)
		var mat := part.surface_get_material(0)
		var nm := mat.resource_name if mat else ""
		var col: Color = mat.albedo_color if mat is BaseMaterial3D else Color.WHITE
		if nm == "B":
			col = color_b
		mi.material_override = U.bmat(_mtype(nm, col), col)
	if not Engine.is_editor_hint() and is_inside_tree():
		GrassField.add_blocker(self, AABB(Vector3(-outer_w * 0.5, -1, -outer_d * 0.5), Vector3(outer_w, 3, outer_d)))

## 拆下旧field模型的soil表面，只复用真实庄稼网格，保持原形状/行距。
func _field_crop_parts() -> Array[ArrayMesh]:
	var parts: Array[ArrayMesh] = []
	var ps := load(_library_path()) as PackedScene
	if ps == null:
		return parts
	var source := ps.instantiate() as Node3D
	for v in source.find_children("*", "MeshInstance3D", true, false):
		var mi := v as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if mat and mat.resource_name.to_lower().contains("soil"):
				continue
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_material(mat)
			st.append_from(mi.mesh, i, _rel_xf(mi, source))
			parts.append(st.commit())
	source.free()
	return parts

func _field_ground(p: Vector3, terrain: BrushTerrain) -> float:
	if terrain == null:
		return 0.0
	var world_p := global_transform * p
	world_p.y = terrain.get_height_global(world_p.x, world_p.z)
	return (global_transform.affine_inverse() * world_p).y

func _field_strip(width: float, z: float, depth: float, terrain: BrushTerrain) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := maxi(1, ceili(width / 2.0))
	for i in steps:
		for j in 2:
			var points: Array[Vector3] = []
			for ix in 2:
				for iz in 2:
					var p := Vector3(-width * 0.5 + (i + ix) * width / steps, 0, z - depth * 0.5 + (j + iz) * depth * 0.5)
					p.y = _field_ground(p, terrain) + (0.055 if j + iz == 1 else 0.025)
					points.append(p)
			for k in [0, 1, 2, 1, 3, 2]:
				var p := points[k]
				st.set_uv(Vector2(p.x, p.z) / 7.0)
				st.add_vertex(p)
	st.generate_normals()
	return st.commit()

func _field_material(file_name: String, tint: Color, scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	var path := "res://assets/textures/terrain/" + file_name
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.uv1_scale = Vector3(scale, scale, scale)
	return m

func _try_formal_lamp() -> bool:
	var path := "res://assets/models/modkit/lamp_post_iron.glb"
	var ps: PackedScene = load(path) if ResourceLoader.exists(path) else null
	if ps == null:
		return false
	var inst := ps.instantiate() as Node3D
	_gen.add_child(inst)
	var bb := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var cur: Node = mi
		while cur != inst and cur is Node3D:
			xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		var a := xf * (mi as MeshInstance3D).get_aabb()
		bb = a if first else bb.merge(a)
		first = false
	if first or bb.size.y <= 0.01:
		inst.queue_free()
		return false
	var target_w := maxf(size.x, 0.8)
	var target_d := maxf(size.z, 0.8)
	# 模型原点就是灯杆落地点；保持xz相同比例与正式铁艺轮廓，避免AABB
	# 居中把灯柱移到道路一侧。
	var sx := minf(target_w / maxf(bb.size.x, 0.01), target_d / maxf(bb.size.z, 0.01))
	var sz := sx
	var sy := maxf(size.y, 3.0) / bb.size.y
	inst.scale = Vector3(sx, sy, sz)
	inst.position = Vector3.ZERO
	_apply_kit(inst)
	if not Engine.is_editor_hint():
		var l := OmniLight3D.new()
		l.position = Vector3(0, 2.98 * sy, 0.70 * sz)
		l.light_color = Color("ffcf80")
		l.omni_range = 9.0
		l.light_energy = 1.4
		l.shadow_enabled = false
		l.visible = false
		l.add_to_group("lamp_lights")
		_gen.add_child(l)
	return true

## Tents are authored by their centre point. On a slope that leaves the low
## corners visibly hovering, so use the lowest sampled footprint corner as the
## placement datum (the same rule used by ZoneBuilder.building()).
func _snap_tent_to_terrain() -> void:
	if kind != "tent" or Engine.is_editor_hint() or not is_inside_tree():
		return
	var terrain = U.terrain_at(get_tree(), global_position.x, global_position.z)
	if terrain == null:
		return
	var ground: float = terrain.get_height_global(global_position.x, global_position.z)
	var half_x := size.x * 0.5
	var half_z := size.z * 0.5
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var q: Vector3 = global_transform * Vector3(half_x * sx, 0.0, half_z * sz)
			ground = minf(ground, terrain.get_height_global(q.x, q.z))
	var p := global_position
	p.y = ground + 0.05
	global_position = p

static var _village_runtime_paths := {}
func _runtime_asset_path() -> String:
	if "original_village" in OS.get_cmdline_user_args(): return asset_scene
	if not asset_scene.begins_with("res://assets/models/village_kit/"):
		return asset_scene
	if not _village_runtime_paths.has(asset_scene):
		var baked := "res://assets/streaming/village/" + asset_scene.get_file().get_basename()
		# Exported GLBs/scripts are remapped; source hashes are only available in the workspace.
		if not OS.has_feature("editor"):
			_village_runtime_paths[asset_scene] = baked + ".scn" if ResourceLoader.exists(baked + ".scn") else asset_scene
			return _village_runtime_paths[asset_scene]
		var signature := FileAccess.get_sha256(asset_scene) + ":" + FileAccess.get_sha256("res://tools/vale_runtime/bake_village.gd")
		_village_runtime_paths[asset_scene] = baked + ".scn" if FileAccess.file_exists(baked + ".sha256") and FileAccess.get_file_as_string(baked + ".sha256").strip_edges() == signature and ResourceLoader.exists(baked + ".scn") else asset_scene
	return _village_runtime_paths[asset_scene]

func _try_asset_scene() -> bool:
	if asset_scene.is_empty():
		return false
	var assembly := load(_runtime_asset_path()) as PackedScene
	if assembly == null:
		push_error("Cannot load assigned modular building: " + asset_scene)
		return false
	var instance := assembly.instantiate() as Node3D
	_gen.add_child(instance)
	set_meta("modular_asset_scene", asset_scene)
	_apply_kit(instance)
	CityMat.apply(instance)
	if flag != "" and not Engine.is_editor_hint():
		add_to_group("gates")
		refresh_gate()
	if not Engine.is_editor_hint():
		GrassField.add_blocker(self, _local_aabb(instance))
	if not collide or Engine.is_editor_hint():
		for body in instance.find_children("*", "CollisionObject3D", true, false):
			body.collision_layer = 0
			body.collision_mask = 0
	if label != "":
		_signboard()
	if not Engine.is_editor_hint():
		_spin = instance.get_node_or_null("Rotor") as Node3D
		_setup_village_auto_door()
		set_process(_spin != null or _auto_door_pivot != null)
		if kind in ["lamp", "lantern_post", "lamp2", "abbey_lamp"]:
			# 构件库铁艺路灯：灯笼在 (0, 3.0, 0.7)，夜间由 World._update_lamps 打开
			var l := OmniLight3D.new()
			l.position = Vector3(0, 3.0, 0.7)
			l.light_color = Color("ffcf80")
			l.omni_range = 9.0
			l.light_energy = 1.4
			l.shadow_enabled = false
			l.visible = false
			l.add_to_group("lamp_lights")
			_gen.add_child(l)
	return true

## 金穗镇村屋门扇是运行时节点：房屋 GLB 只保留门框和门洞，门扇由
## Blender 铰链资产在这里实例化。关闭时保留独立碰撞，打开后释放通行。
func _setup_village_auto_door() -> void:
	_auto_door_pivot = null
	_auto_door_collision = null
	if asset_scene.is_empty() or not asset_scene.contains("/village_kit/"):
		return
	var id := asset_scene.get_file().get_basename()
	if id in ["barn", "farmhouse"]:
		return # 谷仓双扇门仍由专用构件控制
	if _village_door_meta.is_empty():
		var f := FileAccess.open("res://assets/models/village_kit/buildings.json", FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_village_door_meta = parsed
	if not _village_door_meta.has(id):
		return
	var meta: Dictionary = _village_door_meta[id]
	var d: Array = meta.get("door", [])
	if d.size() < 2:
		return
	var scale_factor := float(meta.get("scale", 1.3043478))
	# T03's inner frame uses kit.door(dw-.2,dh-.1); "door" is an
	# approach point. bbox[1] records the actual front wall axis.
	var opening_w := 1.3 * scale_factor
	var opening_h := 2.3 * scale_factor
	var wall_t := 0.45 * scale_factor
	var floor_y := 0.14 * scale_factor
	var bbox: Array = meta.get("bbox", [])
	var wall_z := -float(bbox[1]) if bbox.size() >= 2 else float(d[1]) - (0.225 + (0.25 if bool(meta.get("porch", false)) else 0.9)) * scale_factor
	var frame_center := Vector3(float(d[0]), floor_y, wall_z)
	var w := opening_w - 0.036
	var h := opening_h - 0.044
	var pivot := Node3D.new()
	pivot.name = "AutoDoorPivot"
	# Room-side wall corner hinge: positive Y moves the right edge indoors.
	pivot.position = frame_center + Vector3(-opening_w * 0.5, 0.0, -wall_t * 0.5)
	_gen.add_child(pivot)
	var door_scene := load(VILLAGE_DOOR_ASSET) as PackedScene
	if door_scene == null:
		push_error("Village door asset missing: " + VILLAGE_DOOR_ASSET)
		return
	var leaf := door_scene.instantiate() as Node3D
	leaf.name = "DoorLeaf_BlenderHinged"
	pivot.add_child(leaf)
	# Apply the same project materials without _apply_kit's automatic trimesh
	# collision; the lightweight hinged box below is the only moving collider.
	for mi in leaf.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count():
			var sm := m3.mesh.surface_get_material(i)
			if sm:
				var km := U.kit_mat(sm.resource_name)
				if km:
					m3.set_surface_override_material(i, km)
	# The GLB includes a fixed timber reveal between the existing outer trim
	# and the room-side leaf. Keep its transform while detaching from the hinge.
	var fixed_frame := leaf.find_child("DoorFrame_Fixed_Root", true, false) as Node3D
	if fixed_frame:
		fixed_frame.reparent(_gen, true)
		var frame_body := StaticBody3D.new()
		frame_body.name = "DoorFrameRevealCollision"
		frame_body.collision_layer = 1
		frame_body.collision_mask = 0
		fixed_frame.add_child(frame_body)
		for mesh_node in fixed_frame.find_children("*", "MeshInstance3D", true, false):
			var frame_mesh := mesh_node as MeshInstance3D
			var frame_shape := CollisionShape3D.new()
			frame_shape.shape = frame_mesh.mesh.create_trimesh_shape()
			frame_shape.transform = _rel_xf(frame_mesh, fixed_frame)
			frame_body.add_child(frame_shape)
	# The dimensions describe the wood silhouette; hardware has small extra bounds.
	leaf.set_meta("door_dimensions_m", Vector3(w, h, 0.14))
	leaf.set_meta("door_frame_center_m", frame_center)
	leaf.set_meta("door_frame_opening_m", Vector3(opening_w, opening_h, wall_t))
	leaf.set_meta("door_closed_plane_m", wall_z - wall_t * 0.5 + 0.07)
	leaf.set_meta("door_profile_gap_m", 0.018)
	var body := StaticBody3D.new()
	body.name = "DoorLeafCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, h, 0.14)
	shape.shape = box
	shape.position = Vector3(opening_w * 0.5, 0.026 + h * 0.5, 0.07)
	body.add_child(shape)
	pivot.add_child(body)
	_auto_door_collision = shape
	_auto_door_pivot = pivot
	_auto_door_angle = 0.0
	_auto_door_target = 0.0

## 构件库（tools/blender/modkit）装配：K| 材质换成建筑着色器；没有自带碰撞体时按网格生成（玻璃 / 植物 / nocol 除外）
func _apply_kit(root: Node) -> void:
	var is_kit := false
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		if m3.mesh == null: continue
		for i in m3.mesh.get_surface_count():
			var sm := m3.mesh.surface_get_material(i)
			if sm == null:
				continue
			var km := U.kit_mat(sm.resource_name)
			if km != null:
				m3.set_surface_override_material(i, km)
				is_kit = true
	if not is_kit or not collide or Engine.is_editor_hint():
		return
	if not root.find_children("*", "CollisionObject3D", true, false).is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "KitCollision"
	root.add_child(body)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		if m3.mesh == null: continue
		var nm := String(m3.name).to_lower()
		if "glass" in nm or "ivy" in nm or "nocol" in nm or "flower" in nm:
			continue
		if "colonly" in nm:
			m3.visible = false   # 台阶斜坡等：只做碰撞
		var cs := CollisionShape3D.new()
		cs.shape = m3.mesh.create_trimesh_shape()
		body.add_child(cs)
		cs.transform = _rel_xf(m3, root)   # body 位于 root 原点

## 资产在本节点坐标系下的包围盒（不含不渲染的碰撞件）
func _local_aabb(inst: Node3D) -> AABB:
	var acc := AABB()
	var first := true
	for v in inst.find_children("*", "VisualInstance3D", true, false):
		var vi := v as VisualInstance3D
		if "colonly" in String(vi.name).to_lower():
			continue
		var b: AABB = _rel_xf(vi, self) * vi.get_aabb()
		acc = b if first else acc.merge(b)
		first = false
	return acc

func _rel_xf(n: Node3D, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf

## Tripo3D 精模（docs/buildings_v2，放入 assets/models/tripo/<id>.glb 即自动替换）：kind -> 候选 id（按 variant 轮换）
const TRIPO_DIR := "res://assets/models/tripo/"
const TRIPO := {
	"rowhouse": ["city_townhouse_a", "city_townhouse_b", "city_townhouse_c"], "townhouse": ["city_townhouse_a", "city_townhouse_b", "city_townhouse_c"],
	"corner": ["city_corner_tower"], "guildhouse": ["guild_adventurer"], "civic_hall": ["city_hall"], "cathedral2": ["cathedral"], "cathedral": ["cathedral"],
	"grand_station": ["grand_station"], "mage_tower": ["mage_tower"], "warehouse": ["warehouse"], "beacon": ["lighthouse"], "tholos": ["tholos"],
	"house": ["vale_cottage_timber", "vale_cottage_thatch"], "cottage": ["vale_cottage_thatch"], "windmill": ["vale_windmill"], "church": ["vale_abbey_chapel"],
	"stall": ["prop_market_stall"], "lamp2": ["prop_lamppost"], "fountain": ["prop_well_fountain"], "hall": ["bank_exchange"],
}
## 按招牌文字选用专门的店铺模型
const TRIPO_LABEL := {"武器店": "shop_smithy", "锻铁匠行会": "shop_smithy", "药剂店": "shop_potion", "道具店": "shop_general", "珍品阁": "shop_general",
	"幻化工坊": "shop_florist", "珠宝店": "shop_florist", "海鸥酒馆": "tavern", "旅人之歌酒馆": "tavern", "交易所": "bank_exchange", "公共图书馆": "bank_exchange"}
static var _tripo_aabb := {}

func _tripo_id() -> String:
	var cands: Array = []
	if TRIPO_LABEL.has(label):
		cands = [TRIPO_LABEL[label]]
	elif TRIPO.has(kind):
		cands = TRIPO[kind]
	if cands.is_empty():
		return ""
	var avail := []
	for c in cands:
		if ResourceLoader.exists(TRIPO_DIR + c + ".glb"):
			avail.append(c)
	if avail.is_empty():
		return ""
	return avail[(variant + seed_v) % avail.size()]

func _try_tripo() -> bool:
	if Engine.is_editor_hint() and not ResourceLoader.exists(TRIPO_DIR):
		return false
	var id := _tripo_id()
	if id == "":
		return false
	var ps: PackedScene = load(TRIPO_DIR + id + ".glb")
	if ps == null:
		return false
	var inst := ps.instantiate()
	_gen.add_child(inst)
	var bb: AABB = _tripo_aabb.get(id, AABB())
	if bb.size == Vector3.ZERO:
		var first := true
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var xf: Transform3D = Transform3D.IDENTITY
			var n: Node = mi
			while n != null and n != inst:
				xf = (n as Node3D).transform * xf if n is Node3D else xf
				n = n.get_parent()
			var a2: AABB = xf * (mi as MeshInstance3D).get_aabb()
			bb = a2 if first else bb.merge(a2)
			first = false
		_tripo_aabb[id] = bb
	if bb.size.x <= 0.0:
		return false
	# 底面中心对齐原点，按 size 缩放（保持宽深比例取较小者，高度按 size.y 允许 ±25% 偏差）
	var s := minf(size.x / bb.size.x, size.z / bb.size.z)
	var sy := clampf(size.y / bb.size.y, s * 0.8, s * 1.25)
	inst.scale = Vector3(s, sy, s)
	inst.position = -Vector3((bb.position.x + bb.size.x * 0.5) * s, bb.position.y * sy, (bb.position.z + bb.size.z * 0.5) * s)
	for mi2 in inst.find_children("*", "MeshInstance3D", true, false):
		(mi2 as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if collide and not Engine.is_editor_hint():
		var body := StaticBody3D.new()
		_gen.add_child(body)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(bb.size.x * s, bb.size.y * sy, bb.size.z * s)
		cs.shape = bs
		cs.position = Vector3(0, bs.size.y * 0.5, 0)
		body.add_child(cs)
	if not Engine.is_editor_hint():
		_extras(Vector3(s, sy, s))
	return true

func _recolor(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			var mi: MeshInstance3D = c
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			# 按尺寸做距离剔除：无缝大世界里远处城市/小道具不必绘制（大地标保留远景轮廓）
			var big := maxf(size.x, maxf(size.y, size.z))
			mi.visibility_range_end = clampf(big * 45.0, 140.0, 1800.0)
			mi.visibility_range_end_margin = 20.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s)
				var nm := m.resource_name if m else ""
				var col: Color = (m as BaseMaterial3D).albedo_color if m is BaseMaterial3D else Color.WHITE
				match nm:
					"copper": col = Color("5a9886")
					"A": col = color_a
					"B": col = color_b
					"C": col = color_c
				if nm == "glass":
					mi.set_surface_override_material(s, Prop.get_window_mat())
				elif nm == "lamp":
					mi.set_surface_override_material(s, Prop.get_lamp_mat())
				elif nm == "flame":
					mi.set_surface_override_material(s, U.unshaded(_flame_color()))
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				elif nm == "glow":
					mi.set_surface_override_material(s, U.unshaded(_glow_color(), kind == "portal_ring"))
				elif nm == "water":
					mi.set_surface_override_material(s, _water_mat())
				else:
					mi.set_surface_override_material(s, U.bmat(_mtype(nm, col), col))
		_recolor(c)

const STONE_KINDS := ["wall", "tower", "gate", "platform", "block", "bridge", "arch", "ruin_wall", "column", "pillar", "pillar_row", "obelisk", "culvert", "beacon", "ramp", "well", "fountain", "statue", "goddess", "grave", "altar"]
const WOOD_KINDS := ["pier", "crate", "barrel", "cart", "fence", "bench", "sign", "crane", "boat", "haystack", "chair", "stool", "table", "bucket", "basket", "wood_pile", "trough", "wheelbarrow"]
const PLANT_KINDS := ["tree", "hedge", "bush", "flowerbed", "flower", "cypress", "flower_pot"]
const CLOTH_KINDS := ["stall", "tent", "banner", "awning", "airship"]

## 材质名 + 颜色 -> 建筑着色器类型（见 U.bmat）
func _mtype(nm: String, col: Color) -> int:
	var brick := (col.h < 0.07 or col.h > 0.96) and col.s > 0.35 and col.v < 0.85
	var woody := col.h > 0.03 and col.h < 0.13 and col.s > 0.25 and col.v < 0.6
	match nm:
		"A":
			if kind in PLANT_KINDS:
				return 8
			if brick:
				return 1
			if kind in WOOD_KINDS or (woody and kind not in STONE_KINDS):
				return 6
			if kind in STONE_KINDS:
				return 2
			return 0
		"B":
			if kind in PLANT_KINDS:
				return 8
			if kind in CLOTH_KINDS:
				return 0
			if col.h > 0.36 and col.h < 0.56 and col.s > 0.2:
				return 5
			if (col.h < 0.09 or col.h > 0.95) and col.s > 0.4:
				return 4
			if kind in STONE_KINDS and col.s < 0.3:
				return 2
			return 3
		"C":
			if kind in PLANT_KINDS:
				return 6
			if woody or kind in WOOD_KINDS:
				return 6
			return 9
		"stone", "stone_dark":
			return 2
		"door", "wood_dark", "wood":
			return 6
		"metal", "gold":
			return 7
		"plant":
			return 8
		"thatch", "terracotta":
			return 4
		"brick":
			return 1
		"copper":
			return 5
		"slate":
			return 3
		"white", "beige", "sandstone", "concrete", "red", "fruit_g", "bread":
			return 9
		"sack", "cloth", "rope", "wheat", "soil":
			return 0
		"iron", "red_steel", "bronze":
			return 7
		"leaf", "leaf2", "flower_w", "flower_p", "flower_y", "flower_r":
			return 8
		"trunk":
			return 6
		"slate_dark":
			return 3
		"bronze":
			return 7
	return 0

## 可以走进去/走到下面的建筑：用模型网格的精确碰撞（按 模型+缩放 缓存），其余用包围盒
const MESH_COLLIDE := ["abbey_gate", "tholos", "grand_station", "viaduct", "rotunda", "gazebo", "arch", "bridge", "pier", "market_hall", "station", "terminal", "ramp", "culvert", "gate", "pillar_row", "mine_entrance", "crane", "well"]
static var _shape_cache := {}

func _add_collision(mode: String, nom: Vector3, sc: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	_gen.add_child(body)
	if kind in MESH_COLLIDE and mode != "tile" and mode != "tile2":
		var key := "%s_%s" % [model_name(), str(sc.snapped(Vector3.ONE * 0.01))]
		var shape: ConcavePolygonShape3D = _shape_cache.get(key)
		if shape == null:
			var faces := PackedVector3Array()
			for mi in _gen.find_children("*", "MeshInstance3D", true, false):
				var xf: Transform3D = _gen.global_transform.affine_inverse() * mi.global_transform if mi.is_inside_tree() else mi.transform
				if not mi.is_inside_tree():
					var n: Node = mi.get_parent()
					while n != null and n != _gen:
						xf = n.transform * xf
						n = n.get_parent()
				for f in mi.mesh.get_faces():
					faces.append(xf * f)
			shape = ConcavePolygonShape3D.new()
			shape.backface_collision = true
			shape.set_faces(faces)
			_shape_cache[key] = shape
		var cs0 := CollisionShape3D.new()
		cs0.shape = shape
		body.add_child(cs0)
		return
	var ext: Vector3
	match mode:
		"tile": ext = Vector3(size.x, size.y, size.z if kind == "wall" else 0.25)
		"full": ext = Vector3(size.x, size.y * 1.15, size.z)
		_: ext = nom * sc
	if kind in ["stall", "tent", "cart", "bench"]:
		ext.y = minf(ext.y, 1.1)
	ext = ext.abs().max(Vector3(0.1, 0.1, 0.1))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = ext
	cs.shape = bs
	cs.position = Vector3(0, ext.y * 0.5, 0)
	body.add_child(cs)

func _flame_color() -> Color:
	if kind == "brazier" and color_b != Color("b05a3a"):
		return color_b
	return Color("ffa030")

func _glow_color() -> Color:
	if kind == "signal_lamp":
		return Color("ff4040") if variant == 0 else Color("40ff60")
	if kind == "portal_ring":
		return Color(color_b.r, color_b.g, color_b.b, 0.6)
	return color_b

func _water_mat() -> ShaderMaterial:
	var wm := ShaderMaterial.new()
	wm.shader = WATER_SHADER
	WaterStyle.configure(wm, 0.20)
	if ResourceLoader.exists("res://assets/textures/env/water_normal.png"):
		wm.set_shader_parameter("detail_normal", load("res://assets/textures/env/water_normal.png"))
	wm.set_shader_parameter("noise_tex", BrushTerrain.get_noise_texture())
	wm.set_shader_parameter("has_height", 0.0)
	wm.set_shader_parameter("shallow", Color(0.49, 0.74, 0.65, 0.65))
	wm.set_shader_parameter("minimum_depth", 0.5)
	return wm

## 动态部件：火光与火星、喷泉水花、风车叶片
func _extras(sc: Vector3) -> void:
	match kind:
		"campfire", "brazier":
			var top := 0.9 if kind == "campfire" else 2.0
			preload("res://src/render/local_light.gd").attach(_gen, Vector3(0, top, 0), _flame_color().lerp(Color("ffb060"), 0.3), 9.0, 2.0, true)
			_gen.add_child(_particles(Vector3(0, top - 0.3, 0), 14, 0.9, Color(1, 0.6, 0.2, 0.8), 0.16, Vector3(0, 1.5, 0), 0.6, 1.2))
		"fountain":
			_gen.add_child(_particles(Vector3(0, 4.2 * sc.y, 0), 60, 1.3, Color(0.8, 0.95, 1.0, 0.7), 0.15, Vector3(0, -9.8, 0), 3.0, 4.0, 30.0))
		"train":
			# The already-lit carriage windows now spill a little warm light onto rails.
			for side in [-1.0, 1.0]:
				preload("res://src/render/local_light.gd").attach(_gen, Vector3(side * 1.7, 2.7, 7.0), Color("ffd394"), 8.5, 2.0, false, true)
		"tholos":
			_gen.add_child(_particles(Vector3(0, 3.2 * sc.y, 0), 40, 1.0, Color(0.8, 0.95, 1.0, 0.7), 0.12, Vector3(0, -9.8, 0), 2.5, 3.2, 25.0))
		"goddess":
			var s := sc.y
			_light(Vector3(-3.1 * s, 32.8 * s, -0.5 * s), Color("bff4ff"), 18.0 * s)
			_ring(Vector3(0, 18.0 * s, 0), 6.1 * s, 0.12 * s, Color(0.6, 0.9, 1.0, 0.55), "spin", 0.25)
		"beacon":
			var top := (30.0 + 2.0) * sc.y
			_light(Vector3(0, top, 0), Color("bff0ff"), 30.0)
			var beam := Node3D.new()
			beam.position = Vector3(0, top, 0)
			_gen.add_child(beam)
			for sx in [-1, 1]:
				U.add_mesh(beam, U.cyl_mesh(0.4, 4.0, 70.0, 10), U.unshaded(Color(0.8, 0.95, 1.0, 0.13), true), Vector3(sx * 35.0, 0, 0), Vector3(0, 0, 90), Vector3.ONE, false)
			beam.add_to_group("night_only")
			_anim.append([beam, "spin", 0.5])
		"mage_tower":
			var w := size.x
			var top2 := size.y * 0.8
			for k in 3:
				var r := _ring(Vector3(0, top2 * (0.45 + k * 0.22), 0), w * (0.85 - k * 0.12), 0.18, Color(color_c.r, color_c.g, color_c.b, 0.75), "spin", (0.3 + k * 0.2) * (1 if k % 2 == 0 else -1))
				r.rotation_degrees = Vector3(12 * (k - 1), 0, 8 * k)
			_light(Vector3(0, size.y + 4.0, 0), color_c.lightened(0.3), 24.0)
		"rotunda":
			var r2 := size.x * 0.5
			_ring(Vector3(0, 1.6 + r2 * 0.38 + 0.6, 0), r2 * 0.35, r2 * 0.03, Color(color_c.r, color_c.g, color_c.b, 0.85), "spin_z", 0.5, true)
			_light(Vector3(0, 1.6 + r2 * 0.38 + 0.6, 0), color_c, 16.0)
		"bathhouse":
			for sx in [-1, 1]:
				_gen.add_child(_particles(Vector3(sx * size.x * 0.32, size.y + 4.0, 0), 24, 3.0, Color(1, 1, 1, 0.25), 1.6, Vector3(0.3, 0.6, 0), 0.8, 1.4, 20.0))
		"guildhouse":
			if variant % 4 == 1:
				for zz in [1.8, 5.4]:
					_gen.add_child(_particles(Vector3(6.6 * sc.x, 22.2 * sc.y, zz * sc.z), 18, 4.0, Color(0.35, 0.35, 0.38, 0.35), 1.4, Vector3(0.4, 0.5, 0), 1.0, 1.6, 12.0))
		"galleon", "steamship", "airship":
			_bob = true
			set_process(true)
		"gate":
			if flag != "":
				add_to_group("gates")
				refresh_gate()
		"windmill":
			var bp: PackedScene = load(DIR + "windmill_blades_0.glb")
			if bp:
				_spin = Node3D.new()
				_spin.position = Vector3(0, 11.9 * sc.y, -3.35 * sc.z)
				_gen.add_child(_spin)
				var bl := bp.instantiate()
				bl.scale = Vector3.ONE * sc.x
				_spin.add_child(bl)
				_recolor(_spin)
				set_process(true)

func _particles(pos: Vector3, amount: int, life: float, col: Color, sz: float, grav: Vector3, v0: float, v1: float, spread: float = 15.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.position = pos
	p.direction = Vector3.UP
	p.spread = spread
	p.gravity = grav
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	var qm := QuadMesh.new()
	qm.size = Vector2(sz, sz)
	var mm := U.unshaded(col, true).duplicate()
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = mm
	p.mesh = qm
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	return p

func _process(delta: float) -> void:
	_t += delta
	if _spin and is_instance_valid(_spin):
		_spin.rotation.z += delta * 0.5
	for a in _anim:
		if a[1] == "spin":
			a[0].rotation.y += delta * a[2]
		else:
			a[0].rotation.z += delta * a[2]
	if _bob and _gen:
		_gen.position.y = sin(_t * 0.9 + seed_v) * 0.12
		_gen.rotation.z = sin(_t * 0.7 + seed_v * 0.3) * 0.02
	if _auto_door_pivot and is_instance_valid(_auto_door_pivot):
		var near := false
		if is_instance_valid(Game.player):
			near = _auto_door_pivot.global_position.distance_squared_to(Game.player.global_position) <= VILLAGE_DOOR_RANGE * VILLAGE_DOOR_RANGE
		_auto_door_target = VILLAGE_DOOR_OPEN if near else 0.0
		_auto_door_angle = lerp_angle(_auto_door_angle, _auto_door_target, minf(delta * 7.0, 1.0))
		_auto_door_pivot.rotation.y = _auto_door_angle
		if _auto_door_collision and is_instance_valid(_auto_door_collision):
			# Keep the closed leaf solid; once it has cleared the jamb the player can pass.
			var disabled := absf(_auto_door_angle) > 0.12
			if _auto_door_collision.disabled != disabled:
				_auto_door_collision.disabled = disabled

func _light(pos: Vector3, col: Color, rng: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.omni_range = rng
	l.light_energy = 1.6
	_gen.add_child(l)

## 发光旋转环（动画部件）；upright = 竖直（门户）
func _ring(pos: Vector3, r: float, thick: float, col: Color, anim: String, speed: float, upright: bool = false) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	_gen.add_child(n)
	U.add_mesh(n, U.torus_mesh(r, r + thick, 48), U.unshaded(col, true), Vector3.ZERO, Vector3(90, 0, 0) if upright else Vector3.ZERO)
	if upright:
		U.add_mesh(n, U.cyl_mesh(r, r, 0.05, 40), U.unshaded(Color(col.r, col.g, col.b, 0.5), true), Vector3.ZERO, Vector3(90, 0, 0))
	_anim.append([n, anim, speed])
	set_process(true)
	return n

func refresh_gate() -> void:
	if _gen == null:
		return
	var old := _gen.get_node_or_null("Barrier")
	if old:
		old.free()
	if flag == "" or Engine.is_editor_hint() or Game.has_flag(flag):
		return
	var b := StaticBody3D.new()
	b.name = "Barrier"
	b.collision_layer = 1
	_gen.add_child(b)
	U.add_box_shape(b, Vector3(size.x, size.y + 4.0, 1.0), Vector3(0, size.y * 0.5, 0))
	U.add_mesh(b, U.box_mesh(Vector3(size.x, size.y, 0.2)), U.unshaded(Color(0.4, 0.7, 1.0, 0.28), true), Vector3(0, size.y * 0.5, 0))

func _signboard() -> void:
	var n := Node3D.new()
	n.position = Vector3(0, minf(3.1, size.y * 0.55), -size.z * 0.5 - 0.35)
	if kind == "sign":
		n.position = Vector3(0, 1.92, 0)
	elif kind == "mine_entrance":
		n.position = Vector3(0, 4.9, -0.45)
	_gen.add_child(n)
	if kind == "sign":
		var l0 := _sign_label(label if label != "" else "→")
		l0.position = Vector3(0, 0, -0.07)
		n.add_child(l0)
		var l1 := _sign_label(label if label != "" else "→")
		l1.position = Vector3(0, 0, 0.07)
		l1.rotation_degrees.y = 0
		n.add_child(l1)
		return
	var w := maxf(1.6, label.length() * 0.42 + 0.6)
	U.add_mesh(n, U.box_mesh(Vector3(w, 0.75, 0.1)), U.mat(Color("f0e2c0")), Vector3.ZERO)
	U.add_mesh(n, U.box_mesh(Vector3(w + 0.14, 0.89, 0.08)), U.mat(Color("6a4a30")), Vector3(0, 0, 0.02))
	var l := Label3D.new()
	l.text = label
	l.font_size = 48
	l.pixel_size = 0.0085
	l.modulate = Color("3a2412")
	l.outline_size = 0
	l.position = Vector3(0, 0, -0.06)
	l.rotation_degrees.y = 180
	l.double_sided = false
	n.add_child(l)

func _sign_label(t: String) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font_size = 48
	l.pixel_size = 0.0085
	l.modulate = Color("3a2412")
	l.outline_size = 0
	l.rotation_degrees.y = 180
	l.double_sided = false
	return l

## 小地图轮廓（MapGen）
func map_footprint() -> Array:
	if kind in ["chair", "stool", "table", "bucket", "sack", "basket", "wood_pile", "trough", "wheelbarrow", "crate", "barrel", "bench", "fence", "cart", "grave", "sign", "campfire", "brazier", "anvil", "buoy", "signal_lamp", "obelisk", "web", "rug", "throne", "lamp", "lantern_post", "lamp2", "palm", "hero_statue", "banner", "tree", "haystack", "column", "pillar", "crystal", "boat", "bell", "statue"]:
		return []
	return [color_b.darkened(0.15), Vector2(size.x, size.z) if kind != "tower" else Vector2(size.x, size.x)]

## Release generated render/physics content; retain the authored descriptor.
func stream_unload() -> void:
	set_process(false)
	_spin = null
	_auto_door_pivot = null
	_auto_door_collision = null
	_auto_door_angle = 0.0
	_auto_door_target = 0.0
	_anim.clear()
	_bob = false
	GrassField.remove_blocker(self)
	if is_instance_valid(_gen):
		_gen.free()
	_gen = null
