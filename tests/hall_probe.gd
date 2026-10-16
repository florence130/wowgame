extends Node3D
## 室内白盒排查：只加载一个城市分块 GLB（不经过世界 / 雾 / 天空），在冒险者公会大厅里放一盏厅灯和相机，截两张图。
## Godot --path . res://tests/hall_probe.tscn   → .shots/hall_probe/*.png
const CHUNK := "res://assets/models/city_v7/chunk_-1_1.glb"
const SEA := 8.0
# 冒险者公会大厅（区域坐标，见 docs/city_v7/game.json halls）
const HALL := Vector3(-90.4, 17.38 + SEA, 390.8)
const CEIL := 27.38 + SEA

func _ready() -> void:
	var out := ProjectSettings.globalize_path("res://.shots/hall_probe")
	DirAccess.make_dir_recursive_absolute(out)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(1, 0, 1)          # 品红背景：哪里漏了一眼就能看出来
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.55)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var inst := (load(CHUNK) as PackedScene).instantiate() as Node3D
	inst.position = Vector3(-100, SEA, 300)      # chunk_-1_1 的中心：((i+0.5)*200, (j+0.5)*200)
	add_child(inst)
	CityMat.apply(inst)
	var l := OmniLight3D.new()
	l.position = Vector3(HALL.x, CEIL - 0.8, HALL.z)
	l.light_color = Color("ffe2b0")
	l.omni_range = 20.0
	l.light_energy = 1.6
	add_child(l)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.position = HALL + Vector3(0, 1.7, 0)
	for shot in [["up", Vector3(HALL.x - 4, CEIL, HALL.z - 3)], ["level", Vector3(HALL.x - 8, HALL.y + 2, HALL.z - 6)]]:
		cam.look_at(shot[1])
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/%s.png" % shot[0])
		print("HALL_PROBE ", shot[0])
	get_tree().quit()
