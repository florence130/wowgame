class_name GenSanctum
extends RefCounted
## 海神旧圣堂 v2（2026-10-12 全部重做）。
## 布局来源 tools/sanctum_v2/layout.py → Blender (tools/blender/sanctum_v2/build_shell.py) → assets/models/sanctum_v2/{sanctum_shell.glb, sanctum_data.json, terrain.f32}。
## 本生成器只读这些数据并摆放：外壳 GLB、岛屿地形、小怪、首领、三道封门、灯具、宝箱、入口传送。不再依赖旧 Unity 版 layout.json。
const DIR := "res://assets/models/sanctum_v2/"
const GATE = preload("res://src/world/sanctum_gate.gd")
const CHEST = preload("res://src/world/sanctum_chest.gd")
const DRESS = preload("res://tools/sanctum_v2_dressing.gd")
const SEA := -1.0

static func build() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "sanctum_data.json"))
	var tm: Dictionary = data.terrain
	var res := int(tm.resolution)
	var cs := float(tm.cell_size)
	var origin := Vector2(tm.origin[0], tm.origin[1])
	var b := ZoneBuilder.new("sanctum", res, cs, 20261012, origin)
	b.root.set("default_music", "dungeon")
	# 岛屿地形：Python 导出的高度图（行优先，(res+1)^2 个 float32）
	var raw := FileAccess.get_file_as_bytes(DIR + "terrain.f32").to_float32_array()
	b.data.heights = raw
	b.data.water_level = SEA
	b.data.layer_colors = PackedColorArray(ArtStyle.TERRAIN_COLORS)
	# 地形只作外部景观与山体；室内由外壳 GLB 自带地面碰撞，所以关掉高度场碰撞避免与外壳冲突
	b.terrain.collision_enabled = false
	_paint_terrain(b, data)
	_shell(b)
	_spawn_and_portal(b, data)
	_pulls(b, data)
	_bosses(b, data)
	_gates(b, data)
	DRESS.build(b, data)
	_scenery(b, data)
	b.save("res://data/terrain/sanctum.res", "res://scenes/zones/windwhisper_sanctum.tscn")
	b.root.free()

static func _paint_terrain(b: ZoneBuilder, data: Dictionary) -> void:
	# 岩石陡坡 / 苔藓 / 沙滩：外部景观用，不进入游戏空间
	b.paint_where(3, func(x, z, hv): return smoothstep(0.30, 0.62, b.slope(x, z)))
	b.paint_where(4, func(_x, _z, hv): return 1.0 - smoothstep(SEA + 0.2, SEA + 2.2, hv) if hv > SEA - 3.0 else 0.0)
	b.paint_where(8, func(x, z, hv): return 0.55 * (0.5 + 0.5 * b.n2(x * 3.0, z * 3.0)) if hv > 3.0 and hv < 25.0 else 0.0)

static func _shell(b: ZoneBuilder) -> void:
	var scene := load(DIR + "sanctum_shell.glb") as PackedScene
	var model := scene.instantiate() as Node3D
	model.name = "SanctumShell"
	b.groups.Buildings.add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count():
			var sm := m3.mesh.surface_get_material(i)
			if sm:
				var km := U.kit_mat(sm.resource_name)
				if km:
					m3.set_surface_override_material(i, km)
		var nm := String(m3.name).to_lower()
		if "colonly" in nm:
			m3.visible = false
		if "glass" in nm or "nocol" in nm:
			continue
		m3.create_trimesh_collision()

static func _spawn_and_portal(b: ZoneBuilder, data: Dictionary) -> void:
	var s: Dictionary = data.start
	# 入口（登岸栈桥起点）：出生点 / 墓地 / 返回潮风高地的传送环
	var sp := b.spawn_point("from_tidewind", s.x, s.z, rad_to_deg(float(s.yaw)))
	sp.position.y = float(s.y) + 0.3
	var gy := b.spawn_point("gy_sanctum_in", s.x + 2.0, s.z - 1.0, rad_to_deg(float(s.yaw)))
	gy.position.y = float(s.y) + 0.3
	var pt := b.portal("tidewind", "from_sanctum", "返回潮风高地", s.x - 3.0, s.z + 4.0, 3.0)
	pt.position.y = float(s.y)

static func _spawner(b: ZoneBuilder, mob: String, x: float, z: float, y: float, id: String, bounds: Rect2, flags: Array) -> MobSpawner:
	var sp := b.spawner(mob, x, z, 1, 0, 0, 0)
	sp.position.y = y + 0.1
	sp.encounter_room = id
	sp.encounter_bounds = bounds
	if not flags.is_empty():
		sp.required_flags = PackedStringArray(flags)
	sp.name = id + "_" + mob + "_" + str(b.groups.Spawners.get_child_count())
	return sp

static func _pulls(b: ZoneBuilder, data: Dictionary) -> void:
	var offs := [Vector2(-1.8, 1.0), Vector2(1.8, 1.0), Vector2(0.0, -2.2)]
	for pull in data.pulls:
		var p := Vector2(pull.x, pull.z)
		# 一组小怪的作战范围 = 以组为中心的 22m 方框（通道很窄，边界只用来防止被引出本组区域太远）
		var bounds := Rect2(p - Vector2(14, 14), Vector2(28, 28))
		for i in pull.mobs.size():
			_spawner(b, String(pull.mobs[i]), p.x + offs[i % 3].x, p.y + offs[i % 3].y, float(pull.y), String(pull.id), bounds, pull.flags)

static func _bosses(b: ZoneBuilder, data: Dictionary) -> void:
	for boss in data.bosses:
		var c := Vector2(boss.x, boss.z)
		var r := float(boss.r) + 4.0
		var bounds := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
		var sp := _spawner(b, String(boss.mob), c.x, c.y, float(boss.y), "boss_%d" % int(boss.number), bounds, boss.flags)
		if String(boss.flag) != "":
			sp.defeated_flag = String(boss.flag)
		var poi := b.poi("poi_boss_%d" % int(boss.number), String(boss.name), c.x, c.y, float(boss.r) + 6.0, 6, false, false)
		poi.position.y = float(boss.y)

static func _gates(b: ZoneBuilder, data: Dictionary) -> void:
	for g in data.gates:
		var gate := Node3D.new()
		gate.set_script(GATE)
		gate.set("flag", String(g.flag))
		gate.set("title", String(g.title))
		gate.set("width", float(g.width))
		gate.position = Vector3(g.x, g.y, g.z)
		# 门板法线对准行进方向：封门是 X 方向宽的薄板，yaw 取路线方向垂直
		gate.rotation.y = -float(g.yaw) + PI * 0.5
		gate.name = String(g.flag) + "_Gate"
		b.groups.Buildings.add_child(gate)

static func _scenery(b: ZoneBuilder, data: Dictionary) -> void:
	var tr: Dictionary = data.trees
	var pines: Array = []
	for p in tr.pine:
		pines.append(Vector2(p[0], p[1]))
	var rocks: Array = []
	for p in tr.rock:
		rocks.append(Vector2(p[0], p[1]))
	var bushes: Array = []
	for p in tr.bush:
		bushes.append(Vector2(p[0], p[1]))
	b.forest("pine", pines, Color("435d47"), 0.9, 1.5)
	b.forest("rock", rocks, Color("85867b"), 0.8, 2.2)
	b.forest("bush", bushes, Color("5a8a45"), 0.8, 1.3)
