extends Node3D
## 地标模型画廊：逐个摆放 Landmark 并截图，用于检查造型与比例
## godot --path . res://tests/gallery.tscn -- [out=目录] [only=kind1,kind2]

const ITEMS := [
	["goddess", Vector3(1, 40, 1), Color("f4f2ec"), Color("2f6fa8"), Color("e8e4dc"), 0, 70.0],
	["beacon", Vector3(6, 32, 6), Color("f4f2ec"), Color("2f6fa8"), Color("c8c0b0"), 0, 60.0],
	["clock_spire", Vector3(10, 34, 10), Color("e8dcc4"), Color("2f6fa8"), Color("c8c0b0"), 0, 75.0],
	["cathedral", Vector3(36, 22, 64), Color("f4f2ec"), Color("2f6fa8"), Color("c8c0b0"), 0, 110.0],
	["civic_hall", Vector3(64, 14, 30), Color("f4f2ec"), Color("2f6fa8"), Color("c8c0b0"), 0, 100.0],
	["opera", Vector3(44, 18, 40), Color("f4f2ec"), Color("3a80b8"), Color("c8c0b0"), 0, 85.0],
	["mage_tower", Vector3(12, 56, 12), Color("ece8f4"), Color("2f5fa8"), Color("a080ff"), 0, 85.0],
	["rotunda", Vector3(30, 12, 30), Color("f4f2ec"), Color("2f6fa8"), Color("80d0ff"), 0, 60.0],
	["bathhouse", Vector3(36, 9, 20), Color("e8dcc4"), Color("4a90c0"), Color("c8c0b0"), 0, 55.0],
	["hospital", Vector3(44, 12, 26), Color("f4f2ec"), Color("2f6fa8"), Color("c8c0b0"), 0, 65.0],
	["warehouse", Vector3(16, 9, 30), Color("e0d0b0"), Color("4a6a8a"), Color("a08a70"), 0, 50.0],
	["terminal", Vector3(30, 12, 36), Color("f4f2ec"), Color("2f6fa8"), Color("c8c0b0"), 0, 65.0],
	["rowhouse", Vector3(10, 13, 11), Color("f4f2ec"), Color("2f6fa8"), Color("3a6ab0"), 1, 32.0],
	["guildhouse", Vector3(22, 13, 18), Color("e8dcc4"), Color("2f6fa8"), Color("c04030"), 1, 50.0],
	["galleon", Vector3(7, 3, 32), Color.WHITE, Color("2f6fa8"), Color("7a5a3a"), 0, 55.0],
	["steamship", Vector3(9, 3, 40), Color("f4f2ec"), Color("2f6fa8"), Color.WHITE, 0, 60.0],
	["culvert", Vector3(6, 10, 20), Color("c8c0b0"), Color.WHITE, Color.WHITE, 0, 35.0],
	["market_hall", Vector3(24, 10, 40), Color("e8dcc4"), Color("2f6fa8"), Color.WHITE, 0, 65.0],
	["airship", Vector3(9, 9, 26), Color("f4f2ec"), Color("2f6fa8"), Color("6a4a30"), 1, 45.0],
	["gate", Vector3(14, 10, 3.2), Color("f4f2ec"), Color("2f6fa8"), Color("4a3a2a"), 0, 45.0],
	["tower", Vector3(11, 18, 11), Color("f4f2ec"), Color("2f6fa8"), Color("d8b060"), 0, 40.0],
	["station", Vector3(34, 12, 34), Color("e8dcc4"), Color("2f6fa8"), Color("f4f2ec"), 0, 75.0],
	["hall", Vector3(34, 12, 22), Color("f4f2ec"), Color("2f6fa8"), Color("d8b060"), 1, 60.0],
	["bridge", Vector3(12, 8.0, 22), Color("e0d8c8"), Color.WHITE, Color("f4f2ec"), 0, 40.0],
]
## mode=views：为 Tripo3D 文档输出 正视/侧视/俯视（正交）+ 透视 四张图
var views := false

var cam: Camera3D
var out_dir := ""
var only: PackedStringArray = []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out_dir = a.substr(4)
		if a.begins_with("only="):
			only = a.substr(5).split(",")
		if a == "mode=views":
			views = true
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path("res://.shots/gallery")
	DirAccess.make_dir_recursive_absolute(out_dir)
	if not FileAccess.file_exists(out_dir + "/../.gdignore"):
		FileAccess.open(ProjectSettings.globalize_path("res://.shots/.gdignore"), FileAccess.WRITE)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.78, 0.92)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.82, 0.9)
	e.ambient_light_energy = 0.75
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	ground.mesh = pm
	ground.material_override = U.mat(Color(0.55, 0.7, 0.42))
	add_child(ground)
	cam = Camera3D.new()
	cam.far = 2000.0
	add_child(cam)
	_run()

func _run() -> void:
	var i := 0
	for it in ITEMS:
		if not only.is_empty() and not (it[0] in only):
			continue
		var lm := Landmark.new()
		lm.kind = it[0]
		lm.size = it[1]
		lm.color_a = it[2]
		lm.color_b = it[3]
		lm.color_c = it[4]
		lm.variant = it[5]
		lm.label = "" if it[0] in ["galleon", "steamship"] else it[0]
		add_child(lm)
		var dist: float = it[6]
		var hgt: float = maxf(it[1].y, 10.0)
		if views:
			# 包围盒（含屋顶、尖塔等超出 size 的部分）
			for k in 2:
				await get_tree().process_frame
			var aabb := _aabb(lm)
			var c := aabb.get_center()
			var span := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z)) * 1.15
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = span
			for v in [["front", Vector3(0, 0, -1)], ["side", Vector3(1, 0, 0)], ["top", Vector3(0, 1, 0)]]:
				var dir: Vector3 = v[1]
				cam.position = c + dir * (span * 2.0 + 50.0)
				cam.look_at(c, Vector3.FORWARD if v[0] == "top" else Vector3.UP)
				await _save("%s/%s_%s.png" % [out_dir, it[0], v[0]])
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			cam.position = Vector3(dist * 0.55, hgt * 0.55 + dist * 0.25, -dist * 0.85)
			cam.look_at(Vector3(0, hgt * 0.4, 0))
			await _save("%s/%s_persp.png" % [out_dir, it[0]])
		else:
			cam.position = Vector3(dist * 0.55, hgt * 0.55 + dist * 0.25, -dist * 0.85)
			cam.look_at(Vector3(0, hgt * 0.4, 0))
			await _save("%s/%02d_%s.png" % [out_dir, i, it[0]])
		print("GALLERY ", it[0])
		lm.queue_free()
		i += 1
	print("GALLERY DONE")
	get_tree().quit()

func _save(path: String) -> void:
	for k in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null:
			continue
		var b2: AABB = mi.global_transform * mi.mesh.get_aabb()
		box = b2 if first else box.merge(b2)
		first = false
	return box
