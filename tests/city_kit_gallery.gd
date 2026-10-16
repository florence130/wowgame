extends Node3D
## 城市构件库陈列：manifest 里的全部构件按类别排开 + 3 栋 Blender 示范建筑 + 1 栋 CityKit.building() 运行时拼装楼，
## 截图到 .shots/city_kit/。Godot --path . res://tests/city_kit_gallery.tscn
const MAN := "res://assets/models/city_kit/manifest.json"

func _ready() -> void:
	var out := ProjectSettings.globalize_path("res://.shots/city_kit")
	DirAccess.make_dir_recursive_absolute(out)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("c9d6e3")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a0b6d3")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.3
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	ground.material_override = U.mat(Color("8f8a80"))
	add_child(ground)
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAN))
	var cats := {}
	for id in man.pieces:
		var c: String = man.pieces[id].category
		if not cats.has(c):
			cats[c] = []
		cats[c].append(id)
	var row := 0.0
	var count := 0
	for c in ["底层立面", "标准层立面", "线脚与转角", "屋顶", "塔楼与地标", "街具"]:
		var x := 0.0
		var depth := 0.0
		for id in cats.get(c, []):
			var sz: Array = man.pieces[id].size_m
			var mn: Array = man.pieces[id].min_m
			# Blender (x, y, z) 尺寸 → Godot (x, z, y)；按包围盒最小角对齐到当前格位
			var p := CityKit.piece(id, Transform3D(Basis.IDENTITY, Vector3(x - float(mn[0]), 0, row + float(mn[1]))), false)
			add_child(p)
			var lb := Label3D.new()
			lb.text = id
			lb.position = Vector3(x + float(sz[0]) / 2, float(sz[2]) + 0.6, row + 1.5)
			lb.font_size = 48
			lb.pixel_size = 0.01
			lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			add_child(lb)
			x += float(sz[0]) + 1.6
			depth = maxf(depth, float(sz[1]))
			count += 1
		row -= depth + 6.0
	print("KIT_GALLERY pieces=", count)
	# 示范建筑（Blender 拼装）
	var dx := 0.0
	for id in ["demo_haussmann_corner", "demo_cityhall", "demo_trade_row"]:
		var mn: Array = man.pieces[id].min_m
		add_child(CityKit.piece(id, Transform3D(Basis.IDENTITY, Vector3(dx - float(mn[0]), 0, 90 + float(mn[1]))), false))
		dx += float(man.pieces[id].size_m[0]) + 10.0
	# 运行时拼装：CityKit.building()
	var b := CityKit.building({"name": "runtime_block", "nx": 4, "nz": 3, "floors": 3, "gf": "SADS", "uf": ["balc", "pedi", "seg"],
		"wall": "stucco", "roof": "slate", "dormer": "oculus", "turret": true})
	b.position = Vector3(dx + 4, 0, 80)
	add_child(b)
	print("KIT_GALLERY runtime building children=", b.get_child_count(), " height=", b.get_meta("height"))
	var cam := Camera3D.new()
	cam.far = 1500
	add_child(cam)
	cam.current = true
	var shots := [
		["pieces_a", Vector3(34, 16, 22), Vector3(34, 3, -8)],
		["pieces_b", Vector3(40, 26, 10), Vector3(40, 2, -40)],
		["demos", Vector3(70, 32, 155), Vector3(70, 12, 80)],
		["runtime_block", b.position + Vector3(-14, 10, 22), b.position + Vector3(8, 9, -6)],
	]
	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2])
		for i in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/%s.png" % s[0])
		print("KIT_GALLERY shot ", s[0])
	get_tree().quit()
